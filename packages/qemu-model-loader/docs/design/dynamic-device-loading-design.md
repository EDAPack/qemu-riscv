# QEMU Dynamic Device Model Loading - Design Document

## Executive Summary

This document outlines a design approach to enable QEMU device models to be built as shared libraries and dynamically loaded at runtime via command-line options. This capability would allow developers to add custom devices without recompiling QEMU itself.

## Current QEMU Device Architecture

### QEMU Object Model (QOM)

QEMU uses the QEMU Object Model (QOM) as its foundation for all device implementations. Key characteristics:

1. **Type Registration System**: All devices are registered using `TypeInfo` structures
2. **Dynamic Type System**: Types are registered at initialization via `type_init()` macro
3. **Inheritance**: Single inheritance from base classes (typically `TYPE_DEVICE`)
4. **Properties**: Devices expose configurable properties
5. **Lifecycle Management**: Devices have distinct phases: instantiation → realization → operation → unrealization

### Device Registration Flow

```c
// Typical device registration (from hw/misc/edu.c):

static const TypeInfo edu_types[] = {
    {
        .name          = TYPE_PCI_EDU_DEVICE,
        .parent        = TYPE_PCI_DEVICE,
        .instance_size = sizeof(EduState),
        .instance_init = edu_instance_init,
        .class_init    = edu_class_init,
        .interfaces    = (const InterfaceInfo[]) {
            { INTERFACE_CONVENTIONAL_PCI_DEVICE },
            { },
        },
    }
};

DEFINE_TYPES(edu_types)  // Expands to type_init() macro
```

The `type_init()` macro expands to:
```c
module_init(function, MODULE_INIT_QOM)
```

This uses GCC's `__attribute__((constructor))` to automatically register types before `main()`.

### Existing Module Support

QEMU **already has** a module loading infrastructure (in `util/module.c`):

1. **Module Loading**: Uses GLib's `g_module_open()` (dlopen wrapper)
2. **Search Paths**: 
   - `$QEMU_MODULE_DIR` environment variable
   - Configured module directory (CONFIG_QEMU_MODDIR)
   - `/var/run/qemu/${version}/`
3. **Module Metadata**: Scripts generate module dependency information
4. **Automatic Loading**: `module_load_qom()` can load modules for specific QOM types
5. **Version Checking**: Validates module ABI compatibility via stamps

**Key Insight**: QEMU can already load device modules dynamically when compiled with `BUILD_DSO` defined. The infrastructure exists but is primarily used for optional components (UI, audio, block drivers).

## Proposed Design: Dynamic Device Loading

### Architecture Overview

```
Command Line              Module Loader              QOM Type System
    |                         |                            |
    v                         v                            v
-device foo,... ──> Check if "foo" exists ──> No ──> module_load_qom("foo")
                           |                            |
                           | Yes                        v
                           v                      Search directories
                    Instantiate              Find foo.so / hw-foo.so
                         |                            |
                         v                            v
                    Device object              dlopen() + register
                                                      |
                                                      v
                                              type_init() callbacks
                                                      |
                                                      v
                                              QOM registration
                                                      |
                                              Back to instantiate
```

### Implementation Components

#### 1. Module Naming Convention

Establish a clear naming scheme for device modules:
```
Format: hw-<devicename>.so
Examples:
  - hw-myuart.so
  - hw-mycpu.so
  - hw-customnic.so
```

#### 2. Command-Line Interface

Add a new option to specify module directories:
```bash
qemu-system-x86_64 \
  -device-module-path /path/to/custom/devices \
  -device myuart,iobase=0x3f8,irq=4
```

Or use existing environment variable:
```bash
export QEMU_MODULE_DIR=/path/to/custom/devices
qemu-system-x86_64 -device myuart,iobase=0x3f8,irq=4
```

#### 3. Module API Requirements

Device modules must:

**a) Include required headers:**
```c
#include "qemu/osdep.h"
#include "qemu/module.h"
#include "hw/core/qdev.h"
#include "qom/object.h"
```

**b) Define type with proper naming:**
```c
#define TYPE_MY_DEVICE "mydevice"
```

**c) Implement device structure:**
```c
typedef struct MyDeviceState {
    DeviceState parent_obj;
    // Device-specific fields
    MemoryRegion mmio;
    uint32_t reg1, reg2;
} MyDeviceState;
```

