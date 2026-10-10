#!/bin/sh
# test_remote_setup.sh — unit tests for grub_remote_setup
# Tests remote repository initialization, cleanup, and commit-based push caching.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "${SCRIPT_DIR}/lib/assert.sh"

GRUB_REMOTE_SETUP="${SCRIPT_DIR}/../bin/grub_remote_setup"
GIT_BIN_DIR="$(dirname "$(which git)")"
TEST_TMPDIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TEST_TMPDIR"
}
trap cleanup EXIT INT TERM

# ---------------------------------------------------------------------------
# 1. New repository creation
# ---------------------------------------------------------------------------
describe "new repo creation: initialises and configures repository"
_new_repo="${TEST_TMPDIR}/new_repo"

_output=$(sh "$GRUB_REMOTE_SETUP" "$_new_repo" "$GIT_BIN_DIR" "run_1" "fakecommit" "main" 2>&1)

assert_contains "emits REPO_CREATED" "REPO_CREATED" "$_output"
assert_contains "emits PUSH_NEEDED=1" "PUSH_NEEDED=1" "$_output"
assert_contains "emits EXPANDED_PATH" "EXPANDED_PATH=$_new_repo" "$_output"
assert_contains "emits REMOTE_TMPDIR" "REMOTE_TMPDIR=" "$_output"

if [ -d "$_new_repo/.git" ]; then
  _pass ".git directory exists"
else
  _fail ".git directory exists" "directory" "missing"
fi

_deny_curr=$(git -C "$_new_repo" config --local receive.denyCurrentBranch 2>/dev/null)
assert_eq "receive.denyCurrentBranch is updateInstead" "updateInstead" "$_deny_curr"

_core_comp=$(git -C "$_new_repo" config --local core.compression 2>/dev/null)
assert_eq "core.compression is 6" "6" "$_core_comp"

_proto_ver=$(git -C "$_new_repo" config --local protocol.version 2>/dev/null)
assert_eq "protocol.version is 2" "2" "$_proto_ver"

# ---------------------------------------------------------------------------
# 2. Existing repo: Cache hit (matching commit and branch)
# ---------------------------------------------------------------------------
describe "cache hit: matching commit and branch skips push"
_existing_repo="${TEST_TMPDIR}/existing_repo"
mkdir -p "$_existing_repo"
git -C "$_existing_repo" init -b main >/dev/null 2>&1 || (git -C "$_existing_repo" init >/dev/null 2>&1 && git -C "$_existing_repo" checkout -b main >/dev/null 2>&1)
git -C "$_existing_repo" config user.email "test@example.com"
git -C "$_existing_repo" config user.name "Test Runner"
echo "hello world" > "$_existing_repo/file.txt"
git -C "$_existing_repo" add file.txt
git -C "$_existing_repo" commit -m "initial commit" >/dev/null 2>&1
_head_commit=$(git -C "$_existing_repo" rev-parse HEAD)

_output=$(sh "$GRUB_REMOTE_SETUP" "$_existing_repo" "$GIT_BIN_DIR" "run_2" "$_head_commit" "main" 2>&1)

assert_contains "emits PUSH_NEEDED=0 on match" "PUSH_NEEDED=0" "$_output"
assert_contains "emits REPO_CLEANED" "REPO_CLEANED" "$_output"

# ---------------------------------------------------------------------------
# 3. Existing repo: Cache miss (different commit)
# ---------------------------------------------------------------------------
describe "cache miss: differing commit requires push"
_different_commit="0000000000000000000000000000000000000000"
_output=$(sh "$GRUB_REMOTE_SETUP" "$_existing_repo" "$GIT_BIN_DIR" "run_3" "$_different_commit" "main" 2>&1)

assert_contains "emits PUSH_NEEDED=1 on commit mismatch" "PUSH_NEEDED=1" "$_output"

# ---------------------------------------------------------------------------
# 4. Existing repo: Cache miss (different branch)
# ---------------------------------------------------------------------------
describe "cache miss: differing branch requires push"
_output=$(sh "$GRUB_REMOTE_SETUP" "$_existing_repo" "$GIT_BIN_DIR" "run_4" "$_head_commit" "other-branch" 2>&1)

assert_contains "emits PUSH_NEEDED=1 on branch mismatch" "PUSH_NEEDED=1" "$_output"

# ---------------------------------------------------------------------------
# 5. Working tree cleanup: resets dirty working tree on setup
# ---------------------------------------------------------------------------
describe "working tree cleanup: removes untracked and resets modified files"
echo "modified content" > "$_existing_repo/file.txt"
echo "untracked" > "$_existing_repo/untracked.tmp"

_output=$(sh "$GRUB_REMOTE_SETUP" "$_existing_repo" "$GIT_BIN_DIR" "run_5" "$_head_commit" "main" 2>&1)

