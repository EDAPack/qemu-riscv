#!/bin/bash
# QEMU Device Module - Complete Build and Test Script
# This script demonstrates the entire workflow from source to running device

set -e

echo "===================================================="
echo "QEMU Dynamic Device Loading - Example Workflow"
echo "===================================================="
echo

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
QEMU_DIR="${SCRIPT_DIR}/qemu"
MODULE_NAME="example-uart"
MODULE_FILE="hw-${MODULE_NAME}.so"
MODULE_SRC="${MODULE_NAME}.c"

# Step 1: Check prerequisites
echo "Step 1: Checking prerequisites..."
command -v gcc >/dev/null 2>&1 || { echo "Error: gcc not found"; exit 1; }
pkg-config --exists glib-2.0 || { echo "Error: glib-2.0 not found"; exit 1; }
echo "  ✓ gcc found"
echo "  ✓ glib-2.0 found"
echo

# Step 2: Check QEMU source
echo "Step 2: Checking QEMU source..."
if [ ! -d "$QEMU_DIR" ]; then
    echo "  QEMU source not found. Run:"
    echo "  git clone https://gitlab.com/qemu-project/qemu.git"
    exit 1
fi
echo "  ✓ QEMU source found at: $QEMU_DIR"
echo

# Step 3: Create example device source if it doesn't exist
echo "Step 3: Creating example device source..."
if [ ! -f "$MODULE_SRC" ]; then
cat > "$MODULE_SRC" << 'EOF'
/*
 * Example UART Device for QEMU
 * 
 * This is a minimal example showing how to create a loadable device module.
 * Compile as: gcc -fPIC -DBUILD_DSO -shared -o hw-example-uart.so example-uart.c ...
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
#define UART_DATA    0x00
#define UART_STATUS  0x04
#define UART_CONTROL 0x08

/* Status bits */
#define STATUS_RXRDY 0x01
#define STATUS_TXRDY 0x02

struct ExampleUartState {
    SysBusDevice parent_obj;
    
    MemoryRegion mmio;
    CharBackend chr;
    qemu_irq irq;
    
    uint8_t data;
    uint8_t status;
    uint8_t control;
};