**d) Provide TypeInfo and registration:**
```c
static const TypeInfo my_device_info = {
    .name          = TYPE_MY_DEVICE,
    .parent        = TYPE_SYS_BUS_DEVICE,  // or TYPE_PCI_DEVICE, etc.
    .instance_size = sizeof(MyDeviceState),
    .instance_init = my_device_init,
    .class_init    = my_device_class_init,
};

static void my_device_register_types(void)
{
    type_register_static(&my_device_info);
}

type_init(my_device_register_types)
```

**e) Export module metadata:**
```c
// Declare this is a QEMU module
#define BUILD_DSO
#include "qemu/module.h"

// Tell modinfo system about this type
module_obj(TYPE_MY_DEVICE);
```

#### 4. Build System for External Modules

Create a template Makefile/build system for device modules:

```makefile
# Makefile for external QEMU device module

QEMU_SRC = /path/to/qemu/source
QEMU_BUILD = /path/to/qemu/build

CC = gcc
CFLAGS = -Wall -O2 -fPIC -DBUILD_DSO \
         -I$(QEMU_SRC)/include \
         -I$(QEMU_BUILD) \
         $(shell pkg-config --cflags glib-2.0)

LDFLAGS = -shared
LIBS = $(shell pkg-config --libs glib-2.0)

MODULE_NAME = mydevice
MODULE_FILE = hw-$(MODULE_NAME).so

SOURCES = mydevice.c
OBJECTS = $(SOURCES:.c=.o)

all: $(MODULE_FILE)

$(MODULE_FILE): $(OBJECTS)
	$(CC) $(LDFLAGS) -o $@ $^ $(LIBS)

%.o: %.c
	$(CC) $(CFLAGS) -c -o $@ $<

clean:
	rm -f $(OBJECTS) $(MODULE_FILE)

install: $(MODULE_FILE)
	install -d $(DESTDIR)/usr/lib/qemu
	install -m 644 $(MODULE_FILE) $(DESTDIR)/usr/lib/qemu/

.PHONY: all clean install
```

#### 5. QEMU Core Modifications

**Minimal changes needed** since infrastructure exists:

**a) Enhanced module path handling** (`system/vl.c`):
```c
static void qemu_add_module_path(const char *path)
{
    // Add to module search path list
    // Already supported via QEMU_MODULE_DIR
}
```

**b) Hook into device creation** (`system/qdev-monitor.c`):

The existing code already calls `module_object_class_by_name()` which triggers module loading:

```c
static DeviceClass *qdev_get_device_class(const char **driver, Error **errp)
{
    ObjectClass *oc;
    
    // This already attempts to load module if type not found!
    oc = module_object_class_by_name(*driver);
    if (!oc) {
        // Try alias resolution...
    }
    // ... rest of validation
}
```

**c) Module discovery optimization** (`util/module.c`):

Optionally add wildcard loading to preload all hw-*.so modules:
```c
void module_load_device_all(const char *path)
{
    // Scan directory for hw-*.so files
    // Load each module to register types
}
```

#### 6. ABI Stability Considerations

**Critical for external modules:**

1. **Version Checking**: Use existing DSO_STAMP_FUN mechanism
2. **Header Stability**: Device API headers must remain stable
3. **Symbol Visibility**: Export only necessary QOM registration functions
4. **Deprecation Policy**: Warn before breaking device API changes

**Current stamp mechanism** (from `include/qemu/module.h`):
```c
#define DSO_STAMP_FUN glue(qemu_stamp, CONFIG_STAMP)

void DSO_STAMP_FUN(void);  // Module must implement this
void qemu_module_dummy(void);  // Identifies as QEMU module
```

### Implementation Phases

#### Phase 1: Infrastructure Validation ✓ (Already Exists)
- Module loading system exists
- Type registration system exists
- Command-line device creation exists

#### Phase 2: Documentation & Templates
1. Create device module developer guide
2. Provide sample device implementation
3. Create build system templates (Makefile, meson)
4. Document ABI guarantees

#### Phase 3: Tooling & Convenience
1. Add `-device-module-path` option (optional, can use env var)
2. Create device module skeleton generator script
3. Improve error messages for missing modules
4. Add `info device-modules` monitor command

#### Phase 4: Testing & Examples
1. Convert existing simple device to module (e.g., edu)
2. Create test suite for module loading
3. Document best practices
4. Create example devices of each bus type

