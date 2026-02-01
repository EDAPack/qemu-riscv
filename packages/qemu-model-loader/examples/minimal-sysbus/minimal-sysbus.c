/*
 * Minimal SysBus Device - Example QEMU Device Module
 *
 * This is the absolute minimum required for a loadable QEMU device module.
 * It creates a simple memory-mapped device with a single 4KB MMIO region.
 *
 * Build:
 *   make
 *
 * Use:
 *   export QEMU_MODULE_DIR=$(pwd)
 *   qemu-system-arm -M virt -device minimal-sysbus
 *
 * Copyright (c) 2026 QEMU Model Loader Project
 * Licensed under GPLv2
 */

#define BUILD_DSO
#include "qemu/osdep.h"
#include "qemu/log.h"
#include "qemu/module.h"
#include "hw/sysbus.h"
#include "qom/object.h"

#define TYPE_MINIMAL_SYSBUS "minimal-sysbus"
OBJECT_DECLARE_SIMPLE_TYPE(MinimalSysBusState, MINIMAL_SYSBUS)

struct MinimalSysBusState {
    SysBusDevice parent_obj;
    MemoryRegion mmio;
    uint32_t reg;
};

static uint64_t minimal_sysbus_read(void *opaque, hwaddr addr, unsigned size)
{
    MinimalSysBusState *s = MINIMAL_SYSBUS(opaque);
    
    qemu_log_mask(LOG_GUEST_ERROR, "%s: read from offset 0x%lx\n",
                  TYPE_MINIMAL_SYSBUS, (unsigned long)addr);
    
    if (addr == 0) {
        return s->reg;
    }
    
    return 0;
}

static void minimal_sysbus_write(void *opaque, hwaddr addr,
                                 uint64_t value, unsigned size)
{
    MinimalSysBusState *s = MINIMAL_SYSBUS(opaque);
    
    qemu_log_mask(LOG_GUEST_ERROR, "%s: write 0x%lx to offset 0x%lx\n",
                  TYPE_MINIMAL_SYSBUS, (unsigned long)value,
                  (unsigned long)addr);
    
    if (addr == 0) {
        s->reg = value;
    }
}

static const MemoryRegionOps minimal_sysbus_ops = {
    .read = minimal_sysbus_read,
    .write = minimal_sysbus_write,
    .endianness = DEVICE_NATIVE_ENDIAN,
    .valid = {
        .min_access_size = 4,
        .max_access_size = 4,
    },
};

static void minimal_sysbus_init(Object *obj)
{
    MinimalSysBusState *s = MINIMAL_SYSBUS(obj);
    SysBusDevice *sbd = SYS_BUS_DEVICE(obj);
    
    memory_region_init_io(&s->mmio, obj, &minimal_sysbus_ops, s,
                          TYPE_MINIMAL_SYSBUS, 0x1000);
    sysbus_init_mmio(sbd, &s->mmio);
}

static void minimal_sysbus_class_init(ObjectClass *oc, const void *data)
{
    DeviceClass *dc = DEVICE_CLASS(oc);
    
    dc->desc = "Minimal SysBus Device Example";
    /* No realize, reset, or vmstate needed for this minimal example */
}

static const TypeInfo minimal_sysbus_info = {
    .name          = TYPE_MINIMAL_SYSBUS,
    .parent        = TYPE_SYS_BUS_DEVICE,
    .instance_size = sizeof(MinimalSysBusState),
    .instance_init = minimal_sysbus_init,
    .class_init    = minimal_sysbus_class_init,
};

static void minimal_sysbus_register_types(void)
{
    type_register_static(&minimal_sysbus_info);
}

type_init(minimal_sysbus_register_types)
module_obj(TYPE_MINIMAL_SYSBUS);
