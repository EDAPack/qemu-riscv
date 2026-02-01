# QEMU Model Loader Example - Custom Timer Device

This directory contains a complete example of creating a custom QEMU device that can be dynamically loaded as a module.

## Quick Start

```bash
# Download the latest QEMU build with model-loader support
cd examples/custom-timer
# (QEMU archive should be extracted here as qemu-riscv/)

# Build the custom timer module
make

# Run test
./test.sh
```

## What's Included

### custom-timer.c
A complete implementation of a memory-mapped timer device featuring:
- 32-bit counter that increments every millisecond
- Control register for enable/disable and reset
- Proper QEMU device lifecycle (realize, reset, unrealize)
- Virtual timer integration using QEMU's timer API
- Memory-mapped I/O with proper register handling

### Makefile
Build script that:
- Compiles the device as a shared library (.so)
- Uses QEMU SDK headers from the installation
- Links against required libraries (glib-2.0)
- Produces a module that QEMU can load at runtime

### test.sh
Demonstration script showing:
- How to set QEMU_MODULE_DIR for module loading
- Verifying the device is recognized by QEMU
- Instantiating the device in a virtual machine
- Expected output and behavior

## Architecture

```
custom-timer.c
     ↓ (compile with -DBUILD_DSO -shared)
hw-custom-timer.so
     ↓ (QEMU loads via dlopen)
QEMU Process
     ↓ (registers device type)
QOM Type System
     ↓ (device available)
Virtual Machine
```

## Device Register Map

```
Offset | Size | Access | Name     | Description
-------|------|--------|----------|---------------------------
0x00   | 4B   | RW     | CONTROL  | Control register
       |      |        |          | bit 0: Enable timer
       |      |        |          | bit 1: Reset counter
0x04   | 4B   | RO     | COUNTER  | Counter value (milliseconds)
```

## Usage Example

Once the SDK is available and the module is built:

```bash
# Set module directory
export QEMU_MODULE_DIR=/path/to/examples/custom-timer

# Run QEMU with custom device
qemu-system-riscv64 \
    -M virt \
    -device custom-timer,addr=0x10001000 \
    -kernel your-kernel.elf \
    -nographic
```

In your guest software:
```c
// Map the device
volatile uint32_t *timer_ctrl = (uint32_t *)0x10001000;
volatile uint32_t *timer_count = (uint32_t *)0x10001004;

// Start timer
*timer_ctrl = 0x1;

// Wait a bit
for (int i = 0; i < 1000000; i++) asm("nop");

// Read counter (should show elapsed milliseconds)
uint32_t elapsed = *timer_count;
printf("Elapsed: %u ms\n", elapsed);

// Reset counter
*timer_ctrl = 0x2;

// Stop timer
*timer_ctrl = 0x0;
```

## Current Limitations

⚠️ **SDK Not Available**: The QEMU build in CI doesn't include the device SDK because the patches are for QEMU v9.2 but CI builds from master. See README.md for solutions.

Once the SDK is available, this example will work out of the box.

## Educational Value

This example demonstrates:

1. **QEMU Object Model (QOM)**: Proper type registration and object hierarchy
2. **SysBus Devices**: System bus device creation
3. **Memory-Mapped I/O**: MemoryRegion creation and operation handlers
4. **Virtual Timers**: QEMUTimer usage for periodic callbacks
5. **Device Lifecycle**: Initialize, realize, reset, and unrealize
6. **Module System**: Making devices loadable at runtime

## Extending This Example

You can extend this device to add:
- **Interrupts**: Signal CPU when counter reaches threshold
- **Configuration**: Properties for timer period, counter width
- **Multiple Channels**: Array of timers
- **DMA**: Direct memory access for counter values
- **VMState**: Save/restore for migration support

Example with interrupt:
```c
// In init
sysbus_init_irq(sbd, &s->irq);

// In timer tick
if (s->counter == s->threshold) {
    qemu_irq_raise(s->irq);
}
```

## Related Examples

See also:
- `packages/qemu-model-loader/examples/uart-device/` - Serial device example
- `packages/qemu-model-loader/examples/pci-device/` - PCI device example
- `packages/qemu-model-loader/examples/minimal-sysbus/` - Absolute minimal example

## References

- [QEMU Device Emulation](https://www.qemu.org/docs/master/devel/qdev-api.html)
- [QOM Documentation](https://www.qemu.org/docs/master/devel/qom.html)
- [Module System](https://www.qemu.org/docs/master/devel/modules.html)
- QEMU Model Loader: `../../packages/qemu-model-loader/README.md`

## Troubleshooting

### Module doesn't load
- Check QEMU_MODULE_DIR is set correctly
- Verify file is named `hw-custom-timer.so`
- Check with: `qemu-system-riscv64 -device help | grep custom-timer`

### Build fails
- Ensure QEMU SDK is installed
- Check pkg-config: `pkg-config --cflags --libs glib-2.0`
- Verify headers exist: `ls qemu-riscv/include/qemu-device/`

### Device doesn't appear in VM
- Check device was instantiated: `-device custom-timer`
- Look for errors in QEMU output
- Enable logging: `-d guest_errors`

## License

GPLv2 (matching QEMU's license)
