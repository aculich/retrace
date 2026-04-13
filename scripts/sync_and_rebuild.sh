#!/bin/bash
# =============================================================================
# Sync fork with upstream, rebase your branch, then rebuild
# =============================================================================
# Fetches upstream, checks out your dev branch (develop or main), rebases onto
# upstream/main, then builds and installs. NEVER wipes data or settings.
#
# Usage: ./scripts/sync_and_rebuild.sh [--main]
#   --main       Use main instead of develop
# =============================================================================

set -e

cd "$(dirname "$0")/.."
REPO_ROOT="$PWD"

USE_MAIN=false
for arg in "$@"; do
    [[ "$arg" == "--main" ]] && USE_MAIN=true
done

if [ "$USE_MAIN" = true ]; then
    BRANCH="main"
else
    BRANCH="develop"
fi

echo "=== Sync fork with upstream and rebuild ==="
echo "  Branch: $BRANCH (rebase onto upstream/main)"
echo ""

# Ensure upstream remote exists
if ! git remote get-url upstream &>/dev/null; then
    echo "Error: No 'upstream' remote. Add it with:"
    echo "  git remote add upstream https://github.com/haseab/retrace.git"
    exit 1
fi

# Stash uncommitted changes (modified/staged only; untracked stay)
if [ -n "$(git diff --name-only 2>/dev/null)" ] || [ -n "$(git diff --cached --name-only 2>/dev/null)" ]; then
    echo "[0/5] Stashing uncommitted changes..."
    git stash push -m "sync-and-rebuild auto-stash"
    STASHED=1
else
    STASHED=0
fi

echo "[1/5] Fetching upstream..."
git fetch upstream

echo "[2/5] Checking out $BRANCH..."
git checkout "$BRANCH"

echo "[3/5] Rebasing $BRANCH onto upstream/main..."
git rebase upstream/main

echo "[4/5] Restoring stashed changes (if any)..."
if [ "$STASHED" -eq 1 ]; then
    git stash pop || true
fi

echo "[5/5] Building and installing (preserves all data and settings)..."
./build_and_sign.sh

echo ""
echo "=== Done ==="
echo "  Branch $BRANCH is now rebased on upstream/main."
echo "  App updated in /Applications/Retrace.app (data and settings preserved)."
echo "  To push to your fork: git push origin $BRANCH --force-with-lease"
