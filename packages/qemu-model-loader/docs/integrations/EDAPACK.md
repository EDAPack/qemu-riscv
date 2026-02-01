# EDAPack/qemu-riscv Integration Guide

## Overview

This guide demonstrates how to integrate the QEMU Device SDK patches into the EDAPack/qemu-riscv binary distribution. This serves as a reference implementation for other binary packagers.

## Goals

1. Apply SDK patches during QEMU build process
2. Install the device development SDK alongside QEMU binaries
3. Package the SDK for distribution
4. Enable third-party developers to build device modules

## Integration Architecture

```
EDAPack/qemu-riscv Build Pipeline
│
├─ Clone QEMU source
├─ Apply device SDK patches ← NEW
├─ Configure QEMU build
├─ Build QEMU
├─ Install QEMU binaries
├─ Install device SDK ← NEW
├─ Package SDK ← NEW
└─ Create distribution packages
```

## Prerequisites

- EDAPack/qemu-riscv repository (or fork)
- QEMU Model Loader patches (this repository)
- Build dependencies (see PACKAGER-GUIDE.md)

## Integration Steps

### 1. Add Patches to Repository

Add the qemu-model-loader patches to your EDAPack repository:

```bash
cd EDAPack/qemu-riscv

# Create patches directory
mkdir -p patches/device-sdk

# Copy patches from qemu-model-loader
cp /path/to/qemu-model-loader/patches/v9.2/*.patch \
   patches/device-sdk/

# Add patch metadata
cat > patches/device-sdk/series << EOF
# QEMU Device SDK Patches
0001-build-add-install-dev-sdk-target.patch
0002-build-generate-qemu-device-pc.patch
0003-docs-add-device-module-guide.patch
EOF
```

### 2. Modify Build Script

Update your build script to apply patches before building:

```bash
#!/bin/bash
# build-qemu-with-sdk.sh

set -e

QEMU_VERSION=9.2.0
QEMU_SRC=qemu-${QEMU_VERSION}
PATCHES_DIR=patches/device-sdk

# Download and extract QEMU
wget https://download.qemu.org/qemu-${QEMU_VERSION}.tar.xz
tar xf qemu-${QEMU_VERSION}.tar.xz
cd ${QEMU_SRC}

# Apply SDK patches
echo "Applying device SDK patches..."
for patch in ../${PATCHES_DIR}/*.patch; do
    echo "  Applying $(basename $patch)"
    patch -p1 < "$patch"
done

# Configure QEMU with SDK support
./configure \
    --prefix=/usr \
    --target-list=riscv32-softmmu,riscv64-softmmu \
    --enable-modules \
    --enable-dev-sdk

# Build QEMU
make -j$(nproc)

# Install QEMU binaries
sudo make install

# Install device SDK
sudo make install-dev-sdk

echo "Build complete with SDK support"
```

### 3. Configure SDK Installation Paths

Customize SDK installation paths for your distribution:

```bash
# For EDAPack, install SDK to EDAPack-specific location
./configure \
    --prefix=/opt/edapack/qemu \
    --includedir=/opt/edapack/qemu/include \
    --libdir=/opt/edapack/qemu/lib \
    --enable-dev-sdk
```

### 4. Create SDK Package

Package the SDK for distribution alongside QEMU:

```bash
#!/bin/bash
# package-sdk.sh

SDK_VERSION=9.2.0
PACKAGE_NAME=qemu-device-sdk-${SDK_VERSION}
INSTALL_PREFIX=/opt/edapack/qemu

# Create package directory structure
mkdir -p ${PACKAGE_NAME}/{include,lib/pkgconfig,share/doc}

# Copy SDK files
cp -r ${INSTALL_PREFIX}/include/qemu-device \
      ${PACKAGE_NAME}/include/

cp ${INSTALL_PREFIX}/lib/pkgconfig/qemu-device.pc \
   ${PACKAGE_NAME}/lib/pkgconfig/

# Copy documentation
cp -r ${INSTALL_PREFIX}/share/doc/qemu/device-modules \
      ${PACKAGE_NAME}/share/doc/

# Create tarball
tar czf ${PACKAGE_NAME}.tar.gz ${PACKAGE_NAME}

echo "SDK package created: ${PACKAGE_NAME}.tar.gz"
```

