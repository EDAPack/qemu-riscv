#!/bin/bash
# test-module-load.sh - Test loading modules in QEMU
#
# This script tests that built modules can be loaded by QEMU

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd .. && pwd)"
MODULE_DIR="${1:-$SCRIPT_DIR/examples}"
TIMEOUT=5

echo "================================"
echo "Testing Module Loading"
echo "================================"
echo "Module Dir: $MODULE_DIR"
echo

echo -e "${GREEN}Step 1: Checking QEMU${NC}"
echo "----------------------------"

# Find QEMU binaries
QEMU_ARM=$(command -v qemu-system-arm || echo "")
QEMU_X86=$(command -v qemu-system-x86_64 || echo "")

if [[ -z "$QEMU_ARM" && -z "$QEMU_X86" ]]; then
    echo -e "${RED}✗ No QEMU binaries found${NC}"
    echo
    echo "Install QEMU:"
    echo "  Debian/Ubuntu: sudo apt install qemu-system-arm qemu-system-x86"
    echo "  Fedora/RHEL: sudo dnf install qemu-system-aarch64 qemu-system-x86"
    exit 1
fi

[[ -n "$QEMU_ARM" ]] && echo -e "  qemu-system-arm: ${GREEN}✓${NC} ($QEMU_ARM)"
[[ -n "$QEMU_X86" ]] && echo -e "  qemu-system-x86_64: ${GREEN}✓${NC} ($QEMU_X86)"
echo

echo -e "${GREEN}Step 2: Finding Modules${NC}"
echo "----------------------------"

MODULES=()
for example in minimal-sysbus uart-device pci-device; do
    MODULE_PATH="$MODULE_DIR/$example/hw-$example.so"
    if [[ -f "$MODULE_PATH" ]]; then
        MODULES+=("$example:$MODULE_PATH")
        echo -e "  $example: ${GREEN}✓${NC}"
    else
        echo -e "  $example: ${YELLOW}! not found${NC}"
    fi
done

if [[ ${#MODULES[@]} -eq 0 ]]; then
    echo
    echo -e "${RED}✗ No modules found${NC}"
    echo "Build modules first: cd examples && ./test-all.sh"
    exit 1
fi
echo

echo -e "${GREEN}Step 3: Testing Module Loading${NC}"
echo "----------------------------"

LOADED=0
FAILED=0

for module_entry in "${MODULES[@]}"; do
    IFS=':' read -r name path <<< "$module_entry"
    echo
    echo "Testing: $name"
    echo "  ---"
    
    MODULE_DIR_PATH=$(dirname "$path")
    MODULE_FILE=$(basename "$path")
    
    # Determine which QEMU to use
    if [[ "$name" == "pci-device" ]]; then
        if [[ -z "$QEMU_X86" ]]; then
            echo -e "  ${YELLOW}! Skipped (qemu-system-x86_64 not available)${NC}"
            continue
        fi
        QEMU_BIN="$QEMU_X86"
        MACHINE="pc"
    else
        if [[ -z "$QEMU_ARM" ]]; then
            echo -e "  ${YELLOW}! Skipped (qemu-system-arm not available)${NC}"
            continue
        fi
        QEMU_BIN="$QEMU_ARM"
        MACHINE="virt"
    fi
    
    # Test module loading
    echo "  Testing with $QEMU_BIN..."
    
    # Create test script that runs QEMU and exits immediately
    TEST_OUTPUT=$(mktemp)
    
    (
        export QEMU_MODULE_DIR="$MODULE_DIR_PATH"
        timeout $TIMEOUT "$QEMU_BIN" -M "$MACHINE" \
            -device "$name" \
            -nographic -serial none -monitor none \
            2>&1 || true
    ) > "$TEST_OUTPUT" 2>&1 &
    
    QEMU_PID=$!
    sleep 2
    
    # Kill QEMU if still running
    if kill -0 $QEMU_PID 2>/dev/null; then
        kill $QEMU_PID 2>/dev/null || true
        wait $QEMU_PID 2>/dev/null || true
    fi
    
    # Check output for errors
    if grep -qi "invalid\|error\|fail" "$TEST_OUTPUT"; then
        echo -e "  ${RED}✗ Module load failed${NC}"
        echo
        echo "  Error output:"
        grep -i "invalid\|error\|fail" "$TEST_OUTPUT" | head -5 | sed 's/^/    /'
        ((FAILED++))
    else
        echo -e "  ${GREEN}✓ Module loaded successfully${NC}"
        ((LOADED++))
    fi
    
    rm -f "$TEST_OUTPUT"
done

echo
echo "================================"
echo "Module Loading Test Summary"
echo "================================"
echo "Total modules: ${#MODULES[@]}"
echo -e "Loaded: ${GREEN}$LOADED${NC}"
echo -e "Failed: ${RED}$FAILED${NC}"
echo

if [[ $FAILED -eq 0 ]]; then
    echo -e "${GREEN}✓ All modules loaded successfully!${NC}"
    echo
    echo "The device modules are working correctly."
    echo "You can now use them with QEMU:"
    echo
    echo "  export QEMU_MODULE_DIR=$MODULE_DIR/minimal-sysbus"
    echo "  qemu-system-arm -M virt -device minimal-sysbus"
    exit 0
else
    echo -e "${RED}✗ Some modules failed to load${NC}"
    echo
    echo "Common issues:"
    echo "  1. Module not compatible with QEMU version"
    echo "  2. Missing symbols in module"
    echo "  3. ABI mismatch"
    echo "  4. Module built against wrong SDK"
    echo
    echo "To debug:"
    echo "  export QEMU_MODULE_DIR=$MODULE_DIR/minimal-sysbus"
    echo "  qemu-system-arm -M virt -device minimal-sysbus -d guest_errors"
    exit 1
fi
