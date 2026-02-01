#!/bin/bash
# test-all.sh - Build and test all example device modules

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

EXAMPLES=(
    "minimal-sysbus"
    "uart-device"
    "pci-device"
)

PASS=0
FAIL=0

echo "================================"
echo "Testing All Example Modules"
echo "================================"
echo

for example in "${EXAMPLES[@]}"; do
    echo -e "${YELLOW}Testing: $example${NC}"
    echo "----------------------------"
    
    if [ ! -d "$example" ]; then
        echo -e "${RED}✗ Directory not found: $example${NC}"
        ((FAIL++))
        echo
        continue
    fi
    
    cd "$example"
    
    # Clean
    echo "Cleaning..."
    make clean >/dev/null 2>&1 || true
    
    # Build
    echo "Building..."
    if make >/dev/null 2>&1; then
        echo -e "${GREEN}✓ Build successful${NC}"
    else
        echo -e "${RED}✗ Build failed${NC}"
        ((FAIL++))
        cd ..
        echo
        continue
    fi
    
    # Check module exists
    MODULE=$(ls hw-*.so 2>/dev/null | head -1)
    if [ -n "$MODULE" ]; then
        echo -e "${GREEN}✓ Module created: $MODULE${NC}"
        
        # Check symbols
        if nm "$MODULE" | grep -q "qemu_module_dummy"; then
            echo -e "${GREEN}✓ Required symbols present${NC}"
        else
            echo -e "${RED}✗ Missing required symbols${NC}"
            ((FAIL++))
        fi
        
        # Show module size
        SIZE=$(du -h "$MODULE" | cut -f1)
        echo "  Module size: $SIZE"
        
        ((PASS++))
    else
        echo -e "${RED}✗ Module file not created${NC}"
        ((FAIL++))
    fi
    
    cd ..
    echo
done

echo "================================"
echo "Test Summary"
echo "================================"
echo -e "Passed: ${GREEN}$PASS${NC}"
echo -e "Failed: ${RED}$FAIL${NC}"
echo

if [ $FAIL -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    echo
    echo "To use these modules:"
    echo "  export QEMU_MODULE_DIR=\$(pwd)/minimal-sysbus"
    echo "  qemu-system-arm -M virt -device minimal-sysbus"
    exit 0
else
    echo -e "${RED}Some tests failed.${NC}"
    exit 1
fi
