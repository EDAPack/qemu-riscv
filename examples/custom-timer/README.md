# Custom Timer Device Module Example

This example demonstrates how to create a custom QEMU device that can be loaded as a module at runtime.

## Current Status

✅ **Working**: The QEMU Device SDK patches now successfully apply to QEMU v9.2.0. The SDK headers are included in the binary releases, allowing external device modules to be built without QEMU source code.

## Quick Start

### 1. Download QEMU Release with SDK

Download the latest QEMU RISC-V release from the GitHub Actions artifacts or releases. Extract it to this directory:

```bash
cd examples/custom-timer
# Download and extract qemu-riscv-*.tar.gz here
tar xzf qemu-riscv-ubuntu-*.tar.gz
# This creates qemu-riscv/ directory with SDK headers
```

### 2. Build the Module

```bash
make
```

This will:
- Use pkg-config to find QEMU SDK headers
- Compile custom-timer.c into hw-custom-timer.so
- Create a loadable QEMU device module

### 3. Test the Module

```bash
./test.sh
```

Or manually:

```bash
export QEMU_MODULE_DIR=$(pwd)
./qemu-riscv/bin/qemu-system-riscv64 -device help | grep custom-timer
./qemu-riscv/bin/qemu-system-riscv64 -M virt -device custom-timer -nographic
```

## The Custom Timer Device

The `custom-timer.c` file implements a simple memory-mapped timer with:

- **Control Register** (offset 0x00):
  - Bit 0: Enable/disable timer
  - Bit 1: Reset counter

- **Counter Register** (offset 0x04):
  - Read-only 32-bit counter
  - Increments every millisecond when enabled

### Device Interface

```c
// Memory map
#define TIMER_CONTROL   0x00
#define TIMER_COUNTER   0x04

// Control register bits
#define CTRL_ENABLE     (1 << 0)
#define CTRL_RESET      (1 << 1)
```

## SDK Contents

The QEMU release includes device development SDK at `qemu-riscv/include/qemu-device/`:

```
qemu-device/
├── qemu/          # Core QEMU headers
├── qom/           # QEMU Object Model
├── hw/            # Hardware device headers
├── exec/          # Execution engine
├── sysemu/        # System emulation
├── chardev/       # Character devices
├── io/            # I/O utilities
├── migration/     # Migration support
├── monitor/       # Monitor interface
├── qapi/          # Generated QAPI headers
└── config-host.h  # Build configuration
```

## Building More Devices

Use this example as a template:

```bash
# Copy the example
cp -r examples/custom-timer examples/my-device

# Edit the device implementation
cd examples/my-device
# Modify custom-timer.c or create new .c file

# Update Makefile if needed
# Build
make
```

## Files

- `custom-timer.c` - Complete device implementation
- `Makefile` - Build script using pkg-config
- `test.sh` - Automated testing script
- `README.md` - This file

## Troubleshooting

### Module doesn't load

Check that:
1. Module filename is `hw-<device-type>.so` (e.g., `hw-custom-timer.so`)
2. `QEMU_MODULE_DIR` environment variable is set
3. Module was compiled against the same QEMU version

### Compilation errors

Ensure:
1. QEMU SDK is extracted in the example directory
2. pkg-config can find qemu-device.pc
3. Required headers are present in qemu-riscv/include/qemu-device/

### QEMU crashes

Verify:
1. Device type registration matches filename
2. Memory region initialization is correct
3. Realize/unrealize functions are properly implemented

## References

- QEMU Model Loader: `packages/qemu-model-loader/README.md`
- SDK Patches: `packages/qemu-model-loader/patches/v9.2/README.md`
- QEMU Device API: https://www.qemu.org/docs/master/devel/

## Example Output

```
$ ./test.sh
===================================================================
Custom Timer Device Module - Demonstration
===================================================================

✓ Module found: hw-custom-timer.so
  Size: 24K

✓ QEMU found: qemu-riscv/bin/qemu-system-riscv64
  Version: QEMU emulator version 9.2.0

Test 1: Checking if device is registered...
✓ Device registered: custom-timer
name "custom-timer", desc "Custom Timer Device"

Test 2: Instantiating device...
(This will run QEMU briefly then exit)

===================================================================
Demonstration Complete
===================================================================
```
