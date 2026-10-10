#!/bin/sh
# test_cli_args.sh — unit tests for grub_client CLI argument and option handling
# Tests syntax validation, exit codes, error messages, and option precedence.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "${SCRIPT_DIR}/lib/assert.sh"

GRUB_CLIENT="${SCRIPT_DIR}/../bin/grub_client"
FIXTURES="${SCRIPT_DIR}/fixtures"
TEST_TMPDIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TEST_TMPDIR"
}
trap cleanup EXIT INT TERM

# ---------------------------------------------------------------------------
# 1. Help and Version flags
# ---------------------------------------------------------------------------
describe "help: -h and --help exit 0 with syntax usage"
_out_h=$(bash "$GRUB_CLIENT" -h 2>&1)
_rc_h=$?
assert_eq "exit code is 0 for -h" "0" "$_rc_h"
assert_contains "contains Usage" "Usage: grub_client" "$_out_h"

_out_help=$(bash "$GRUB_CLIENT" --help 2>&1)
_rc_help=$?
assert_eq "exit code is 0 for --help" "0" "$_rc_help"
assert_contains "contains Usage" "Usage: grub_client" "$_out_help"

describe "version: --version exits 0 with version string"
_out_ver=$(bash "$GRUB_CLIENT" --version 2>&1)
_rc_ver=$?
assert_eq "exit code is 0 for --version" "0" "$_rc_ver"
assert_contains "contains version format" "grub_client version" "$_out_ver"

# ---------------------------------------------------------------------------
# 2. Unknown and missing options
# ---------------------------------------------------------------------------
describe "unknown option: exits 4 with error message"
_out_unk=$(bash "$GRUB_CLIENT" --unknown-option 2>&1)
_rc_unk=$?
assert_eq "exit code is 4 for unknown option" "4" "$_rc_unk"
assert_contains "error message for unknown option" "Error: Unknown option: --unknown-option" "$_out_unk"

describe "missing option arguments: exit 4 with specific error messages"
_out_rp=$(bash "$GRUB_CLIENT" --repo-path 2>&1)
assert_eq "exit code is 4 for missing --repo-path argument" "4" "$?"
assert_contains "error message for --repo-path" "Error: --repo-path requires a path argument" "$_out_rp"

_out_sr=$(bash "$GRUB_CLIENT" --server-root 2>&1)
assert_eq "exit code is 4 for missing --server-root argument" "4" "$?"
assert_contains "error message for --server-root" "Error: --server-root requires a path argument" "$_out_sr"

_out_gd=$(bash "$GRUB_CLIENT" --git-dir 2>&1)
assert_eq "exit code is 4 for missing --git-dir argument" "4" "$?"
assert_contains "error message for --git-dir" "Error: --git-dir requires a path argument" "$_out_gd"

_out_inv=$(bash "$GRUB_CLIENT" --inventory 2>&1)
assert_eq "exit code is 4 for missing --inventory argument" "4" "$?"
assert_contains "error message for --inventory" "Error: --inventory requires a file path" "$_out_inv"

_out_i=$(bash "$GRUB_CLIENT" -i 2>&1)
assert_eq "exit code is 4 for missing -i argument" "4" "$?"
assert_contains "error message for -i" "Error: --inventory requires a file path" "$_out_i"

_out_ev=$(bash "$GRUB_CLIENT" -e 2>&1)
assert_eq "exit code is 4 for missing -e argument" "4" "$?"
assert_contains "error message for -e" "Error: --extra-vars requires a file path" "$_out_ev"

_out_cc=$(bash "$GRUB_CLIENT" --clear-cache 2>&1)
assert_eq "exit code is 4 for missing --clear-cache argument" "4" "$?"
assert_contains "error message for --clear-cache" "Error: --clear-cache requires a server name" "$_out_cc"

# ---------------------------------------------------------------------------
# 3. Positional argument validation
# ---------------------------------------------------------------------------
describe "positional arguments: missing server exits 4"
_out_noserver=$(bash "$GRUB_CLIENT" 2>&1)
assert_eq "exit code is 4 for missing server" "4" "$?"
assert_contains "shows usage on missing server" "Usage: grub_client" "$_out_noserver"

# ---------------------------------------------------------------------------
# 4. Cache clearing
# ---------------------------------------------------------------------------
describe "cache clearing: --clear-cache unsets config and reports success"
git config --global "grub.testserver.gitdir" "/test/path"
_out_cc_ok=$(bash "$GRUB_CLIENT" --clear-cache testserver 2>&1)
assert_eq "exit code is 0 for --clear-cache <server>" "0" "$?"
assert_contains "confirms cache cleared" "Cache cleared for server: testserver" "$_out_cc_ok"
_val=$(git config --global --get "grub.testserver.gitdir" 2>/dev/null)
assert_empty "git config was removed" "$_val"

# ---------------------------------------------------------------------------
# 5. Invalid repository path & invalid extra-vars file
# ---------------------------------------------------------------------------
describe "repository validation: non-existent path exits 8"
_out_badrepo=$(bash "$GRUB_CLIENT" --repo-path "${TEST_TMPDIR}/nonexistent_dir" myserver 2>&1)
assert_eq "exit code is 8 for non-existent repo" "8" "$?"
assert_contains "error message for non-existent repo" "Error: Repository path" "$_out_badrepo"

describe "inventory & extra-vars file validation: non-existent files exit 4"
_dummy_repo="${TEST_TMPDIR}/dummy_repo"
mkdir -p "$_dummy_repo"
git -C "$_dummy_repo" init >/dev/null 2>&1
git -C "$_dummy_repo" remote add origin https://github.com/example/repo.git >/dev/null 2>&1

