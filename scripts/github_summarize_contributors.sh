#!/bin/bash
# =============================================================================
# Summarize contributors from github_export_upstream.sh JSON cache.
# =============================================================================
# Reads: research/github-haseab/{pulls,issues,forks}.json
# Writes: research/github-haseab/contributors-summary.md (gitignored)
#
# Requires: jq
# Usage: ./scripts/github_summarize_contributors.sh
# =============================================================================

set -euo pipefail

cd "$(dirname "$0")/.."
CACHEDIR="${GITHUB_HASEAB_CACHE:-$PWD/research/github-haseab}"
OUT="$CACHEDIR/contributors-summary.md"

if ! command -v jq &>/dev/null; then
    echo "Error: install jq"
    exit 1
fi

for f in pulls.json issues.json forks.json; do
    if [[ ! -f "$CACHEDIR/$f" ]]; then
        echo "Error: missing $CACHEDIR/$f — run ./scripts/github_export_upstream.sh first"
        exit 1
    fi
done

mkdir -p "$CACHEDIR"

EXPORTED=$(jq -r '.exported_at // "unknown"' "$CACHEDIR/manifest.json" 2>/dev/null || echo "unknown")

{
    echo "# Upstream contributor signals (generated)"
    echo ""
    echo "_Cache: \`$CACHEDIR\` · manifest exported_at: **$EXPORTED**_"
    echo ""
    echo "## Merged PR authors (by merge count)"
    echo ""
    jq -r '
      [.[] | select(.merged_at != null) | .user.login] | group_by(.) | map({author: .[0], merges: length}) | sort_by(-.merges) | .[] | "- **\(.author)**: \(.merges) merged PR(s)"
    ' "$CACHEDIR/pulls.json"
    echo ""
    echo "## PR authors (all states, by PR count)"
    echo ""
    jq -r '
      [.[] | .user.login] | group_by(.) | map({author: .[0], prs: length}) | sort_by(-.prs) | .[] | "- **\(.author)**: \(.prs) PR(s)"
    ' "$CACHEDIR/pulls.json"
    echo ""
    echo "## Issue authors (issues only, excludes items that are PRs)"
    echo ""
    jq -r '
      [.[] | select(.pull_request == null) | .user.login] | group_by(.) | map({author: .[0], issues: length}) | sort_by(-.issues) | .[] | "- **\(.author)**: \(.issues) issue(s)"
    ' "$CACHEDIR/issues.json"
    echo ""
    echo "## Forks (owner, pushed_at, stars)"
    echo ""
    jq -r '
      sort_by(.pushed_at // "") | reverse | .[] |
      "- **\(.owner.login)** — pushed: \(.pushed_at // "?") · stars: \(.stargazers_count // 0)"
    ' "$CACHEDIR/forks.json"
} > "$OUT"

echo "Wrote $OUT"
