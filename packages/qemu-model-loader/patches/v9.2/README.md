# QEMU Device Module Patches - v9.2.0

These patches add device development SDK installation support to QEMU v9.2.0.

## Status

✅ **WORKING** - Patches have been tested and verified to apply cleanly to QEMU v9.2.0

## Patch Series

### 0001-build-add-install-dev-sdk-target-for-device-module-d.patch
**Complete working patch** that adds device SDK installation support via meson option:
- Adds `install_dev_sdk` meson build option
- Installs all public headers from `include/{qemu,qom,hw,exec,sysemu,chardev,io,migration,monitor}`
- Installs generated `config-host.h`
- Installs generated QAPI headers
- Generates and installs `qemu-device.pc` pkg-config file
- Proper SDK directory structure at `${prefix}/include/qemu-device/`

## Applying Patches

### For QEMU v9.2.0

```bash
git clone --branch v9.2.0 https://gitlab.com/qemu-project/qemu.git
cd qemu

# Apply patch
git apply /path/to/qemu-model-loader/patches/v9.2/0001-*.patch

# Or with git am
git am /path/to/qemu-model-loader/patches/v9.2/0001-*.patch
```

### For Build Systems

```bash
# In your build script:
cd qemu-source
patch -p1 < /path/to/patches/v9.2/0001-*.patch
```

### Verifying Application

```bash
# Check patch applied
git log --oneline -1

# Should see:
# xxxxxxx build: add install-dev-sdk target for device module development

# Verify meson option exists
grep install_dev_sdk meson_options.txt
```

## Building with SDK Support

**Meson (QEMU v9.2.0 uses meson):**

```bash
# Configure with SDK installation enabled
meson setup build --prefix=/usr/local -Dinstall_dev_sdk=true

# Build
meson compile -C build

# Install (includes SDK)
meson install -C build
```

**Or configure first, then enable SDK:**

```bash
# Initial setup
meson setup build --prefix=/usr/local

# Enable SDK installation
meson configure build -Dinstall_dev_sdk=true

# Build and install
meson compile -C build
meson install -C build
```

## What Gets Installed

After `meson install` with `-Dinstall_dev_sdk=true`:

```
/usr/local/
├── include/qemu-device/          ← SDK headers
│   ├── qemu/                     ← Core QEMU headers
│   ├── qom/                      ← QOM (QEMU Object Model)
│   ├── hw/                       ← Hardware device headers
│   ├── exec/                     ← Execution engine headers
│   ├── sysemu/                   ← System emulation
│   ├── chardev/                  ← Character devices
│   ├── io/                       ← I/O utilities
│   ├── migration/                ← Migration support
│   ├── monitor/                  ← Monitor interface
│   ├── config-host.h             ← Generated config
│   └── qapi/                     ← Generated QAPI headers
└── lib/pkgconfig/
    └── qemu-device.pc            ← pkg-config file
```

## Testing the SDK

### Build Example Module

