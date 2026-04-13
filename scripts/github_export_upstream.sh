#!/bin/bash
# =============================================================================
# Export haseab/retrace PRs, issues, and forks to local JSON (gitignored).
# =============================================================================
# Requires: gh (gh auth login), jq
# Output:  research/github-haseab/{pulls,issues,forks}.json + manifest.json
#
# Usage: ./scripts/github_export_upstream.sh
# =============================================================================

set -euo pipefail

cd "$(dirname "$0")/.."
REPO_FULL="haseab/retrace"
OUTDIR="${GITHUB_HASEAB_CACHE:-$PWD/research/github-haseab}"

if ! command -v gh &>/dev/null; then
    echo "Error: install GitHub CLI (gh) and run: gh auth login"
    exit 1
fi
if ! command -v jq &>/dev/null; then
    echo "Error: install jq (e.g. brew install jq)"
    exit 1
fi

mkdir -p "$OUTDIR"

fetch_paginated() {
    local path="$1"   # e.g. repos/haseab/retrace/pulls
    local query="$2"  # e.g. state=all&per_page=100
    local prefix="$3" # temp file prefix
    local page=1
    rm -f "$OUTDIR/${prefix}-p"*.json
    while true; do
        gh api "${path}?${query}&page=${page}" > "$OUTDIR/${prefix}-p${page}.json"
        local n
        n=$(jq 'length' "$OUTDIR/${prefix}-p${page}.json")
        if [[ "$n" -eq 0 ]]; then
            rm -f "$OUTDIR/${prefix}-p${page}.json"
            break
        fi
        page=$((page + 1))
        if [[ "$n" -lt 100 ]]; then
            break
        fi
    done
    shopt -s nullglob
    local files=( "$OUTDIR/${prefix}-p"*.json )
    if (( ${#files[@]} == 0 )); then
        echo '[]' > "$OUTDIR/${prefix}.merged.json"
    else
        jq -s 'add' "${files[@]}" > "$OUTDIR/${prefix}.merged.json"
        rm -f "${files[@]}"
    fi
}

echo "Exporting to $OUTDIR ..."

echo "  pulls (state=all)..."
fetch_paginated "repos/${REPO_FULL}/pulls" "state=all&per_page=100" "pulls"
mv "$OUTDIR/pulls.merged.json" "$OUTDIR/pulls.json"

echo "  issues (state=all; includes PRs — filter pull_request in consumers)..."
fetch_paginated "repos/${REPO_FULL}/issues" "state=all&per_page=100" "issues"
mv "$OUTDIR/issues.merged.json" "$OUTDIR/issues.json"

echo "  forks..."
fetch_paginated "repos/${REPO_FULL}/forks" "per_page=100" "forks"
mv "$OUTDIR/forks.merged.json" "$OUTDIR/forks.json"

EXPORTED_AT=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
GH_VER=$(gh --version 2>/dev/null | head -1 || echo "unknown")

jq -n \
    --arg repo "$REPO_FULL" \
    --arg at "$EXPORTED_AT" \
    --arg gh "$GH_VER" \
    '{repo: $repo, exported_at: $at, gh_version: $gh, files: ["pulls.json","issues.json","forks.json"]}' \
    > "$OUTDIR/manifest.json"

echo "Done."
echo "  manifest: $OUTDIR/manifest.json"
wc -c "$OUTDIR/pulls.json" "$OUTDIR/issues.json" "$OUTDIR/forks.json" | tail -1
