# QEMU Device Module SDK Requirements (Binary-Only QEMU)

## Problem Statement

When QEMU is distributed as **binary-only** (without source), device module developers need a minimal SDK containing:
1. Public API headers
2. Build-time generated configuration
3. Build tooling/helpers

This document analyzes what must be exported for external module development.

## Critical Build Dependencies

### 1. Generated Configuration Headers

These are **generated during QEMU build** and are REQUIRED:

#### `config-host.h` (Build directory)
- **Purpose**: Host platform configuration
- **Contains**: 
  - `CONFIG_LINUX`, `CONFIG_DARWIN`, `CONFIG_WIN32`
  - `CONFIG_MODULES` (module support enabled)
  - `CONFIG_HOST_DSOSUF` (`.so`, `.dll`, `.dylib`)
  - `CONFIG_QEMU_MODDIR` (module install path)
  - Feature flags for available functionality
- **Used by**: `qemu/osdep.h` (line 34)
- **Critical**: YES - Cannot compile without it

#### `config-target.h` (One per target, e.g., `config-target-x86_64.h`)
- **Purpose**: Target architecture configuration  
- **Contains**:
  - `TARGET_X86_64`, `TARGET_ARM`, etc.
  - `TARGET_BIG_ENDIAN` / `TARGET_LITTLE_ENDIAN`
  - Target-specific feature flags
  - Address size configuration
- **Used by**: `qemu/osdep.h` (line 36, when `COMPILING_PER_TARGET`)
- **Critical**: Only if device is target-specific

#### `qemu-version.h` (Build directory)
- **Purpose**: QEMU version information
- **Contains**:
  - `QEMU_VERSION` string
  - `QEMU_PKGVERSION`
  - Build timestamp
- **Used by**: Version checking, DSO stamp validation
- **Critical**: For version compatibility checking

#### `qapi/qapi-builtin-types.h` (Generated)
- **Purpose**: QAPI type definitions
- **Contains**: Generated QOM/QAPI types
- **Used by**: `qom/object.h`
- **Critical**: YES

### 2. Source Tree Headers (1346 files)

All headers from `qemu/include/` directory are needed:

#### Absolutely Required for Basic Device:
```
qemu/include/
├── qemu/
│   ├── osdep.h           ← Master include (CRITICAL)
│   ├── module.h          ← Module registration
│   ├── compiler.h        ← Compiler abstractions
│   ├── typedefs.h        ← Basic type definitions
│   ├── atomic.h          ← Atomic operations
│   ├── log.h             ← Logging
│   └── timer.h           ← Timers
├── qom/
│   ├── object.h          ← QOM type system (CRITICAL)
│   └── object_interfaces.h
├── hw/core/
│   ├── qdev.h            ← Device API (CRITICAL)
│   ├── sysbus.h          ← SysBus devices
│   ├── irq.h             ← IRQ handling
│   └── resettable.h      ← Reset handling
├── hw/qdev-properties.h  ← Device properties
├── hw/qdev-properties-system.h
└── qapi/
    ├── error.h           ← Error handling
    └── visitor.h         ← Property visitors
```

#### Bus-Specific Headers:
```
hw/pci/pci.h              ← PCI devices
hw/isa/isa.h              ← ISA devices  
hw/usb.h                  ← USB devices
hw/i2c/i2c.h              ← I2C devices
```

#### Common Utility Headers:
```
qemu/queue.h              ← List/queue macros
qemu/bitmap.h             ← Bit manipulation
qemu/bitops.h
qemu/bswap.h              ← Endian conversion
qemu/units.h              ← Size units (KiB, MiB)
chardev/char-fe.h         ← Character device backend
sysemu/dma.h              ← DMA operations
exec/memory.h             ← Memory regions
exec/address-spaces.h     ← Address space access
```

### 3. Build System Integration

#### What Module Build Needs:

```makefile
# Essential build flags
CFLAGS = -fPIC                           # Position independent code
         -DBUILD_DSO                      # Enable module mode
         -I$(SDK_PATH)/include            # Public headers
         -I$(SDK_PATH)/config             # Generated config headers
         $(shell pkg-config --cflags glib-2.0)

LDFLAGS = -shared                         # Create shared library

# Target-specific builds (if needed)
CFLAGS += -DCOMPILING_PER_TARGET          # For target-specific modules
          -I$(SDK_PATH)/config/target-x86_64  # Target config
```

