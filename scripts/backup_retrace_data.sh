#!/bin/bash
# =============================================================================
# Backup Retrace data excluding the big bulk (chunks, optionally logs)
# =============================================================================
# Backs up: DB, app_names.json, Preferences. Optionally logs.
# Excludes: chunks (recorded frames), favicon_cache.
#
# Usage: ./scripts/backup_retrace_data.sh [--include-logs]
#   (no args)      Backup DB + prefs + app_names only (~1 MB)
#   --include-logs Also include logs/ (~231 MB)
# =============================================================================

set -e

cd "$(dirname "$0")/.."
SAVEDIR="$HOME/Library/Application Support/Retrace"
PREFS="$HOME/Library/Preferences/io.retrace.app.plist"
BACKUP_DIR="${RETRACE_BACKUP_DIR:-$HOME/Retrace-backups}"
ARCHIVE="$BACKUP_DIR/retrace-backup-$(date +%Y%m%d-%H%M).tar.gz"

INCLUDE_LOGS=false
[[ "$1" == "--include-logs" ]] && INCLUDE_LOGS=true

mkdir -p "$BACKUP_DIR"

echo "Backing up Retrace (excluding chunks and favicon_cache)..."
if [ "$INCLUDE_LOGS" = true ]; then
    echo "  Including logs."
fi
echo "  Output: $ARCHIVE"
echo ""

# Paths relative to $HOME; only add if they exist
LIST=$(mktemp)
BASE="Library/Application Support/Retrace"
[ -f "$SAVEDIR/retrace.db" ]           && echo "$BASE/retrace.db" >> "$LIST"
[ -f "$SAVEDIR/retrace.db-wal" ]      && echo "$BASE/retrace.db-wal" >> "$LIST"
[ -f "$SAVEDIR/retrace.db-shm" ]      && echo "$BASE/retrace.db-shm" >> "$LIST"
[ -f "$SAVEDIR/app_names.json" ]      && echo "$BASE/app_names.json" >> "$LIST"
[ -f "$PREFS" ]                       && echo "Library/Preferences/io.retrace.app.plist" >> "$LIST"
[ "$INCLUDE_LOGS" = true ] && [ -d "$SAVEDIR/logs" ] && echo "$BASE/logs" >> "$LIST"

tar -czf "$ARCHIVE" -C "$HOME" -T "$LIST"
rm -f "$LIST"

echo "Done. $(ls -lh "$ARCHIVE" | awk '{print $5}')"
echo "  $ARCHIVE"
