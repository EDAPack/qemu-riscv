/*
 * Example PCI Device - QEMU Device Module
 *
 * This demonstrates a PCI device module with:
 * - PCI configuration space
 * - MMIO BAR
 * - MSI support
 * - Standard PCI device structure
 *
 * Build:
 *   make
 *
 * Use:
 *   export QEMU_MODULE_DIR=$(pwd)
 *   qemu-system-x86_64 -M pc -device example-pci
 *
 * Copyright (c) 2026 QEMU Model Loader Project
 * Licensed under GPLv2
 */

#define BUILD_DSO
#include "qemu/osdep.h"
#include "qemu/log.h"
#include "qemu/module.h"
#include "hw/pci/pci.h"
#include "hw/pci/msi.h"
#include "qom/object.h"

#define TYPE_EXAMPLE_PCI "example-pci"
OBJECT_DECLARE_SIMPLE_TYPE(ExamplePCIState, EXAMPLE_PCI)

/* PCI Vendor/Device IDs (using QEMU's vendor ID) */
#define PCI_VENDOR_ID_EXAMPLE  PCI_VENDOR_ID_QEMU
#define PCI_DEVICE_ID_EXAMPLE  0x1234

/* MMIO register offsets */
#define REG_ID       0x00  /* Device ID register */
#define REG_STATUS   0x04  /* Status register */
#define REG_CONTROL  0x08  /* Control register */
#define REG_DATA     0x0C  /* Data register */

struct ExamplePCIState {
    PCIDevice parent_obj;
    
    MemoryRegion mmio;
    
    uint32_t status;
    uint32_t control;
    uint32_t data;
};

static uint64_t example_pci_mmio_read(void *opaque, hwaddr addr, unsigned size)
{
    ExamplePCIState *s = EXAMPLE_PCI(opaque);
    uint32_t value = 0;
    
    switch (addr) {
    case REG_ID:
        value = 0xEDA00001;  /* Example device ID */
        break;
        
    case REG_STATUS:
        value = s->status;
        break;
        
    case REG_CONTROL:
        value = s->control;
        break;
        
    case REG_DATA:
        value = s->data;
        break;
        
    default:
        qemu_log_mask(LOG_GUEST_ERROR,
                      "%s: bad read offset 0x%lx\n",
                      TYPE_EXAMPLE_PCI, (unsigned long)addr);
        break;
    }
    
    return value;
}

static void example_pci_mmio_write(void *opaque, hwaddr addr,
                                   uint64_t value, unsigned size)
{
    ExamplePCIState *s = EXAMPLE_PCI(opaque);
    
    switch (addr) {
    case REG_STATUS:
        /* Status is mostly read-only, but allow clearing bits */
        s->status &= ~value;
        break;
        
    case REG_CONTROL:
        s->control = value;
        /* Could trigger actions based on control bits */
        break;
        
    case REG_DATA:
        s->data = value;
        break;
        
    default:
        qemu_log_mask(LOG_GUEST_ERROR,
                      "%s: bad write offset 0x%lx value 0x%lx\n",
                      TYPE_EXAMPLE_PCI, (unsigned long)addr,
                      (unsigned long)value);
        break;
    }
}

static const MemoryRegionOps example_pci_mmio_ops = {
    .read = example_pci_mmio_read,
    .write = example_pci_mmio_write,
    .endianness = DEVICE_LITTLE_ENDIAN,
    .valid = {
        .min_access_size = 4,
        .max_access_size = 4,
    },
};

static void example_pci_realize(PCIDevice *pdev, Error **errp)
{
    ExamplePCIState *s = EXAMPLE_PCI(pdev);
    
    /* Setup PCI configuration space */
    pci_config_set_interrupt_pin(pdev->config, 1);
    
    /* Initialize MMIO region (BAR 0) */
    memory_region_init_io(&s->mmio, OBJECT(pdev), &example_pci_mmio_ops, s,
                          "example-pci-mmio", 1024);
    pci_register_bar(pdev, 0, PCI_BASE_ADDRESS_SPACE_MEMORY, &s->mmio);
    
    /* Initialize MSI support (optional) */
    if (msi_init(pdev, 0, 1, true, false, errp)) {
        return;
    }
    
    /* Initialize device state */
    s->status = 0;
    s->control = 0;
    s->data = 0;
}

static void example_pci_exit(PCIDevice *pdev)
{
    msi_uninit(pdev);
}

static void example_pci_reset(DeviceState *dev)
{
    ExamplePCIState *s = EXAMPLE_PCI(dev);
    
    s->status = 0;
    s->control = 0;
    s->data = 0;
}

static void example_pci_class_init(ObjectClass *oc, const void *data)
{
    DeviceClass *dc = DEVICE_CLASS(oc);
    PCIDeviceClass *pc = PCI_DEVICE_CLASS(oc);
    
    pc->realize = example_pci_realize;
    pc->exit = example_pci_exit;
    pc->vendor_id = PCI_VENDOR_ID_EXAMPLE;
    pc->device_id = PCI_DEVICE_ID_EXAMPLE;
    pc->revision = 0x01;
    pc->class_id = PCI_CLASS_OTHERS;
    
    dc->desc = "Example PCI Device Module";
    device_class_set_legacy_reset(dc, example_pci_reset);
    set_bit(DEVICE_CATEGORY_MISC, dc->categories);
}

static const TypeInfo example_pci_info = {
    .name          = TYPE_EXAMPLE_PCI,
    .parent        = TYPE_PCI_DEVICE,
    .instance_size = sizeof(ExamplePCIState),
    .class_init    = example_pci_class_init,
    .interfaces = (const InterfaceInfo[]) {
        { INTERFACE_CONVENTIONAL_PCI_DEVICE },
        { },
    },
};

static void example_pci_register_types(void)
{
    type_register_static(&example_pci_info);
}

type_init(example_pci_register_types)
module_obj(TYPE_EXAMPLE_PCI);
