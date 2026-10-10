#!/bin/sh
# test_patch.sh — unit tests for patch generation and application
# Tests that local unstaged, staged, and untracked changes are accurately captured and applied.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "${SCRIPT_DIR}/lib/assert.sh"

TEST_TMPDIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TEST_TMPDIR"
}
trap cleanup EXIT INT TERM

# ---------------------------------------------------------------------------
# Setup local repo and remote clone repo
# ---------------------------------------------------------------------------
LOCAL_REPO="${TEST_TMPDIR}/local_repo"
REMOTE_REPO="${TEST_TMPDIR}/remote_repo"

mkdir -p "$LOCAL_REPO" "$REMOTE_REPO"

git -C "$LOCAL_REPO" init -b main >/dev/null 2>&1 || (git -C "$LOCAL_REPO" init >/dev/null 2>&1 && git -C "$LOCAL_REPO" checkout -b main >/dev/null 2>&1)
git -C "$LOCAL_REPO" config user.email "test@example.com"
git -C "$LOCAL_REPO" config user.name "Test Runner"

# Create base tracked files
echo "base tracked" > "$LOCAL_REPO/tracked.txt"
mkdir -p "$LOCAL_REPO/sub"
echo "sub tracked" > "$LOCAL_REPO/sub/nested.txt"
git -C "$LOCAL_REPO" add tracked.txt sub/nested.txt
git -C "$LOCAL_REPO" commit -m "base commit" >/dev/null 2>&1

# Clone to remote repo so both have exact same commit
git clone "$LOCAL_REPO" "$REMOTE_REPO" >/dev/null 2>&1

# ---------------------------------------------------------------------------
# Helper: simulate grub_client patch creation logic
# ---------------------------------------------------------------------------
create_grub_patch() {
  _repo="$1"
  _patch_out="$2"

  (
    cd "$_repo" || exit 1
    {
      git diff --src-prefix=a/ --dst-prefix=b/ --no-color HEAD
      git ls-files --others --exclude-standard | while read -r file; do
        [ -f "$file" ] || continue
        git diff --no-index --src-prefix=a/ --dst-prefix=b/ --no-color /dev/null "$file" 2>/dev/null || true
      done
    } > "$_patch_out"
  )
}

# ---------------------------------------------------------------------------
# 1. Unstaged modifications to tracked files
# ---------------------------------------------------------------------------
describe "patch: unstaged changes to tracked files"
echo "modified content" > "$LOCAL_REPO/tracked.txt"

_patch="${TEST_TMPDIR}/patch1.patch"
create_grub_patch "$LOCAL_REPO" "$_patch"

assert_not_empty "patch file created" "$(cat "$_patch")"
assert_contains "contains modified diff" "modified content" "$(cat "$_patch")"

# Apply on remote repo
git -C "$REMOTE_REPO" apply --whitespace=nowarn "$_patch"
_remote_content=$(cat "$REMOTE_REPO/tracked.txt")
assert_eq "remote file updated with unstaged change" "modified content" "$_remote_content"

# ---------------------------------------------------------------------------
# 2. Untracked new files (root and nested)
# ---------------------------------------------------------------------------
describe "patch: untracked new files (root and nested)"
echo "brand new file" > "$LOCAL_REPO/new_root.txt"
mkdir -p "$LOCAL_REPO/sub/dir"
echo "brand new nested" > "$LOCAL_REPO/sub/dir/new_nested.txt"

# Reset remote repo to clean state first
git -C "$REMOTE_REPO" reset --hard HEAD >/dev/null 2>&1
git -C "$REMOTE_REPO" clean -fdx >/dev/null 2>&1

_patch2="${TEST_TMPDIR}/patch2.patch"
create_grub_patch "$LOCAL_REPO" "$_patch2"

# Apply on remote repo
git -C "$REMOTE_REPO" apply --whitespace=nowarn "$_patch2"
_app_rc=$?
assert_eq "git apply succeeded with exit code 0" "0" "$_app_rc"

_remote_root=$(cat "$REMOTE_REPO/new_root.txt" 2>/dev/null)
assert_eq "untracked root file created on remote" "brand new file" "$_remote_root"

_remote_nested=$(cat "$REMOTE_REPO/sub/dir/new_nested.txt" 2>/dev/null)
assert_eq "untracked nested file created on remote" "brand new nested" "$_remote_nested"

# ---------------------------------------------------------------------------
# 3. Staged changes
# ---------------------------------------------------------------------------
describe "patch: staged changes"
echo "staged modification" > "$LOCAL_REPO/tracked.txt"
git -C "$LOCAL_REPO" add "$LOCAL_REPO/tracked.txt"

git -C "$REMOTE_REPO" reset --hard HEAD >/dev/null 2>&1
git -C "$REMOTE_REPO" clean -fdx >/dev/null 2>&1

_patch3="${TEST_TMPDIR}/patch3.patch"
create_grub_patch "$LOCAL_REPO" "$_patch3"

git -C "$REMOTE_REPO" apply --whitespace=nowarn "$_patch3"
_remote_staged=$(cat "$REMOTE_REPO/tracked.txt")
assert_eq "staged change applied on remote" "staged modification" "$_remote_staged"

# ---------------------------------------------------------------------------
# 4. Mixed changes: staged, unstaged, untracked all together
# ---------------------------------------------------------------------------
describe "patch: combined staged, unstaged, and untracked changes"
echo "staged mod" > "$LOCAL_REPO/tracked.txt"
git -C "$LOCAL_REPO" add "$LOCAL_REPO/tracked.txt"
echo "unstaged mod in nested" > "$LOCAL_REPO/sub/nested.txt"
echo "untracked mixed" > "$LOCAL_REPO/untracked_mix.txt"

git -C "$REMOTE_REPO" reset --hard HEAD >/dev/null 2>&1
git -C "$REMOTE_REPO" clean -fdx >/dev/null 2>&1

_patch4="${TEST_TMPDIR}/patch4.patch"
create_grub_patch "$LOCAL_REPO" "$_patch4"

git -C "$REMOTE_REPO" apply --whitespace=nowarn --allow-empty "$_patch4"
assert_eq "git apply succeeded for combined patch" "0" "$?"

assert_eq "staged change applied" "staged mod" "$(cat "$REMOTE_REPO/tracked.txt")"
assert_eq "unstaged change applied" "unstaged mod in nested" "$(cat "$REMOTE_REPO/sub/nested.txt")"
assert_eq "untracked file created" "untracked mixed" "$(cat "$REMOTE_REPO/untracked_mix.txt")"

# ---------------------------------------------------------------------------
# 5. Empty patch application with --allow-empty
# ---------------------------------------------------------------------------
describe "patch: empty patch file with --allow-empty"
_empty_patch="${TEST_TMPDIR}/empty.patch"
touch "$_empty_patch"

git -C "$REMOTE_REPO" apply --whitespace=nowarn --allow-empty "$_empty_patch"
assert_eq "empty patch succeeds with --allow-empty" "0" "$?"

print_summary
