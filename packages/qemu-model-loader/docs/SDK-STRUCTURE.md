# QEMU Device SDK - Structure Specification

Official specification of the QEMU Device SDK installation layout.

## Overview

The QEMU Device SDK provides headers and configuration files needed to build QEMU device modules as external shared libraries.

**Installation Prefix**: `/usr/local` (configurable)  
**Total Size**: ~10-15 MB uncompressed, ~3-5 MB compressed  
**File Count**: ~1300 headers + configs

## Directory Layout

```
$(prefix)/
├── include/qemu-device/              # All SDK headers
│   ├── qemu/                         # Core QEMU headers
│   ├── qom/                          # QOM system
│   ├── hw/                           # Device APIs
│   ├── exec/                         # Memory system
│   ├── sysemu/                       # System emulation
│   ├── chardev/                      # Character devices
│   ├── qapi/                         # QAPI types
│   ├── io/                           # I/O
│   ├── migration/                    # Migration
│   ├── monitor/                      # Monitor
│   └── config/                       # Generated configs
│       ├── config-host.h
│       └── qapi/
└── lib/pkgconfig/
    └── qemu-device.pc                # pkg-config file
```

## Critical Headers

### Core (qemu/)
- `osdep.h` - OS compatibility layer (must include first)
- `module.h` - Module registration macros
- `log.h` - Logging facilities
- `timer.h` - Timer APIs

### QOM (qom/)
- `object.h` - Object Model core

### Devices (hw/core/)
- `qdev.h` - Device infrastructure
- `sysbus.h` - System bus devices

### Buses (hw/)
- `hw/pci/pci.h` - PCI devices
- `hw/isa/isa.h` - ISA devices
- `hw/i2c/i2c.h` - I2C devices

### Memory (exec/)
- `memory.h` - Memory regions
- `address-spaces.h` - Address spaces

### Generated (config/)
- `config-host.h` - Platform configuration
- `qapi/qapi-builtin-types.h` - QAPI types

## pkg-config File

`qemu-device.pc` provides:
- Include paths
- Required dependencies (glib-2.0)
- Compiler flags (-DBUILD_DSO)

Usage: `pkg-config --cflags qemu-device`

## Version Information

SDK version matches QEMU version (e.g., SDK 10.0.0 for QEMU 10.0.0)

## ABI Compatibility

**Important**: Device modules are ABI-specific. Modules built for QEMU 10.0.0 may not work with QEMU 10.1.0.

Always rebuild modules when updating QEMU.
