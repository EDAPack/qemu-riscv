# Example UART Device Module

Complete UART implementation demonstrating advanced device module features.

## Features

- **Character device backend**: Connect to stdio, file, socket, etc.
- **IRQ support**: Generates interrupts on RX/TX events
- **Multiple registers**: Data, status, and control registers
- **Full reset handling**: Proper device reset
- **Device properties**: Configurable chardev backend
- **~230 lines** of well-commented code

## Register Map

| Offset | Name    | Access | Description |
|--------|---------|--------|-------------|
| 0x00   | DATA    | R/W    | Data register (read RX, write TX) |
| 0x04   | STATUS  | R/W    | Status register |
| 0x08   | CONTROL | R/W    | Control register |

### Status Register (0x04)

| Bit | Name   | Description |
|-----|--------|-------------|
| 0   | RXRDY  | Receive data ready |
| 1   | TXRDY  | Transmit ready |
| 7   | ERROR  | Error flag (write 1 to clear) |

### Control Register (0x08)

| Bit | Name   | Description |
|-----|--------|-------------|
| 0   | RXIRQ  | Enable RX interrupt |
| 1   | TXIRQ  | Enable TX interrupt |
| 7   | ENABLE | Enable UART |

## Building

```bash
make
```

Output: `hw-example-uart.so`

## Usage

### With stdio

```bash
export QEMU_MODULE_DIR=$(pwd)
qemu-system-arm -M virt \
    -device example-uart,chardev=uart0 \
    -chardev stdio,id=uart0
```

Type characters to send to the UART. They will be echoed back.

### With File

```bash
# Write to file
export QEMU_MODULE_DIR=$(pwd)
qemu-system-arm -M virt \
    -device example-uart,chardev=uart0 \
    -chardev file,id=uart0,path=uart-output.txt
```

### With Socket

```bash
# TCP socket
export QEMU_MODULE_DIR=$(pwd)
qemu-system-arm -M virt \
    -device example-uart,chardev=uart0 \
    -chardev socket,id=uart0,host=localhost,port=1234,server=on
```

Then connect: `telnet localhost 1234`

## Programming the UART

### Sending a Character

```c
// Enable UART
*UART_CONTROL = CONTROL_ENABLE;

// Wait for TX ready
while (!(*UART_STATUS & STATUS_TXRDY));

// Send character
*UART_DATA = 'A';
```

### Receiving a Character

```c
// Enable UART and RX interrupt
*UART_CONTROL = CONTROL_ENABLE | CONTROL_RXIRQ;

// Wait for RX ready
while (!(*UART_STATUS & STATUS_RXRDY));

// Read character
char c = *UART_DATA;
```

### Using Interrupts

```c
// Enable UART with RX/TX interrupts
*UART_CONTROL = CONTROL_ENABLE | CONTROL_RXIRQ | CONTROL_TXIRQ;

// In IRQ handler:
if (*UART_STATUS & STATUS_RXRDY) {
    char c = *UART_DATA;
    // Process received character
}
```

## Code Structure

### State Structure

```c
struct ExampleUartState {
    SysBusDevice parent_obj;
    
    MemoryRegion mmio;    // MMIO region
    CharBackend chr;      // Character backend
    qemu_irq irq;         // Interrupt line
    
    uint8_t data_reg;     // Data register
    uint8_t status_reg;   // Status register
    uint8_t control_reg;  // Control register
};
```

### Key Functions

- `example_uart_read/write()` - MMIO handlers
- `example_uart_can_receive()` - Can accept data?
- `example_uart_receive()` - Handle received data
- `example_uart_update_irq()` - Update interrupt state
- `example_uart_realize()` - Setup chardev handlers
- `example_uart_reset()` - Reset device state

## Testing

### Quick Test

```bash
make test
```

### Manual Test with ARM Guest

