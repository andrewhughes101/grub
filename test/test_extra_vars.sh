#!/bin/sh
# test_extra_vars.sh — unit tests for --extra-vars key validation and env file generation
# Tests the logic in grub_client's extra-vars processing block in isolation.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "${SCRIPT_DIR}/lib/assert.sh"
. "${SCRIPT_DIR}/../bin/grub_yaml"

FIXTURES="${SCRIPT_DIR}/fixtures"

# ---------------------------------------------------------------------------
# Helper: run the same key validation logic used in grub_client
# Reads a vars file, validates keys, writes export statements to a temp file.
# Prints the temp file path on success. Exits non-zero if any key is invalid.
# ---------------------------------------------------------------------------
build_env_file() {
  _input="$1"
  _out="$(mktemp)"
  _pairs="$(mktemp)"
  _errors=0

  grub_yaml_iter_flat "$_input" > "$_pairs"

  while IFS= read -r pair; do
    _key="${pair%%=*}"
    if ! echo "$_key" | grep -qE '^[A-Za-z_][A-Za-z0-9_]*$'; then
      _errors=$((_errors + 1))
    else
      echo "export $pair" >> "$_out"
    fi
  done < "$_pairs"
  rm -f "$_pairs"

  if [ "$_errors" -gt 0 ]; then
    rm -f "$_out"
    return 1
  fi
  echo "$_out"
}

# ---------------------------------------------------------------------------
# Key validation
# ---------------------------------------------------------------------------
describe "key validation: valid identifiers accepted"
_env=$(build_env_file "${FIXTURES}/extra_vars.yml")
assert_not_empty "env file created" "$_env"
rm -f "$_env"

describe "key validation: invalid keys cause failure"
assert_exit_nonzero "bad keys rejected" build_env_file "${FIXTURES}/bad_keys.yml"

describe "key validation: leading digit rejected"
_tf=$(mktemp)
printf '123bad: value\n' > "$_tf"
assert_exit_nonzero "leading digit" build_env_file "$_tf"
rm -f "$_tf"

describe "key validation: hyphen rejected"
_tf=$(mktemp)
printf 'has-hyphen: value\n' > "$_tf"
assert_exit_nonzero "hyphen in key" build_env_file "$_tf"
rm -f "$_tf"

describe "key validation: space in key rejected"
_tf=$(mktemp)
printf 'has space: value\n' > "$_tf"
assert_exit_nonzero "space in key" build_env_file "$_tf"
rm -f "$_tf"

describe "key validation: underscore prefix accepted"
_tf=$(mktemp)
printf '_PRIVATE: value\n' > "$_tf"
_env=$(build_env_file "$_tf")
assert_not_empty "underscore prefix ok" "$_env"
rm -f "$_tf" "$_env"

describe "key validation: mixed valid and invalid fails overall"
_tf=$(mktemp)
printf 'GOOD: value\nbad-key: value\n' > "$_tf"
assert_exit_nonzero "mixed valid+invalid fails" build_env_file "$_tf"
rm -f "$_tf"

# ---------------------------------------------------------------------------
# Generated env file content
# ---------------------------------------------------------------------------
describe "env file: contains export statements"
_env=$(build_env_file "${FIXTURES}/extra_vars.yml")
_content=$(cat "$_env")
assert_contains "export keyword" "export MY_API_KEY=" "$_content"
assert_contains "export BUILD_FLAGS" "export BUILD_FLAGS=" "$_content"
rm -f "$_env"

describe "env file: is sourceable and sets variables"
_env=$(build_env_file "${FIXTURES}/extra_vars.yml")
# shellcheck disable=SC1090
. "$_env"
assert_eq "MY_API_KEY sourced" "s3cr3t" "$MY_API_KEY"
assert_eq "BUILD_FLAGS sourced" "--release --verbose" "$BUILD_FLAGS"
assert_eq "URL_VAR sourced" "https://example.com/path" "$URL_VAR"
assert_eq "QUOTED_SINGLE sourced" "hello world" "$QUOTED_SINGLE"
assert_eq "WITH_SINGLE_QUOTE sourced" "it's a value" "$WITH_SINGLE_QUOTE"
assert_empty "EMPTY_VAR sourced empty" "$EMPTY_VAR"
rm -f "$_env"

describe "env file: empty input file produces empty output"
_tf=$(mktemp)
printf '# only comments\n\n' > "$_tf"
_env=$(build_env_file "$_tf")
# build_env_file succeeds (no bad keys) but file is empty
if [ -n "$_env" ]; then
  assert_empty "no vars in output" "$(cat "$_env")"
  rm -f "$_env"
else
  _pass "no output file for comment-only input"
fi
rm -f "$_tf"

print_summary
