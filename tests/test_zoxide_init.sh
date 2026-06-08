#!/bin/bash
# =============================================================================
# Idempotency test for the zoxide init step in zsh-config.sh.
#
# zoxide's init MUST be the last line of ~/.zshrc so it captures the final $PATH;
# otherwise its _ZO_DOCTOR check warns on every shell start. This test pins the
# step's behavior: it extracts the REAL block from zsh-config.sh (so the test
# cannot drift from the implementation) and runs it against representative
# fixtures, asserting that zoxide ends up as the single last non-blank line, that
# already-correct files are left byte-identical, and that surrounding lines
# survive a reposition.
#
# Usage: tests/test_zoxide_init.sh   (or: bash tests/test_zoxide_init.sh)
# Exit:  0 = all assertions passed, 1 = at least one failed.
# =============================================================================
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$SCRIPT_DIR/../zsh-config.sh"

if [ ! -f "$SCRIPT" ]; then
  echo "FATAL: cannot find zsh-config.sh at $SCRIPT" >&2
  exit 1
fi

# Extract from the 'zoxide_marker=' assignment through the first standalone 'fi'.
BLOCK="$(awk '/^zoxide_marker=/{f=1} f{print} f&&/^fi$/{exit}' "$SCRIPT")"
if [ -z "$BLOCK" ]; then
  echo "FATAL: could not extract the zoxide block from $SCRIPT" >&2
  exit 1
fi

# Portable SHA helper (GNU coreutils on Linux/CI, BSD shasum on macOS).
sha() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum
  else shasum -a 256
  fi
}

PASS=0
FAIL=0

# Stubs for the logging functions the extracted block calls.
log_info() { :; }
log_skip() { ACTION="skip"; }

assert() { # message, condition_exit_status (0 = pass)
  if [ "$2" -eq 0 ]; then
    echo "    PASS: $1"
    PASS=$((PASS + 1))
  else
    echo "    FAIL: $1"
    FAIL=$((FAIL + 1))
  fi
}

run_case() { # name, fixture_content, expected_action, [preserve_regex]
  local name="$1" fixture="$2" expect_action="$3" preserve="${4:-}"
  local tmp before after last count
  tmp="$(mktemp -d)"
  HOME="$tmp"
  printf '%b' "$fixture" > "$tmp/.zshrc"
  before="$(sha < "$tmp/.zshrc")"
  CONFIGURED=()
  ACTION=""

  eval "$BLOCK"

  if [ -z "$ACTION" ] && [ "${#CONFIGURED[@]}" -gt 0 ]; then
    ACTION="${CONFIGURED[${#CONFIGURED[@]} - 1]}"
  fi
  after="$(sha < "$tmp/.zshrc")"
  last="$(grep -vE '^[[:space:]]*$' "$tmp/.zshrc" | tail -n 1)"
  count="$(grep -c 'zoxide init' "$tmp/.zshrc")"

  echo "[$name]"
  echo "$last" | grep -q 'zoxide init'
  assert "zoxide init is the last non-blank line" $?
  [ "$count" -eq 1 ]
  assert "exactly one zoxide init line (got $count)" $?
  [ "$ACTION" = "$expect_action" ]
  assert "action == '$expect_action' (got '$ACTION')" $?
  if [ "$expect_action" = "skip" ]; then
    [ "$before" = "$after" ]
    assert "file unchanged (skip = no churn)" $?
  fi
  if [ -n "$preserve" ]; then
    grep -qE "$preserve" "$tmp/.zshrc"
    assert "preserved line still present: /$preserve/" $?
  fi
  echo
  rm -rf "$tmp"
}

CANON='eval "$(zoxide init --cmd cd zsh)"'
VARIANT='eval "$(zoxide init zsh --cmd cd)"'

run_case "S1: no zoxide present" \
  'export PATH=foo\nalias x=y\n' \
  "zoxide init"

run_case "S2: canonical, already last" \
  "alias x=y\n\n# zoxide (must be last)\n$CANON\n" \
  "skip"

run_case "S3: variant arg-order, already last" \
  "alias x=y\n# Zoxide\n$VARIANT\n" \
  "skip"

run_case "S4: stranded mid-file, pipx PATH appended after" \
  "# zoxide (must be last)\n$CANON\n\n# pipx\nexport PATH=\"\$PATH:\$HOME/.local/bin\"\n" \
  "zoxide init repositioned to end" \
  'export PATH=.*\.local/bin'

run_case "S5: duplicate stranded zoxide lines" \
  "$CANON\nalias a=b\n$VARIANT\nexport PATH=\"\$PATH:/x\"\n" \
  "zoxide init repositioned to end" \
  'export PATH=.*:/x'

run_case "S6: multiline comment, variant init already last" \
  "alias python=\"python3\"\n\n# Zoxide note line 1\n# note line 2 _ZO_DOCTOR\n$VARIANT\n" \
  "skip"

echo "=================================="
echo "RESULTS: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