## Example: Complete Custom Device Module

### File: `my_uart.c`

```c
#include "qemu/osdep.h"
#include "qemu/log.h"
#include "qemu/module.h"
#include "hw/sysbus.h"
#include "hw/irq.h"
#include "chardev/char-fe.h"
#include "qom/object.h"

#define TYPE_MY_UART "my-uart"
OBJECT_DECLARE_SIMPLE_TYPE(MyUartState, MY_UART)

#define MY_UART_REG_DATA    0x00
#define MY_UART_REG_STATUS  0x04
#define MY_UART_REG_CONTROL 0x08

struct MyUartState {
    SysBusDevice parent_obj;
    
    MemoryRegion mmio;
    CharBackend chr;
    qemu_irq irq;
    
    uint8_t data_reg;
    uint8_t status_reg;
    uint8_t control_reg;
};

static uint64_t my_uart_read(void *opaque, hwaddr addr, unsigned size)
{
    MyUartState *s = MY_UART(opaque);
    
    switch (addr) {
    case MY_UART_REG_DATA:
        return s->data_reg;
    case MY_UART_REG_STATUS:
        return s->status_reg;
    case MY_UART_REG_CONTROL:
        return s->control_reg;
    default:
        qemu_log_mask(LOG_GUEST_ERROR, 
                      "my-uart: bad read offset 0x%x\n", (int)addr);
        return 0;
    }
}

static void my_uart_write(void *opaque, hwaddr addr, 
                          uint64_t val, unsigned size)
{
    MyUartState *s = MY_UART(opaque);
    
    switch (addr) {
    case MY_UART_REG_DATA:
        s->data_reg = val;
        if (qemu_chr_fe_backend_connected(&s->chr)) {
            qemu_chr_fe_write_all(&s->chr, &s->data_reg, 1);
        }
        break;
    case MY_UART_REG_CONTROL:
        s->control_reg = val;
        break;
    default:
        qemu_log_mask(LOG_GUEST_ERROR,
                      "my-uart: bad write offset 0x%x\n", (int)addr);
    }
}

static const MemoryRegionOps my_uart_ops = {
    .read = my_uart_read,
    .write = my_uart_write,
    .endianness = DEVICE_NATIVE_ENDIAN,
    .valid = {
        .min_access_size = 1,
        .max_access_size = 4,
    },
};

static void my_uart_realize(DeviceState *dev, Error **errp)
{
    MyUartState *s = MY_UART(dev);
    
    qemu_chr_fe_set_handlers(&s->chr, NULL, NULL, NULL, NULL, s, NULL, true);
}

static void my_uart_init(Object *obj)
{
    MyUartState *s = MY_UART(obj);
    SysBusDevice *sbd = SYS_BUS_DEVICE(obj);
    
    memory_region_init_io(&s->mmio, obj, &my_uart_ops, s,
                          TYPE_MY_UART, 0x1000);
    sysbus_init_mmio(sbd, &s->mmio);
    sysbus_init_irq(sbd, &s->irq);
}

static Property my_uart_properties[] = {
    DEFINE_PROP_CHR("chardev", MyUartState, chr),
    DEFINE_PROP_END_OF_LIST(),
};

static void my_uart_class_init(ObjectClass *oc, const void *data)
{
    DeviceClass *dc = DEVICE_CLASS(oc);
    
    dc->realize = my_uart_realize;
    dc->desc = "My Custom UART";
    device_class_set_props(dc, my_uart_properties);
    set_bit(DEVICE_CATEGORY_INPUT, dc->categories);
}

static const TypeInfo my_uart_info = {
    .name          = TYPE_MY_UART,
    .parent        = TYPE_SYS_BUS_DEVICE,
    .instance_size = sizeof(MyUartState),
    .instance_init = my_uart_init,
    .class_init    = my_uart_class_init,
};

static void my_uart_register_types(void)
{
    type_register_static(&my_uart_info);
}

type_init(my_uart_register_types)
module_obj(TYPE_MY_UART);
```

### Building the Module