```bash
# Start QEMU (will drop to console)
export QEMU_MODULE_DIR=$(pwd)
qemu-system-arm -M virt -device example-uart,chardev=uart0 \
                -chardev stdio,id=uart0 -nographic

# In guest (if you have a kernel):
# echo test > /dev/ttyAMA1  # (or wherever UART is mapped)
```

### Test with QEMU Monitor

```bash
export QEMU_MODULE_DIR=$(pwd)
qemu-system-arm -M virt -device example-uart,chardev=uart0 \
                -chardev stdio,id=uart0,mux=on \
                -mon chardev=uart0

# Switch to monitor: Ctrl-A C
# Info about device: info qtree
# Switch back: Ctrl-A C
```

## Advanced Features

### Adding More Registers

```c
#define UART_BAUD       0x0C

static uint64_t example_uart_read(void *opaque, hwaddr addr, unsigned size) {
    ExampleUartState *s = EXAMPLE_UART(opaque);
    
    switch (addr) {
    // ... existing cases ...
    case UART_BAUD:
        return s->baud_rate;
    }
}
```

### Adding FIFO Buffer

```c
#include "qemu/fifo8.h"

struct ExampleUartState {
    // ... existing fields ...
    Fifo8 rx_fifo;
    Fifo8 tx_fifo;
};

static void example_uart_init(Object *obj) {
    ExampleUartState *s = EXAMPLE_UART(obj);
    
    fifo8_create(&s->rx_fifo, 16);  // 16-byte RX FIFO
    fifo8_create(&s->tx_fifo, 16);  // 16-byte TX FIFO
    
    // ... rest of init ...
}
```

### Adding VMState (Migration Support)

```c
static const VMStateDescription vmstate_example_uart = {
    .name = TYPE_EXAMPLE_UART,
    .version_id = 1,
    .minimum_version_id = 1,
    .fields = (const VMStateField[]) {
        VMSTATE_UINT8(data_reg, ExampleUartState),
        VMSTATE_UINT8(status_reg, ExampleUartState),
        VMSTATE_UINT8(control_reg, ExampleUartState),
        VMSTATE_END_OF_LIST()
    }
};

static void example_uart_class_init(ObjectClass *oc, const void *data) {
    DeviceClass *dc = DEVICE_CLASS(oc);
    dc->vmsd = &vmstate_example_uart;
    // ... rest of class_init ...
}
```

## Debugging

### Enable UART Logging

```bash
export QEMU_MODULE_DIR=$(pwd)
qemu-system-arm -M virt -device example-uart,chardev=uart0 \
                -chardev stdio,id=uart0 \
                -d guest_errors  # Show guest error logs
```

### Check IRQ State

```bash
# In QEMU monitor (Ctrl-A C):
info irq

# Should show IRQ state for your device
```

### Trace Character Device

```bash
qemu-system-arm -M virt -device example-uart,chardev=uart0 \
                -chardev stdio,id=uart0 \
                -trace 'qemu_chr_*'  # Trace chardev events
```

## Troubleshooting

### No Input/Output

**Problem**: Typing doesn't produce output

**Solutions**:
- Check `-chardev` is specified
- Verify `chardev=uart0` matches `-chardev id=uart0`
- Ensure UART is enabled (CONTROL register bit 7)

### IRQs Not Working

**Problem**: No interrupts generated

**Solutions**:
- Check control register has IRQ bits enabled
- Verify device is connected to an IRQ line in machine
- Use `-d int` to debug interrupts

### Module Won't Load

**Problem**: Device not found

**Solutions**:
- Check module filename: `hw-example-uart.so`
- Verify `QEMU_MODULE_DIR` is set
- Ensure SDK version matches QEMU

## Next Steps

- See `../minimal-sysbus/` for simpler example
- See `../pci-device/` for PCI device example
- Read QEMU docs: `docs/devel/device-modules.rst`
- Study QEMU's built-in UARTs: `hw/char/` in QEMU source

## License

GPLv2, matching QEMU's license.
