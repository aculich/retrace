#!/bin/bash
# =============================================================================
# Sync fork with upstream, rebase your branch, then rebuild
# =============================================================================
# Fetches upstream, mirrors upstream/main to origin/main (fork default track),
# checks out your dev branch (develop or main), rebases onto upstream/main,
# then builds and installs. NEVER wipes data or settings.
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
    echo "[0/6] Stashing uncommitted changes..."
    git stash push -m "sync-and-rebuild auto-stash"
    STASHED=1
else
    STASHED=0
fi

echo "[1/6] Fetching upstream..."
git fetch upstream

echo "[2/6] Mirroring upstream/main to origin/main (fork tracks upstream)..."
if git remote get-url origin &>/dev/null; then
    git push origin upstream/main:main --force-with-lease
    # Keep local ref main aligned (no checkout) when the branch exists
    git branch -f main upstream/main 2>/dev/null || true
else
    echo "  (no origin remote; skipping mirror push)"
fi

echo "[3/6] Checking out $BRANCH..."
git checkout "$BRANCH"

echo "[4/6] Rebasing $BRANCH onto upstream/main..."
git rebase upstream/main

echo "[5/6] Restoring stashed changes (if any)..."
if [ "$STASHED" -eq 1 ]; then
    git stash pop || true
fi

echo "[6/6] Building and installing (preserves all data and settings)..."
./build_and_sign.sh

echo ""
echo "=== Done ==="
echo "  origin/main now matches upstream/main (unless push failed)."
echo "  Branch $BRANCH is now rebased on upstream/main."
echo "  App updated in /Applications/Retrace.app (data and settings preserved)."
echo "  To push your working branch: git push origin $BRANCH --force-with-lease"
