# Custom Timer Device Module Example

This example demonstrates how to create a custom QEMU device that can be loaded as a module at runtime.

## Current Status

⚠️ **Partially Working**: The QEMU Device SDK patches successfully apply to QEMU v9.2.0 and install most headers. However, a required generated file (`config-poison.h`) is not currently included in the SDK, preventing module compilation.

### What's Working
- ✅ SDK headers are installed in binary releases
- ✅ pkg-config integration is available  
- ✅ Most QEMU headers are accessible

### Known Issue
- ❌ Missing `config-poison.h` prevents compilation
- This file is generated during QEMU build but not installed by the SDK patch
- **Fix needed**: Update patch to install generated files from build directory

## Workaround (Until Fixed)

Until the patch is updated, modules can be built with full QEMU source:

```bash
# Clone and build QEMU with patches
git clone --branch v9.2.0 https://gitlab.com/qemu-project/qemu.git
cd qemu
git apply /path/to/qemu-riscv-loader/packages/qemu-model-loader/patches/v9.2/*.patch
./configure --target-list=riscv32-softmmu,riscv64-softmmu
make -j$(nproc)
make install

# Build module
cd /path/to/examples/custom-timer
export PKG_CONFIG_PATH=/usr/local/lib/x86_64-linux-gnu/pkgconfig
make
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