### 5. Add CI/CD Integration

Integrate SDK build into your CI/CD pipeline. See `github-actions-example.yml` for a complete example.

Key CI steps:
1. Checkout QEMU source
2. Apply SDK patches
3. Build QEMU with SDK
4. Install SDK
5. Test SDK with example device
6. Package SDK
7. Upload SDK artifacts

## Testing Integration

### Test 1: Verify Patches Apply

```bash
cd qemu-${QEMU_VERSION}

# Test patch application
for patch in ../patches/device-sdk/*.patch; do
    if patch -p1 --dry-run < "$patch"; then
        echo "✓ $(basename $patch) applies cleanly"
    else
        echo "✗ $(basename $patch) has conflicts"
        exit 1
    fi
done
```

### Test 2: Build Example Device

```bash
# After SDK installation, build a test device
cd /tmp
cat > test-device.c << 'EOF'
#include "qemu/osdep.h"
#include "hw/sysbus.h"
#include "qom/object.h"

#define TYPE_TEST_DEVICE "test-device"
OBJECT_DECLARE_SIMPLE_TYPE(TestDevice, TEST_DEVICE)

struct TestDevice {
    SysBusDevice parent_obj;
};

static void test_device_class_init(ObjectClass *klass, void *data)
{
    DeviceClass *dc = DEVICE_CLASS(klass);
    dc->desc = "Test Device";
}

static const TypeInfo test_device_info = {
    .name = TYPE_TEST_DEVICE,
    .parent = TYPE_SYS_BUS_DEVICE,
    .instance_size = sizeof(TestDevice),
    .class_init = test_device_class_init,
};

static void test_device_register_types(void)
{
    type_register_static(&test_device_info);
}

type_init(test_device_register_types)
EOF

# Build using pkg-config
gcc -shared -fPIC \
    $(pkg-config --cflags qemu-device) \
    -o test-device.so \
    test-device.c \
    $(pkg-config --libs qemu-device)

if [ -f test-device.so ]; then
    echo "✓ Test device built successfully"
else
    echo "✗ Test device build failed"
    exit 1
fi
```

### Test 3: Load Device in QEMU

```bash
# Test loading the device module
qemu-system-riscv64 \
    -M virt \
    -device loader,file=test-device.so \
    -nographic

# Should see device registered in QEMU output
```

## Distribution Strategies

### Strategy 1: Separate SDK Package

Ship SDK as a separate optional package:

```
EDAPack Packages:
├── qemu-riscv-9.2.0.tar.gz          ← QEMU binaries
└── qemu-device-sdk-9.2.0.tar.gz     ← SDK (optional)
```

**Pros**: Users only download SDK if needed
**Cons**: Two packages to maintain

### Strategy 2: Bundled SDK

Include SDK in main QEMU package:

```
EDAPack Package:
└── qemu-riscv-9.2.0-with-sdk.tar.gz  ← QEMU + SDK
```

**Pros**: Single package, always available
**Cons**: Larger download for users who don't need SDK

### Strategy 3: SDK as Addon

Provide SDK installation script that fetches from QEMU install:

```bash
# User installs QEMU normally
edapack install qemu-riscv

# SDK can be installed on-demand
edapack install qemu-riscv-sdk
```

**Recommended**: Strategy 3 for EDAPack (follows EDAPack patterns)

## EDAPack-Specific Considerations

### Package Naming

Follow EDAPack naming conventions:

```
qemu-riscv               ← Base QEMU package
qemu-riscv-sdk           ← SDK package
qemu-riscv-examples      ← Example devices
```

### Installation Paths

Use EDAPack standard paths:

