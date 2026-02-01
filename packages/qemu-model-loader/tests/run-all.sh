#!/bin/bash
# run-all.sh - Run complete test suite
#
# This script runs all tests in order

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
QEMU_VERSION="${1:-master}"

echo "========================================"
echo "  QEMU Model Loader Test Suite"
echo "========================================"
echo
echo "QEMU Version: $QEMU_VERSION"
echo

# Array to track results
declare -A RESULTS

# Test 1: Patch Application
echo -e "${BLUE}Running: test-patch-apply.sh${NC}"
echo "----------------------------------------"
if "$SCRIPT_DIR/test-patch-apply.sh" "$QEMU_VERSION"; then
    RESULTS[patch]="PASS"
    echo -e "${GREEN}✓ PASSED${NC}"
else
    RESULTS[patch]="FAIL"
    echo -e "${RED}✗ FAILED${NC}"
fi
echo

# Test 2: SDK Build (optional, expensive)
if [[ "${SKIP_SDK_BUILD:-0}" != "1" ]]; then
    echo -e "${BLUE}Running: test-sdk-build.sh${NC}"
    echo "----------------------------------------"
    if "$SCRIPT_DIR/test-sdk-build.sh" "$QEMU_VERSION"; then
        RESULTS[sdk]="PASS"
        echo -e "${GREEN}✓ PASSED${NC}"
    else
        RESULTS[sdk]="FAIL"
        echo -e "${RED}✗ FAILED${NC}"
    fi
    echo
else
    echo -e "${YELLOW}Skipping: test-sdk-build.sh (set SKIP_SDK_BUILD=0 to run)${NC}"
    RESULTS[sdk]="SKIP"
    echo
fi

# Test 3: Module Build (requires SDK)
if [[ "${RESULTS[sdk]}" == "PASS" ]] || [[ -d "/usr/local/include/qemu-device" ]]; then
    echo -e "${BLUE}Running: test-module-build.sh${NC}"
    echo "----------------------------------------"
    if "$SCRIPT_DIR/test-module-build.sh"; then
        RESULTS[module_build]="PASS"
        echo -e "${GREEN}✓ PASSED${NC}"
    else
        RESULTS[module_build]="FAIL"
        echo -e "${RED}✗ FAILED${NC}"
    fi
    echo
else
    echo -e "${YELLOW}Skipping: test-module-build.sh (SDK not available)${NC}"
    RESULTS[module_build]="SKIP"
    echo
fi

# Test 4: Module Loading (requires built modules)
if [[ "${RESULTS[module_build]}" == "PASS" ]]; then
    echo -e "${BLUE}Running: test-module-load.sh${NC}"
    echo "----------------------------------------"
    if "$SCRIPT_DIR/test-module-load.sh"; then
        RESULTS[module_load]="PASS"
        echo -e "${GREEN}✓ PASSED${NC}"
    else
        RESULTS[module_load]="FAIL"
        echo -e "${RED}✗ FAILED${NC}"
    fi
    echo
else
    echo -e "${YELLOW}Skipping: test-module-load.sh (modules not built)${NC}"
    RESULTS[module_load]="SKIP"
    echo
fi

# Summary
echo "========================================"
echo "  Test Suite Summary"
echo "========================================"
echo

PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0

for test in patch sdk module_build module_load; do
    result="${RESULTS[$test]}"
    case $result in
        PASS)
            echo -e "  $test: ${GREEN}PASS${NC}"
            ((PASS_COUNT++))
            ;;
        FAIL)
            echo -e "  $test: ${RED}FAIL${NC}"
            ((FAIL_COUNT++))
            ;;
        SKIP)
            echo -e "  $test: ${YELLOW}SKIP${NC}"
            ((SKIP_COUNT++))
            ;;
    esac
done

echo
echo "Passed: $PASS_COUNT"
echo "Failed: $FAIL_COUNT"
echo "Skipped: $SKIP_COUNT"
echo

if [[ $FAIL_COUNT -eq 0 ]]; then
    echo -e "${GREEN}✓ All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}✗ Some tests failed.${NC}"
    exit 1
fi