```bash
# Set paths
export QEMU_SRC=/path/to/qemu-source
export QEMU_BUILD=/path/to/qemu-build

# Compile
gcc -Wall -O2 -fPIC -DBUILD_DSO \
    -I$QEMU_SRC/include \
    -I$QEMU_BUILD \
    $(pkg-config --cflags glib-2.0) \
    -c my_uart.c -o my_uart.o

# Link as shared library
gcc -shared -o hw-my-uart.so my_uart.o $(pkg-config --libs glib-2.0)

# Install
mkdir -p ~/.local/lib/qemu
cp hw-my-uart.so ~/.local/lib/qemu/
```

### Using the Module

```bash
# Set module path
export QEMU_MODULE_DIR=$HOME/.local/lib/qemu

# Run QEMU with custom device
qemu-system-arm -M virt \
    -device my-uart,chardev=uart0 \
    -chardev stdio,id=uart0
```

## Technical Challenges & Solutions

### Challenge 1: ABI Stability
**Problem**: QEMU internals change frequently
**Solution**: 
- Define stable device API subset
- Version checking via DSO stamps
- Document API guarantees per QEMU release

### Challenge 2: Symbol Conflicts
**Problem**: Multiple modules might define same symbols
**Solution**:
- Use `G_MODULE_BIND_LOCAL` flag (already done)
- Namespace device type names
- Use `static` for internal functions

### Challenge 3: Module Dependencies
**Problem**: Device might depend on other modules
**Solution**:
- Use existing `module_dep()` metadata system
- Modinfo scripts track dependencies
- Automatic dependency loading (already implemented)

### Challenge 4: Hot-Loading vs. Cold-Loading
**Problem**: When to load modules?
**Solution**:
- **Cold-load**: At startup (safe, current approach)
- **Hot-load**: On-demand via monitor (future work)
- Start with cold-load only for safety

### Challenge 5: Debugging
**Problem**: Harder to debug external modules
**Solution**:
- Preserve symbols in .so files
- Add module load tracing (already exists)
- Provide debug build options
- Document GDB workflow

## Security Considerations

1. **Module Verification**: Consider code signing for production
2. **Path Restrictions**: Only load from trusted directories
3. **Privilege Separation**: Modules run in QEMU process context
4. **Input Validation**: Validate all guest-facing interfaces
5. **Resource Limits**: Prevent module resource exhaustion

## Benefits of This Approach

1. **No QEMU Recompilation**: Add devices without rebuilding
2. **Rapid Development**: Faster iteration on custom devices
3. **Proprietary Models**: Distribute without source code
4. **Version Independence**: Modules work across compatible QEMU versions
5. **Minimal Core Changes**: Leverage existing infrastructure
6. **Standard Workflow**: Uses normal QEMU device API

## Limitations

1. **ABI Coupling**: Modules tied to QEMU version range
2. **API Subset**: Can't use all QEMU internals safely
3. **No Hot-Reload**: Must restart QEMU to reload module
4. **Build Complexity**: Need QEMU headers and build artifacts
5. **Limited Distribution**: Binary compatibility requirements

## Recommendations

### For QEMU Project:

1. **Document Device API Stability**: Commit to stable API subset
2. **Provide SDK**: Package headers + tools for module developers
3. **Create Examples**: Sample modules for each bus type
4. **Version Policy**: Clear ABI compatibility guarantees
5. **Module Registry**: Optional repository for community modules

### For Module Developers:

1. **Keep It Simple**: Avoid complex QEMU internals
2. **Test Thoroughly**: Modules can crash QEMU
3. **Version Lock**: Build against specific QEMU version
4. **Document Requirements**: Specify QEMU version range
5. **Provide Source**: Even if distributing binaries

## Conclusion

QEMU already possesses the core infrastructure needed for dynamic device loading. The existing module system, QOM type registration, and device instantiation code can support external device modules with minimal modifications.

**Key takeaway**: This is primarily a **documentation and tooling problem**, not an architectural problem. The main work involves:

1. Documenting the device module API
2. Providing build templates and tools
3. Creating example modules
4. Establishing ABI stability guarantees

The technical foundation exists and works today. With proper documentation and examples, developers can already create loadable device modules using the existing QEMU infrastructure.

## Next Steps

1. **Prototype**: Create working example module using edu device
2. **Document API**: Write comprehensive device module guide
3. **Create Tools**: Build skeleton generator and build system
4. **Test Suite**: Validate module loading across scenarios
5. **Upstream Discussion**: Propose API stability guarantees to QEMU community

## References

