# QEMU Device Module Quick Reference

## Minimal Working Module Template

```c
// my_device.c
#define BUILD_DSO
#include "qemu/osdep.h"
#include "qemu/module.h"
#include "hw/sysbus.h"
#include "qom/object.h"

#define TYPE_MY_DEVICE "my-device"
OBJECT_DECLARE_SIMPLE_TYPE(MyDeviceState, MY_DEVICE)

struct MyDeviceState {
    SysBusDevice parent_obj;
    MemoryRegion mmio;
};

static uint64_t my_device_read(void *opaque, hwaddr addr, unsigned size) {
    return 0;
}

static void my_device_write(void *opaque, hwaddr addr, uint64_t val, unsigned size) {
}

static const MemoryRegionOps my_device_ops = {
    .read = my_device_read,
    .write = my_device_write,
    .endianness = DEVICE_NATIVE_ENDIAN,
};

static void my_device_realize(DeviceState *dev, Error **errp) {
}

static void my_device_init(Object *obj) {
    MyDeviceState *s = MY_DEVICE(obj);
    SysBusDevice *sbd = SYS_BUS_DEVICE(obj);
    
    memory_region_init_io(&s->mmio, obj, &my_device_ops, s,
                          TYPE_MY_DEVICE, 0x1000);
    sysbus_init_mmio(sbd, &s->mmio);
}

static void my_device_class_init(ObjectClass *oc, const void *data) {
    DeviceClass *dc = DEVICE_CLASS(oc);
    dc->realize = my_device_realize;
    dc->desc = "My Device";
}

static const TypeInfo my_device_info = {
    .name          = TYPE_MY_DEVICE,
    .parent        = TYPE_SYS_BUS_DEVICE,
    .instance_size = sizeof(MyDeviceState),
    .instance_init = my_device_init,
    .class_init    = my_device_class_init,
};

static void my_device_register_types(void) {
    type_register_static(&my_device_info);
}

type_init(my_device_register_types)
module_obj(TYPE_MY_DEVICE);
```

## Build Commands

```bash
# One-liner build
gcc -fPIC -DBUILD_DSO -shared -o hw-my-device.so my_device.c \
    -I/path/to/qemu/include \
    $(pkg-config --cflags --libs glib-2.0)

# Or with Makefile
make
```

## Makefile Template

```makefile
QEMU_SRC ?= /usr/local/src/qemu
QEMU_BUILD ?= /usr/local/build/qemu
MODULE_NAME = my-device
CC = gcc
CFLAGS = -Wall -O2 -fPIC -DBUILD_DSO \
         -I$(QEMU_SRC)/include -I$(QEMU_BUILD) \
         $(shell pkg-config --cflags glib-2.0)
LDFLAGS = -shared
LIBS = $(shell pkg-config --libs glib-2.0)

hw-$(MODULE_NAME).so: $(MODULE_NAME).c
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $< $(LIBS)

clean:
	rm -f hw-$(MODULE_NAME).so

install: hw-$(MODULE_NAME).so
	install -d $(HOME)/.local/lib/qemu
	install -m 644 $< $(HOME)/.local/lib/qemu/

.PHONY: clean install
```

## Usage

```bash
# Set module path
export QEMU_MODULE_DIR=$HOME/.local/lib/qemu

# Use device
qemu-system-arm -M virt -device my-device

# Or inline
QEMU_MODULE_DIR=/path/to/modules qemu-system-x86_64 -device my-device
```

## Common Parent Types

| Type | Header | Use Case |
|------|--------|----------|
| `TYPE_DEVICE` | `hw/core/qdev.h` | Abstract base |
| `TYPE_SYS_BUS_DEVICE` | `hw/core/sysbus.h` | MMIO devices |
| `TYPE_PCI_DEVICE` | `hw/pci/pci.h` | PCI devices |
| `TYPE_ISA_DEVICE` | `hw/isa/isa.h` | ISA bus devices |
| `TYPE_USB_DEVICE` | `hw/usb.h` | USB devices |

## Device Categories

