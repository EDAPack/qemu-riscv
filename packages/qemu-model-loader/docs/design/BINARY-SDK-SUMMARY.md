# Binary-Only QEMU: Device Module SDK Summary

## Question
**Can device modules be built when only binary QEMU is available (no source)?**

## Answer
**YES** - with an SDK package containing headers and generated configuration.

## What's Required

### The SDK Package (~10-15 MB)

```
qemu-device-sdk/
├── include/              ← 1346 public header files
│   ├── qemu/            ← Core utilities
│   ├── qom/             ← Object model
│   ├── hw/              ← Hardware APIs
│   ├── exec/            ← Memory/execution
│   └── ...
├── config/              ← Generated files (CRITICAL!)
│   ├── config-host.h    ← Platform config
│   ├── qemu-version.h   ← Version info
│   └── qapi/            ← Generated types
│       └── qapi-builtin-types.h
└── lib/pkgconfig/
    └── qemu-device.pc   ← Build integration
```

### Critical Generated Files

These **cannot** come from source - they're created during QEMU build:

1. **`config-host.h`** - Platform configuration
   ```c
   #define CONFIG_LINUX 1
   #define CONFIG_MODULES 1
   #define CONFIG_HOST_DSOSUF ".so"
   // ... hundreds of CONFIG_* defines
   ```
   - **Why critical**: Required by `qemu/osdep.h` (first include in every file)
   - **Platform-specific**: Different for Linux/macOS/Windows
   - **Cannot compile without it**

2. **`qapi/qapi-builtin-types.h`** - Generated QOM types
   - **Why critical**: Required by `qom/object.h`
   - **Auto-generated**: From QAPI schema files
   - **Cannot compile without it**

3. **`qemu-version.h`** - Version information
   ```c
   #define QEMU_VERSION "9.2.0"
   #define QEMU_PKGVERSION "(Debian 9.2.0-1)"
   ```
   - **Why important**: ABI compatibility checking
   - **Strongly recommended**

## Distribution Models

### Model 1: Platform-Specific SDK (Recommended)

```bash
# Separate SDK per platform
qemu-device-sdk-9.2.0-linux-x86_64.deb
qemu-device-sdk-9.2.0-darwin-arm64.pkg
qemu-device-sdk-9.2.0-windows-x86_64.zip
```

**Pros**: Simple, platform-appropriate configs
**Cons**: Multiple packages to maintain

### Model 2: Universal SDK with Multi-Config

```
qemu-device-sdk/
└── config/
    ├── linux-x86_64/config-host.h
    ├── darwin-arm64/config-host.h
    ├── windows-x86_64/config-host.h
    └── config-host.h → (auto-selected)
```

**Pros**: Single package for all platforms
**Cons**: Larger download, complex selection logic

## Installation & Usage

### As System Package (Recommended)

```bash
# Debian/Ubuntu
sudo apt install qemu-device-sdk

# Fedora/RHEL
sudo dnf install qemu-device-sdk

# macOS
brew install qemu-device-sdk

# Windows
vcpkg install qemu-device-sdk
```

### Building a Module

```bash
# Old way (with source)
gcc -I./qemu/include -I./qemu/build -DBUILD_DSO ...

# New way (with SDK)
gcc $(pkg-config --cflags qemu-device) -shared device.c -o hw-device.so
```

**That's it!** The pkg-config file handles all include paths and flags.

## SDK Package Contents

### Headers (1346 files, ~5-10 MB)
- All public APIs from `qemu/include/`
- Device model APIs (QOM, QDEV)
- Bus-specific headers (PCI, ISA, USB, etc.)
- Utility functions (logging, timers, DMA, etc.)

### Generated Configs (~50 KB)
- `config-host.h` - Platform configuration
- `qemu-version.h` - Version string
- `qapi/*.h` - Generated type definitions

### Build Tools
- `qemu-device.pc` - pkg-config integration
- `qemu-device-init` - Skeleton generator
- `qemu-device-check` - Module validator

### Documentation & Examples
- API documentation
- Example device implementations
- Build instructions
- Troubleshooting guide

## pkg-config Integration

**File**: `/usr/lib/pkgconfig/qemu-device.pc`
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
# Get compiler flags
CFLAGS="$(pkg-config --cflags qemu-device)"

# Build module
gcc $CFLAGS -fPIC -shared mydevice.c -o hw-mydevice.so $(pkg-config --libs glib-2.0)
```

## Developer Workflow

### 1. Install SDK
```bash
apt install qemu-device-sdk qemu-system-x86
```

### 2. Create Device
```bash
# Generate skeleton
qemu-device-init my-uart sysbus

# Edit my-uart.c
vim my-uart.c
```

### 3. Build Module
```bash
gcc $(pkg-config --cflags qemu-device) \
    -fPIC -shared my-uart.c \
    -o hw-my-uart.so \
    $(pkg-config --libs glib-2.0)