- QEMU Source Code: https://gitlab.com/qemu-project/qemu
- QOM Documentation: `docs/devel/qom.rst`
- QDEV Documentation: `docs/devel/qdev-api.rst`
- Module System: `include/qemu/module.h`, `util/module.c`
- Example Device: `hw/misc/edu.c`
- Device Monitor: `system/qdev-monitor.c`

---

## ADDENDUM: Binary-Only QEMU Support (2026-02-01)

### New Constraint Analysis

When QEMU is distributed **binary-only** (without source code), device module developers need an SDK package containing all necessary headers and build-time configuration.

### Critical Requirements

#### 1. SDK Package Contents

**Minimum Required** (~10-15 MB):
```
qemu-device-sdk-X.Y.Z/
├── include/                    ← All 1346 public headers
├── config/
│   ├── config-host.h          ← Generated: MUST be included
│   ├── qemu-version.h         ← Generated: MUST be included
│   └── qapi/
│       └── qapi-builtin-types.h ← Generated: MUST be included
├── lib/pkgconfig/
│   └── qemu-device.pc         ← Build system integration
└── bin/
    ├── qemu-device-init       ← Skeleton generator
    └── qemu-device-check      ← Module validator
```

#### 2. Essential Generated Files

These are created during QEMU build and **cannot be source-distributed**:

1. **`config-host.h`** - Platform configuration (Linux/macOS/Windows)
   - Contains: CONFIG_LINUX, CONFIG_MODULES, CONFIG_HOST_DSOSUF
   - Used by: qemu/osdep.h (required by everything)
   - Status: **CRITICAL** - Nothing compiles without it

2. **`qapi/qapi-builtin-types.h`** - Generated QAPI types
   - Contains: QOM type definitions
   - Used by: qom/object.h
   - Status: **CRITICAL**

3. **`qemu-version.h`** - Version information
   - Contains: QEMU_VERSION, build info
   - Used by: Version checking, DSO stamp
   - Status: **STRONGLY RECOMMENDED**

4. **`config-target-*.h`** - Per-target configuration (optional)
   - Contains: TARGET_X86_64, endianness, etc.
   - Used by: Target-specific devices only
   - Status: **REQUIRED for target-specific modules**

#### 3. Distribution Options

**Option A: Per-Platform SDK** (Recommended)
```bash
# Different SDK per platform/version
qemu-device-sdk-9.2.0-linux-x86_64.tar.gz
qemu-device-sdk-9.2.0-darwin-arm64.tar.gz
qemu-device-sdk-9.2.0-windows-x86_64.zip

# Each contains appropriate config-host.h
```

**Option B: Multi-Config SDK**
```
qemu-device-sdk/config/
├── config-host-linux-x86_64.h
├── config-host-darwin-arm64.h
├── config-host-windows-x86_64.h
└── config-host.h -> (auto-detect or symlink)
```

**Option C: Runtime Feature Detection**
```c
// config-host-detect.h
#if defined(__linux__)
#  include "config/linux/config-host.h"
#elif defined(__APPLE__)
#  include "config/darwin/config-host.h"
#endif
```

### Updated Build Workflow

#### For SDK Maintainers (QEMU Distributors):

```bash
# Build QEMU
./configure --enable-modules --prefix=/usr/local
make

# Create SDK package
make install-dev-sdk DESTDIR=/tmp/sdk-staging

# Package includes:
# - All headers from qemu/include/
# - Generated config-host.h
# - Generated qapi headers
# - pkg-config file
# - Example projects
```

#### For Module Developers:

```bash
# Install SDK (binary package)
apt install qemu-device-sdk           # Debian/Ubuntu
dnf install qemu-device-sdk           # Fedora/RHEL
brew install qemu-device-sdk          # macOS

# Build module
gcc $(pkg-config --cflags qemu-device) \
    -shared mydevice.c -o hw-mydevice.so

# Use module
export QEMU_MODULE_DIR=$(pwd)
qemu-system-x86_64 -device mydevice
```

### pkg-config Integration

**File: `/usr/lib/pkgconfig/qemu-device.pc`**
```ini
prefix=/usr
includedir=${prefix}/include/qemu-device
configdir=${prefix}/include/qemu-device/config

Name: QEMU Device SDK
Description: SDK for building QEMU device modules
Version: 9.2.0
Requires: glib-2.0 >= 2.56

Cflags: -I${includedir} -I${configdir} -DBUILD_DSO
```

