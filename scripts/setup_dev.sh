#!/bin/bash
# =============================================================================
# Retrace Development Environment Setup
# =============================================================================
# Verifies prerequisites, resolves dependencies, builds, and runs tests.
# Usage: ./scripts/setup_dev.sh [--skip-tests]
# =============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SKIP_TESTS=false
if [[ "$1" == "--skip-tests" ]]; then
    SKIP_TESTS=true
fi

ERRORS=0

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}  Retrace Development Environment Setup${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

# ---------------------------------------------------------------------------
# 1. Check macOS version (require 13.0+)
# ---------------------------------------------------------------------------
echo -e "${YELLOW}[1/7] Checking macOS version...${NC}"
MACOS_VERSION=$(sw_vers -productVersion)
MACOS_MAJOR=$(echo "$MACOS_VERSION" | cut -d. -f1)
if [ "$MACOS_MAJOR" -lt 13 ]; then
    echo -e "${RED}  macOS 13.0+ (Ventura) required, found ${MACOS_VERSION}${NC}"
    ERRORS=$((ERRORS + 1))
else
    echo -e "${GREEN}  macOS ${MACOS_VERSION}${NC}"
fi

# ---------------------------------------------------------------------------
# 2. Check architecture (require arm64 / Apple Silicon)
# ---------------------------------------------------------------------------
echo -e "${YELLOW}[2/7] Checking architecture...${NC}"
ARCH=$(uname -m)
if [ "$ARCH" != "arm64" ]; then
    echo -e "${RED}  Apple Silicon (arm64) required, found ${ARCH}${NC}"
    ERRORS=$((ERRORS + 1))
else
    echo -e "${GREEN}  Apple Silicon (${ARCH})${NC}"
fi

# ---------------------------------------------------------------------------
# 3. Check Xcode / Command Line Tools + Swift
# ---------------------------------------------------------------------------
echo -e "${YELLOW}[3/7] Checking Xcode and Swift...${NC}"

if ! xcode-select -p &>/dev/null; then
    echo -e "${RED}  Xcode Command Line Tools not found.${NC}"
    echo -e "${RED}  Install with: xcode-select --install${NC}"
    ERRORS=$((ERRORS + 1))
else
    XCODE_PATH=$(xcode-select -p)
    echo -e "${GREEN}  Xcode tools: ${XCODE_PATH}${NC}"
fi

SWIFT_VERSION=$(swift --version 2>/dev/null | head -1 || echo "not found")
if echo "$SWIFT_VERSION" | grep -q "not found"; then
    echo -e "${RED}  Swift not found. Install Xcode 15+.${NC}"
    ERRORS=$((ERRORS + 1))
else
    echo -e "${GREEN}  ${SWIFT_VERSION}${NC}"
fi

# ---------------------------------------------------------------------------
# 4. Check optional tools
# ---------------------------------------------------------------------------
echo -e "${YELLOW}[4/7] Checking optional tools...${NC}"

if command -v xcodegen &>/dev/null; then
    echo -e "${GREEN}  xcodegen: $(xcodegen --version 2>/dev/null || echo 'installed')${NC}"
else
    echo -e "${YELLOW}  xcodegen: not installed (optional, needed for release builds)${NC}"
    echo -e "${YELLOW}    Install with: brew install xcodegen${NC}"
fi

if command -v swiftlint &>/dev/null; then
    echo -e "${GREEN}  swiftlint: $(swiftlint version 2>/dev/null)${NC}"
else
    echo -e "${YELLOW}  swiftlint: not installed (optional)${NC}"
fi

if command -v swiftformat &>/dev/null; then
    echo -e "${GREEN}  swiftformat: $(swiftformat --version 2>/dev/null)${NC}"
else
    echo -e "${YELLOW}  swiftformat: not installed (optional)${NC}"
fi

if command -v gh &>/dev/null; then
    echo -e "${GREEN}  gh CLI: $(gh --version | head -1)${NC}"
else
    echo -e "${YELLOW}  gh CLI: not installed (optional, for fork/PR workflow)${NC}"
fi

# ---------------------------------------------------------------------------
# 5. Bail out if required checks failed
# ---------------------------------------------------------------------------
if [ "$ERRORS" -gt 0 ]; then
    echo ""
    echo -e "${RED}${ERRORS} required check(s) failed. Fix the issues above and re-run.${NC}"
    exit 1
fi

# ---------------------------------------------------------------------------
# 6. Resolve dependencies
# ---------------------------------------------------------------------------
echo ""
echo -e "${YELLOW}[5/7] Resolving Swift packages...${NC}"
swift package resolve
echo -e "${GREEN}  Packages resolved.${NC}"

# ---------------------------------------------------------------------------
# 7. Build (release)
# ---------------------------------------------------------------------------
echo ""
echo -e "${YELLOW}[6/7] Building (release configuration)...${NC}"
swift build -c release
echo -e "${GREEN}  Build succeeded.${NC}"

# ---------------------------------------------------------------------------
# 8. Run tests
# ---------------------------------------------------------------------------
if [ "$SKIP_TESTS" = true ]; then
    echo ""
    echo -e "${YELLOW}[7/7] Skipping tests (--skip-tests flag).${NC}"
else
    echo ""
    echo -e "${YELLOW}[7/7] Running tests...${NC}"
    swift test
    echo -e "${GREEN}  All tests passed.${NC}"
fi

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
echo ""
echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN}  Development environment is ready.${NC}"
echo -e "${GREEN}================================================${NC}"
echo ""
echo "Next steps:"
echo "  ./dev.sh                     # Build and run (debug)"
echo "  ./build_and_sign.sh          # Build signed .app bundle"
echo "  swift test                   # Run tests"
echo "  open Package.swift           # Open in Xcode"
echo ""
echo "See QUICKSTART.md for more details."