```c
set_bit(DEVICE_CATEGORY_STORAGE, dc->categories);
set_bit(DEVICE_CATEGORY_NETWORK, dc->categories);
set_bit(DEVICE_CATEGORY_INPUT, dc->categories);
set_bit(DEVICE_CATEGORY_DISPLAY, dc->categories);
set_bit(DEVICE_CATEGORY_SOUND, dc->categories);
set_bit(DEVICE_CATEGORY_MISC, dc->categories);
```

## Adding Properties

```c
static Property my_device_properties[] = {
    DEFINE_PROP_UINT32("reg-size", MyDeviceState, reg_size, 0x1000),
    DEFINE_PROP_STRING("name", MyDeviceState, name),
    DEFINE_PROP_CHR("chardev", MyDeviceState, chr),
    DEFINE_PROP_BOOL("enabled", MyDeviceState, enabled, true),
    DEFINE_PROP_END_OF_LIST(),
};

static void my_device_class_init(ObjectClass *oc, const void *data) {
    DeviceClass *dc = DEVICE_CLASS(oc);
    device_class_set_props(dc, my_device_properties);
}
```

## Memory Regions

```c
// Initialize MMIO region
memory_region_init_io(&s->mmio, obj, &my_device_ops, s,
                      "my-device-mmio", size);

// Register with sysbus
sysbus_init_mmio(sbd, &s->mmio);

// Or PCI BAR
pci_register_bar(pdev, 0, PCI_BASE_ADDRESS_SPACE_MEMORY, &s->mmio);
```

## IRQs

```c
// SysBus IRQ
qemu_irq irq;
sysbus_init_irq(sbd, &s->irq);

// Raise/lower
qemu_set_irq(s->irq, 1);  // raise
qemu_set_irq(s->irq, 0);  // lower

// PCI IRQ
pci_set_irq(pdev, level);

// MSI
msi_notify(pdev, vector);
```

## DMA

```c
#include "sysemu/dma.h"

// Read from guest memory
dma_memory_read(as, addr, buf, len, MEMTXATTRS_UNSPECIFIED);

// Write to guest memory  
dma_memory_write(as, addr, buf, len, MEMTXATTRS_UNSPECIFIED);
```

## Character Device Backend

```c
#include "chardev/char-fe.h"

typedef struct {
    DeviceState parent;
    CharBackend chr;
} MyDeviceState;

static Property props[] = {
    DEFINE_PROP_CHR("chardev", MyDeviceState, chr),
    DEFINE_PROP_END_OF_LIST(),
};

static void my_device_realize(DeviceState *dev, Error **errp) {
    MyDeviceState *s = MY_DEVICE(dev);
    qemu_chr_fe_set_handlers(&s->chr, can_receive, receive,
                            event, NULL, s, NULL, true);
}

// Write to chardev
qemu_chr_fe_write_all(&s->chr, buf, len);
```

## Timers

```c
#include "qemu/timer.h"

typedef struct {
    DeviceState parent;
    QEMUTimer *timer;
} MyDeviceState;

static void timer_callback(void *opaque) {
    MyDeviceState *s = opaque;
    // Handle timer event
}

static void my_device_init(Object *obj) {
    MyDeviceState *s = MY_DEVICE(obj);
    s->timer = timer_new_ns(QEMU_CLOCK_VIRTUAL, timer_callback, s);
}

// Start timer (1 second)
timer_mod(s->timer, qemu_clock_get_ns(QEMU_CLOCK_VIRTUAL) + 1000000000);

// Stop timer
timer_del(s->timer);
```

## Logging

```c
#include "qemu/log.h"

// Guest error
qemu_log_mask(LOG_GUEST_ERROR, "bad register access at 0x%x\n", addr);

// Debug
qemu_log_mask(LOG_UNIMP, "unimplemented feature\n");

// Always logged
error_report("my-device: critical error");
```

## Reset Handling

```c
static void my_device_reset(DeviceState *dev) {
    MyDeviceState *s = MY_DEVICE(dev);
    s->status = 0;
    s->control = 0;
}

static void my_device_class_init(ObjectClass *oc, const void *data) {
    DeviceClass *dc = DEVICE_CLASS(oc);
    device_class_set_legacy_reset(dc, my_device_reset);
}
```

## VMState (Save/Restore)