```
/opt/edapack/qemu/
├── bin/                 ← QEMU binaries
├── include/             ← SDK headers
│   └── qemu-device/
├── lib/                 ← Libraries
│   └── pkgconfig/
└── share/
    └── doc/             ← Documentation
```

### Version Pinning

Pin SDK version to QEMU version:

```yaml
# EDAPack package.yml
name: qemu-riscv-sdk
version: 9.2.0
depends:
  - qemu-riscv == 9.2.0
```

### Integration with EDAPack Build System

If EDAPack uses a specific build system (ivpm, etc):

```yaml
# ivpm.yaml example
packages:
  qemu-riscv-sdk:
    type: source
    url: git@github.com:edapack/qemu-riscv.git
    ref: v9.2.0-sdk
    build:
      - ./configure --prefix=$PREFIX --enable-dev-sdk
      - make -j$NPROC
      - make install
      - make install-dev-sdk
```

## Troubleshooting

### Issue: Patches Don't Apply

**Symptom**: Patch command fails with conflicts

**Solution**: 
1. Check QEMU version matches patch version
2. Verify no local modifications to QEMU source
3. Use correct patch directory
4. See `docs/PATCH-INTEGRATION.md` for version compatibility

### Issue: SDK Headers Missing

**Symptom**: pkg-config works but headers not found

**Solution**:
```bash
# Verify SDK installation
ls -la /opt/edapack/qemu/include/qemu-device/

# Check pkg-config paths
pkg-config --cflags qemu-device

# Ensure PKG_CONFIG_PATH is set
export PKG_CONFIG_PATH=/opt/edapack/qemu/lib/pkgconfig:$PKG_CONFIG_PATH
```

### Issue: Example Device Won't Load

**Symptom**: QEMU can't load .so module

**Solution**:
1. Check module was compiled for correct architecture
2. Verify QEMU was built with `--enable-modules`
3. Check for symbol resolution issues
4. See device loading documentation

## Maintenance

### Updating to New QEMU Version

When EDAPack updates QEMU version:

```bash
# Update patches for new QEMU version
cd qemu-model-loader
./scripts/update-patches.sh v9.2 v9.3

# Copy updated patches to EDAPack
cp patches/v9.3/*.patch \
   /path/to/edapack/qemu-riscv/patches/device-sdk/

# Test build
cd /path/to/edapack/qemu-riscv
./build-qemu-with-sdk.sh
```

### Monitoring Patch Health

Set up automated testing:

```yaml
# .github/workflows/test-patches.yml
name: Test SDK Patches
on:
  schedule:
    - cron: '0 0 * * 0'  # Weekly
  
jobs:
  test-patches:
    runs-on: ubuntu-latest
    steps:
      - name: Test patch application
        run: ./tests/test-patch-apply.sh
      
      - name: Build SDK
        run: ./tests/test-sdk-build.sh
      
      - name: Notify on failure
        if: failure()
        uses: actions/notification@v1
```

## Support

### For EDAPack Maintainers

- Reference: `docs/PACKAGER-GUIDE.md`
- Issues: https://github.com/mballance/qemu-model-loader/issues
- Contact: See repository README

### For Device Developers Using EDAPack

- Documentation: https://edapack.github.io/qemu-riscv/
- Examples: `examples/` directory in qemu-model-loader
- Support: EDAPack community channels

## Contributing

Found issues with EDAPack integration?

1. Report in qemu-model-loader issues
2. Submit PR with fixes
3. Update this documentation

## Next Steps

After integration:

1. ✓ Test with example devices
2. ✓ Update EDAPack documentation
3. ✓ Announce SDK availability
4. ✓ Gather user feedback
5. → Submit PR to EDAPack/qemu-riscv

## References

- [PACKAGER-GUIDE.md](../PACKAGER-GUIDE.md) - General packaging guide
- [PATCH-INTEGRATION.md](../PATCH-INTEGRATION.md) - Detailed patch integration
- [SDK-STRUCTURE.md](../SDK-STRUCTURE.md) - SDK structure specification
- [github-actions-example.yml](./github-actions-example.yml) - CI/CD example
