#!/bin/bash
# verify-sdk.sh - Validate QEMU Device SDK installation
#
# Usage:
#   ./verify-sdk.sh /usr/local
#   ./verify-sdk.sh --installed  # Check system installation

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Counters
CHECKS_PASSED=0
CHECKS_FAILED=0
CHECKS_WARNED=0

# Functions
pass() {
    echo -e "  ${GREEN}✓${NC} $*"
    ((CHECKS_PASSED++))
}

fail() {
    echo -e "  ${RED}✗${NC} $*"
    ((CHECKS_FAILED++))
}

warn() {
    echo -e "  ${YELLOW}!${NC} $*"
    ((CHECKS_WARNED++))
}

header() {
    echo
    echo "=== $* ==="
}

usage() {
    cat << EOF
Usage: $0 [PATH]

Verify QEMU Device SDK installation.

ARGUMENTS:
    PATH                   Path to check (e.g., /usr/local)
    --installed            Check system installation
    --help                 Show this help

EXAMPLES:
    # Check installed SDK
    $0 /usr/local
    
    # Check system installation
    $0 --installed
    
    # Check DESTDIR installation
    $0 /tmp/install/usr/local

EOF
    exit 0
}

# Parse arguments
if [[ $# -eq 0 ]] || [[ "$1" == "--help" ]]; then
    usage
fi

if [[ "$1" == "--installed" ]]; then
    SDK_ROOT=""
else
    SDK_ROOT="$1"
    [[ ! -d "$SDK_ROOT" ]] && { echo "Error: Directory not found: $SDK_ROOT"; exit 1; }
fi

echo "QEMU Device SDK Verification"
echo "============================="
[[ -n "$SDK_ROOT" ]] && echo "Path: $SDK_ROOT" || echo "Checking: System installation"

# Construct paths
if [[ -n "$SDK_ROOT" ]]; then
    INCLUDE_DIR="$SDK_ROOT/include/qemu-device"
    PKGCONFIG_DIR="$SDK_ROOT/lib/pkgconfig"
    PKGCONFIG_ALT="$SDK_ROOT/share/pkgconfig"
else
    INCLUDE_DIR="/usr/include/qemu-device"
    PKGCONFIG_DIR="/usr/lib/pkgconfig"
    [[ ! -d "$PKGCONFIG_DIR" ]] && PKGCONFIG_DIR="/usr/lib/x86_64-linux-gnu/pkgconfig"
    [[ ! -d "$PKGCONFIG_DIR" ]] && PKGCONFIG_DIR="/usr/local/lib/pkgconfig"
fi

# Check 1: SDK directory exists
header "SDK Directory Structure"

if [[ -d "$INCLUDE_DIR" ]]; then
    pass "SDK directory exists: $INCLUDE_DIR"
else
    fail "SDK directory not found: $INCLUDE_DIR"
    echo
    echo "SDK is not installed. Please run:"
    echo "  make install-dev-sdk"
    exit 1
fi

# Check 2: Required header directories
REQUIRED_DIRS=(
    "qemu"
    "qom"
    "hw"
    "hw/core"
    "exec"
    "config"
)

for dir in "${REQUIRED_DIRS[@]}"; do
    if [[ -d "$INCLUDE_DIR/$dir" ]]; then
        pass "Directory: $dir/"
    else
        fail "Missing directory: $dir/"
    fi
done

# Check 3: Critical headers
header "Critical Headers"

CRITICAL_HEADERS=(
    "qemu/osdep.h"
    "qemu/module.h"
    "qom/object.h"
    "hw/core/qdev.h"
    "hw/core/sysbus.h"
    "config/config-host.h"
)

for header in "${CRITICAL_HEADERS[@]}"; do
    if [[ -f "$INCLUDE_DIR/$header" ]]; then
        pass "$header"
    else
        fail "Missing: $header"
    fi
done

# Check 4: Generated config files
header "Generated Configuration"

if [[ -f "$INCLUDE_DIR/config/config-host.h" ]]; then
    pass "config-host.h present"
    
    # Check for key defines
    if grep -q "CONFIG_MODULES" "$INCLUDE_DIR/config/config-host.h" 2>/dev/null; then
        pass "CONFIG_MODULES defined"
    else
        warn "CONFIG_MODULES not defined (modules may not work)"
    fi
    
    if grep -q "CONFIG_HOST_DSOSUF" "$INCLUDE_DIR/config/config-host.h" 2>/dev/null; then
        DSOSUF=$(grep CONFIG_HOST_DSOSUF "$INCLUDE_DIR/config/config-host.h" | cut -d'"' -f2)
        pass "DSO suffix: $DSOSUF"
    else
        warn "CONFIG_HOST_DSOSUF not defined"
    fi
else
    fail "config-host.h missing"
fi

if [[ -d "$INCLUDE_DIR/config/qapi" ]]; then
    pass "QAPI headers present"
    
    if [[ -f "$INCLUDE_DIR/config/qapi/qapi-builtin-types.h" ]]; then
        pass "qapi-builtin-types.h present"
    else
        warn "qapi-builtin-types.h missing"
    fi
else
    fail "QAPI headers directory missing"
fi

# Check 5: Bus-specific headers
header "Bus-Specific Headers"

BUS_HEADERS=(
    "hw/pci/pci.h:PCI"
    "hw/isa/isa.h:ISA"
    "hw/i2c/i2c.h:I2C"
)

for entry in "${BUS_HEADERS[@]}"; do
    IFS=':' read -r header name <<< "$entry"
    if [[ -f "$INCLUDE_DIR/$header" ]]; then
        pass "$name support ($header)"
    else
        warn "$name support missing ($header)"
    fi
done

# Check 6: pkg-config file
header "pkg-config Integration"

PKGCONFIG_FILE=""
if [[ -f "$PKGCONFIG_DIR/qemu-device.pc" ]]; then
    PKGCONFIG_FILE="$PKGCONFIG_DIR/qemu-device.pc"
elif [[ -n "$PKGCONFIG_ALT" ]] && [[ -f "$PKGCONFIG_ALT/qemu-device.pc" ]]; then
    PKGCONFIG_FILE="$PKGCONFIG_ALT/qemu-device.pc"
fi

if [[ -n "$PKGCONFIG_FILE" ]]; then
    pass "pkg-config file found: $(basename $(dirname $PKGCONFIG_FILE))/qemu-device.pc"
    
    # Validate pkg-config content
    if grep -q "Name.*QEMU Device" "$PKGCONFIG_FILE" 2>/dev/null; then
        pass "pkg-config file is valid"
    else
        warn "pkg-config file may be malformed"
    fi
    
    # Check if pkg-config works (only if system installation)
    if [[ -z "$SDK_ROOT" ]] && command -v pkg-config >/dev/null 2>&1; then
        if pkg-config --exists qemu-device 2>/dev/null; then
            pass "pkg-config command works"
            
            VERSION=$(pkg-config --modversion qemu-device 2>/dev/null || echo "unknown")
            pass "SDK version: $VERSION"
            
            CFLAGS=$(pkg-config --cflags qemu-device 2>/dev/null || echo "")
            if [[ -n "$CFLAGS" ]]; then
                pass "pkg-config --cflags returns flags"
            else
                warn "pkg-config --cflags returns empty"
            fi
        else
            warn "pkg-config can't find qemu-device (PATH issue?)"
        fi
    fi
else
    fail "pkg-config file not found"
fi

# Check 7: File counts
header "SDK Statistics"

TOTAL_HEADERS=$(find "$INCLUDE_DIR" -name "*.h" 2>/dev/null | wc -l)
pass "Total headers: $TOTAL_HEADERS"

SDK_SIZE=$(du -sh "$INCLUDE_DIR" 2>/dev/null | cut -f1)
pass "SDK size: $SDK_SIZE"

# Check 8: Permissions
header "Permissions"

if [[ -r "$INCLUDE_DIR/qemu/osdep.h" ]]; then
    pass "Headers are readable"
else
    fail "Headers are not readable (permission issue?)"
fi

# Check 9: Header syntax check (basic)
header "Header Syntax (Sample Check)"

TEST_HEADER="$INCLUDE_DIR/qemu/module.h"
if [[ -f "$TEST_HEADER" ]]; then
    if grep -q "#ifndef.*#define" "$TEST_HEADER" 2>/dev/null; then
        pass "Headers have include guards"
    else
        warn "Include guards may be missing"
    fi
    
    if grep -q "type_init\|module_init" "$TEST_HEADER" 2>/dev/null; then
        pass "Module registration macros present"
    else
        warn "Module macros may be missing"
    fi
fi

# Summary
header "Verification Summary"

echo
echo "Checks passed:  $CHECKS_PASSED"
echo "Checks failed:  $CHECKS_FAILED"
echo "Warnings:       $CHECKS_WARNED"
echo

if [[ $CHECKS_FAILED -eq 0 ]]; then
    echo -e "${GREEN}✓ SDK verification PASSED${NC}"
    echo
    echo "The SDK appears to be correctly installed."
    echo
    echo "Next steps:"
    echo "  1. Build a test module (see examples/)"
    echo "  2. Test module loading in QEMU"
    echo "  3. See docs/PACKAGER-GUIDE.md for more info"
    echo
    exit 0
else
    echo -e "${RED}✗ SDK verification FAILED${NC}"
    echo
    echo "The SDK installation is incomplete or incorrect."
    echo
    echo "To fix:"
    echo "  1. Ensure patches are applied to QEMU"
    echo "  2. Run: make install-dev-sdk"
    echo "  3. Check for errors during installation"
    echo
    exit 1
fi