## Proposed SDK Structure

### Directory Layout

```
qemu-device-sdk-9.2.0/
├── include/                              ← All public headers (1346 files)
│   ├── qemu/
│   ├── qom/
│   ├── hw/
│   ├── exec/
│   ├── chardev/
│   └── ...
├── config/                               ← Build-generated configs
│   ├── config-host.h                     ← Host config
│   ├── qemu-version.h                    ← Version info
│   ├── qapi/                             ← Generated QAPI
│   │   └── qapi-builtin-types.h
│   └── target/                           ← Per-target configs
│       ├── config-target-x86_64.h
│       ├── config-target-aarch64.h
│       └── config-target-riscv64.h
├── share/
│   ├── pkgconfig/
│   │   └── qemu-device.pc                ← pkg-config file
│   └── cmake/
│       └── QEMUDeviceConfig.cmake        ← CMake support
├── bin/
│   ├── qemu-device-init                  ← Skeleton generator
│   └── qemu-device-check                 ← Module validator
├── examples/
│   ├── minimal-device.c
│   ├── uart-device.c
│   ├── pci-device.c
│   └── Makefile
└── doc/
    ├── device-api.txt
    └── module-building.txt
```

### pkg-config File (`qemu-device.pc`)

```ini
# qemu-device.pc - pkg-config for QEMU device modules

prefix=/usr/local
exec_prefix=${prefix}
includedir=${prefix}/include/qemu-device
configdir=${prefix}/include/qemu-device/config
libdir=${prefix}/lib

Name: QEMU Device SDK
Description: SDK for building QEMU device modules
Version: 9.2.0
URL: https://www.qemu.org

Requires: glib-2.0 >= 2.56
Cflags: -I${includedir} -I${configdir} -DBUILD_DSO
Libs: -L${libdir}
```

Usage:
```bash
gcc $(pkg-config --cflags qemu-device) -shared device.c -o hw-device.so
```

## Header Export Policy

### What MUST Be Exported

#### Tier 1: Core Device API (Always)
- `qemu/osdep.h` and its dependencies
- `qom/object.h` - QOM type system
- `hw/core/qdev.h` - Device base class
- `hw/core/sysbus.h` - SysBus devices
- `hw/qdev-properties*.h` - Device properties
- `qemu/module.h` - Module registration
- `qapi/error.h` - Error handling

#### Tier 2: Common Functionality (Recommended)
- `hw/pci/pci.h` - PCI devices
- `hw/isa/isa.h` - ISA devices  
- `hw/irq.h` - IRQ handling
- `exec/memory.h` - Memory regions
- `chardev/char-fe.h` - Character backends
- `qemu/timer.h` - Timers
- `qemu/log.h` - Logging
- `sysemu/dma.h` - DMA

#### Tier 3: Extended (Optional)
- Bus-specific headers (USB, I2C, SPI, etc.)
- Advanced features (migration, tracing)
- Platform-specific headers

### What Should NOT Be Exported

- QEMU internal implementation details
- Target CPU emulation internals (`target/*/`)
- System emulation private APIs
- TCG (translation) internals
- Monitor/QMP implementation details
- Build system internals

### Stability Contract

**Stable API** (guaranteed across minor versions):
- Core QOM/QDEV types and macros
- Device lifecycle callbacks (realize, reset, etc.)
- Memory region operations
- IRQ functions
- Basic property types
- Module registration macros

**Unstable API** (may change):
- Internal data structures
- Helper function internals
- Platform-specific code
- Experimental features

## Build-Time Configuration Challenges

### Problem: `config-host.h` Variations

Different build configurations produce different `config-host.h`:

```c
// Linux x86_64 build
#define CONFIG_LINUX 1
#define CONFIG_MODULES 1
#define CONFIG_HOST_DSOSUF ".so"

// macOS ARM64 build  
#define CONFIG_DARWIN 1
#define CONFIG_MODULES 1
#define CONFIG_HOST_DSOSUF ".dylib"

// Windows x86_64 build
#define CONFIG_WIN32 1
#define CONFIG_MODULES 1
#define CONFIG_HOST_DSOSUF ".dll"
```