```

### 4. Validate Module
```bash
qemu-device-check hw-my-uart.so
```

### 5. Use with QEMU
```bash
export QEMU_MODULE_DIR=$(pwd)
qemu-system-arm -M virt -device my-uart
```

## Comparison: Source vs Binary Distribution

| Aspect | Source Available | Binary Only + SDK |
|--------|------------------|-------------------|
| **Install** | Clone 500MB repo | Install 10MB package |
| **Headers** | qemu/include/ | /usr/include/qemu-device/ |
| **Config** | Build directory | Pre-packaged in SDK |
| **Updates** | `git pull && make` | `apt update && apt upgrade` |
| **Build Time** | Hours (QEMU + module) | Seconds (module only) |
| **Disk Space** | ~2GB | ~50MB |
| **Complexity** | High | Standard library dev |

## Precedents (This is Standard Practice)

### GTK Development
```bash
apt install libgtk-3-dev    # Headers + pkg-config
gcc $(pkg-config --cflags gtk+-3.0) app.c
```

### Qt Development
```bash
apt install qtbase5-dev     # Headers + qmake
qmake project.pro && make
```

### Kernel Modules
```bash
apt install linux-headers-$(uname -r)
make -C /lib/modules/$(uname -r)/build M=$(pwd) modules
```

### QEMU Device Modules (Proposed)
```bash
apt install qemu-device-sdk
gcc $(pkg-config --cflags qemu-device) -shared device.c
```

**Same pattern, proven approach!**

## Implementation Checklist

### For QEMU Project

- [ ] Add `make install-dev-sdk` build target
- [ ] Generate `qemu-device.pc` pkg-config file
- [ ] Package headers + generated configs
- [ ] Create skeleton generator tool
- [ ] Write SDK documentation
- [ ] Define API stability policy

### For Distributors (distros, Homebrew, etc.)

- [ ] Create `-dev` or `-sdk` packages
- [ ] Install to standard paths (`/usr/include/qemu-device/`)
- [ ] Include pkg-config file
- [ ] Provide examples in `/usr/share/qemu-device/`
- [ ] Version SDK with QEMU releases

### For Module Developers

- [ ] Install SDK package
- [ ] Use pkg-config for builds
- [ ] Check SDK version matches QEMU
- [ ] Test module loading

## Key Benefits

✅ **No source required** - Just install SDK package
✅ **Standard workflow** - Same as other libraries
✅ **Small footprint** - 10-15 MB vs 500+ MB source
✅ **Quick builds** - Seconds instead of hours
✅ **Version management** - Standard package updates
✅ **Proven approach** - Used by GTK, Qt, kernel modules

## Potential Issues & Solutions

### Issue 1: Platform Variations
**Problem**: Different config-host.h per platform
**Solution**: Platform-specific SDK packages or multi-config SDK

### Issue 2: ABI Compatibility
**Problem**: Modules break across QEMU versions
**Solution**: Version SDK with QEMU, document stable API subset

### Issue 3: Target-Specific Configs
**Problem**: Some devices need target configs
**Solution**: Include config-target-*.h for common targets

### Issue 4: Build Complexity
**Problem**: Many include paths needed
**Solution**: pkg-config handles everything automatically

## Estimated Sizes

| Component | Size |
|-----------|------|
| Headers (1346 files) | ~5-10 MB |
| Generated configs | ~50 KB |
| Examples | ~1 MB |
| Documentation | ~500 KB |
| **Total SDK** | **~10-15 MB** |

Compressed: ~3-5 MB

## Next Steps

### Immediate (QEMU 9.x)
1. Prototype SDK packaging
2. Create example SDK for one platform
3. Test module building with SDK
4. Document process

### Short-term (QEMU 10.0)
1. Official SDK packages for Linux/macOS/Windows
2. Distribution packages (deb, rpm, brew)
3. API stability documentation
4. Developer guide

### Long-term
1. ABI versioning and compatibility
2. SDK auto-generation in CI/CD
3. Module registry/repository
4. Enhanced tooling

## Conclusion

**Binary-only QEMU CAN support device modules** with a properly packaged SDK.

**Requirements**:
- ~10-15 MB SDK package per platform
- Include all public headers + generated configs
- Standard pkg-config integration
- Version with QEMU releases

**Workflow**:
```bash
apt install qemu-device-sdk
gcc $(pkg-config --cflags qemu-device) -shared device.c -o hw-device.so
export QEMU_MODULE_DIR=$(pwd)
qemu-system-x86_64 -device device
```

**This is feasible, practical, and follows industry standards.**

---

See also:
- [SDK-REQUIREMENTS.md](SDK-REQUIREMENTS.md) - Complete technical details
- [dynamic-device-loading-design.md](dynamic-device-loading-design.md) - Full design
- [QUICK_REFERENCE.md](QUICK_REFERENCE.md) - Developer guide