_out_badinv=$(bash "$GRUB_CLIENT" --inventory "${TEST_TMPDIR}/missing.yml" myserver 2>&1)
assert_eq "exit code is 4 for non-existent inventory" "4" "$?"
assert_contains "error message for non-existent inventory" "Error: --inventory file not found" "$_out_badinv"

_out_bad_i=$(bash "$GRUB_CLIENT" -i "${TEST_TMPDIR}/missing.yml" myserver 2>&1)
assert_eq "exit code is 4 for non-existent -i inventory" "4" "$?"
assert_contains "error message for non-existent -i inventory" "Error: --inventory file not found" "$_out_bad_i"

_out_badev=$(bash "$GRUB_CLIENT" --repo-path "$_dummy_repo" -e "${TEST_TMPDIR}/missing.yml" myserver 2>&1)
assert_eq "exit code is 4 for non-existent extra-vars" "4" "$?"
assert_contains "error message for non-existent extra-vars" "Error: --extra-vars file not found" "$_out_badev"

# ---------------------------------------------------------------------------
# 6. Option Precedence & Inventory resolution (via verbose tracing)
# ---------------------------------------------------------------------------
describe "option precedence: CLI --server-root overrides inventory"
_out_trace=$(bash "$GRUB_CLIENT" -v --repo-path "$_dummy_repo" --inventory "${FIXTURES}/inventory.yml" --server-root /cli/override/root myzos 2>&1 || true)
assert_contains "uses CLI server_root override" "Using CLI server_root: /cli/override/root" "$_out_trace"

describe "option precedence: inventory grub_server_root used when CLI omitted"
_out_trace2=$(bash "$GRUB_CLIENT" -v --repo-path "$_dummy_repo" --inventory "${FIXTURES}/inventory.yml" myzos 2>&1 || true)
assert_contains "uses inventory server_root" "Inventory: grub_server_root=/u/zosuser/projects" "$_out_trace2"

_out_trace2_short=$(bash "$GRUB_CLIENT" -v --repo-path "$_dummy_repo" -i "${FIXTURES}/inventory.yml" myzos 2>&1 || true)
assert_contains "-i short option loads inventory" "Inventory: grub_server_root=/u/zosuser/projects" "$_out_trace2_short"

describe "option precedence: CLI --git-dir overrides inventory"
_out_trace3=$(bash "$GRUB_CLIENT" -v --repo-path "$_dummy_repo" --inventory "${FIXTURES}/inventory.yml" --git-dir /cli/override/git myzos 2>&1 || true)
assert_contains "uses CLI git_dir override" "Using specified git_dir: /cli/override/git" "$_out_trace3"

describe "option precedence: inventory grub_git_dir used when CLI omitted"
_out_trace4=$(bash "$GRUB_CLIENT" -v --repo-path "$_dummy_repo" --inventory "${FIXTURES}/inventory.yml" myzos 2>&1 || true)
assert_contains "uses inventory git_dir" "Inventory: grub_git_dir=/usr/lpp/IBM/foz/v1r1/bin" "$_out_trace4"

describe "multiplexing: enabled by default and disabled via --no-multiplex"
assert_contains "multiplex enabled by default" "SSH multiplexing enabled" "$_out_trace"

_out_trace_nomux=$(bash "$GRUB_CLIENT" -v --no-multiplex --repo-path "$_dummy_repo" --inventory "${FIXTURES}/inventory.yml" myzos 2>&1 || true)
case "$_out_trace_nomux" in
  *"SSH multiplexing enabled"*) _fail "no-multiplex disables multiplexing" "multiplex disabled" "multiplex enabled" ;;
  *)                            _pass "no-multiplex disables multiplexing" ;;
esac

describe "inventory SSH options: passed into GIT_SSH_COMMAND"
assert_contains "ansible_host in GIT_SSH_COMMAND" "-o HostName=zos.example.com" "$_out_trace"
assert_contains "ansible_user in GIT_SSH_COMMAND" "-o User=zosuser" "$_out_trace"
assert_contains "ansible_port in GIT_SSH_COMMAND" "-o Port=2022" "$_out_trace"
assert_contains "ansible_ssh_common_args in GIT_SSH_COMMAND" "-o ProxyJump=jump.example.com" "$_out_trace"

# ---------------------------------------------------------------------------
# 7. Flexible Flag & Positional Placement
# ---------------------------------------------------------------------------
describe "flexible argument placement: flags after server argument"
_out_after=$(bash "$GRUB_CLIENT" myzos -v --repo-path "$_dummy_repo" --inventory "${FIXTURES}/inventory.yml" 2>&1 || true)
assert_contains "parses flags after positional server" "Server: myzos" "$_out_after"
assert_contains "parses inventory flag after positional server" "Inventory: ansible_host=zos.example.com" "$_out_after"

describe "flexible argument placement: unquoted multi-word build commands"
_out_multi=$(bash "$GRUB_CLIENT" -v --repo-path "$_dummy_repo" --inventory "${FIXTURES}/inventory.yml" myzos make -j8 test 2>&1 || true)
assert_contains "joins multi-word build command" "Build command: make -j8 test" "$_out_multi"

describe "explicit end of options: -- allows flag-like build commands"
_out_dashdash=$(bash "$GRUB_CLIENT" -v --repo-path "$_dummy_repo" --inventory "${FIXTURES}/inventory.yml" myzos -- -v 2>&1 || true)
assert_contains "treats -v as build command after --" "Build command: -v" "$_out_dashdash"

print_summary
