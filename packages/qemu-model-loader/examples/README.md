# QEMU Device Module Examples

Reference implementations demonstrating how to build QEMU device modules.

## Examples

### 1. minimal-sysbus (Beginner)

**File**: `minimal-sysbus/minimal-sysbus.c` (~100 lines)

The absolute minimum for a working device module:
- Simple SysBus device
- Single MMIO region (4KB)
- One register (read/write)
- No IRQs, no properties

**Best for**: Understanding basic structure, first device module

**Build**: 
```bash
cd minimal-sysbus && make
```

**Use**:
```bash
export QEMU_MODULE_DIR=$(pwd)
qemu-system-arm -M virt -device minimal-sysbus
```

---

### 2. uart-device (Intermediate)

**File**: `uart-device/example-uart.c` (~230 lines)

Complete UART implementation:
- Character device backend (stdio, file, socket)
- IRQ support (RX/TX interrupts)
- Multiple registers (data, status, control)
- Device properties
- Reset handling

**Best for**: Real-world device with interrupts and I/O

**Build**:
```bash
cd uart-device && make
```

**Use**:
```bash
export QEMU_MODULE_DIR=$(pwd)
qemu-system-arm -M virt \
    -device example-uart,chardev=uart0 \
    -chardev stdio,id=uart0
```

---

### 3. pci-device (Advanced)

**File**: `pci-device/example-pci.c` (~180 lines)

PCI device implementation:
- PCI configuration space
- MMIO BAR (Base Address Register)
- MSI (Message Signaled Interrupts)
- PCI device class
- Standard PCI structure

**Best for**: PCI devices, x86 platforms

**Build**:
```bash
cd pci-device && make
```

**Use**:
```bash
export QEMU_MODULE_DIR=$(pwd)
qemu-system-x86_64 -M pc -device example-pci
```

## Quick Start

### Build All Examples

```bash
./test-all.sh
```

This builds and validates all three examples.

### Build Individual Example

```bash
cd minimal-sysbus
make
```

### Test Individual Example

```bash
cd minimal-sysbus
make test
```

## Learning Path

### Beginner → Intermediate → Advanced

1. **Start with minimal-sysbus**
   - Understand basic structure
   - Learn QOM type system
   - Grasp memory region basics

2. **Move to uart-device**
   - Add interrupts
   - Use character backends
   - Implement properties
   - Handle reset

3. **Try pci-device**
   - Understand PCI specifics
   - Work with BARs
   - Use MSI
   - Handle PCI configuration

## Common Patterns

### Device Structure

All examples follow this pattern:

```c
#define BUILD_DSO
#include "qemu/osdep.h"
#include "qemu/module.h"
#include "hw/.../..." // Bus-specific
#include "qom/object.h"

#define TYPE_MY_DEVICE "my-device"
OBJECT_DECLARE_SIMPLE_TYPE(MyDeviceState, MY_DEVICE)

struct MyDeviceState {
    /* Parent must be first */
    ParentDevice parent_obj;
    
    /* Device-specific fields */
    MemoryRegion mmio;
    // ...
};

/* Implement functions */
static void my_device_init(Object *obj) { /* ... */ }
static void my_device_class_init(ObjectClass *oc, const void *data) { /* ... */ }

/* Register type */
static const TypeInfo my_device_info = {
    .name = TYPE_MY_DEVICE,
    .parent = TYPE_PARENT_DEVICE,
    .instance_size = sizeof(MyDeviceState),
    .instance_init = my_device_init,
    .class_init = my_device_class_init,
};

static void register_types(void) {
    type_register_static(&my_device_info);
}

type_init(register_types)
module_obj(TYPE_MY_DEVICE);
```

### MMIO Read/Write

```c
static uint64_t my_device_read(void *opaque, hwaddr addr, unsigned size) {
    MyDeviceState *s = MY_DEVICE(opaque);
    
    switch (addr) {
    case REG_DATA:
        return s->data;
    default:
        qemu_log_mask(LOG_GUEST_ERROR, "bad read offset 0x%lx\n", addr);
        return 0;
    }
}

static void my_device_write(void *opaque, hwaddr addr,
                            uint64_t value, unsigned size) {
    MyDeviceState *s = MY_DEVICE(opaque);
    
    switch (addr) {
    case REG_DATA:
        s->data = value;
        break;
    default:
        qemu_log_mask(LOG_GUEST_ERROR, "bad write offset 0x%lx\n", addr);
    }
}
```

### Adding IRQs

```c
struct MyDeviceState {
    ParentDevice parent_obj;
    qemu_irq irq;
    // ...
};

static void my_device_init(Object *obj) {
    MyDeviceState *s = MY_DEVICE(obj);
    SysBusDevice *sbd = SYS_BUS_DEVICE(obj);
    
    sysbus_init_irq(sbd, &s->irq);
}

/* Raise interrupt */
qemu_set_irq(s->irq, 1);

/* Lower interrupt */
qemu_set_irq(s->irq, 0);
```