assert_contains "still reports PUSH_NEEDED=0 when HEAD matches" "PUSH_NEEDED=0" "$_output"

_file_content=$(cat "$_existing_repo/file.txt")
assert_eq "modified file reset to HEAD content" "hello world" "$_file_content"

if [ ! -f "$_existing_repo/untracked.tmp" ]; then
  _pass "untracked file was cleaned"
else
  _fail "untracked file was cleaned" "file removed" "file exists"
fi

# ---------------------------------------------------------------------------
# 6. Fallback when commit or branch arguments are omitted
# ---------------------------------------------------------------------------
describe "argument fallback: missing commit or branch defaults to push needed"
_output=$(sh "$GRUB_REMOTE_SETUP" "$_existing_repo" "$GIT_BIN_DIR" "run_6" 2>&1)

assert_contains "defaults to PUSH_NEEDED=1 when args missing" "PUSH_NEEDED=1" "$_output"

# ---------------------------------------------------------------------------
# 7. .gitattributes modification triggers full repo recreation
# ---------------------------------------------------------------------------
describe "gitattributes change: modified .gitattributes recreates repo"
_attr_repo="${TEST_TMPDIR}/attr_repo"
mkdir -p "$_attr_repo"
git -C "$_attr_repo" init -b main >/dev/null 2>&1 || (git -C "$_attr_repo" init >/dev/null 2>&1 && git -C "$_attr_repo" checkout -b main >/dev/null 2>&1)
git -C "$_attr_repo" config user.email "test@example.com"
git -C "$_attr_repo" config user.name "Test Runner"
echo "*.c zos-working-tree-encoding=ibm-1047" > "$_attr_repo/.gitattributes"
git -C "$_attr_repo" add .gitattributes
git -C "$_attr_repo" commit -m "add gitattributes" >/dev/null 2>&1
_attr_commit=$(git -C "$_attr_repo" rev-parse HEAD)
_attr_hash1=$(git -C "$_attr_repo" hash-object .gitattributes)

# First run with same hash -> clean, no push
_output=$(sh "$GRUB_REMOTE_SETUP" "$_attr_repo" "$GIT_BIN_DIR" "run_7a" "$_attr_commit" "main" "$_attr_hash1" 2>&1)
assert_contains "matching gitattributes does not recreate" "REPO_CLEANED" "$_output"
assert_contains "matching gitattributes push not needed" "PUSH_NEEDED=0" "$_output"

# Second run with different gitattributes hash -> recreate repo
_fake_new_hash="1111222233334444555566667777888899990000"
_output=$(sh "$GRUB_REMOTE_SETUP" "$_attr_repo" "$GIT_BIN_DIR" "run_7b" "$_attr_commit" "main" "$_fake_new_hash" 2>&1)
assert_contains "differing gitattributes emits REPO_RECREATED" "REPO_RECREATED" "$_output"
assert_contains "differing gitattributes emits PUSH_NEEDED=1" "PUSH_NEEDED=1" "$_output"

_deny_curr=$(git -C "$_attr_repo" config --local receive.denyCurrentBranch 2>/dev/null)
assert_eq "recreated repo has receive.denyCurrentBranch" "updateInstead" "$_deny_curr"

# ---------------------------------------------------------------------------
# 8. .gitattributes added or removed triggers full repo recreation
# ---------------------------------------------------------------------------
describe "gitattributes change: added or removed .gitattributes recreates repo"
_noattr_repo="${TEST_TMPDIR}/noattr_repo"
mkdir -p "$_noattr_repo"
git -C "$_noattr_repo" init -b main >/dev/null 2>&1 || (git -C "$_noattr_repo" init >/dev/null 2>&1 && git -C "$_noattr_repo" checkout -b main >/dev/null 2>&1)
git -C "$_noattr_repo" config user.email "test@example.com"
git -C "$_noattr_repo" config user.name "Test Runner"
echo "hello" > "$_noattr_repo/file.txt"
git -C "$_noattr_repo" add file.txt
git -C "$_noattr_repo" commit -m "init" >/dev/null 2>&1
_noattr_commit=$(git -C "$_noattr_repo" rev-parse HEAD)

# Remote currently has no .gitattributes ("none"), client now has one
_output=$(sh "$GRUB_REMOTE_SETUP" "$_noattr_repo" "$GIT_BIN_DIR" "run_8" "$_noattr_commit" "main" "$_attr_hash1" 2>&1)
assert_contains "adding gitattributes emits REPO_RECREATED" "REPO_RECREATED" "$_output"
assert_contains "adding gitattributes emits PUSH_NEEDED=1" "PUSH_NEEDED=1" "$_output"

print_summary
