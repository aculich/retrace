#!/bin/bash
# =============================================================================
# Add a fork remote and a local tracking branch (track/<owner>-<branch>).
# =============================================================================
# Idempotent: adds remote if missing; creates or force-updates tracking branch
# to match the fork branch tip after fetch.
#
# Usage: ./scripts/fork_track_remote.sh <github_owner> [branch]
#   branch defaults to main
#
# Example: ./scripts/fork_track_remote.sh stuartsc main
# =============================================================================

set -euo pipefail

cd "$(dirname "$0")/.."

OWNER="${1:?Usage: $0 <github_owner> [branch]}"
BRANCH="${2:-main}"
REMOTE="fork-${OWNER}"
REPO_URL="https://github.com/${OWNER}/retrace.git"
TRACK="track/${OWNER}-${BRANCH}"

if git remote get-url "$REMOTE" &>/dev/null; then
    echo "Remote $REMOTE already exists."
else
    echo "Adding remote $REMOTE -> $REPO_URL"
    git remote add "$REMOTE" "$REPO_URL"
fi

echo "Fetching $REMOTE $BRANCH ..."
git fetch "$REMOTE" "$BRANCH"

if git show-ref --verify --quiet "refs/heads/$TRACK"; then
    echo "Updating branch $TRACK -> $REMOTE/$BRANCH"
    git branch -f "$TRACK" "${REMOTE}/${BRANCH}"
else
    echo "Creating branch $TRACK from $REMOTE/$BRANCH"
    git branch "$TRACK" "${REMOTE}/${BRANCH}"
fi

echo ""
echo "Done. Inspect vs upstream:"
echo "  git log upstream/main..$TRACK --oneline"
echo "  open 'https://github.com/haseab/retrace/compare/main...${OWNER}:retrace:${BRANCH}'"
