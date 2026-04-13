#!/bin/bash
# =============================================================================
# Reset Retrace permissions and prepare for clean install
# =============================================================================
# DEFAULT: Safe. Quit app, build, install. Preserves ALL data and settings.
#
# Use --full-reset ONLY when you explicitly want a clean slate. Requires
# typing 'yes' to confirm. Deletes database, recordings, settings, resets
# permissions.
#
# Usage: ./scripts/reset_permissions_and_install.sh [--full-reset]
#   (no args)     Safe: build + install only. Data and settings preserved.
#   --full-reset  DESTRUCTIVE: wipe data, settings, permissions. Must confirm.
# =============================================================================

set -e

BUNDLE_ID="io.retrace.app"
APP_NAME="Retrace"
APP_PATH="/Applications/${APP_NAME}.app"
BUILD_APP=".build/release/${APP_NAME}.app"

FULL_RESET=false
[[ "$1" == "--full-reset" ]] && FULL_RESET=true

echo "=== Retrace: Build and install ==="
echo ""

# 0. If --full-reset, require explicit confirmation
if [ "$FULL_RESET" = true ]; then
    echo "DESTRUCTIVE: --full-reset will:"
    echo "  - Delete all recordings and database (~/Library/Application Support/Retrace)"
    echo "  - Clear all settings and preferences"
    echo "  - Reset Screen Recording, Accessibility, Input Monitoring permissions"
    echo ""
    printf "Type 'yes' to confirm and continue: "
    read -r confirm
    if [ "$confirm" != "yes" ]; then
        echo "Aborted. No changes made."
        exit 1
    fi
    echo ""
fi

# 1. Quit Retrace if running
echo "[1/4] Quitting Retrace..."
pkill -x "$APP_NAME" 2>/dev/null && echo "  Quit." || echo "  Not running."

# 2. (Full reset only) Reset TCC, clear prefs, delete data
if [ "$FULL_RESET" = true ]; then
    echo ""
    echo "[2/4] Resetting permissions and wiping data..."
    if command -v tccutil &>/dev/null; then
        sudo tccutil reset ScreenCapture "$BUNDLE_ID" 2>/dev/null || true
        sudo tccutil reset Accessibility "$BUNDLE_ID" 2>/dev/null || true
        sudo tccutil reset InputMonitoring "$BUNDLE_ID" 2>/dev/null || true
    fi
    defaults delete "$BUNDLE_ID" 2>/dev/null || true
    rm -rf "$HOME/Library/Application Support/Retrace"
    echo "  Done."
fi

# 3. Rebuild and reinstall
echo ""
echo "[3/4] Building and installing..."
if [ -f "build_and_sign.sh" ]; then
    ./build_and_sign.sh
else
    echo "  Run from repo root. build_and_sign.sh not found."
    exit 1
fi

# 4. Remove quarantine (if present)
echo ""
echo "[4/4] Removing quarantine attribute..."
if [ -d "$APP_PATH" ]; then
    if xattr "$APP_PATH" 2>/dev/null | grep -q com.apple.quarantine; then
        xattr -d com.apple.quarantine "$APP_PATH"
        echo "  Removed."
    else
        echo "  Not in quarantine."
    fi
fi

echo ""
echo "=== Done ==="
echo ""
echo "Next: open $APP_PATH"
if [ "$FULL_RESET" = true ]; then
    echo ""
    echo "The app will prompt for Screen Recording and Accessibility."
    echo "Grant both in System Settings when asked."
fi