## Prerequisites

### Software Requirements

- **QEMU Device SDK**: `qemu-device-sdk` package
- **GLib**: `libglib2.0-dev` or `glib2-devel`
- **Compiler**: GCC or Clang
- **pkg-config**: For build configuration
- **QEMU**: qemu-system-* binaries

### Installation (Debian/Ubuntu)

```bash
sudo apt install qemu-device-sdk libglib2.0-dev build-essential pkg-config
sudo apt install qemu-system-arm qemu-system-x86
```

### Installation (Fedora/RHEL)

```bash
sudo dnf install qemu-device-sdk glib2-devel gcc make pkg-config
sudo dnf install qemu-system-aarch64 qemu-system-x86
```

## Build System

All examples use a standard Makefile:

```makefile
CC = gcc
CFLAGS = $(shell pkg-config --cflags qemu-device glib-2.0) -fPIC
LDFLAGS = -shared
LIBS = $(shell pkg-config --libs glib-2.0)

hw-mydevice.so: mydevice.c
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $< $(LIBS)
```

## Testing

### Automated Testing

```bash
# Test all examples
./test-all.sh
```

### Manual Testing

```bash
# Build
cd minimal-sysbus
make

# Test load
export QEMU_MODULE_DIR=$(pwd)
qemu-system-arm -M virt -device minimal-sysbus -nographic

# Should start without errors
# Press Ctrl-C to exit
```

### With Monitor

```bash
export QEMU_MODULE_DIR=$(pwd)
qemu-system-arm -M virt -device minimal-sysbus -monitor stdio

# In monitor:
info qtree    # Show device tree
info mtree    # Show memory regions
```

## Troubleshooting

### Build Issues

**Problem**: `qemu/osdep.h: No such file or directory`

**Solution**: Install SDK
```bash
sudo apt install qemu-device-sdk
# or
pkg-config --cflags qemu-device  # Check if SDK is found
```

**Problem**: `undefined reference to g_malloc0`

**Solution**: Link with GLib
```bash
# Make sure this is in LIBS:
$(pkg-config --libs glib-2.0)
```

### Runtime Issues

**Problem**: `'my-device' is not a valid device`

**Solutions**:
- Set `QEMU_MODULE_DIR`: `export QEMU_MODULE_DIR=$(pwd)`
- Check filename: must be `hw-<typename>.so`
- Verify module exists: `ls hw-*.so`

**Problem**: `version mismatch`

**Solution**: Rebuild module
```bash
make clean
make
```

### Testing Issues

**Problem**: QEMU exits immediately

**Solution**: This is normal with `-nographic`. Try:
```bash
qemu-system-arm -M virt -device mydevice -nographic -serial none
# Press Ctrl-A X to exit
```

## Advanced Topics

### Adding Properties

```c
static Property my_device_properties[] = {
    DEFINE_PROP_UINT32("size", MyDeviceState, size, 0x1000),
    DEFINE_PROP_STRING("name", MyDeviceState, name),
    DEFINE_PROP_END_OF_LIST(),
};

static void my_device_class_init(ObjectClass *oc, const void *data) {
    DeviceClass *dc = DEVICE_CLASS(oc);
    device_class_set_props(dc, my_device_properties);
}
```

### VMState (Migration)

```c
static const VMStateDescription vmstate_my_device = {
    .name = TYPE_MY_DEVICE,
    .version_id = 1,
    .minimum_version_id = 1,
    .fields = (const VMStateField[]) {
        VMSTATE_UINT32(data, MyDeviceState),
        VMSTATE_END_OF_LIST()
    }
};
```

### Timers

```c
#include "qemu/timer.h"

struct MyDeviceState {
    // ...
    QEMUTimer *timer;
};

static void timer_cb(void *opaque) {
    MyDeviceState *s = opaque;
    // Handle timer
}

static void my_device_init(Object *obj) {
    MyDeviceState *s = MY_DEVICE(obj);
    s->timer = timer_new_ns(QEMU_CLOCK_VIRTUAL, timer_cb, s);
}

// Start timer (1 second)
timer_mod(s->timer, qemu_clock_get_ns(QEMU_CLOCK_VIRTUAL) + 1000000000);
```

## Further Reading

- **QEMU Documentation**: `docs/devel/device-modules.rst`
- **QOM Guide**: `docs/devel/qom.rst`
- **QDEV API**: `docs/devel/qdev-api.rst`
- **QEMU Source**: `hw/` directory for more examples

## Support

- **Issues**: https://github.com/fvutils/qemu-model-loader/issues
- **Documentation**: See `../docs/` directory
- **QEMU Mailing List**: qemu-devel@nongnu.org

## License

All examples are licensed under GPLv2, matching QEMU's license.
