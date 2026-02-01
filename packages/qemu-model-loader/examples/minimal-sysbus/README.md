# Minimal SysBus Device Example

The absolute minimum required for a loadable QEMU device module.

## What This Is

A bare-bones SysBus device with:
- Single 4KB MMIO region
- One 32-bit register
- Read/write operations
- ~100 lines of code

This demonstrates the minimal structure needed for a working device module.

## Building

### Prerequisites

- QEMU Device SDK installed (`qemu-device-sdk` package)
- GLib development files (`libglib2.0-dev`)
- C compiler (GCC or Clang)

### Build Commands

```bash
# Simple build
make

# Or manually
gcc $(pkg-config --cflags qemu-device) \
    -fPIC -shared minimal-sysbus.c \
    -o hw-minimal-sysbus.so \
    $(pkg-config --libs glib-2.0)
```

Output: `hw-minimal-sysbus.so`

## Usage

### Basic Usage

```bash
# Set module directory
export QEMU_MODULE_DIR=$(pwd)

# Run QEMU with device
qemu-system-arm -M virt -device minimal-sysbus
```

### With More Verbose Output

```bash
# Enable guest error logging
export QEMU_MODULE_DIR=$(pwd)
qemu-system-arm -M virt -device minimal-sysbus \
    -d guest_errors
```

### Testing Module Load

```bash
# Quick test (will exit immediately)
make test
```

## Device Details

### Type Name

`minimal-sysbus`

### Memory Region

- Size: 4KB (0x1000 bytes)
- Offset 0x0: 32-bit register (read/write)

### Behavior

- **Read from register 0**: Returns last written value
- **Write to register 0**: Stores value
- **All other accesses**: Return 0, logged as guest error

## Code Structure

```c
struct MinimalSysBusState {
    SysBusDevice parent_obj;  // Parent class
    MemoryRegion mmio;        // MMIO region
    uint32_t reg;             // Single register
};
```

### Key Functions

- `minimal_sysbus_read()` - Handle MMIO reads
- `minimal_sysbus_write()` - Handle MMIO writes
- `minimal_sysbus_init()` - Initialize instance
- `minimal_sysbus_class_init()` - Initialize class
- `minimal_sysbus_register_types()` - Register with QOM

### Required Macros

- `BUILD_DSO` - Enable module mode
- `type_init()` - Register types at module load
- `module_obj()` - Declare exported type

## Extending This Example

To add more functionality:

### Add IRQ Support

```c
struct MinimalSysBusState {
    SysBusDevice parent_obj;
    MemoryRegion mmio;
    qemu_irq irq;  // Add IRQ
};

static void minimal_sysbus_init(Object *obj) {
    MinimalSysBusState *s = MINIMAL_SYSBUS(obj);
    SysBusDevice *sbd = SYS_BUS_DEVICE(obj);
    
    memory_region_init_io(&s->mmio, obj, &minimal_sysbus_ops, s,
                          TYPE_MINIMAL_SYSBUS, 0x1000);
    sysbus_init_mmio(sbd, &s->mmio);
    sysbus_init_irq(sbd, &s->irq);  // Initialize IRQ
}
```

### Add Properties

```c
static Property minimal_sysbus_properties[] = {
    DEFINE_PROP_UINT32("reg-size", MinimalSysBusState, mmio_size, 0x1000),
    DEFINE_PROP_END_OF_LIST(),
};

static void minimal_sysbus_class_init(ObjectClass *oc, const void *data) {
    DeviceClass *dc = DEVICE_CLASS(oc);
    dc->desc = "Minimal SysBus Device Example";
    device_class_set_props(dc, minimal_sysbus_properties);
}
```

### Add Reset Handler

```c
static void minimal_sysbus_reset(DeviceState *dev) {
    MinimalSysBusState *s = MINIMAL_SYSBUS(dev);
    s->reg = 0;
}

static void minimal_sysbus_class_init(ObjectClass *oc, const void *data) {
    DeviceClass *dc = DEVICE_CLASS(oc);
    dc->desc = "Minimal SysBus Device Example";
    device_class_set_legacy_reset(dc, minimal_sysbus_reset);
}
```

## Troubleshooting

### Module Not Found

**Error**: `'minimal-sysbus' is not a valid device`

**Solution**:
- Check `QEMU_MODULE_DIR` is set
- Verify module filename is `hw-minimal-sysbus.so`
- Ensure module is in the directory

### Build Errors

**Error**: `qemu/osdep.h: No such file or directory`

**Solution**:
- Install QEMU Device SDK
- Check `pkg-config --cflags qemu-device` works

**Error**: `undefined reference to 'g_malloc0'`

**Solution**:
- Link with GLib: `$(pkg-config --libs glib-2.0)`

### Runtime Errors

**Error**: `version mismatch`

**Solution**:
- Rebuild module against correct QEMU version
- Ensure SDK matches installed QEMU

## Next Steps

After understanding this minimal example:

1. See `../uart-device/` for a complete device with interrupts and char backend
2. See `../pci-device/` for a PCI device example
3. Read QEMU documentation: `docs/devel/device-modules.rst`

## License

GPLv2, matching QEMU's license.
