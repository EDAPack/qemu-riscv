# qemu-model-loader - QEMU Dynamic Device Loading Patches

## Project Purpose

**Centralized maintenance of QEMU patches** that enable binary distributions (like [EDAPack/qemu-riscv](https://github.com/EDAPack/qemu-riscv)) to:

1. Support loading device models as shared libraries
2. Install device development SDK alongside QEMU binary
3. Allow third-party device development without QEMU source

This is a **patch maintenance repository**, not an end-user tool.

## Target Users

- **Binary packagers**: Projects like EDAPack/qemu-riscv, Linux distros, Homebrew
- **Build systems**: CI/CD pipelines building QEMU for distribution
- **Integration projects**: Commercial and open-source projects packaging QEMU

## What This Repository Provides

### 1. QEMU Patches (Primary Deliverable)

Patches to add SDK installation support to QEMU's build system:

```
patches/
├── v9.2/
│   ├── 0001-build-add-install-dev-sdk-target.patch
│   ├── 0002-build-generate-qemu-device-pc.patch
│   └── 0003-docs-add-device-module-guide.patch
├── v9.1/
│   └── (backports)
├── v10.0/
│   └── (forward ports)
└── master/
    └── (latest development)
```

### 2. SDK Packaging Scripts

Tools to create SDK packages from installed QEMU:

```
sdk-package/
├── create-sdk.sh              ← Main packaging script
├── templates/
│   ├── qemu-device.pc.in      ← pkg-config template
│   ├── CMakeLists.txt.in      ← CMake config template
│   └── debian/                ← Debian packaging
├── verify-sdk.sh              ← SDK validation
└── README.md                  ← Packaging guide
```

### 3. Documentation

Usage guides for binary packagers:

```
docs/
├── PACKAGER-GUIDE.md          ← For binary distributors
├── PATCH-INTEGRATION.md       ← How to apply patches
├── SDK-STRUCTURE.md           ← SDK layout specification
├── DEVICE-API.md              ← Stable API documentation
└── EXAMPLES.md                ← Example device modules
```

### 4. Example Devices

Reference implementations for testing:

```
examples/
├── minimal-sysbus/            ← Minimal SysBus device
├── uart-device/               ← Complete UART example
├── pci-device/                ← PCI device example
└── test-all.sh                ← Test suite
```

### 5. Validation Tests

Ensure patches work correctly:

```
tests/
├── test-patch-apply.sh        ← Test patch application
├── test-sdk-build.sh          ← Test SDK packaging
├── test-module-build.sh       ← Test module compilation
└── test-module-load.sh        ← Test dynamic loading
```

## Repository Structure

```
qemu-model-loader/
├── README.md                  ← This file
├── patches/                   ← QEMU patches by version
│   ├── v9.2/
│   ├── v9.1/
│   ├── v10.0/
│   └── master/
├── sdk-package/               ← SDK packaging tools
│   ├── create-sdk.sh
│   ├── templates/
│   └── verify-sdk.sh
├── docs/                      ← Documentation
│   ├── PACKAGER-GUIDE.md
│   ├── PATCH-INTEGRATION.md
│   ├── SDK-STRUCTURE.md
│   ├── DEVICE-API.md
│   └── design/                ← Design documents
│       ├── dynamic-device-loading-design.md
│       ├── SDK-REQUIREMENTS.md
│       └── ...
├── examples/                  ← Example device modules
│   ├── minimal-sysbus/
│   ├── uart-device/
│   └── pci-device/
├── tests/                     ← Validation and tests
│   ├── test-patch-apply.sh
│   ├── test-sdk-build.sh
│   └── test-module-load.sh
└── scripts/                   ← Maintenance utilities
    ├── update-patches.sh      ← Rebase patches
    └── release.sh             ← Create release

```

## Workflow for Binary Packagers

### 1. Apply Patches to QEMU

```bash
# Clone QEMU
git clone https://gitlab.com/qemu-project/qemu.git
cd qemu
git checkout v9.2.0

# Apply patches
git am /path/to/qemu-model-loader/patches/v9.2/*.patch

# Configure and build
./configure --enable-modules --prefix=/usr/local
make -j$(nproc)
```

### 2. Install with SDK

```bash
# Install QEMU binaries
make install

# Install SDK (new target added by patches)
make install-dev-sdk
```

This installs:
```
/usr/local/
├── bin/qemu-system-*              ← QEMU binaries
├── share/qemu/                    ← Data files
└── include/qemu-device/           ← SDK (NEW)
    ├── qemu/                      ← Headers
    ├── qom/
    ├── hw/
    ├── config/                    ← Generated configs
    │   ├── config-host.h
    │   ├── qemu-version.h
    │   └── qapi/
    └── lib/pkgconfig/
        └── qemu-device.pc
```

### 3. Package SDK

```bash
# Create SDK package
cd /path/to/qemu-model-loader
./sdk-package/create-sdk.sh \
    --qemu-install /usr/local \
    --output qemu-device-sdk-9.2.0.tar.gz

# Or create distro package
./sdk-package/create-sdk.sh \
    --qemu-install /usr/local \
    --format deb \
    --output qemu-device-sdk_9.2.0_amd64.deb
```

### 4. Test Everything

```bash
# Validate SDK
./sdk-package/verify-sdk.sh /usr/local

# Test example modules
cd examples
./test-all.sh
```

## For EDAPack/qemu-riscv Integration

### In Your Build Pipeline

```yaml
# .github/workflows/build.yml (example)
steps:
  - name: Checkout QEMU
    uses: actions/checkout@v3
    with:
      repository: qemu/qemu
      ref: v9.2.0
      
  - name: Apply device loading patches
    run: |
      git clone https://github.com/fvutils/qemu-model-loader
      cd qemu
      git am ../qemu-model-loader/patches/v9.2/*.patch
      
  - name: Build QEMU
    run: |
      ./configure --enable-modules --target-list=riscv32-softmmu,riscv64-softmmu
      make -j$(nproc)
      
  - name: Install with SDK
    run: |
      make install DESTDIR=$PWD/install
      make install-dev-sdk DESTDIR=$PWD/install
      
  - name: Create SDK package
    run: |
      cd qemu-model-loader
      ./sdk-package/create-sdk.sh \
        --qemu-install ../qemu/install/usr/local \
        --output qemu-riscv-sdk-9.2.0.tar.gz
        
  - name: Upload artifacts
    uses: actions/upload-artifact@v3
    with:
      name: qemu-riscv-with-sdk
      path: |
        qemu/install/
        qemu-model-loader/qemu-riscv-sdk-9.2.0.tar.gz
```

### In Your Release

Distribute two packages:
1. `qemu-riscv-9.2.0.tar.gz` - QEMU binaries (with module support)
2. `qemu-riscv-sdk-9.2.0.tar.gz` - Device development SDK

Users can then:
```bash
# Install QEMU
tar xzf qemu-riscv-9.2.0.tar.gz -C /usr/local

# Install SDK (optional, for developers)
tar xzf qemu-riscv-sdk-9.2.0.tar.gz -C /usr/local

# Build custom device
gcc $(pkg-config --cflags qemu-device) -shared mydevice.c -o hw-mydevice.so
```

## Patch Maintenance

### Version Support

- **Stable**: Patches for current QEMU stable (v9.2)
- **Previous**: Patches for previous stable (v9.1) - best effort
- **Development**: Patches for QEMU master branch
- **Future**: Pre-release patches for upcoming versions

### Update Process

When new QEMU version is released:

```bash
# 1. Create new version directory
cd patches
mkdir v9.3

# 2. Rebase patches
./scripts/update-patches.sh v9.2 v9.3

# 3. Test patches
./tests/test-patch-apply.sh v9.3

# 4. Validate SDK build
./tests/test-sdk-build.sh v9.3

# 5. Test example devices
./tests/test-module-build.sh v9.3
./tests/test-module-load.sh v9.3

# 6. Commit and tag release
git add patches/v9.3
git commit -m "Add patches for QEMU v9.3"
git tag v9.3.0
```

### Patch Submission Upstream

Goal: Get these patches into mainline QEMU

```bash
# Prepare for upstream submission
./scripts/prepare-upstream.sh v9.2

# Creates:
# - upstream/v1/0001-*.patch  (formatted for QEMU mailing list)
# - upstream/cover-letter.txt
# - upstream/submission-notes.txt
```

Submit to qemu-devel@nongnu.org following QEMU's contribution process.

## Patch Set Description

### Patch 0001: Add install-dev-sdk Target

Adds `make install-dev-sdk` target to QEMU build system.

**What it does**:
- Installs all public headers from `include/`
- Installs generated configs (`config-host.h`, `qapi/*.h`)
- Creates directory structure for SDK
- Preserves header dependencies

**Files modified**:
- `Makefile`
- `meson.build`
- `meson_options.txt`

### Patch 0002: Generate pkg-config File

Generates `qemu-device.pc` pkg-config file during build.

**What it does**:
- Template-based generation
- Includes correct paths and version
- Specifies required dependencies (glib-2.0)
- Installs to `$libdir/pkgconfig/`

**Files added**:
- `qemu-device.pc.in` (template)

**Files modified**:
- `meson.build`

### Patch 0003: Add SDK Documentation

Adds device module development documentation.

**What it does**:
- Documents stable device API
- Provides module building guide
- Includes example devices
- Specifies ABI compatibility policy

**Files added**:
- `docs/devel/device-modules.rst`
- `docs/devel/device-api-stability.rst`

### Patch 0004: Module Helper Tools (Optional)

Adds helper tools for module developers.

**What it does**:
- `qemu-device-init`: Skeleton generator
- `qemu-device-check`: Module validator

**Files added**:
- `scripts/device/qemu-device-init.sh`
- `scripts/device/qemu-device-check.sh`

**Files modified**:
- `Makefile` (install tools)

## SDK Contents After Patch Application

When patches are applied and `make install-dev-sdk` is run:

```
/usr/local/include/qemu-device/
├── qemu/                        ← Core headers (module.h, osdep.h, etc.)
├── qom/                         ← QOM system (object.h)
├── hw/                          ← Device APIs
│   ├── core/                    ← qdev.h, sysbus.h
│   ├── pci/                     ← PCI support
│   ├── isa/                     ← ISA support
│   └── ...
├── exec/                        ← Memory system
├── chardev/                     ← Character devices
├── sysemu/                      ← System emulation
├── qapi/                        ← QAPI types
└── config/                      ← Generated configs
    ├── config-host.h            ← Platform config
    ├── qemu-version.h           ← Version info
    └── qapi/
        └── qapi-builtin-types.h

/usr/local/lib/pkgconfig/
└── qemu-device.pc               ← pkg-config integration

/usr/local/share/qemu-device/
├── examples/                    ← Example devices
└── doc/                         ← Documentation
```

## Testing the Patches

### Automated Testing

```bash
# Test patch application
./tests/test-patch-apply.sh v9.2

# Test SDK build
./tests/test-sdk-build.sh v9.2

# Test module compilation
./tests/test-module-build.sh v9.2

# Test dynamic loading
./tests/test-module-load.sh v9.2

# Run all tests
./tests/run-all.sh v9.2
```

### Manual Testing

```bash
# 1. Apply patches
cd /tmp/qemu-test
git clone https://gitlab.com/qemu-project/qemu.git
cd qemu
git checkout v9.2.0
git am /path/to/patches/v9.2/*.patch

# 2. Build
./configure --enable-modules
make -j$(nproc)

# 3. Install SDK
make install-dev-sdk DESTDIR=/tmp/qemu-sdk

# 4. Build example device
cd /path/to/examples/minimal-sysbus
make SDK_PATH=/tmp/qemu-sdk/usr/local

# 5. Test loading
export QEMU_MODULE_DIR=$(pwd)
/tmp/qemu-test/qemu/build/qemu-system-x86_64 -device minimal-sysbus
```

## Release Process

### Creating a Release

```bash
# 1. Ensure patches are tested
./tests/run-all.sh v9.2

# 2. Update CHANGELOG
vi CHANGELOG.md

# 3. Tag release
git tag -a v9.2.0 -m "Release for QEMU v9.2.0"
git push --tags

# 4. Create GitHub release
./scripts/release.sh v9.2.0
```

### Release Artifacts

Each release includes:
1. Patch files (`.patch`)
2. SDK packaging scripts
3. Example devices
4. Documentation
5. Test suite

## Contributing

### For Patch Maintainers

1. Keep patches minimal - only add SDK installation support
2. Test against multiple QEMU versions
3. Follow QEMU coding standards
4. Document all changes
5. Prepare for upstream submission

### For Users (Binary Packagers)

1. Report issues with patch application
2. Test SDK on your platform
3. Share packaging scripts
4. Document integration process
5. Provide feedback on SDK structure

## Frequently Asked Questions

### Q: Do these patches modify QEMU functionality?
**A**: No. Patches only add SDK installation - no runtime changes.

### Q: Are these patches upstream compatible?
**A**: Yes. Designed for eventual upstream submission.

### Q: Do patches require QEMU source modification?
**A**: No. Patches are clean additions to build system.

### Q: What QEMU versions are supported?
**A**: Current stable (v9.2), previous stable (v9.1), and master.

### Q: Can I use these patches in commercial products?
**A**: Yes. Patches are GPLv2 like QEMU itself.

### Q: Will modules work across QEMU versions?
**A**: Modules are ABI-specific. Rebuild for each QEMU version.

### Q: How big is the SDK?
**A**: ~10-15 MB uncompressed, ~5 MB compressed.

## Status and Roadmap

### Current Status (v0.1.0)

- [x] Design and analysis complete
- [x] Documentation written
- [ ] Patches written and tested
- [ ] SDK packaging scripts
- [ ] Example devices
- [ ] Test suite
- [ ] Integration tested with EDAPack

### Roadmap

**v0.1.0** (Current) - Initial Release
- QEMU v9.2 patches
- Basic SDK packaging
- Minimal examples
- Documentation

**v0.2.0** - Enhanced
- QEMU v9.3 patches
- Improved SDK packaging
- More examples (UART, PCI)
- Automated testing

**v0.3.0** - Mature
- Multi-version support
- Distro packages (deb, rpm)
- Comprehensive examples
- CI/CD integration guides

**v1.0.0** - Production Ready
- Upstream submission
- Stable API documentation
- Commercial support
- Community ecosystem

## Support and Contact

- **Issues**: https://github.com/fvutils/qemu-model-loader/issues
- **Documentation**: See `docs/` directory
- **Examples**: See `examples/` directory

## License

- **Patches**: GPLv2 (matching QEMU)
- **Scripts**: MIT License
- **Documentation**: CC-BY-4.0

---

**Project Status**: Design Complete, Implementation Pending

**Target Users**: Binary packagers like EDAPack/qemu-riscv

**Goal**: Centralize QEMU dynamic device loading patch maintenance
