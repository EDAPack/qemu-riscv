/*
 * Custom Timer Device - QEMU Device Module Example
 *
 * This demonstrates a custom memory-mapped timer device that can be
 * loaded as a QEMU module without recompiling QEMU.
 *
 * Features:
 * - Memory-mapped control register at offset 0x0
 * - Memory-mapped counter register at offset 0x4
 * - Timer can be started/stopped via control register
 * - Counter increments every millisecond when enabled
 *
 * Register Map:
 *   0x00: Control Register (bit 0: enable, bit 1: reset)
 *   0x04: Counter Register (read-only, 32-bit counter value)
 *
 * Build:
 *   See Makefile or build instructions below
 *
 * Usage:
 *   qemu-system-riscv64 -M virt -device custom-timer -nographic
 *
 * Copyright (c) 2026 EDAPack QEMU Model Loader Example
 * Licensed under GPLv2
 */

#define BUILD_DSO
#include "qemu/osdep.h"
#include "qemu/log.h"
#include "qemu/module.h"
#include "qemu/timer.h"
#include "hw/sysbus.h"
#include "hw/irq.h"
#include "qom/object.h"

#define TYPE_CUSTOM_TIMER "custom-timer"
OBJECT_DECLARE_SIMPLE_TYPE(CustomTimerState, CUSTOM_TIMER)

/* Register offsets */
#define REG_CONTROL  0x00
#define REG_COUNTER  0x04

/* Control register bits */
#define CTRL_ENABLE  (1 << 0)
#define CTRL_RESET   (1 << 1)

struct CustomTimerState {
    SysBusDevice parent_obj;
    
    MemoryRegion mmio;
    QEMUTimer *timer;
    
    uint32_t control;
    uint32_t counter;
    
    qemu_irq irq;
};

static void custom_timer_tick(void *opaque)
{
    CustomTimerState *s = CUSTOM_TIMER(opaque);
    
    if (s->control & CTRL_ENABLE) {
        s->counter++;
        
        /* Re-arm timer for next tick (1ms) */
        timer_mod(s->timer, qemu_clock_get_ms(QEMU_CLOCK_VIRTUAL) + 1);
        
        qemu_log("custom-timer: tick, counter = %u\n", s->counter);
    }
}

static uint64_t custom_timer_read(void *opaque, hwaddr addr, unsigned size)
{
    CustomTimerState *s = CUSTOM_TIMER(opaque);
    uint64_t value = 0;
    
    switch (addr) {
    case REG_CONTROL:
        value = s->control;
        qemu_log("custom-timer: read control = 0x%x\n", (uint32_t)value);
        break;
        
    case REG_COUNTER:
        value = s->counter;
        qemu_log("custom-timer: read counter = %u\n", s->counter);
        break;
        
    default:
        qemu_log_mask(LOG_GUEST_ERROR,
                      "custom-timer: invalid read at offset 0x%lx\n",
                      (unsigned long)addr);
        break;
    }
    
    return value;
}

static void custom_timer_write(void *opaque, hwaddr addr,
                               uint64_t value, unsigned size)
{
    CustomTimerState *s = CUSTOM_TIMER(opaque);
    
    switch (addr) {
    case REG_CONTROL:
        qemu_log("custom-timer: write control = 0x%lx\n", (unsigned long)value);
        
        /* Handle reset */
        if (value & CTRL_RESET) {
            s->counter = 0;
            s->control &= ~CTRL_RESET;  /* Auto-clear reset bit */
            qemu_log("custom-timer: reset counter\n");
        }
        
        /* Handle enable/disable */
        bool was_enabled = s->control & CTRL_ENABLE;
        s->control = value & CTRL_ENABLE;  /* Only keep enable bit */
        
        if ((s->control & CTRL_ENABLE) && !was_enabled) {
            /* Start timer */
            qemu_log("custom-timer: starting\n");
            timer_mod(s->timer, qemu_clock_get_ms(QEMU_CLOCK_VIRTUAL) + 1);
        } else if (!(s->control & CTRL_ENABLE) && was_enabled) {
            /* Stop timer */
            qemu_log("custom-timer: stopping\n");
            timer_del(s->timer);
        }
        break;
        
    case REG_COUNTER:
        qemu_log_mask(LOG_GUEST_ERROR,
                      "custom-timer: counter register is read-only\n");
        break;
        
    default:
        qemu_log_mask(LOG_GUEST_ERROR,
                      "custom-timer: invalid write 0x%lx to offset 0x%lx\n",
                      (unsigned long)value, (unsigned long)addr);
        break;
    }
}

static const MemoryRegionOps custom_timer_ops = {
    .read = custom_timer_read,
    .write = custom_timer_write,
    .endianness = DEVICE_NATIVE_ENDIAN,
    .valid = {
        .min_access_size = 4,
        .max_access_size = 4,
    },
};

static void custom_timer_init(Object *obj)
{
    CustomTimerState *s = CUSTOM_TIMER(obj);
    SysBusDevice *sbd = SYS_BUS_DEVICE(obj);
    
    /* Initialize MMIO region (8 bytes: 2 registers) */
    memory_region_init_io(&s->mmio, obj, &custom_timer_ops, s,
                          TYPE_CUSTOM_TIMER, 0x1000);
    sysbus_init_mmio(sbd, &s->mmio);
    
    /* Initialize IRQ (optional, for future use) */
    sysbus_init_irq(sbd, &s->irq);
}

static void custom_timer_realize(DeviceState *dev, Error **errp)
{
    CustomTimerState *s = CUSTOM_TIMER(dev);
    
    /* Create the timer */
    s->timer = timer_new_ms(QEMU_CLOCK_VIRTUAL, custom_timer_tick, s);
    
    qemu_log("custom-timer: device realized\n");
}

static void custom_timer_unrealize(DeviceState *dev)
{
    CustomTimerState *s = CUSTOM_TIMER(dev);
    
    /* Clean up timer */
    if (s->timer) {
        timer_free(s->timer);
        s->timer = NULL;
    }
}

static void custom_timer_reset(DeviceState *dev)
{
    CustomTimerState *s = CUSTOM_TIMER(dev);
    
    s->control = 0;
    s->counter = 0;
    
    timer_del(s->timer);
    
    qemu_log("custom-timer: device reset\n");
}

static void custom_timer_class_init(ObjectClass *oc, const void *data)
{
    DeviceClass *dc = DEVICE_CLASS(oc);
    
    dc->desc = "Custom Timer Device (Loadable Module Example)";
    dc->realize = custom_timer_realize;
    dc->unrealize = custom_timer_unrealize;
    dc->reset = custom_timer_reset;
}

static const TypeInfo custom_timer_info = {
    .name          = TYPE_CUSTOM_TIMER,
    .parent        = TYPE_SYS_BUS_DEVICE,
    .instance_size = sizeof(CustomTimerState),
    .instance_init = custom_timer_init,
    .class_init    = custom_timer_class_init,
};

static void custom_timer_register_types(void)
{
    type_register_static(&custom_timer_info);
}

type_init(custom_timer_register_types)

/* This macro is required for QEMU module loading */
module_obj(TYPE_CUSTOM_TIMER);
