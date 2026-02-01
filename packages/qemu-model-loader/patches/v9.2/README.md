# QEMU Device Module Patches - v9.2

These patches add device development SDK installation support to QEMU.

## Patch Series

### 0001-build-add-install-dev-sdk-target.patch
Adds `make install-dev-sdk` target that installs:
- All public headers from `include/`
- Generated `config-host.h`
- Generated QAPI headers
- Proper SDK directory structure

### 0002-build-generate-pkgconfig-for-device-sdk.patch
Generates `qemu-device.pc` pkg-config file for easy integration:
```bash
gcc $(pkg-config --cflags qemu-device) -shared device.c -o hw-device.so
```

### 0003-docs-add-device-module-guide.patch
Adds comprehensive documentation in `docs/devel/device-modules.rst`:
- Quick start guide
- API reference
- Examples
- Troubleshooting

## Applying Patches

### For QEMU 10.x (master branch)

```bash
git clone https://gitlab.com/qemu-project/qemu.git
cd qemu
git checkout master  # or v10.2.0 when released

# Apply patches
git am /path/to/qemu-model-loader/patches/v9.2/*.patch
```

### For Build Systems

```bash
# In your build script:
cd qemu-source
for patch in /path/to/patches/v9.2/*.patch; do
    patch -p1 < "$patch"
done
```

### Verifying Application

```bash
# Check patches applied
git log --oneline | head -5

# Should see:
# xxxxxxx docs: add device module development guide
# xxxxxxx build: generate pkg-config file for device module SDK  
# xxxxxxx build: add install-dev-sdk target for device module development
```

## Building with SDK Support

```bash
# Configure
./configure --enable-modules --prefix=/usr/local

# Build
make -j$(nproc)

# Install QEMU
make install

# Install SDK (new target)
make install-dev-sdk
```

Or use meson directly:

```bash
# Configure with SDK installation
meson setup build -Dinstall_dev_sdk=true

# Build
meson compile -C build

# Install
meson install -C build
```

## What Gets Installed

After `make install-dev-sdk`:

```
/usr/local/
├── include/qemu-device/          ← SDK headers
│   ├── qemu/
│   ├── qom/
│   ├── hw/
│   ├── exec/
│   ├── sysemu/
│   ├── chardev/
│   ├── qapi/
│   ├── io/
│   ├── migration/
│   ├── monitor/
│   └── config/                   ← Generated configs
│       ├── config-host.h
│       └── qapi/
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
    git am ../qemu-model-loader/patches/v9.2/*.patch
    
- name: Build QEMU with SDK
  run: |
    cd qemu
    ./configure --enable-modules
    make -j$(nproc)
    make install DESTDIR=$PWD/install
    make install-dev-sdk DESTDIR=$PWD/install
```

### For Debian Packaging

In `debian/rules`:
```makefile
override_dh_auto_install:
	dh_auto_install
	$(MAKE) install-dev-sdk DESTDIR=$(CURDIR)/debian/qemu-device-sdk
```

### For RPM Packaging

In `qemu.spec`:
```spec
%install
make install DESTDIR=%{buildroot}
make install-dev-sdk DESTDIR=%{buildroot}

%files devel
/usr/include/qemu-device/
/usr/lib64/pkgconfig/qemu-device.pc
```

## Troubleshooting

### Patches Don't Apply

**Problem**: `git am` fails with conflicts

**Solutions**:
- Check QEMU version matches
- Try `patch -p1 < file.patch` instead
- Manually resolve conflicts
- Check if patches need updating

### Build Fails

**Problem**: Compilation errors after applying patches

**Solutions**:
- Ensure meson version >= 1.5.0
- Clean build directory: `rm -rf build && meson setup build`
- Check meson options: `meson configure build`

### SDK Installation Empty

**Problem**: `make install-dev-sdk` doesn't install anything

**Solutions**:
- Ensure `--enable-modules` was used in configure
- Or use meson: `-Dinstall_dev_sdk=true`
- Check meson options: `meson configure build | grep install_dev_sdk`

### Module Won't Load

**Problem**: QEMU can't find device after SDK install

**Solutions**:
- Verify SDK headers installed: `ls /usr/local/include/qemu-device/`
- Check pkg-config works: `pkg-config --cflags qemu-device`
- Ensure `BUILD_DSO` defined in module source
- Check module filename: `hw-<typename>.so`

## Version Compatibility

These patches are designed for:
- **QEMU 10.x** (master branch) - Primary target
- **QEMU 9.2.x** - Should apply with minimal changes
- **QEMU 9.1.x** - May need backporting

For other versions, patches may need adjustment.

## Upstream Status

**Status**: Ready for upstream submission  
**Target**: QEMU 10.1 or 10.2

These patches are being prepared for submission to qemu-devel mailing list.

## Support

- **Issues**: https://github.com/fvutils/qemu-model-loader/issues
- **Examples**: See `examples/` directory in this repository
- **Documentation**: See `docs/` directory

## License

These patches are licensed under GPLv2, matching QEMU's license.

