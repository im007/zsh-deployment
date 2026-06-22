#!/bin/bash
# =============================================================================
# Idempotency test for the Claude-only _ZO_DOCTOR guard step in zsh-config.sh.
#
# Claude Code's Bash tool rebuilds the shell from a snapshot that captures
# zoxide's functions but not its chpwd/precmd hook registration, so zoxide's
# doctor false-positives on every `cd` inside Claude. The guard step appends a
# $CLAUDECODE-gated `export _ZO_DOCTOR=0` so the warning is silenced in Claude
# only, while the (useful) doctor stays active in interactive shells.
#
# This test extracts the REAL guard block from zsh-config.sh (so it cannot drift
# from the implementation) and asserts: the line is added when absent, the step
# is a no-op when already present (no churn), and the written line is gated on
# $CLAUDECODE (never unconditional).
#
# Usage: tests/test_zo_doctor_guard.sh   (or: bash tests/test_zo_doctor_guard.sh)
# Exit:  0 = all assertions passed, 1 = at least one failed.
# =============================================================================
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$SCRIPT_DIR/../zsh-config.sh"

if [ ! -f "$SCRIPT" ]; then
  echo "FATAL: cannot find zsh-config.sh at $SCRIPT" >&2
  exit 1
fi

# Extract from the guard's 'if ! grep -qF ..._ZO_DOCTOR=0' through its 'fi'.
BLOCK="$(awk "/^if ! grep -qF '_ZO_DOCTOR=0'/{f=1} f{print} f&&/^fi\$/{exit}" "$SCRIPT")"
if [ -z "$BLOCK" ]; then
  echo "FATAL: could not extract the _ZO_DOCTOR guard block from $SCRIPT" >&2
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

run_case() { # name, fixture_content, expected_action
  local name="$1" fixture="$2" expect_action="$3"
  local tmp before after count
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
  count="$(grep -cF '_ZO_DOCTOR=0' "$tmp/.zshrc")"

  echo "[$name]"
  [ "$count" -eq 1 ]
  assert "exactly one _ZO_DOCTOR=0 line (got $count)" $?
  [ "$ACTION" = "$expect_action" ]
  assert "action == '$expect_action' (got '$ACTION')" $?
  # The guard MUST be gated on \$CLAUDECODE — never silence the doctor globally.
  grep -F '_ZO_DOCTOR=0' "$tmp/.zshrc" | grep -q 'CLAUDECODE'
  assert "guard line is gated on \$CLAUDECODE" $?
  if [ "$expect_action" = "skip" ]; then
    [ "$before" = "$after" ]
    assert "file unchanged (skip = no churn)" $?
  fi
  echo
  rm -rf "$tmp"
}

GUARD='[[ -n "$CLAUDECODE" ]] && export _ZO_DOCTOR=0  # Claude snapshot: silence zoxide doctor false-positive'

run_case "G1: guard absent" \
  'export PATH=foo\nalias x=y\n' \
  "zoxide _ZO_DOCTOR guard"

run_case "G2: guard already present" \
  "alias x=y\n$GUARD\n" \
  "skip"

echo "=================================="
echo "RESULTS: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
