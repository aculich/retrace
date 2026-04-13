# Retrace local data: what it is and how big

All paths under `~/Library/Application Support/Retrace/` unless noted.

## Size breakdown (typical)

| What | Size | Why |
|------|------|-----|
| **chunks/** | **largest** | Recorded screen frames (images/video). Organized by year-month (e.g. `202602`), then day/hour, then timestamped files. |
| **logs/** | can be large | Process/CPU usage logs (e.g. `cpu_process_usage.jsonl`). |
| **favicon_cache/** | small | Cached favicons for the UI. |
| **retrace.db** + **-shm** / **-wal** | small | Main SQLite DB: timeline metadata, search index. **Important to backup.** |
| **app_names.json** | tiny | Cache of app names. |
| **Preferences** (`~/Library/Preferences/io.retrace.app.plist`) | tiny | UserDefaults: shortcuts, UI toggles, etc. **Important to backup.** |

## Backup without the bulk

Use `./scripts/backup_retrace_data.sh` (optional `--include-logs`). It backs up DB + prefs + `app_names.json` and excludes `chunks/` by default.
