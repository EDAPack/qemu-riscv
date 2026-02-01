#!/bin/bash
# test-integration.sh - End-to-end integration test
#
# This script runs the complete workflow: patch -> build -> SDK -> modules -> load

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd .. && pwd)"
QEMU_VERSION="${1:-master}"
WORK_DIR=$(mktemp -d)

trap "rm -rf $WORK_DIR" EXIT

echo "========================================"
echo "  QEMU Model Loader Integration Test"
echo "========================================"
echo
echo "This test runs the complete workflow:"
echo "  1. Apply patches to QEMU"
echo "  2. Build QEMU with SDK support"
echo "  3. Install SDK"
echo "  4. Build example modules"
echo "  5. Test module loading"
echo
echo "QEMU Version: $QEMU_VERSION"
echo "Work Directory: $WORK_DIR"
echo
echo -e "${YELLOW}This will take 10-30 minutes depending on your system.${NC}"
echo
read -p "Continue? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
fi

START_TIME=$(date +%s)

# Test 1: Patch Application
echo
echo -e "${BLUE}========================================"
echo -e "Test 1: Patch Application"
echo -e "========================================${NC}"
export WORK_DIR
if "$SCRIPT_DIR/tests/test-patch-apply.sh" "$QEMU_VERSION"; then
    echo -e "${GREEN}✓ Test 1 PASSED${NC}"
    TEST1=PASS
else
    echo -e "${RED}✗ Test 1 FAILED${NC}"
    TEST1=FAIL
    echo
    echo "Integration test failed at patch application."
    echo "Cannot continue."
    exit 1
fi

# Test 2: SDK Build
echo
echo -e "${BLUE}========================================"
echo -e "Test 2: SDK Build"  
echo -e "========================================${NC}"

# Note: This is expensive, so we'll skip if SKIP_BUILD is set
if [[ "${SKIP_BUILD:-0}" == "1" ]]; then
    echo -e "${YELLOW}Skipped (SKIP_BUILD=1)${NC}"
    TEST2=SKIP
else
    if "$SCRIPT_DIR/tests/test-sdk-build.sh" "$QEMU_VERSION"; then
        echo -e "${GREEN}✓ Test 2 PASSED${NC}"
        TEST2=PASS
        SDK_INSTALL="$WORK_DIR/install"
    else
        echo -e "${RED}✗ Test 2 FAILED${NC}"
        TEST2=FAIL
        echo
        echo "Integration test failed at SDK build."
        exit 1
    fi
fi

# Test 3: Module Build
if [[ "$TEST2" != "SKIP" ]]; then
    echo
    echo -e "${BLUE}========================================"
    echo -e "Test 3: Module Build"
    echo -e "========================================${NC}"
    
    if "$SCRIPT_DIR/tests/test-module-build.sh" "$SDK_INSTALL"; then
        echo -e "${GREEN}✓ Test 3 PASSED${NC}"
        TEST3=PASS
    else
        echo -e "${RED}✗ Test 3 FAILED${NC}"
        TEST3=FAIL
        echo
        echo "Integration test failed at module build."
        exit 1
    fi
    
    # Test 4: Module Loading
    echo
    echo -e "${BLUE}========================================"
    echo -e "Test 4: Module Loading"
    echo -e "========================================${NC}"
    
    if "$SCRIPT_DIR/tests/test-module-load.sh"; then
        echo -e "${GREEN}✓ Test 4 PASSED${NC}"
        TEST4=PASS
    else
        echo -e "${RED}✗ Test 4 FAILED${NC}"
        TEST4=FAIL
        echo
        echo "Integration test failed at module loading."
        exit 1
    fi
else
    TEST3=SKIP
    TEST4=SKIP
fi

# Calculate duration
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
MINUTES=$((DURATION / 60))
SECONDS=$((DURATION % 60))

# Summary
echo
echo "========================================"
echo "  Integration Test Summary"
echo "========================================"
echo
echo "Test Results:"
echo -e "  1. Patch Application:  $([[ $TEST1 == PASS ]] && echo -e \"${GREEN}PASS${NC}\" || echo -e \"${RED}FAIL${NC}\")"
echo -e "  2. SDK Build:          $([[ $TEST2 == PASS ]] && echo -e \"${GREEN}PASS${NC}\" || [[ $TEST2 == SKIP ]] && echo -e \"${YELLOW}SKIP${NC}\" || echo -e \"${RED}FAIL${NC}\")"
echo -e "  3. Module Build:       $([[ $TEST3 == PASS ]] && echo -e \"${GREEN}PASS${NC}\" || [[ $TEST3 == SKIP ]] && echo -e \"${YELLOW}SKIP${NC}\" || echo -e \"${RED}FAIL${NC}\")"
echo -e "  4. Module Loading:     $([[ $TEST4 == PASS ]] && echo -e \"${GREEN}PASS${NC}\" || [[ $TEST4 == SKIP ]] && echo -e \"${YELLOW}SKIP${NC}\" || echo -e \"${RED}FAIL${NC}\")"
echo
echo "Duration: ${MINUTES}m ${SECONDS}s"
echo

if [[ "$TEST1" == "PASS" ]] && ([[ "$TEST2" == "PASS" ]] || [[ "$TEST2" == "SKIP" ]]); then
    echo -e "${GREEN}========================================"
    echo -e "  ✓ INTEGRATION TEST PASSED"
    echo -e "========================================${NC}"
    echo
    echo "The QEMU Model Loader system is working correctly!"
    echo
    echo "What was tested:"
    echo "  ✓ Patches apply cleanly to QEMU"
    if [[ "$TEST2" == "PASS" ]]; then
        echo "  ✓ QEMU builds with SDK support"
        echo "  ✓ SDK installs correctly"
        echo "  ✓ Example modules build with SDK"
        echo "  ✓ Modules load in QEMU"
    fi
    echo
    echo "Next steps:"
    echo "  - Use patches in production: patches/v9.2/*.patch"
    echo "  - Package SDK: ./sdk-package/create-sdk.sh"
    echo "  - Build custom devices: see examples/"
    exit 0
else
    echo -e "${RED}========================================"
    echo -e "  ✗ INTEGRATION TEST FAILED"
    echo -e "========================================${NC}"
    echo
    echo "One or more tests failed."
    echo "Check the output above for details."
    exit 1
fi
