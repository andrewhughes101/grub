#!/bin/sh
# assert.sh — minimal test assertion helpers for grub unit tests
# No external dependencies. Source this file in each test_*.sh.

_PASS=0
_FAIL=0
_CURRENT_TEST=""

# Colour codes (suppressed if not a tty or NO_COLOR is set)
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  _GREEN='\033[0;32m'
  _RED='\033[0;31m'
  _RESET='\033[0m'
else
  _GREEN=''
  _RED=''
  _RESET=''
fi

# describe <name>  — set the current test group label
describe() {
  _CURRENT_TEST="$1"
}

# _pass <label>
_pass() {
  _PASS=$((_PASS + 1))
  printf "${_GREEN}  PASS${_RESET} %s: %s\n" "$_CURRENT_TEST" "$1"
}

# _fail <label> <expected> <got>
_fail() {
  _FAIL=$((_FAIL + 1))
  printf "${_RED}  FAIL${_RESET} %s: %s\n" "$_CURRENT_TEST" "$1"
  printf "       expected: %s\n" "$2"
  printf "       got:      %s\n" "$3"
}

# assert_eq <label> <expected> <actual>
assert_eq() {
  _label="$1"
  _expected="$2"
  _actual="$3"
  if [ "$_expected" = "$_actual" ]; then
    _pass "$_label"
  else
    _fail "$_label" "$_expected" "$_actual"
  fi
}

# assert_empty <label> <actual>
assert_empty() {
  _label="$1"
  _actual="$2"
  if [ -z "$_actual" ]; then
    _pass "$_label"
  else
    _fail "$_label" "(empty)" "$_actual"
  fi
}

# assert_not_empty <label> <actual>
assert_not_empty() {
  _label="$1"
  _actual="$2"
  if [ -n "$_actual" ]; then
    _pass "$_label"
  else
    _fail "$_label" "(non-empty)" "(empty)"
  fi
}

# assert_contains <label> <substring> <actual>
assert_contains() {
  _label="$1"
  _sub="$2"
  _actual="$3"
  case "$_actual" in
    *"$_sub"*) _pass "$_label" ;;
    *)         _fail "$_label" "*${_sub}*" "$_actual" ;;
  esac
}

# assert_exit <label> <expected_code> <command...>
# Runs the remaining args as a command and checks the exit code.
assert_exit() {
  _label="$1"
  _expected_code="$2"
  shift 2
  "$@" >/dev/null 2>&1
  _actual_code=$?
  if [ "$_expected_code" = "$_actual_code" ]; then
    _pass "$_label"
  else
    _fail "$_label" "exit $1" "exit $_actual_code"
  fi
}

# assert_exit_nonzero <label> <command...>
assert_exit_nonzero() {
  _label="$1"
  shift
  "$@" >/dev/null 2>&1
  _actual_code=$?
  if [ "$_actual_code" -ne 0 ]; then
    _pass "$_label"
  else
    _fail "$_label" "exit non-zero" "exit 0"
  fi
}

# print_summary — call at the end of each test file
print_summary() {
  _total=$((_PASS + _FAIL))
  printf "\n%d tests: %d passed, %d failed\n" "$_total" "$_PASS" "$_FAIL"
  [ "$_FAIL" -eq 0 ]  # return 0 only if all passed
}
