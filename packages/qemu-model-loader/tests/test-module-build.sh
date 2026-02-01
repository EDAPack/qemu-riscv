#!/bin/bash
# test-module-build.sh - Test building example modules with SDK
#
# This script tests that example modules can be built using the installed SDK

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd .. && pwd)"
SDK_PATH="${1:-/usr/local}"

echo "================================"
echo "Testing Module Build"
echo "================================"
echo "SDK Path: $SDK_PATH"
echo

echo -e "${GREEN}Step 1: Checking SDK${NC}"
echo "----------------------------"

SDK_INCLUDE="$SDK_PATH/include/qemu-device"
if [[ ! -d "$SDK_INCLUDE" ]]; then
    echo -e "${RED}✗ SDK not found at $SDK_INCLUDE${NC}"
    echo
    echo "SDK must be installed first."
    echo "Run: ./tests/test-sdk-build.sh"
    echo "Or: make install-dev-sdk (from QEMU build)"
    exit 1
fi

echo -e "${GREEN}✓ SDK found${NC}"

# Check pkg-config
if pkg-config --exists qemu-device 2>/dev/null; then
    echo -e "${GREEN}✓ pkg-config configured${NC}"
    PKG_CONFIG_OK=1
else
    echo -e "${YELLOW}! pkg-config not configured (will use manual flags)${NC}"
    PKG_CONFIG_OK=0
fi
echo

echo -e "${GREEN}Step 2: Testing Example Builds${NC}"
echo "----------------------------"

EXAMPLES=(
    "minimal-sysbus"
    "uart-device"
    "pci-device"
)

BUILT=0
FAILED=0
BUILD_DIR=$(mktemp -d)
trap "rm -rf $BUILD_DIR" EXIT

for example in "${EXAMPLES[@]}"; do
    echo
    echo "Building: $example"
    echo "  ---"
    
    EXAMPLE_DIR="$SCRIPT_DIR/examples/$example"
    if [[ ! -d "$EXAMPLE_DIR" ]]; then
        echo -e "  ${RED}✗ Example not found${NC}"
        ((FAILED++))
        continue
    fi
    
    # Copy to build directory
    cp -r "$EXAMPLE_DIR" "$BUILD_DIR/$example"
    cd "$BUILD_DIR/$example"
    
    # Set up build environment
    if [[ $PKG_CONFIG_OK -eq 1 ]]; then
        export PKG_CONFIG_PATH="$SDK_PATH/lib/pkgconfig:$PKG_CONFIG_PATH"
    else
        # Manual flags
        export CFLAGS="-I$SDK_INCLUDE -I$SDK_INCLUDE/config -DBUILD_DSO $(pkg-config --cflags glib-2.0)"
    fi
    
    # Clean first
    make clean >/dev/null 2>&1 || true
    
    # Build
    if make >/dev/null 2>&1; then
        echo -e "  ${GREEN}✓ Build successful${NC}"
        
        # Check module exists
        MODULE=$(ls hw-*.so 2>/dev/null | head -1)
        if [[ -n "$MODULE" ]]; then
            echo -e "  ${GREEN}✓ Module created: $MODULE${NC}"
            
            # Check size
            SIZE=$(du -h "$MODULE" | cut -f1)
            echo "    Size: $SIZE"
            
            # Check symbols
            if nm "$MODULE" | grep -q "qemu_module_dummy"; then
                echo -e "  ${GREEN}✓ Required symbols present${NC}"
            else
                echo -e "  ${YELLOW}! Warning: qemu_module_dummy not found${NC}"
            fi
            
            if nm "$MODULE" | grep -q "type_init"; then
                echo -e "  ${GREEN}✓ type_init found${NC}"
            else
                echo -e "  ${YELLOW}! Warning: type_init not found${NC}"
            fi
            
            # Check dependencies
            LDD_OUT=$(ldd "$MODULE" 2>/dev/null || echo "")
            if echo "$LDD_OUT" | grep -q "libglib"; then
                echo -e "  ${GREEN}✓ GLib linked${NC}"
            else
                echo -e "  ${YELLOW}! Warning: GLib not detected${NC}"
            fi
            
            ((BUILT++))
        else
            echo -e "  ${RED}✗ Module file not created${NC}"
            ((FAILED++))
        fi
    else
        echo -e "  ${RED}✗ Build failed${NC}"
        echo
        echo "  Build output:"
        make 2>&1 | head -20 | sed 's/^/    /'
        ((FAILED++))
    fi
done

echo
echo "================================"
echo "Module Build Test Summary"
echo "================================"
echo "Total examples: ${#EXAMPLES[@]}"
echo -e "Built: ${GREEN}$BUILT${NC}"
echo -e "Failed: ${RED}$FAILED${NC}"
echo

if [[ $FAILED -eq 0 ]]; then
    echo -e "${GREEN}✓ All modules built successfully!${NC}"
    echo
    echo "Modules are ready to test with QEMU."
    echo "See: ./tests/test-module-load.sh"
    exit 0
else
    echo -e "${RED}✗ Some modules failed to build${NC}"
    echo
    echo "Common issues:"
    echo "  1. SDK not installed properly"
    echo "  2. Missing dependencies (glib-2.0-dev)"
    echo "  3. Compiler not found"
    echo "  4. pkg-config not configured"
    echo
    echo "To fix:"
    echo "  1. Verify SDK: ls $SDK_INCLUDE"
    echo "  2. Install GLib: sudo apt install libglib2.0-dev"
    echo "  3. Check compiler: gcc --version"
    echo "  4. Test pkg-config: pkg-config --cflags qemu-device"
    exit 1
fi
