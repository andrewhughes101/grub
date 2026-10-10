#!/bin/sh
# test_grub_yaml.sh — unit tests for bin/grub_yaml

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "${SCRIPT_DIR}/lib/assert.sh"
. "${SCRIPT_DIR}/../bin/grub_yaml"

FIXTURES="${SCRIPT_DIR}/fixtures"

# ---------------------------------------------------------------------------
# grub_yaml_strip_value
# ---------------------------------------------------------------------------
describe "grub_yaml_strip_value: plain value"
assert_eq "no-op" "hello" "$(grub_yaml_strip_value 'hello')"

describe "grub_yaml_strip_value: trims whitespace"
assert_eq "leading/trailing" "hello" "$(grub_yaml_strip_value '  hello  ')"

describe "grub_yaml_strip_value: strips double quotes"
assert_eq "double-quoted" "hello world" "$(grub_yaml_strip_value '"hello world"')"

describe "grub_yaml_strip_value: strips single quotes"
assert_eq "single-quoted" "hello world" "$(grub_yaml_strip_value "'hello world'")"

describe "grub_yaml_strip_value: strips inline comment"
assert_eq "inline comment" "value" "$(grub_yaml_strip_value 'value # comment')"

describe "grub_yaml_strip_value: empty input"
assert_empty "empty" "$(grub_yaml_strip_value '')"

# ---------------------------------------------------------------------------
# grub_yaml_get_flat
# ---------------------------------------------------------------------------
FLAT="${FIXTURES}/flat_vars.yml"

describe "grub_yaml_get_flat: basic lookup"
assert_eq "ansible_host" "zos.example.com" "$(grub_yaml_get_flat "$FLAT" ansible_host)"

describe "grub_yaml_get_flat: ansible_user"
assert_eq "ansible_user" "myuser" "$(grub_yaml_get_flat "$FLAT" ansible_user)"

describe "grub_yaml_get_flat: path with tilde"
assert_eq "ssh key path" "~/.ssh/id_zos" "$(grub_yaml_get_flat "$FLAT" ansible_ssh_private_key_file)"

describe "grub_yaml_get_flat: ansible_port"
assert_eq "ssh port" "2022" "$(grub_yaml_get_flat "$FLAT" ansible_port)"

describe "grub_yaml_get_flat: ansible_ssh_common_args"
assert_eq "ssh common args" "-o ProxyJump=jump.example.com" "$(grub_yaml_get_flat "$FLAT" ansible_ssh_common_args)"

describe "grub_yaml_get_flat: grub_server_root"
assert_eq "server_root" "/u/myuser/projects" "$(grub_yaml_get_flat "$FLAT" grub_server_root)"

describe "grub_yaml_get_flat: grub_git_dir"
assert_eq "git_dir" "/usr/lpp/IBM/foz/v1r1/bin" "$(grub_yaml_get_flat "$FLAT" grub_git_dir)"

describe "grub_yaml_get_flat: empty value"
assert_empty "empty_key" "$(grub_yaml_get_flat "$FLAT" empty_key)"

describe "grub_yaml_get_flat: single-quoted value strips quotes"
assert_eq "single-quoted" "hello world" "$(grub_yaml_get_flat "$FLAT" quoted_single)"

describe "grub_yaml_get_flat: double-quoted value strips quotes"
assert_eq "double-quoted" "hello world" "$(grub_yaml_get_flat "$FLAT" quoted_double)"

describe "grub_yaml_get_flat: URL value preserves colons"
assert_eq "url" "https://example.com/path" "$(grub_yaml_get_flat "$FLAT" url_value)"

describe "grub_yaml_get_flat: inline comment stripped"
assert_eq "inline comment" "value" "$(grub_yaml_get_flat "$FLAT" with_hash)"

describe "grub_yaml_get_flat: value with embedded single quote"
assert_eq "embedded quote" "it's a value" "$(grub_yaml_get_flat "$FLAT" with_single_quote)"

describe "grub_yaml_get_flat: missing key returns empty"
assert_empty "missing key" "$(grub_yaml_get_flat "$FLAT" no_such_key)"

describe "grub_yaml_get_flat: missing file returns non-zero"
assert_exit_nonzero "missing file" grub_yaml_get_flat /no/such/file.yml some_key

# ---------------------------------------------------------------------------
# grub_yaml_iter_flat
# ---------------------------------------------------------------------------
EVARS="${FIXTURES}/extra_vars.yml"

describe "grub_yaml_iter_flat: emits KEY='value' pairs"
_out="$(grub_yaml_iter_flat "$EVARS")"
assert_contains "MY_API_KEY present" "MY_API_KEY='s3cr3t'" "$_out"
assert_contains "BUILD_FLAGS present" "BUILD_FLAGS='--release --verbose'" "$_out"

