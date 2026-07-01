#!/bin/bash
# =============================================================================
# Test for the zoxide _ZO_DOCTOR fix in zsh-config.sh.
#
# Claude Code's Bash tool rebuilds the shell from a snapshot that serializes
# functions and aliases but NOT top-level env-var exports from ~/.zshrc, and it
# does not register zoxide's chpwd hook -- so zoxide's doctor false-positives on
# every `cd` inside Claude. The earlier ~/.zshrc `export _ZO_DOCTOR=0` fix did
# NOT work (the export never reached the tool env). The correct fix sets
# _ZO_DOCTOR=0 in ~/.claude/settings.json "env", which Claude injects into every
# tool subprocess (snapshot-independent, Claude-scoped).
#
# This test extracts the REAL blocks from zsh-config.sh (between sentinel markers,
# so the test cannot drift from the implementation) and asserts:
#   settings-fix : key added when absent, other keys preserved, idempotent when
#                  already set, missing settings.json handled without creating one.
#   rc-cleanup   : a previously-appended dead guard line is removed; no-op when
#                  absent.
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

if ! command -v jq >/dev/null 2>&1; then
  echo "SKIP: jq not installed; cannot test the settings.json fix" >&2
  exit 0
fi

extract() { # marker-basename -> prints the block between its >>>/<<< sentinels
  awk -v m="$1" '
    $0 ~ ("# >>> " m)  {f=1; next}
    $0 ~ ("# <<< " m)  {f=0}
    f' "$SCRIPT"
}

FIX_BLOCK="$(extract 'zodoctor-settings-fix')"
CLEAN_BLOCK="$(extract 'zodoctor-rc-cleanup')"
if [ -z "$FIX_BLOCK" ] || [ -z "$CLEAN_BLOCK" ]; then
  echo "FATAL: could not extract zodoctor blocks from $SCRIPT" >&2
  exit 1
fi

PASS=0
FAIL=0
log_info()  { :; }
log_error() { :; }
log_skip()  { ACTION="skip"; }

assert() { # message, condition_exit_status (0 = pass)
  if [ "$2" -eq 0 ]; then
    echo "    PASS: $1"; PASS=$((PASS + 1))
  else
    echo "    FAIL: $1"; FAIL=$((FAIL + 1))
  fi
}

assert_eq() { # message, actual, expected  (compares values; no reliance on $?)
  if [ "$2" = "$3" ]; then
    echo "    PASS: $1"; PASS=$((PASS + 1))
  else
    echo "    FAIL: $1 (got '$2' want '$3')"; FAIL=$((FAIL + 1))
  fi
}

# --- settings.json fix ------------------------------------------------------
fix_case() { # name, settings_content|MISSING, expect_val, expect_action
  local name="$1" fixture="$2" expect_val="$3" expect_action="$4"
  local tmp val
  tmp="$(mktemp -d)"
  HOME="$tmp"
  mkdir -p "$tmp/.claude"
  [ "$fixture" != "MISSING" ] && printf '%s' "$fixture" > "$tmp/.claude/settings.json"
  CONFIGURED=()
  ACTION=""

  eval "$FIX_BLOCK"

  [ -z "$ACTION" ] && [ "${#CONFIGURED[@]}" -gt 0 ] && ACTION="set"

  echo "[$name]"
  [ "$ACTION" = "$expect_action" ]
  assert "action == '$expect_action' (got '$ACTION')" $?
  if [ "$fixture" = "MISSING" ]; then
    [ ! -f "$tmp/.claude/settings.json" ]
    assert "missing settings.json NOT created" $?
  else
    val="$(jq -r '.env._ZO_DOCTOR // "ABSENT"' "$tmp/.claude/settings.json" 2>/dev/null)"
    [ "$val" = "$expect_val" ]
    assert "_ZO_DOCTOR == '$expect_val' (got '$val')" $?
    jq -e . "$tmp/.claude/settings.json" >/dev/null 2>&1
    assert "settings.json still valid JSON" $?
  fi
  echo
  rm -rf "$tmp"
}

fix_case "F1: no env block"        '{"model":"opus","permissions":{"defaultMode":"auto"}}' "0" "set"
fix_case "F2: already set"         '{"env":{"_ZO_DOCTOR":"0"}}'                             "0" "skip"
fix_case "F3: missing settings"    'MISSING'                                                ""  "skip"

# F4: existing env keys preserved when adding _ZO_DOCTOR
tmp="$(mktemp -d)"; HOME="$tmp"; mkdir -p "$tmp/.claude"
printf '%s' '{"env":{"FOO":"bar"},"model":"opus"}' > "$tmp/.claude/settings.json"
CONFIGURED=(); ACTION=""; eval "$FIX_BLOCK"
echo "[F4: existing keys preserved]"
assert_eq ".env.FOO preserved"    "$(jq -r '.env.FOO' "$tmp/.claude/settings.json")"        "bar"
assert_eq ".model preserved"      "$(jq -r '.model' "$tmp/.claude/settings.json")"          "opus"
assert_eq ".env._ZO_DOCTOR added" "$(jq -r '.env._ZO_DOCTOR' "$tmp/.claude/settings.json")" "0"
echo; rm -rf "$tmp"

# --- rc cleanup -------------------------------------------------------------
GUARD='[[ -n "$CLAUDECODE" ]] && export _ZO_DOCTOR=0  # Claude snapshot: silence zoxide doctor false-positive'

clean_case() { # name, zshrc_content, expect_present_count
  local name="$1" fixture="$2" expect="$3"
  local tmp count
  tmp="$(mktemp -d)"
  HOME="$tmp"
  printf '%b' "$fixture" > "$tmp/.zshrc"
  CONFIGURED=()

  eval "$CLEAN_BLOCK"

  count="$(grep -cF 'export _ZO_DOCTOR=0' "$tmp/.zshrc")"
  echo "[$name]"
  [ "$count" -eq "$expect" ]
  assert "guard lines present == $expect (got $count)" $?
  # Cleanup must never nuke unrelated lines.
  grep -qF 'alias keepme=1' "$tmp/.zshrc"
  assert "unrelated line preserved" $?
  echo
  rm -rf "$tmp"
}

clean_case "C1: dead guard present -> removed" "alias keepme=1\n$GUARD\neval \"\$(zoxide init)\"\n" 0
clean_case "C2: no guard -> no-op"             "alias keepme=1\neval \"\$(zoxide init)\"\n"          0

echo "=================================="
echo "RESULTS: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