### Solution: Multi-Config SDK

```
qemu-device-sdk/
└── config/
    ├── config-host-linux-x86_64.h
    ├── config-host-linux-aarch64.h
    ├── config-host-darwin-x86_64.h
    ├── config-host-darwin-aarch64.h
    ├── config-host-windows-x86_64.h
    └── config-host.h -> config-host-linux-x86_64.h  (symlink)
```

Or use feature detection:
```c
// config-host-detect.h
#if defined(__linux__)
#  include "config-host-linux.h"
#elif defined(__APPLE__)
#  include "config-host-darwin.h"
#elif defined(_WIN32)
#  include "config-host-windows.h"
#endif
```

## Verification & Testing

### SDK Validation Tool

```bash
#!/bin/bash
# qemu-device-check - Validate device module

MODULE=$1

echo "Checking QEMU device module: $MODULE"

# Check ELF/shared library
file "$MODULE" | grep -q "shared object" || { echo "Not a shared library"; exit 1; }

# Check required symbols
nm "$MODULE" | grep -q "qemu_module_dummy" || { echo "Missing qemu_module_dummy"; exit 1; }
nm "$MODULE" | grep -q "type_init" || { echo "No type_init found"; exit 1; }

# Check DSO stamp (if available)
nm "$MODULE" | grep -q "qemu_stamp" && echo "✓ DSO stamp found"

# Check dependencies
ldd "$MODULE" 2>/dev/null | grep -q "libglib" || echo "⚠ GLib not linked"

echo "✓ Module validation passed"
```

### Example Skeleton Generator

```bash
#!/bin/bash
# qemu-device-init - Generate device skeleton

DEVICE_NAME=$1
DEVICE_TYPE=${2:-sysbus}  # sysbus, pci, isa

cat > "${DEVICE_NAME}.c" << EOF
#define BUILD_DSO
#include "qemu/osdep.h"
#include "qemu/module.h"
#include "hw/core/${DEVICE_TYPE}.h"
#include "qom/object.h"

#define TYPE_${DEVICE_NAME^^} "${DEVICE_NAME}"

typedef struct ${DEVICE_NAME^}State {
    $(get_parent_type $DEVICE_TYPE) parent_obj;
    MemoryRegion mmio;
} ${DEVICE_NAME^}State;

OBJECT_DECLARE_SIMPLE_TYPE(${DEVICE_NAME^}State, ${DEVICE_NAME^^})

// TODO: Implement device operations

static const TypeInfo ${DEVICE_NAME}_info = {
    .name = TYPE_${DEVICE_NAME^^},
    .parent = TYPE_$(get_type_constant $DEVICE_TYPE),
    .instance_size = sizeof(${DEVICE_NAME^}State),
    .class_init = ${DEVICE_NAME}_class_init,
};

static void register_types(void) {
    type_register_static(&${DEVICE_NAME}_info);
}

type_init(register_types)
module_obj(TYPE_${DEVICE_NAME^^});
EOF

echo "Created ${DEVICE_NAME}.c"
```

## SDK Distribution

### Package Formats

#### Linux: DEB Package
```
Package: qemu-device-sdk
Version: 9.2.0
Architecture: amd64
Depends: libglib2.0-dev (>= 2.56)
Description: QEMU Device Module Development SDK
 Headers and tools for building QEMU device modules
```

Install: `apt install qemu-device-sdk`

#### Linux: RPM Package
```spec
Name: qemu-device-sdk
Version: 9.2.0
Release: 1
BuildArch: x86_64
Requires: glib2-devel >= 2.56
Summary: QEMU Device Module SDK
```

Install: `dnf install qemu-device-sdk`

#### macOS: Homebrew
```ruby
class QemuDeviceSdk < Formula
  desc "SDK for building QEMU device modules"
  homepage "https://www.qemu.org"
  url "https://example.com/qemu-device-sdk-9.2.0.tar.gz"
  
  depends_on "glib"
  
  def install
    prefix.install "include"
    prefix.install "config"
    bin.install Dir["bin/*"]
  end
end
```