describe "grub_yaml_iter_flat: URL with colon preserved"
assert_contains "url colon" "URL_VAR='https://example.com/path'" "$(grub_yaml_iter_flat "$EVARS")"

describe "grub_yaml_iter_flat: strips surrounding quotes from values"
assert_contains "single-quoted stripped" "QUOTED_SINGLE='hello world'" "$(grub_yaml_iter_flat "$EVARS")"
assert_contains "double-quoted stripped" "QUOTED_DOUBLE='hello world'" "$(grub_yaml_iter_flat "$EVARS")"

describe "grub_yaml_iter_flat: value with embedded single quote escaped"
assert_contains "embedded quote escaped" "WITH_SINGLE_QUOTE='it'\\''s a value'" "$(grub_yaml_iter_flat "$EVARS")"

describe "grub_yaml_iter_flat: empty value emits empty"
assert_contains "empty var" "EMPTY_VAR=''" "$(grub_yaml_iter_flat "$EVARS")"

describe "grub_yaml_iter_flat: output is eval-safe"
eval "$(grub_yaml_iter_flat "$EVARS")"
assert_eq "eval MY_API_KEY" "s3cr3t" "$MY_API_KEY"
assert_eq "eval BUILD_FLAGS" "--release --verbose" "$BUILD_FLAGS"
assert_eq "eval URL_VAR" "https://example.com/path" "$URL_VAR"
assert_eq "eval QUOTED_SINGLE" "hello world" "$QUOTED_SINGLE"
assert_eq "eval WITH_SINGLE_QUOTE" "it's a value" "$WITH_SINGLE_QUOTE"
assert_empty "eval EMPTY_VAR" "$EMPTY_VAR"

describe "grub_yaml_iter_flat: indented keys emit stripped key name and value"
_tf=$(mktemp)
printf 'root_key:\n  nested_key: value_nested\n' > "$_tf"
_iter_out=$(grub_yaml_iter_flat "$_tf")
assert_contains "parent key emitted empty" "root_key=''" "$_iter_out"
assert_contains "nested key emitted directly" "nested_key='value_nested'" "$_iter_out"
rm -f "$_tf"

describe "grub_yaml_iter_flat: missing file returns non-zero"
assert_exit_nonzero "missing file" grub_yaml_iter_flat /no/such/file.yml

# ---------------------------------------------------------------------------
# grub_yaml_get_host
# ---------------------------------------------------------------------------
INV="${FIXTURES}/inventory.yml"

describe "grub_yaml_get_host: myzos ansible_host"
assert_eq "myzos host" "zos.example.com" "$(grub_yaml_get_host "$INV" myzos ansible_host)"

describe "grub_yaml_get_host: myzos ansible_user"
assert_eq "myzos user" "zosuser" "$(grub_yaml_get_host "$INV" myzos ansible_user)"

describe "grub_yaml_get_host: myzos ansible_port"
assert_eq "myzos port" "2022" "$(grub_yaml_get_host "$INV" myzos ansible_port)"

describe "grub_yaml_get_host: myzos ansible_ssh_common_args"
assert_eq "myzos common args" "-o ProxyJump=jump.example.com" "$(grub_yaml_get_host "$INV" myzos ansible_ssh_common_args)"

describe "grub_yaml_get_host: myzos grub_server_root"
assert_eq "myzos server_root" "/u/zosuser/projects" "$(grub_yaml_get_host "$INV" myzos grub_server_root)"

describe "grub_yaml_get_host: myzos grub_git_dir"
assert_eq "myzos git_dir" "/usr/lpp/IBM/foz/v1r1/bin" "$(grub_yaml_get_host "$INV" myzos grub_git_dir)"

describe "grub_yaml_get_host: second host mylinux ansible_host"
assert_eq "mylinux host" "linux.example.com" "$(grub_yaml_get_host "$INV" mylinux ansible_host)"

describe "grub_yaml_get_host: second host mylinux ansible_user"
assert_eq "mylinux user" "linuxuser" "$(grub_yaml_get_host "$INV" mylinux ansible_user)"

describe "grub_yaml_get_host: second host mylinux grub_server_root"
assert_eq "mylinux server_root" "~/dev" "$(grub_yaml_get_host "$INV" mylinux grub_server_root)"

describe "grub_yaml_get_host: key absent from one host but present in another"
assert_empty "mylinux git_dir absent" "$(grub_yaml_get_host "$INV" mylinux grub_git_dir)"

describe "grub_yaml_get_host: myzos key that doesn't exist"
assert_empty "myzos missing key" "$(grub_yaml_get_host "$INV" myzos no_such_key)"

describe "grub_yaml_get_host: host that doesn't exist"
assert_empty "unknown host" "$(grub_yaml_get_host "$INV" unknownhost ansible_host)"

describe "grub_yaml_get_host: missing file returns non-zero"
assert_exit_nonzero "missing file" grub_yaml_get_host /no/such/file.yml myzos ansible_host

print_summary
