#define BUILD_DSO
#include "qemu/osdep.h"
#include "qemu/module.h"
#include "hw/sysbus.h"
#include "qom/object.h"

#define TYPE_TEST "test-device"

typedef struct TestState {
    SysBusDevice parent_obj;
    MemoryRegion mmio;
} TestState;

OBJECT_DECLARE_SIMPLE_TYPE(TestState, TEST)

static uint64_t test_read(void *opaque, hwaddr addr, unsigned size) { return 0; }
static void test_write(void *opaque, hwaddr addr, uint64_t val, unsigned size) {}

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
    dc->desc = "Test";
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
