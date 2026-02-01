#!/bin/bash
# test-sdk-build.sh - Test SDK installation from patched QEMU
#
# This script tests building QEMU with patches and installing the SDK

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd .. && pwd)"
QEMU_VERSION="${1:-master}"
WORK_DIR=$(mktemp -d)
QEMU_REPO="https://gitlab.com/qemu-project/qemu.git"
SKIP_BUILD="${SKIP_BUILD:-0}"

trap "rm -rf $WORK_DIR" EXIT

echo "================================"
echo "Testing SDK Build"
echo "================================"
echo "QEMU Version: $QEMU_VERSION"
echo "Work Dir: $WORK_DIR"
echo

# Find patches
PATCH_DIR="$SCRIPT_DIR/patches/v9.2"
if [[ ! -d "$PATCH_DIR" ]]; then
    echo -e "${RED}Error: Patch directory not found${NC}"
    exit 1
fi

echo -e "${GREEN}Step 1: Setting up QEMU${NC}"
echo "----------------------------"
cd "$WORK_DIR"

if [[ "$QEMU_VERSION" == "master" ]]; then
    git clone --depth 1 "$QEMU_REPO" qemu
else
    git clone --depth 1 --branch "$QEMU_VERSION" "$QEMU_REPO" qemu
fi

cd qemu
echo -e "${GREEN}✓ Cloned QEMU${NC}"
echo