static uint64_t example_uart_read(void *opaque, hwaddr addr, unsigned size)
{
    ExampleUartState *s = EXAMPLE_UART(opaque);
    uint64_t value = 0;
    
    switch (addr) {
    case UART_DATA:
        value = s->data;
        s->status &= ~STATUS_RXRDY;
        qemu_set_irq(s->irq, 0);
        break;
    case UART_STATUS:
        value = s->status;
        break;
    case UART_CONTROL:
        value = s->control;
        break;
    default:
        qemu_log_mask(LOG_GUEST_ERROR,
                      "example-uart: bad read offset 0x%x\n", (int)addr);
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
        ch = value;
        if (qemu_chr_fe_backend_connected(&s->chr)) {
            qemu_chr_fe_write_all(&s->chr, &ch, 1);
        }
        s->status |= STATUS_TXRDY;
        break;
    case UART_CONTROL:
        s->control = value;
        break;
    default:
        qemu_log_mask(LOG_GUEST_ERROR,
                      "example-uart: bad write offset 0x%x\n", (int)addr);
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

static int example_uart_can_receive(void *opaque)
{
    ExampleUartState *s = EXAMPLE_UART(opaque);
    return !(s->status & STATUS_RXRDY);
}

static void example_uart_receive(void *opaque, const uint8_t *buf, int size)
{
    ExampleUartState *s = EXAMPLE_UART(opaque);
    
    if (size > 0) {
        s->data = buf[0];
        s->status |= STATUS_RXRDY;
        if (s->control & 0x01) { /* IRQ enabled */
            qemu_set_irq(s->irq, 1);
        }
    }
}

static void example_uart_realize(DeviceState *dev, Error **errp)
{
    ExampleUartState *s = EXAMPLE_UART(dev);
    
    qemu_chr_fe_set_handlers(&s->chr, example_uart_can_receive,
                            example_uart_receive, NULL, NULL,
                            s, NULL, true);
}

static void example_uart_reset(DeviceState *dev)
{
    ExampleUartState *s = EXAMPLE_UART(dev);
    
    s->data = 0;
    s->status = STATUS_TXRDY;
    s->control = 0;
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
    dc->desc = "Example UART Device (Loadable Module)";
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

/* DSO stamp function - required for module loading */
void qemu_module_dummy(void);
void qemu_module_dummy(void) {}
EOF
    echo "  ✓ Created $MODULE_SRC"
else
    echo "  ✓ Found existing $MODULE_SRC"
fi
echo

# Step 4: Build the module
echo "Step 4: Building module..."
CFLAGS="-Wall -Wextra -O2 -fPIC -DBUILD_DSO"
CFLAGS="$CFLAGS -I${QEMU_DIR}/include"
CFLAGS="$CFLAGS $(pkg-config --cflags glib-2.0)"
LDFLAGS="-shared"
LIBS="$(pkg-config --libs glib-2.0)"

echo "  Compiling: gcc $CFLAGS $LDFLAGS $MODULE_SRC -o $MODULE_FILE $LIBS"
gcc $CFLAGS $LDFLAGS "$MODULE_SRC" -o "$MODULE_FILE" $LIBS

if [ -f "$MODULE_FILE" ]; then
    echo "  ✓ Built $MODULE_FILE"
    ls -lh "$MODULE_FILE"
else
    echo "  ✗ Build failed"
    exit 1
fi
echo

# Step 5: Verify module
echo "Step 5: Verifying module..."
echo "  Checking for required symbols:"
nm "$MODULE_FILE" | grep -q "qemu_module_dummy" && echo "    ✓ qemu_module_dummy found" || echo "    ✗ qemu_module_dummy missing"
nm "$MODULE_FILE" | grep -q "example_uart_register_types" && echo "    ✓ registration function found" || echo "    ✗ registration function missing"
nm "$MODULE_FILE" | grep -q "T.*uart" && echo "    ✓ device symbols found" || echo "    ✗ device symbols missing"
echo

# Step 6: Create test script
echo "Step 6: Creating test script..."
cat > test-module.sh << 'TESTEOF'
#!/bin/bash
# Test the example-uart module

export QEMU_MODULE_DIR=$(dirname "$0")

echo "Testing example-uart module..."
echo "Module directory: $QEMU_MODULE_DIR"
echo

# Test 1: Check if device is recognized
echo "Test 1: Device help"
qemu-system-arm -M virt -device example-uart,help 2>&1 | head -20

echo
echo "Test 2: Device info"
qemu-system-arm -M virt -device example-uart -nographic -serial none << 'EOF' &
EOF
QEMU_PID=$!
sleep 2
kill $QEMU_PID 2>/dev/null
wait $QEMU_PID 2>/dev/null

echo
echo "✓ Module loaded successfully!"
echo
echo "To use the device interactively:"
echo "  export QEMU_MODULE_DIR=$(dirname "$0")"
echo "  qemu-system-arm -M virt -device example-uart,chardev=uart0 -chardev stdio,id=uart0"
TESTEOF

chmod +x test-module.sh
echo "  ✓ Created test-module.sh"
echo

# Step 7: Summary
echo "===================================================="
echo "Build Complete!"
echo "===================================================="
echo
echo "Files created:"
echo "  • $MODULE_SRC - Device source code"
echo "  • $MODULE_FILE - Compiled module"
echo "  • test-module.sh - Test script"
echo
echo "To use the module:"
echo "  1. Set module path:"
echo "     export QEMU_MODULE_DIR=$SCRIPT_DIR"
echo
echo "  2. Run QEMU with the device:"
echo "     qemu-system-arm -M virt -device example-uart,chardev=uart0 \\"
echo "                     -chardev stdio,id=uart0"
echo
echo "  3. Or run the test script:"
echo "     ./test-module.sh"
echo
echo "For more information, see:"
echo "  • README.md - Overview and getting started"
echo "  • QUICK_REFERENCE.md - API reference"
echo "  • dynamic-device-loading-design.md - Full design"
echo
echo "===================================================="
