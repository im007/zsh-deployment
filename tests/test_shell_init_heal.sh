#!/bin/bash
# =============================================================================
# Test for the thefuck and fzf init steps in zsh-config.sh.
#
# On Ubuntu 24.04 earlier versions broke every shell start: the bare
# `eval "$(thefuck --alias)"` printed a traceback (apt thefuck crashes on Python
# 3.12+), and `eval "$(fzf --zsh)"` printed "unknown option: --zsh" (apt fzf is
# 0.44; --zsh arrived in 0.48). The steps now write guarded blocks and rewrite
# the old ones in place.
#
# This test extracts the REAL blocks from zsh-config.sh (between sentinel markers,
# so the test cannot drift from the implementation) and asserts, for each:
#   fresh    : block added when absent.
#   old form : old line(s) replaced in place, surrounding lines preserved.
#   current  : already-current file left byte-identical.
# plus fzf  : an old eval line in an unexpected form is reported, file untouched.
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

THEFUCK_BLOCK="$(extract 'thefuck-init')"
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
# expected_action is "skip", "error", or the CONFIGURED entry the step records.
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
  after="$(sha < "$tmp/.zshrc")"

  echo "[$name]"
  [ "$ACTION" = "$expect_action" ]
  assert "action == '$expect_action' (got '$ACTION')" $?
  if [ "$expect_action" = "skip" ] || [ "$expect_action" = "error" ]; then
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
TF_OLD='eval "$(thefuck --alias)"'
TF_NEW='eval "$(thefuck --alias 2>/dev/null)"'
TF_GUARDED="alias keepme=1\n\n# thefuck\nif command -v thefuck &> /dev/null; then\n  $TF_NEW\nfi\n"

run_case "T1: no thefuck init" "$THEFUCK_BLOCK" \
  'alias keepme=1\n' \
  "thefuck alias" "$TF_NEW"

run_case "T2: old bare eval line" "$THEFUCK_BLOCK" \
  "alias keepme=1\n\n# thefuck\n$TF_OLD\nexport PATH=foo\n" \
  "thefuck init guarded" "$TF_NEW" "$TF_OLD"

run_case "T3: already guarded" "$THEFUCK_BLOCK" \
  "$TF_GUARDED" \
  "skip"

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
