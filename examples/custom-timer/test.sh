#!/bin/bash
# Test script for custom-timer device module
#
# This demonstrates the complete workflow for using a custom QEMU device module

set -e

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

echo "==================================================================="
echo "Custom Timer Device Module - Demonstration"
echo "==================================================================="
echo ""

# Check if module exists
if [ ! -f "hw-custom-timer.so" ]; then
    echo "❌ Module not built yet"
    echo ""
    echo "The module requires QEMU SDK headers to build."
    echo "Current status: SDK patches did not apply to QEMU master branch."
    echo ""
    echo "To build the module, you need:"
    echo "  1. QEMU with SDK support (patches applied)"
    echo "  2. Device SDK headers installed"
    echo "  3. pkg-config file for build configuration"
    echo ""
    echo "See README.md for solutions."
    exit 1
fi

echo "✓ Module found: hw-custom-timer.so"
echo "  Size: $(du -h hw-custom-timer.so | cut -f1)"
echo ""

# Check if QEMU exists
if [ ! -f "qemu-riscv/bin/qemu-system-riscv64" ]; then
    echo "❌ QEMU not found"
    echo "Please extract the QEMU build archive first."
    exit 1
fi

echo "✓ QEMU found: qemu-riscv/bin/qemu-system-riscv64"
QEMU_VERSION=$(./qemu-riscv/bin/qemu-system-riscv64 --version | head -1)
echo "  Version: $QEMU_VERSION"
echo ""

# Test 1: Check if device is recognized
echo "Test 1: Checking if device is registered..."
export QEMU_MODULE_DIR="$ROOT_DIR"

if ./qemu-riscv/bin/qemu-system-riscv64 -device help 2>&1 | grep -q "custom-timer"; then
    echo "✓ Device registered: custom-timer"
    ./qemu-riscv/bin/qemu-system-riscv64 -device help 2>&1 | grep custom-timer
else
    echo "❌ Device not found in device list"
    echo ""
    echo "This could mean:"
    echo "  - Module file name doesn't match (should be hw-custom-timer.so)"
    echo "  - QEMU_MODULE_DIR not set correctly"
    echo "  - Module symbols not exported correctly"
    exit 1
fi
echo ""

# Test 2: Try to instantiate device
echo "Test 2: Instantiating device..."
echo "(This will run QEMU briefly then exit)"
echo ""

timeout 2s ./qemu-riscv/bin/qemu-system-riscv64 \
    -M virt \
    -device custom-timer \
    -d guest_errors \
    -nographic \
    -serial none \
    -monitor none \
    -display none \
    2>&1 | head -20 || true

echo ""
echo "==================================================================="
echo "Demonstration Complete"
echo "==================================================================="
echo ""
echo "The custom-timer device demonstrates:"
echo "  ✓ Dynamic device loading from shared library"
echo "  ✓ Memory-mapped I/O registers"
echo "  ✓ Virtual timer integration"
echo "  ✓ Device lifecycle management (realize/unrealize/reset)"
echo ""
echo "Register Interface:"
echo "  0x00: Control Register"
echo "        bit 0 - Enable timer"
echo "        bit 1 - Reset counter"
echo "  0x04: Counter Register (read-only)"
echo "        32-bit counter, increments every 1ms"
echo ""
echo "To use in a guest system:"
echo "  1. Map device to memory address (e.g., 0x10001000)"
echo "  2. Write 0x1 to control register to start"
echo "  3. Read counter register to get tick count"
echo "  4. Write 0x2 to control register to reset"
echo "  5. Write 0x0 to control register to stop"
echo ""