Install: `brew install qemu-device-sdk`

#### Windows: Installer / vcpkg
```json
{
  "name": "qemu-device-sdk",
  "version": "9.2.0",
  "description": "QEMU Device Module SDK",
  "dependencies": ["glib"]
}
```

### SDK Versioning

**Semantic versioning tied to QEMU**:
- SDK 9.2.0 → QEMU 9.2.x compatible
- SDK 9.3.0 → QEMU 9.3.x compatible (may break ABI)
- SDK 9.2.1 → Bug fixes, same ABI

## Minimal SDK Checklist

✅ **Must Have**:
- [ ] All headers from `qemu/include/` (~1346 files)
- [ ] `config-host.h` (generated, platform-specific)
- [ ] `qapi/qapi-builtin-types.h` (generated)
- [ ] `qemu-version.h` (generated)
- [ ] pkg-config file
- [ ] Example device source
- [ ] Build instructions

⚠️ **Should Have**:
- [ ] Target-specific configs (for target-aware devices)
- [ ] CMake support files
- [ ] Skeleton generator tool
- [ ] Module validator tool
- [ ] Multiple platform configs

🎯 **Nice to Have**:
- [ ] Pre-built template projects
- [ ] CI/CD integration examples
- [ ] Debugging helpers
- [ ] Unit test framework

## Example: Complete SDK Package

### Tarball Contents
```
qemu-device-sdk-9.2.0.tar.gz
├── README.md                 (How to use SDK)
├── LICENSE
├── include/                  (1346 headers)
├── config/
│   ├── config-host.h
│   ├── qemu-version.h
│   └── qapi/
├── lib/
│   └── pkgconfig/
│       └── qemu-device.pc
├── bin/
│   ├── qemu-device-init
│   └── qemu-device-check
├── examples/
│   ├── simple/
│   │   ├── simple.c
│   │   └── Makefile
│   ├── uart/
│   └── pci/
└── docs/
    └── device-api.md
```

### Installation
```bash
tar xzf qemu-device-sdk-9.2.0.tar.gz
cd qemu-device-sdk-9.2.0
./configure --prefix=/usr/local
make install
```

### Usage After Install
```bash
# Generate device skeleton
qemu-device-init mydevice sysbus

# Build
gcc $(pkg-config --cflags qemu-device) -shared mydevice.c -o hw-mydevice.so

# Validate
qemu-device-check hw-mydevice.so

# Use
export QEMU_MODULE_DIR=$(pwd)
qemu-system-x86_64 -device mydevice
```

## Recommendations for QEMU Project

### 1. Official SDK Package
- Create `make install-dev-sdk` target
- Package headers + generated config
- Provide versioned releases

### 2. Header Stability
- Mark stable vs unstable APIs
- Provide deprecation warnings
- Document ABI guarantees

### 3. Build System Integration
- Export `qemu-device.pc` pkg-config
- Provide CMake config files
- Document required flags

### 4. Developer Tools
- Include skeleton generator
- Include module validator
- Provide example projects

### 5. Documentation
- Device module guide
- API reference
- Migration guide for QEMU updates

## Critical Files Summary

**Without these, modules CANNOT be built**:

1. `config-host.h` (generated) - 100% required
2. `qapi/qapi-builtin-types.h` (generated) - 100% required  
3. All `qemu/include/` headers - 100% required
4. `qemu-version.h` (generated) - Strongly recommended
5. `config-target.h` (generated) - Required if target-specific

**Size estimate**:
- Headers: ~5-10 MB (1346 files)
- Generated config: ~50 KB
- Total SDK: ~10-15 MB compressed

## Conclusion

For binary-only QEMU distribution to support device modules:

1. **Must export**: All public headers (~1346 files) + build configs
2. **Must generate**: Platform-specific config-host.h
3. **Should provide**: SDK package with tools and examples
4. **Should document**: Stable API contract and versioning

This is **feasible** and follows standard practice for library SDKs (e.g., GTK, Qt, kernel headers).