```c
static const VMStateDescription vmstate_my_device = {
    .name = TYPE_MY_DEVICE,
    .version_id = 1,
    .minimum_version_id = 1,
    .fields = (const VMStateField[]) {
        VMSTATE_UINT32(status, MyDeviceState),
        VMSTATE_UINT32(control, MyDeviceState),
        VMSTATE_END_OF_LIST()
    }
};

static void my_device_class_init(ObjectClass *oc, const void *data) {
    DeviceClass *dc = DEVICE_CLASS(oc);
    dc->vmsd = &vmstate_my_device;
}
```

## PCI Device Template

```c
#include "hw/pci/pci.h"

#define TYPE_MY_PCI_DEVICE "my-pci-device"
OBJECT_DECLARE_SIMPLE_TYPE(MyPCIState, MY_PCI_DEVICE)

struct MyPCIState {
    PCIDevice parent_obj;
    MemoryRegion mmio;
};

static void my_pci_realize(PCIDevice *pdev, Error **errp) {
    MyPCIState *s = MY_PCI_DEVICE(pdev);
    
    pci_config_set_interrupt_pin(pdev->config, 1);
    
    memory_region_init_io(&s->mmio, OBJECT(pdev), &my_pci_ops, s,
                         "my-pci-mmio", 1024);
    pci_register_bar(pdev, 0, PCI_BASE_ADDRESS_SPACE_MEMORY, &s->mmio);
}

static void my_pci_class_init(ObjectClass *oc, const void *data) {
    DeviceClass *dc = DEVICE_CLASS(oc);
    PCIDeviceClass *k = PCI_DEVICE_CLASS(oc);
    
    k->realize = my_pci_realize;
    k->vendor_id = 0x1234;
    k->device_id = 0x5678;
    k->revision = 0x01;
    k->class_id = PCI_CLASS_OTHERS;
    
    set_bit(DEVICE_CATEGORY_MISC, dc->categories);
}

static const TypeInfo my_pci_info = {
    .name          = TYPE_MY_PCI_DEVICE,
    .parent        = TYPE_PCI_DEVICE,
    .instance_size = sizeof(MyPCIState),
    .class_init    = my_pci_class_init,
    .interfaces = (const InterfaceInfo[]) {
        { INTERFACE_CONVENTIONAL_PCI_DEVICE },
        { },
    },
};
```

## Debugging

```bash
# Enable module loading trace
qemu-system-x86_64 -trace 'module_*' -device my-device

# Run with GDB
gdb --args qemu-system-x86_64 -device my-device
(gdb) break my_device_realize
(gdb) run

# Check module symbols
nm hw-my-device.so | grep my_device

# Verify DSO stamp
nm hw-my-device.so | grep qemu_stamp
nm hw-my-device.so | grep qemu_module_dummy
```

## Common Errors

| Error | Cause | Solution |
|-------|-------|----------|
| "failed to initialize module" | Missing DSO stamp | Define BUILD_DSO |
| "not a valid device" | Type not registered | Check type_init() |
| "unknown device" | Module not found | Check QEMU_MODULE_DIR |
| "version mismatch" | Wrong QEMU version | Rebuild against correct version |
| "undefined symbol" | Missing dependency | Check required libraries |

## Best Practices

1. ✓ Keep module self-contained
2. ✓ Use static for internal functions
3. ✓ Validate all guest inputs
4. ✓ Handle errors gracefully
5. ✓ Document properties
6. ✓ Test save/restore
7. ✓ Check memory leaks
8. ✓ Use proper endianness
9. ✓ Log guest errors
10. ✓ Version your device

## Testing

```bash
# Basic test
qemu-system-x86_64 -M pc -device my-device,help

# With machine
qemu-system-arm -M virt -device my-device -nographic

# Monitor interaction
qemu-system-x86_64 -M pc -device my-device -monitor stdio
(qemu) info qtree
(qemu) device_add my-device,id=dev1
```

## Resources

- Full Design: `dynamic-device-loading-design.md`
- Summary: `SUMMARY.md`  
- QEMU Docs: `docs/devel/qom.rst`, `docs/devel/qdev-api.rst`
- Examples: `hw/misc/edu.c`, `hw/misc/debugexit.c`