```bash
# Create test device
cat > test-device.c << 'EOF'
#define BUILD_DSO
#include "qemu/osdep.h"
#include "qemu/module.h"
#include "hw/sysbus.h"
#include "qom/object.h"

#define TYPE_TEST "test-device"
OBJECT_DECLARE_SIMPLE_TYPE(TestState, TEST)

struct TestState {
    SysBusDevice parent_obj;
    MemoryRegion mmio;
};

static uint64_t test_read(void *opaque, hwaddr addr, unsigned size) {
    return 0;
}

static void test_write(void *opaque, hwaddr addr, uint64_t val, unsigned size) {
}

static const MemoryRegionOps test_ops = {
    .read = test_read,
    .write = test_write,
    .endianness = DEVICE_NATIVE_ENDIAN,
};

static void test_init(Object *obj) {
    TestState *s = TEST(obj);
    memory_region_init_io(&s->mmio, obj, &test_ops, s, TYPE_TEST, 0x1000);
    sysbus_init_mmio(SYS_BUS_DEVICE(obj), &s->mmio);
}

static void test_class_init(ObjectClass *oc, const void *data) {
    DeviceClass *dc = DEVICE_CLASS(oc);
    dc->desc = "Test Device";
}

static const TypeInfo test_info = {
    .name = TYPE_TEST,
    .parent = TYPE_SYS_BUS_DEVICE,
    .instance_size = sizeof(TestState),
    .instance_init = test_init,
    .class_init = test_class_init,
};

static void register_types(void) {
    type_register_static(&test_info);
}

type_init(register_types)
module_obj(TYPE_TEST);
EOF

# Build module
gcc $(pkg-config --cflags qemu-device) \
    -fPIC -shared test-device.c \
    -o hw-test-device.so \
    $(pkg-config --libs glib-2.0)

# Test loading
export QEMU_MODULE_DIR=$(pwd)
qemu-system-x86_64 -M pc -device test-device -nographic -serial none

# Should start without errors (Ctrl-C to exit)
```

## Integration with Build Systems

### For GitHub Actions

```yaml
- name: Apply QEMU patches
  run: |
    cd qemu
    git apply ../qemu-model-loader/patches/v9.2/*.patch
    
- name: Build QEMU with SDK
  run: |
    cd qemu
    meson setup build -Dinstall_dev_sdk=true --prefix=/usr/local
    meson compile -C build
    meson install -C build --destdir=$PWD/install
```

### For Debian Packaging

In `debian/rules`:
```makefile
override_dh_auto_configure:
	dh_auto_configure -- -Dinstall_dev_sdk=true

override_dh_auto_install:
	dh_auto_install
```

### For RPM Packaging

In `qemu.spec`:
```spec
%build
meson setup build -Dinstall_dev_sdk=true --prefix=%{_prefix}
meson compile -C build

%install
meson install -C build --destdir=%{buildroot}

%files devel
%{_includedir}/qemu-device/
%{_libdir}/pkgconfig/qemu-device.pc
```

## Troubleshooting

### Patches Don't Apply

**Problem**: `git apply` fails with conflicts

**Solutions**:
- Verify you have QEMU v9.2.0 exactly: `git describe --tags` should show `v9.2.0`
- Try `patch -p1 < file.patch` instead
- Check patch file integrity

### Build Fails

**Problem**: Meson configuration or compilation errors

**Solutions**:
- Ensure meson version >= 0.63.0: `meson --version`
- Clean build directory: `rm -rf build && meson setup build`
- Check meson options: `meson configure build`

### SDK Installation Not Enabled

**Problem**: SDK files not installed after build

**Solutions**:
- Verify option is set: `meson configure build | grep install_dev_sdk`
- Should show: `install_dev_sdk true`
- Reconfigure if needed: `meson configure build -Dinstall_dev_sdk=true`

### Module Won't Load

**Problem**: QEMU can't find device after SDK install

**Solutions**:
- Verify SDK headers installed: `ls /usr/local/include/qemu-device/`
- Check pkg-config works: `pkg-config --cflags qemu-device`
- Ensure `BUILD_DSO` defined in module source
- Check module filename: `hw-<typename>.so`

## Version Compatibility

These patches are specifically for:
- **QEMU v9.2.0** - Tested and verified ✅

For other versions:
- **QEMU v9.1.x** - Will need adjustment (different meson.build structure)
- **QEMU v9.0.x** - Will need adjustment
- **QEMU v10.x** - Will need separate patches (upstream changes)

## Upstream Status

**Status**: Functional patch ready for local use  
**Target**: This is a working implementation for QEMU v9.2.0

These patches enable device SDK installation for binary distributions of QEMU.

## Support

- **Issues**: https://github.com/fvutils/qemu-model-loader/issues
- **Examples**: See `examples/` directory in this repository
- **Documentation**: See `docs/` directory

## License

These patches are licensed under GPLv2, matching QEMU's license.

