#!/bin/bash
# Build + reinstall. Preserves data and settings. Run from repo root: ./go [--full-reset]
# Use --full-reset only when you explicitly want to wipe everything (requires confirmation).
cd "$(dirname "$0")"
exec ./scripts/reset_permissions_and_install.sh "$@"