**Usage**:
```bash
# Get all required flags
CFLAGS="$(pkg-config --cflags qemu-device) $(pkg-config --cflags glib-2.0)"

# Compile
gcc $CFLAGS -fPIC -shared device.c -o hw-device.so
```

### Example SDK Package Structure

```
/usr/
├── include/qemu-device/
│   ├── qemu/                    ← All QEMU utility headers
│   ├── qom/                     ← QOM headers
│   ├── hw/                      ← Hardware device headers
│   ├── exec/                    ← Execution/memory headers
│   ├── chardev/                 ← Character device headers
│   └── config/                  ← Generated configs
│       ├── config-host.h        ← Platform config
│       ├── qemu-version.h       ← Version info
│       └── qapi/                ← Generated QAPI
├── lib/pkgconfig/
│   └── qemu-device.pc           ← Build system integration
├── bin/
│   ├── qemu-device-init         ← Skeleton generator
│   └── qemu-device-check        ← Module validator
└── share/qemu-device/
    ├── examples/                ← Example devices
    └── doc/                     ← API documentation
```

### Comparison: Source vs Binary Distribution

| Aspect | With Source | Binary Only + SDK |
|--------|-------------|-------------------|
| Headers | Use from source tree | Install SDK package |
| config-host.h | From build dir | Packaged in SDK |
| qapi headers | Generated during build | Pre-generated in SDK |
| Size | ~500MB source | ~10-15MB SDK |
| Updates | Rebuild QEMU | Update SDK package |
| Build complexity | High | Low (standard -I flags) |

### Recommendations for Binary Distribution

#### For QEMU Packagers (Linux distros, Homebrew, etc.):

1. **Create separate SDK package**:
   - `qemu-device-sdk` or `qemu-device-devel`
   - Contains headers + generated configs
   - Installs to `/usr/include/qemu-device/`

2. **Include pkg-config file**:
   - Simplifies module builds
   - Standard practice for libraries

3. **Provide examples**:
   - Working device implementations
   - Makefiles/build scripts
   - Testing procedures

4. **Version SDK with QEMU**:
   - SDK 9.2.x compatible with QEMU 9.2.x
   - Document ABI compatibility

#### For Module Developers:

1. **Install SDK package first**:
   ```bash
   apt install qemu-device-sdk    # Gets all headers + configs
   ```

2. **Use pkg-config**:
   ```bash
   gcc $(pkg-config --cflags qemu-device) -shared module.c -o hw-module.so
   ```

3. **Check SDK version matches QEMU**:
   ```bash
   pkg-config --modversion qemu-device
   qemu-system-x86_64 --version
   ```

### Updated Implementation Phases

**Phase 1: SDK Infrastructure** (New)
1. Add `make install-dev-sdk` target to QEMU build
2. Create pkg-config file generation
3. Package headers + generated configs
4. Create SDK validation tools

**Phase 2: Distribution** (New)
1. Create SDK packages (deb, rpm, brew, etc.)
2. Document installation procedures
3. Provide binary SDK downloads
4. Set up SDK versioning

**Phase 3: Documentation & Examples** (Enhanced)
1. Write SDK user guide
2. Provide example devices
3. Create build templates
4. Document troubleshooting

**Phase 4: Community & Support**
1. SDK release with each QEMU version
2. Maintain ABI compatibility
3. Support module developers
4. Gather feedback and iterate

### Conclusion: Binary-Only is Feasible

**Binary-only QEMU distribution CAN support device modules**, but requires:

1. ✅ **SDK package** containing:
   - All public headers (~1346 files, ~5-10MB)
   - Generated config-host.h (platform-specific)
   - Generated QAPI headers
   - Build system integration (pkg-config)

2. ✅ **Standard installation**:
   - System package (apt/dnf/brew)
   - Versioned with QEMU
   - Works like any other dev library

3. ✅ **Developer workflow**:
   - Install SDK package
   - Build with standard tools
   - Use with binary QEMU

**This is standard practice** - same model as:
- GTK development (libgtk-3-dev)
- Qt development (qtbase5-dev)
- Kernel modules (linux-headers)

**Action Items**:
1. Add SDK packaging to QEMU build system
2. Create SDK packages for major platforms
3. Document SDK usage and API stability
4. Maintain SDK versions in sync with QEMU

See [SDK-REQUIREMENTS.md](SDK-REQUIREMENTS.md) for complete details.
