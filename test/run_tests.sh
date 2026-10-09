#!/bin/sh
# run_tests.sh — test runner for grub unit tests
# Discovers and runs all test_*.sh files in the test/ directory.
# Exits non-zero if any test file reports failures.
# Usage: ./test/run_tests.sh [test_file ...]

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Colour codes (suppressed if not a tty or NO_COLOR is set)
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  GREEN='\033[0;32m'
  RED='\033[0;31m'
  BOLD='\033[1m'
  RESET='\033[0m'
else
  GREEN=''
  RED=''
  BOLD=''
  RESET=''
fi

total_pass=0
total_fail=0
failed_files=""

# Determine which test files to run
if [ $# -gt 0 ]; then
  test_files="$*"
else
  test_files=$(find "$SCRIPT_DIR" -maxdepth 1 -name 'test_*.sh' | sort)
fi

if [ -z "$test_files" ]; then
  echo "No test files found in ${SCRIPT_DIR}"
  exit 1
fi

printf "${BOLD}Running grub unit tests${RESET}\n\n"

for test_file in $test_files; do
  # Resolve to absolute path if given relative
  case "$test_file" in
    /*) ;;
    *)  test_file="${SCRIPT_DIR}/${test_file}" ;;
  esac

  if [ ! -f "$test_file" ]; then
    printf "${RED}NOT FOUND${RESET} %s\n" "$test_file"
    total_fail=$((total_fail + 1))
    continue
  fi

  printf "${BOLD}=== %s ===${RESET}\n" "$(basename "$test_file")"

  # Run each test file in a subshell so state doesn't leak between files.
  # Capture its summary line to extract pass/fail counts.
  output=$(sh "$test_file" 2>&1)
  exit_code=$?

  echo "$output"

  # Parse the summary line: "N tests: P passed, F failed"
  summary=$(echo "$output" | grep -E '^[0-9]+ tests:')
  if [ -n "$summary" ]; then
    file_pass=$(echo "$summary" | sed 's/.*: \([0-9]*\) passed.*/\1/')
    file_fail=$(echo "$summary" | sed 's/.*, \([0-9]*\) failed.*/\1/')
    total_pass=$((total_pass + file_pass))
    total_fail=$((total_fail + file_fail))
  elif [ $exit_code -ne 0 ]; then
    # File crashed before printing summary
    total_fail=$((total_fail + 1))
    failed_files="${failed_files} $(basename "$test_file")"
  fi

  if [ $exit_code -ne 0 ]; then
    failed_files="${failed_files} $(basename "$test_file")"
  fi

  printf "\n"
done

# Final summary
total=$((total_pass + total_fail))
printf "${BOLD}=== Results ===${RESET}\n"
printf "Total: %d tests, " "$total"
if [ $total_fail -eq 0 ]; then
  printf "${GREEN}%d passed${RESET}, %d failed\n" "$total_pass" "$total_fail"
  exit 0
else
  printf "%d passed, ${RED}%d failed${RESET}\n" "$total_pass" "$total_fail"
  printf "${RED}Failed files:${RESET}%s\n" "$failed_files"
  exit 1
fi
