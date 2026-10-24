#!/bin/bash
# =============================================================================
# Test for the thefuck cleanup and fzf init steps in zsh-config.sh.
#
# On Ubuntu 24.04 earlier versions broke every shell start: the bare
# `eval "$(thefuck --alias)"` printed a traceback (apt thefuck crashes on Python
# 3.12+), and `eval "$(fzf --zsh)"` printed "unknown option: --zsh" (apt fzf is
# 0.44; --zsh arrived in 0.48). thefuck is no longer installed, so its init line
# is removed; the fzf block is rewritten in place with a fallback.
#
# This test extracts the REAL blocks from zsh-config.sh (between sentinel markers,
# so the test cannot drift from the implementation) and asserts:
#   thefuck : init line, its comment and the blank line before it removed;
#             surrounding lines kept; no-op when absent.
#   fzf     : block added when absent; old block replaced in place; current
#             file left byte-identical; an old eval line in an unexpected form
#             is reported and the file left untouched.
#
# Usage: tests/test_shell_init_heal.sh   (or: bash tests/test_shell_init_heal.sh)
# Exit:  0 = all assertions passed, 1 = at least one failed.
# =============================================================================
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$SCRIPT_DIR/../zsh-config.sh"

if [ ! -f "$SCRIPT" ]; then
  echo "FATAL: cannot find zsh-config.sh at $SCRIPT" >&2
  exit 1
fi

extract() { # marker-basename -> prints the block between its >>>/<<< sentinels
  awk -v m="$1" '
    $0 ~ ("# >>> " m)  {f=1; next}
    $0 ~ ("# <<< " m)  {f=0}
    f' "$SCRIPT"
}

THEFUCK_BLOCK="$(extract 'thefuck-rc-cleanup')"
FZF_BLOCK="$(extract 'fzf-init')"
if [ -z "$THEFUCK_BLOCK" ] || [ -z "$FZF_BLOCK" ]; then
  echo "FATAL: could not extract thefuck/fzf blocks from $SCRIPT" >&2
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
log_info()  { :; }
log_error() { ACTION="error"; }
log_skip()  { ACTION="skip"; }

assert() { # message, condition_exit_status (0 = pass)
  if [ "$2" -eq 0 ]; then
    echo "    PASS: $1"; PASS=$((PASS + 1))
  else
    echo "    FAIL: $1"; FAIL=$((FAIL + 1))
  fi
}

# run_case: name, block, zshrc_content, expected_action, [present_fixed], [absent_fixed]
# expected_action is "skip", "error", "none" (silent no-op), or the CONFIGURED
# entry the step records.
run_case() {
  local name="$1" block="$2" fixture="$3" expect_action="$4"
  local present="${5:-}" absent="${6:-}"
  local tmp before after
  tmp="$(mktemp -d)"
  HOME="$tmp"
  printf '%b' "$fixture" > "$tmp/.zshrc"
  before="$(sha < "$tmp/.zshrc")"
  CONFIGURED=()
  FAILED=()
  ACTION=""

  eval "$block"

  if [ -z "$ACTION" ] && [ "${#CONFIGURED[@]}" -gt 0 ]; then
    ACTION="${CONFIGURED[${#CONFIGURED[@]} - 1]}"
  fi
  [ -z "$ACTION" ] && ACTION="none"
  after="$(sha < "$tmp/.zshrc")"

  echo "[$name]"
  [ "$ACTION" = "$expect_action" ]
  assert "action == '$expect_action' (got '$ACTION')" $?
  if [ "$expect_action" = "skip" ] || [ "$expect_action" = "error" ] || [ "$expect_action" = "none" ]; then
    [ "$before" = "$after" ]
    assert "file unchanged" $?
  fi
  if [ "$expect_action" = "error" ]; then
    [ "${#FAILED[@]}" -gt 0 ]
    assert "failure recorded in summary" $?
  fi
  if [ -n "$present" ]; then
    grep -qF -- "$present" "$tmp/.zshrc"
    assert "contains: $present" $?
  fi
  if [ -n "$absent" ]; then
    ! grep -qxF -- "$absent" "$tmp/.zshrc"
    assert "no longer contains line: $absent" $?
  fi
  grep -qF 'alias keepme=1' "$tmp/.zshrc"
  assert "unrelated line preserved" $?
  [ ! -e "$tmp/.zshrc.thefuck.tmp" ] && [ ! -e "$tmp/.zshrc.fzf.tmp" ]
  assert "no temp files left behind" $?
  echo
  rm -rf "$tmp"
}

