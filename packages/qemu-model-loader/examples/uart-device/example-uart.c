/*
 * Example UART Device - Complete QEMU Device Module
 *
 * This is a complete UART device implementation showing:
 * - Character device backend integration
 * - IRQ support
 * - Device properties
 * - Reset handling
 * - Basic UART registers (data, status, control)
 *
 * Build:
 *   make
 *
 * Use:
 *   export QEMU_MODULE_DIR=$(pwd)
 *   qemu-system-arm -M virt -device example-uart,chardev=uart0 \
 *                   -chardev stdio,id=uart0
 *
 * Copyright (c) 2026 QEMU Model Loader Project
 * Licensed under GPLv2
 */

#define BUILD_DSO
#include "qemu/osdep.h"
#include "qemu/log.h"
#include "qemu/module.h"
#include "hw/sysbus.h"
#include "hw/irq.h"
#include "chardev/char-fe.h"
#include "qom/object.h"

#define TYPE_EXAMPLE_UART "example-uart"
OBJECT_DECLARE_SIMPLE_TYPE(ExampleUartState, EXAMPLE_UART)

/* Register offsets */
#define UART_DATA       0x00
#define UART_STATUS     0x04
#define UART_CONTROL    0x08

/* Status register bits */
#define STATUS_RXRDY    0x01  /* Receive data ready */
#define STATUS_TXRDY    0x02  /* Transmit ready */
#define STATUS_ERROR    0x80  /* Error flag */

/* Control register bits */
#define CONTROL_RXIRQ   0x01  /* Enable RX interrupt */
#define CONTROL_TXIRQ   0x02  /* Enable TX interrupt */
#define CONTROL_ENABLE  0x80  /* Enable UART */

struct ExampleUartState {
    SysBusDevice parent_obj;
    
    MemoryRegion mmio;
    CharBackend chr;
    qemu_irq irq;
    
    uint8_t data_reg;
    uint8_t status_reg;
    uint8_t control_reg;
};

static void example_uart_update_irq(ExampleUartState *s)
{
    int level = 0;
    
    if (s->control_reg & CONTROL_ENABLE) {
        if ((s->status_reg & STATUS_RXRDY) && (s->control_reg & CONTROL_RXIRQ)) {
            level = 1;
        }
        if ((s->status_reg & STATUS_TXRDY) && (s->control_reg & CONTROL_TXIRQ)) {
            level = 1;
        }
    }
    
    qemu_set_irq(s->irq, level);
}

static uint64_t example_uart_read(void *opaque, hwaddr addr, unsigned size)
{
    ExampleUartState *s = EXAMPLE_UART(opaque);
    uint32_t value = 0;
    
    switch (addr) {
    case UART_DATA:
        value = s->data_reg;
        /* Clear RX ready when data is read */
        s->status_reg &= ~STATUS_RXRDY;
        example_uart_update_irq(s);
        break;
        
    case UART_STATUS:
        value = s->status_reg;
        break;
        
    case UART_CONTROL:
        value = s->control_reg;
        break;
        
    default:
        qemu_log_mask(LOG_GUEST_ERROR,
                      "%s: bad read offset 0x%lx\n",
                      TYPE_EXAMPLE_UART, (unsigned long)addr);
        break;
    }
    
    return value;
}

static void example_uart_write(void *opaque, hwaddr addr,
                               uint64_t value, unsigned size)
{
    ExampleUartState *s = EXAMPLE_UART(opaque);
    unsigned char ch;
    
    switch (addr) {
    case UART_DATA:
        /* Transmit character */
        ch = value;
        if (qemu_chr_fe_backend_connected(&s->chr)) {
            qemu_chr_fe_write_all(&s->chr, &ch, 1);
        }
        /* TX ready stays set in this simple implementation */
        s->status_reg |= STATUS_TXRDY;
        example_uart_update_irq(s);
        break;
        
    case UART_STATUS:
        /* Status is mostly read-only, but allow clearing error flag */
        if (value & STATUS_ERROR) {
            s->status_reg &= ~STATUS_ERROR;
        }
        break;
        
    case UART_CONTROL:
        s->control_reg = value;
        example_uart_update_irq(s);
        break;
        
    default:
        qemu_log_mask(LOG_GUEST_ERROR,
                      "%s: bad write offset 0x%lx value 0x%lx\n",
                      TYPE_EXAMPLE_UART, (unsigned long)addr,
                      (unsigned long)value);
        break;
    }
}

static const MemoryRegionOps example_uart_ops = {
    .read = example_uart_read,
    .write = example_uart_write,
    .endianness = DEVICE_NATIVE_ENDIAN,
    .valid = {
        .min_access_size = 1,
        .max_access_size = 4,
    },
};

/* Character device callbacks */
static int example_uart_can_receive(void *opaque)
{
    ExampleUartState *s = EXAMPLE_UART(opaque);
    /* Can receive if enabled and no data pending */
    return (s->control_reg & CONTROL_ENABLE) &&
           !(s->status_reg & STATUS_RXRDY);
}

static void example_uart_receive(void *opaque, const uint8_t *buf, int size)
{
    ExampleUartState *s = EXAMPLE_UART(opaque);
    
    if (size > 0) {
        s->data_reg = buf[0];
        s->status_reg |= STATUS_RXRDY;
        example_uart_update_irq(s);
    }
}

static void example_uart_event(void *opaque, QEMUChrEvent event)
{
    /* Handle chardev events if needed */
}

static void example_uart_realize(DeviceState *dev, Error **errp)
{
    ExampleUartState *s = EXAMPLE_UART(dev);
    
    qemu_chr_fe_set_handlers(&s->chr, example_uart_can_receive,
                            example_uart_receive, example_uart_event,
                            NULL, s, NULL, true);
}

static void example_uart_reset(DeviceState *dev)
{
    ExampleUartState *s = EXAMPLE_UART(dev);
    
    s->data_reg = 0;
    s->status_reg = STATUS_TXRDY;  /* TX ready by default */
    s->control_reg = 0;
    
    example_uart_update_irq(s);
}

static void example_uart_init(Object *obj)
{
    ExampleUartState *s = EXAMPLE_UART(obj);
    SysBusDevice *sbd = SYS_BUS_DEVICE(obj);
    
    memory_region_init_io(&s->mmio, obj, &example_uart_ops, s,
                          TYPE_EXAMPLE_UART, 0x1000);
    sysbus_init_mmio(sbd, &s->mmio);
    sysbus_init_irq(sbd, &s->irq);
}

static Property example_uart_properties[] = {
    DEFINE_PROP_CHR("chardev", ExampleUartState, chr),
    DEFINE_PROP_END_OF_LIST(),
};

static void example_uart_class_init(ObjectClass *oc, const void *data)
{
    DeviceClass *dc = DEVICE_CLASS(oc);
    
    dc->realize = example_uart_realize;
    dc->desc = "Example UART Device Module";
    device_class_set_legacy_reset(dc, example_uart_reset);
    device_class_set_props(dc, example_uart_properties);
}

static const TypeInfo example_uart_info = {
    .name          = TYPE_EXAMPLE_UART,
    .parent        = TYPE_SYS_BUS_DEVICE,
    .instance_size = sizeof(ExampleUartState),
    .instance_init = example_uart_init,
    .class_init    = example_uart_class_init,
};

static void example_uart_register_types(void)
{
    type_register_static(&example_uart_info);
}

type_init(example_uart_register_types)
module_obj(TYPE_EXAMPLE_UART);
