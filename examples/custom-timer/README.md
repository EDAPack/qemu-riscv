# Custom Timer Device Module Example

This example demonstrates how to create a custom QEMU device that can be loaded as a module at runtime.

## Current Status

⚠️ **Important**: The QEMU Device SDK patches are designed for QEMU v9.2, but the CI builds from QEMU master branch. The patches did not apply successfully, so the device SDK headers are not available in the downloaded build.

### What This Means

Without the SDK installation, we cannot build external device modules using only the QEMU binary distribution. The model-loader patches add this capability by:

1. **install-dev-sdk target**: Installs QEMU headers needed for device development
2. **pkg-config file**: Provides build configuration for easy module compilation  
3. **Documentation**: Adds comprehensive device module development guide

## Solution Options

### Option 1: Update Patches for QEMU Master

The patches in `packages/qemu-model-loader/patches/v9.2/` need to be updated to work with the current QEMU master branch. This involves:

```bash
# Clone QEMU master
git clone https://gitlab.com/qemu-project/qemu.git
cd qemu

# Try to apply patches and fix conflicts
git am /path/to/patches/v9.2/*.patch
# ... resolve conflicts ...
# Generate updated patches
git format-patch -3 HEAD
```

### Option 2: Build Against Specific QEMU Version

Use QEMU v9.2.0 where the patches apply cleanly:

```bash
# In scripts/build.sh, change:
qemu_latest_rls="v9.2.0"  # instead of "master"
```

### Option 3: Build With QEMU Source

For now, to demonstrate the model-loader concept, you can build modules with access to QEMU source:

```bash
# Clone QEMU and apply patches
git clone https://gitlab.com/qemu-project/qemu.git
cd qemu
git checkout v9.2.0
git am ../packages/qemu-model-loader/patches/v9.2/*.patch

# Build QEMU with SDK support
./configure --prefix=$PWD/install
make -j$(nproc)
make install
make install-dev-sdk

# Now you can build the custom-timer module
cd ../examples/custom-timer
export PKG_CONFIG_PATH=$PWD/../qemu/install/lib/pkgconfig
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

### Usage (once SDK is available)

```bash
# Build the module
make

# Set module directory
export QEMU_MODULE_DIR=$(pwd)

# Run QEMU with custom device
./qemu-riscv/bin/qemu-system-riscv64 \
    -M virt \
    -device custom-timer \
    -nographic
```

## Files

- `custom-timer.c` - Complete device implementation
- `Makefile` - Build script (requires SDK)
- `README.md` - This file

## Next Steps

1. **Update patches** for QEMU master or switch to v9.2.0 builds
2. **Verify SDK installation** after rebuild
3. **Test module loading** with example device
4. **Create more examples** (UART, interrupt controller, etc.)

## References

- QEMU Model Loader: `packages/qemu-model-loader/README.md`
- Patch documentation: `packages/qemu-model-loader/patches/v9.2/README.md`
- More examples: `packages/qemu-model-loader/examples/`

## Build Log Analysis

The CI build logs show:

```
=== Applying model-loader patches ===
Applying 0001-build-add-install-dev-sdk-target.patch...
Hunk #1 FAILED at 4450.
WARNING: Failed to apply 0001-build-add-install-dev-sdk-target.patch, continuing...
```

This confirms the patches need updating for the current QEMU version.
