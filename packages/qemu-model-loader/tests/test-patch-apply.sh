#!/bin/bash
# test-patch-apply.sh - Test QEMU patch application
#
# This script tests whether our patches apply cleanly to QEMU

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

trap "rm -rf $WORK_DIR" EXIT

echo "================================"
echo "Testing Patch Application"
echo "================================"
echo "QEMU Version: $QEMU_VERSION"
echo "Work Dir: $WORK_DIR"
echo

# Map version to patch directory
PATCH_DIR="$SCRIPT_DIR/patches/v9.2"
if [[ "$QEMU_VERSION" == "master" || "$QEMU_VERSION" =~ ^v10 ]]; then
    PATCH_DIR="$SCRIPT_DIR/patches/v9.2"  # Using v9.2 patches for now
elif [[ "$QEMU_VERSION" =~ ^v9\.2 ]]; then
    PATCH_DIR="$SCRIPT_DIR/patches/v9.2"
elif [[ "$QEMU_VERSION" =~ ^v9\.1 ]]; then
    PATCH_DIR="$SCRIPT_DIR/patches/v9.1"
    if [[ ! -d "$PATCH_DIR" ]]; then
        echo -e "${YELLOW}Warning: v9.1 patches not yet created, using v9.2${NC}"
        PATCH_DIR="$SCRIPT_DIR/patches/v9.2"
    fi
fi

if [[ ! -d "$PATCH_DIR" ]]; then
    echo -e "${RED}Error: Patch directory not found: $PATCH_DIR${NC}"
    exit 1
fi

echo -e "${GREEN}Step 1: Cloning QEMU${NC}"
echo "----------------------------"
cd "$WORK_DIR"
if [[ "$QEMU_VERSION" == "master" ]]; then
    git clone --depth 1 "$QEMU_REPO" qemu
else
    git clone --depth 1 --branch "$QEMU_VERSION" "$QEMU_REPO" qemu
fi
cd qemu
QEMU_COMMIT=$(git rev-parse --short HEAD)
echo -e "${GREEN}✓ Cloned QEMU at commit $QEMU_COMMIT${NC}"
echo

echo -e "${GREEN}Step 2: Applying Patches${NC}"
echo "----------------------------"
PATCHES=( $(ls "$PATCH_DIR"/*.patch 2>/dev/null | sort) )

if [[ ${#PATCHES[@]} -eq 0 ]]; then
    echo -e "${RED}✗ No patches found in $PATCH_DIR${NC}"
    exit 1
fi

echo "Found ${#PATCHES[@]} patches:"
for patch in "${PATCHES[@]}"; do
    echo "  - $(basename $patch)"
done
echo

APPLIED=0
FAILED=0

for patch in "${PATCHES[@]}"; do
    echo -n "Applying $(basename $patch)... "
    
    if git am "$patch" >/dev/null 2>&1; then
        echo -e "${GREEN}✓${NC}"
        ((APPLIED++))
    else
        echo -e "${RED}✗${NC}"
        echo
        echo "Patch application failed. Trying with 3-way merge..."
        git am --abort 2>/dev/null || true
        
        if git am -3 "$patch" >/dev/null 2>&1; then
            echo -e "${YELLOW}✓ Applied with 3-way merge${NC}"
            ((APPLIED++))
        else
            echo -e "${RED}✗ Failed even with 3-way merge${NC}"
            ((FAILED++))
            
            # Show details
            echo
            echo "Failure details:"
            git am --show-current-patch=diff 2>/dev/null | head -50
            git am --abort 2>/dev/null || true
            break
        fi
    fi
done

echo
echo "================================"
echo "Patch Application Summary"
echo "================================"
echo "Total patches: ${#PATCHES[@]}"
echo -e "Applied: ${GREEN}$APPLIED${NC}"
echo -e "Failed: ${RED}$FAILED${NC}"
echo

if [[ $FAILED -eq 0 ]]; then
    echo -e "${GREEN}✓ All patches applied successfully!${NC}"
    
    # Show resulting commit log
    echo
    echo "Resulting commits:"
    git log --oneline --graph -n $((${#PATCHES[@]} + 1))
    
    exit 0
else
    echo -e "${RED}✗ Some patches failed to apply${NC}"
    echo
    echo "Possible causes:"
    echo "  1. QEMU version mismatch"
    echo "  2. Patches need rebasing"
    echo "  3. Conflicting changes in QEMU"
    echo
    echo "To fix:"
    echo "  1. Try a different QEMU version"
    echo "  2. Update patches: ./scripts/update-patches.sh"
    echo "  3. Manually rebase patches"
    
    exit 1
fi