echo -e "${GREEN}Step 2: Applying Patches${NC}"
echo "----------------------------"
for patch in "$PATCH_DIR"/*.patch; do
    echo -n "  $(basename $patch)... "
    if git am "$patch" >/dev/null 2>&1 || git am -3 "$patch" >/dev/null 2>&1; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${RED}✗${NC}"
        git am --abort 2>/dev/null || true
        exit 1
    fi
done
echo

if [[ "$SKIP_BUILD" == "1" ]]; then
    echo -e "${YELLOW}Skipping build (SKIP_BUILD=1)${NC}"
    echo "Patches applied successfully. Exiting."
    exit 0
fi

echo -e "${GREEN}Step 3: Checking Dependencies${NC}"
echo "----------------------------"
DEPS_OK=1

# Check for build tools
for tool in gcc make meson ninja pkg-config; do
    if command -v $tool >/dev/null 2>&1; then
        echo -e "  $tool: ${GREEN}✓${NC}"
    else
        echo -e "  $tool: ${RED}✗ missing${NC}"
        DEPS_OK=0
    fi
done

# Check for GLib
if pkg-config --exists glib-2.0; then
    GLIB_VER=$(pkg-config --modversion glib-2.0)
    echo -e "  glib-2.0: ${GREEN}✓ ($GLIB_VER)${NC}"
else
    echo -e "  glib-2.0: ${RED}✗ missing${NC}"
    DEPS_OK=0
fi

if [[ $DEPS_OK -eq 0 ]]; then
    echo
    echo -e "${RED}✗ Missing dependencies${NC}"
    echo "Install with:"
    echo "  Debian/Ubuntu: sudo apt install build-essential meson ninja-build libglib2.0-dev pkg-config"
    echo "  Fedora/RHEL: sudo dnf install gcc make meson ninja-build glib2-devel pkgconfig"
    exit 1
fi
echo

echo -e "${GREEN}Step 4: Configuring QEMU${NC}"
echo "----------------------------"
./configure --enable-modules \
            --prefix="$WORK_DIR/install" \
            --disable-docs \
            --disable-sdl \
            --disable-gtk \
            --disable-vnc \
            --target-list=x86_64-softmmu,aarch64-softmmu

if [[ $? -eq 0 ]]; then
    echo -e "${GREEN}✓ Configuration successful${NC}"
else
    echo -e "${RED}✗ Configuration failed${NC}"
    exit 1
fi
echo

echo -e "${GREEN}Step 5: Building QEMU${NC}"
echo "----------------------------"
echo "This may take several minutes..."
make -j$(nproc) >/dev/null 2>&1 &
BUILD_PID=$!

# Show progress
while kill -0 $BUILD_PID 2>/dev/null; do
    echo -n "."
    sleep 2
done
wait $BUILD_PID
BUILD_STATUS=$?

echo
if [[ $BUILD_STATUS -eq 0 ]]; then
    echo -e "${GREEN}✓ Build successful${NC}"
else
    echo -e "${RED}✗ Build failed${NC}"
    echo "Check build logs for details"
    exit 1
fi
echo

echo -e "${GREEN}Step 6: Installing QEMU${NC}"
echo "----------------------------"
if make install >/dev/null 2>&1; then
    echo -e "${GREEN}✓ QEMU installed${NC}"
else
    echo -e "${RED}✗ Installation failed${NC}"
    exit 1
fi
echo

echo -e "${GREEN}Step 7: Installing SDK${NC}"
echo "----------------------------"

# Try install-dev-sdk target
if make install-dev-sdk >/dev/null 2>&1; then
    echo -e "${GREEN}✓ SDK installed${NC}"
elif meson install -C build --tags devel >/dev/null 2>&1; then
    echo -e "${GREEN}✓ SDK installed (via meson)${NC}"
else
    echo -e "${RED}✗ SDK installation failed${NC}"
    echo
    echo "Possible causes:"
    echo "  1. Patches not applied correctly"
    echo "  2. Build system doesn't recognize install-dev-sdk target"
    echo "  3. Meson option not enabled"
    exit 1
fi
echo

echo -e "${GREEN}Step 8: Validating SDK${NC}"
echo "----------------------------"
SDK_DIR="$WORK_DIR/install/include/qemu-device"

# Check SDK directory
if [[ -d "$SDK_DIR" ]]; then
    echo -e "  SDK directory: ${GREEN}✓${NC}"
else
    echo -e "  SDK directory: ${RED}✗ missing${NC}"
    exit 1
fi

# Check critical headers
CRITICAL_HEADERS=(
    "qemu/osdep.h"
    "qemu/module.h"
    "qom/object.h"
    "hw/core/qdev.h"
    "config/config-host.h"
)

for header in "${CRITICAL_HEADERS[@]}"; do
    if [[ -f "$SDK_DIR/$header" ]]; then
        echo -e "  $header: ${GREEN}✓${NC}"
    else
        echo -e "  $header: ${RED}✗ missing${NC}"
        exit 1
    fi
done

# Check pkg-config file
PKGCONFIG_FILE="$WORK_DIR/install/lib/pkgconfig/qemu-device.pc"
if [[ -f "$PKGCONFIG_FILE" ]]; then
    echo -e "  qemu-device.pc: ${GREEN}✓${NC}"
else
    echo -e "  qemu-device.pc: ${RED}✗ missing${NC}"
    # This is a warning, not an error
fi

# Count headers
HEADER_COUNT=$(find "$SDK_DIR" -name "*.h" | wc -l)
SDK_SIZE=$(du -sh "$SDK_DIR" | cut -f1)
echo -e "  Total headers: ${GREEN}$HEADER_COUNT${NC}"
echo -e "  SDK size: ${GREEN}$SDK_SIZE${NC}"

echo
echo "================================"
echo "SDK Build Test Summary"
echo "================================"
echo -e "Status: ${GREEN}PASSED${NC}"
echo "SDK Location: $SDK_DIR"
echo "Headers: $HEADER_COUNT files"
echo "Size: $SDK_SIZE"
echo

# Run verification if available
if [[ -x "$SCRIPT_DIR/sdk-package/verify-sdk.sh" ]]; then
    echo "Running SDK verification..."
    echo
    "$SCRIPT_DIR/sdk-package/verify-sdk.sh" "$WORK_DIR/install"
fi

echo
echo -e "${GREEN}✓ SDK build test completed successfully!${NC}"
