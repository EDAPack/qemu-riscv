# Example PCI Device Module

PCI device implementation demonstrating PCI-specific features.

## Features

- **PCI configuration space**: Standard PCI device setup
- **MMIO BAR**: Memory-mapped I/O region (BAR 0)
- **MSI support**: Message Signaled Interrupts
- **PCI device class**: Proper PCI device classification
- **~180 lines** of focused code

## Device Details

### PCI Configuration

- **Vendor ID**: 0x1234 (QEMU)
- **Device ID**: 0x1234 (Example)
- **Class**: Unclassified (PCI_CLASS_OTHERS)
- **BAR 0**: 1KB MMIO region

### Register Map (BAR 0)

| Offset | Name    | Access | Description |
|--------|---------|--------|-------------|
| 0x00   | ID      | R      | Device ID (0xEDA00001) |
| 0x04   | STATUS  | R/W    | Status register |
| 0x08   | CONTROL | R/W    | Control register |
| 0x0C   | DATA    | R/W    | Data register |

## Building

```bash
make
```

Output: `hw-example-pci.so`

## Usage

### Basic Usage

```bash
export QEMU_MODULE_DIR=$(pwd)
qemu-system-x86_64 -M pc -device example-pci
```

### With Linux Guest

```bash
export QEMU_MODULE_DIR=$(pwd)
qemu-system-x86_64 -M pc -device example-pci \
    -kernel bzImage -append "console=ttyS0" \
    -nographic
```

In the guest:
```bash
# List PCI devices
lspci

# Should show:
# 00:04.0 Unclassified device [0000]: Device 1234:1234 (rev 01)

# Check device details
lspci -v -s 00:04.0
```

### Accessing Registers from Guest

```c
// Map BAR 0
volatile uint32_t *dev = mmap(NULL, 1024, PROT_READ | PROT_WRITE,
                              MAP_SHARED, fd, bar0_addr);

// Read device ID
uint32_t id = dev[0];  // Should be 0xEDA00001

// Write control register
dev[2] = 0x0001;  // Enable device

// Read/write data
dev[3] = 0x12345678;
uint32_t data = dev[3];
```

## Code Structure

### State Structure

```c
struct ExamplePCIState {
    PCIDevice parent_obj;  // PCI device base
    
    MemoryRegion mmio;     // BAR 0 MMIO region
    
    uint32_t status;       // Status register
    uint32_t control;      // Control register
    uint32_t data;         // Data register
};
```

### Key Functions

- `example_pci_realize()` - Initialize PCI device
- `example_pci_exit()` - Cleanup
- `example_pci_reset()` - Reset device
- `example_pci_mmio_read/write()` - Handle BAR 0 access

## Advanced Features

### Multiple BARs

```c
static void example_pci_realize(PCIDevice *pdev, Error **errp) {
    ExamplePCIState *s = EXAMPLE_PCI(pdev);
    
    // BAR 0: MMIO
    memory_region_init_io(&s->mmio, OBJECT(pdev), &example_pci_mmio_ops, s,
                          "example-pci-mmio", 1024);
    pci_register_bar(pdev, 0, PCI_BASE_ADDRESS_SPACE_MEMORY, &s->mmio);
    
    // BAR 1: I/O ports
    memory_region_init_io(&s->io, OBJECT(pdev), &example_pci_io_ops, s,
                          "example-pci-io", 256);
    pci_register_bar(pdev, 1, PCI_BASE_ADDRESS_SPACE_IO, &s->io);
}
```

### Using MSI

```c
static void example_pci_raise_irq(ExamplePCIState *s) {
    PCIDevice *pdev = PCI_DEVICE(s);
    
    if (msi_enabled(pdev)) {
        msi_notify(pdev, 0);  // Send MSI
    } else {
        pci_set_irq(pdev, 1);  // Legacy IRQ
    }
}
```

### DMA Support

```c
#include "sysemu/dma.h"

static void example_pci_do_dma(ExamplePCIState *s) {
    PCIDevice *pdev = PCI_DEVICE(s);
    uint8_t buffer[256];
    
    // Read from system memory
    pci_dma_read(pdev, s->dma_addr, buffer, sizeof(buffer));
    
    // Process data...
    
    // Write back
    pci_dma_write(pdev, s->dma_addr, buffer, sizeof(buffer));
}
```

### Configuration Space Capabilities

```c
static void example_pci_realize(PCIDevice *pdev, Error **errp) {
    // ... existing code ...
    
    // Add power management capability
    if (pci_add_capability(pdev, PCI_CAP_ID_PM, 0, PCI_PM_SIZEOF, errp) < 0) {
        return;
    }
}
```

## Testing

### Quick Test

```bash
make test
```

### Check PCI Configuration in Monitor

```bash
export QEMU_MODULE_DIR=$(pwd)
qemu-system-x86_64 -M pc -device example-pci -monitor stdio

# In monitor:
info pci

# Should show device at some bus/slot
```

### Access from Guest (Linux)

```bash
# Find device
lspci -d 1234:1234

# Dump configuration
lspci -x -s 00:04.0

# Access via sysfs
echo 1 > /sys/bus/pci/devices/0000:00:04.0/enable
cat /sys/bus/pci/devices/0000:00:04.0/resource
```

## Debugging

### Enable PCI Logging

```bash
export QEMU_MODULE_DIR=$(pwd)
qemu-system-x86_64 -M pc -device example-pci \
    -d guest_errors \
    -trace 'pci_*'
```

### Check BAR Mapping

```bash
# In QEMU monitor:
info mtree

# Should show BAR 0 mapping in system address space
```

### Debug with GDB

```bash
gdb --args qemu-system-x86_64 -M pc -device example-pci

(gdb) break example_pci_realize
(gdb) run
```

## Troubleshooting

### Device Not Showing in lspci

**Problem**: Guest doesn't see PCI device

**Solutions**:
- Check device shows in `info pci` (monitor)
- Verify module loaded: check QEMU output
- Try different PCI slot: `-device example-pci,addr=05.0`

### BAR Not Mapped

**Problem**: BAR has address 0x00000000

**Solutions**:
- Guest BIOS may need to assign BAR addresses
- Try with Linux guest (better PCI support)
- Check `info mtree` for BAR mapping

### MSI Not Working

**Problem**: No interrupts received

**Solutions**:
- Check guest kernel has MSI support
- Verify MSI enabled: `lspci -v`
- Fall back to legacy IRQ if needed

## Extending This Example

- Add more BARs (I/O, prefetchable memory)
- Implement DMA engine
- Add PCI-Express capabilities
- Support multiple MSI vectors
- Implement proper device driver (guest side)

## Next Steps

- See `../minimal-sysbus/` for simpler example
- See `../uart-device/` for character device example
- Read QEMU PCI docs: `docs/pci*.txt`
- Study QEMU's PCI devices: `hw/*/pci-*.c`

## License

GPLv2, matching QEMU's license.