# --- thefuck ----------------------------------------------------------------
TF_INIT='eval "$(thefuck --alias)"'
TF_REMOVED="removed thefuck init from ~/.zshrc"

run_case "T1: init block as earlier versions wrote it" "$THEFUCK_BLOCK" \
  "alias keepme=1\n\n# thefuck\n$TF_INIT\n\n# fzf\nexport PATH=foo\n" \
  "$TF_REMOVED" "export PATH=foo" "$TF_INIT"

run_case "T2: init line without its comment" "$THEFUCK_BLOCK" \
  "alias keepme=1\n$TF_INIT\nexport PATH=foo\n" \
  "$TF_REMOVED" "export PATH=foo" "$TF_INIT"

run_case "T3: no thefuck init" "$THEFUCK_BLOCK" \
  'alias keepme=1\n# thefuck is great\n' \
  "none" "# thefuck is great"

# T4: exact output, so the comment and the blank line before it go too.
tmp="$(mktemp -d)"; HOME="$tmp"
printf '%s\n' 'alias keepme=1' '' '# thefuck' "$TF_INIT" '' '# fzf' 'export PATH=foo' > "$tmp/.zshrc"
CONFIGURED=(); eval "$THEFUCK_BLOCK"
got="$(cat "$tmp/.zshrc")"
want="$(printf '%s\n' 'alias keepme=1' '' '# fzf' 'export PATH=foo')"
echo "[T4: exact output after removal]"
if [ "$got" = "$want" ]; then rc=0; else rc=1; fi
assert "comment, init line and preceding blank line removed; rest unchanged" "$rc"
echo; rm -rf "$tmp"

# --- fzf --------------------------------------------------------------------
FZF_OLD_EVAL='  eval "$(fzf --zsh)"'
FZF_OLD="# fzf\nif command -v fzf &> /dev/null; then\n$FZF_OLD_EVAL\nfi\n"
FZF_FALLBACK='source /usr/share/doc/fzf/examples/key-bindings.zsh'

run_case "Z1: no fzf init" "$FZF_BLOCK" \
  'alias keepme=1\n' \
  "fzf init" "$FZF_FALLBACK"

run_case "Z2: old --zsh-only block" "$FZF_BLOCK" \
  "alias keepme=1\n\n$FZF_OLD\nexport PATH=foo\n" \
  "fzf init updated" "$FZF_FALLBACK" "$FZF_OLD_EVAL"

# Z3 fixture = the output of Z1, so "current" means exactly what the step writes.
tmp="$(mktemp -d)"; HOME="$tmp"; printf 'alias keepme=1\n' > "$tmp/.zshrc"
CONFIGURED=(); ACTION=""; eval "$FZF_BLOCK"
FZF_CURRENT="$(cat "$tmp/.zshrc")"; rm -rf "$tmp"

run_case "Z3: already current" "$FZF_BLOCK" \
  "${FZF_CURRENT//\\/\\\\}\n" \
  "skip"

run_case "Z4: old eval in unexpected form" "$FZF_BLOCK" \
  "alias keepme=1\nif [[ -o interactive ]]; then\n$FZF_OLD_EVAL\nfi\n" \
  "error"

echo "=================================="
echo "RESULTS: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
