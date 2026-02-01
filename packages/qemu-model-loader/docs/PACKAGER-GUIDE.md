# QEMU Model Loader - Binary Packager Guide

Complete guide for integrating QEMU Model Loader patches into binary QEMU distributions.

**Target Audience**: Linux distribution maintainers, package managers, build system integrators

## Table of Contents

1. [Quick Start](#quick-start)
2. [Understanding the Patches](#understanding-the-patches)
3. [Integration Steps](#integration-steps)
4. [Packaging the SDK](#packaging-the-sdk)
5. [Distribution Examples](#distribution-examples)
6. [Testing](#testing)
7. [Maintenance](#maintenance)
8. [Troubleshooting](#troubleshooting)

---

## Quick Start

For impatient packagers who want to get started immediately:

```bash
# 1. Clone QEMU
git clone https://gitlab.com/qemu-project/qemu.git
cd qemu
git checkout v10.0.0  # or your target version

# 2. Apply patches
git am /path/to/qemu-model-loader/patches/v9.2/*.patch

# 3. Build with SDK support
./configure --enable-modules --prefix=/usr
make -j$(nproc)

# 4. Install QEMU and SDK
make install DESTDIR=$PWD/package
make install-dev-sdk DESTDIR=$PWD/package

# 5. Package
tar czf qemu-10.0.0.tar.gz -C package .
tar czf qemu-device-sdk-10.0.0.tar.gz -C package ./usr/include/qemu-device ./usr/lib/pkgconfig
```

Done! You now have QEMU with SDK support.

---

## Understanding the Patches

### What the Patches Add

The qemu-model-loader patches add **SDK installation support** to QEMU's build system. They do NOT modify QEMU's runtime behavior.

**Patch 0001**: `build-add-install-dev-sdk-target.patch`
- Adds `make install-dev-sdk` target
- Installs headers to `$(includedir)/qemu-device/`
- Installs generated configs (config-host.h, QAPI)
- ~70 lines added to meson.build

**Patch 0002**: `build-generate-pkgconfig-for-device-sdk.patch`
- Generates `qemu-device.pc` pkg-config file
- Simplifies module builds
- ~40 lines total

**Patch 0003**: `docs-add-device-module-guide.patch`
- Adds documentation in `docs/devel/device-modules.rst`
- ~350 lines of documentation
- Not strictly required for packaging

### Why These Patches Are Safe

1. **No runtime changes** - Only affects build system
2. **Optional** - `install-dev-sdk` is a separate target
3. **Non-intrusive** - Doesn't modify existing code
4. **Upstream-compatible** - Follows QEMU conventions
5. **Tested** - Validated by test suite

### What Gets Installed

After `make install-dev-sdk`:

```
/usr/
├── include/qemu-device/          # All SDK headers
│   ├── qemu/                     # Core (module.h, osdep.h, etc.)
│   ├── qom/                      # QOM (object.h)
│   ├── hw/                       # Device APIs (qdev.h, sysbus.h, pci, etc.)
│   ├── exec/                     # Memory (memory.h)
│   ├── sysemu/                   # System
│   ├── chardev/                  # Character devices
│   ├── qapi/                     # QAPI types
│   └── config/                   # Generated configs
│       ├── config-host.h
│       └── qapi/
└── lib/pkgconfig/
    └── qemu-device.pc            # pkg-config file
```

Size: ~10-15 MB uncompressed, ~3-5 MB compressed

---

## Integration Steps

### Step 1: Obtain Patches

```bash
git clone https://github.com/fvutils/qemu-model-loader.git
cd qemu-model-loader
ls patches/v9.2/
```

Or download specific version:
```bash
wget https://github.com/fvutils/qemu-model-loader/releases/download/v9.2.0/patches.tar.gz
tar xzf patches.tar.gz
```

### Step 2: Apply to QEMU Source

#### Method A: git am (Recommended)

```bash
cd /path/to/qemu-source
git am /path/to/qemu-model-loader/patches/v9.2/*.patch
```

#### Method B: patch command

```bash
cd /path/to/qemu-source
for p in /path/to/qemu-model-loader/patches/v9.2/*.patch; do
    patch -p1 < "$p"
done
```

#### Method C: In spec file (RPM)

```spec
Patch0001: 0001-build-add-install-dev-sdk-target.patch
Patch0002: 0002-build-generate-pkgconfig-for-device-sdk.patch
Patch0003: 0003-docs-add-device-module-guide.patch

%prep
%setup -q
%patch0001 -p1
%patch0002 -p1
%patch0003 -p1
```

### Step 3: Configure QEMU

```bash
./configure \
    --enable-modules \
    --prefix=/usr \
    --sysconfdir=/etc \
    --localstatedir=/var \
    # ... your other options
```

**Important**: `--enable-modules` is required for module support.

### Step 4: Build QEMU

```bash
make -j$(nproc)
```

No changes to the build process. Everything works as before.

### Step 5: Install QEMU

```bash
# Install QEMU binaries
make install DESTDIR=/path/to/package

# Install SDK (new step)
make install-dev-sdk DESTDIR=/path/to/package
```

Or with meson:
```bash
meson setup build -Dinstall_dev_sdk=true
meson compile -C build
meson install -C build --destdir /path/to/package
```

### Step 6: Validate Installation

```bash
# Check SDK installed
ls /path/to/package/usr/include/qemu-device/

# Should contain: qemu/, qom/, hw/, exec/, config/

# Verify pkg-config file
ls /path/to/package/usr/lib/pkgconfig/qemu-device.pc
```

Use the verification script:
```bash
cd qemu-model-loader
./sdk-package/verify-sdk.sh /path/to/package/usr
```

---

## Packaging the SDK

### Option 1: Single Package (Simple)

Include SDK in main QEMU package:

**Pros**:
- Simpler packaging
- One package to maintain

**Cons**:
- Larger package
- Users who don't develop get SDK

**Example (Debian)**:
```
Package: qemu
Architecture: amd64
Depends: ...
Description: QEMU full system emulation (with SDK)
 QEMU is a fast processor emulator.
 .
 This package includes the device development SDK.
```

### Option 2: Separate Package (Recommended)

Split into runtime and development packages:

**Pros**:
- Cleaner separation
- Users choose what to install
- Follows distribution conventions

**Cons**:
- More packages to maintain

**Example (Debian)**:
```
Package: qemu
Architecture: amd64
Description: QEMU full system emulation binaries

Package: qemu-device-sdk
Architecture: all
Depends: qemu (= ${binary:Version}), libglib2.0-dev
Description: QEMU device module development SDK
 SDK for building QEMU device modules as shared libraries.
```

**Example (RPM)**:
```spec
%package devel
Summary: QEMU device module development SDK
Requires: %{name}%{?_isa} = %{version}-%{release}
Requires: glib2-devel

%description devel
SDK for building QEMU device modules as shared libraries.

%files devel
%{_includedir}/qemu-device/
%{_libdir}/pkgconfig/qemu-device.pc
```

### Option 3: Separate Source Package

Create standalone SDK package:

**Use when**: Distribution policy requires it

```bash
# After building QEMU
cd qemu-model-loader/sdk-package
./create-sdk.sh --qemu-install /path/to/qemu/install \
                --format deb \
                --output qemu-device-sdk_10.0.0_all.deb
```

---

## Distribution Examples

### Debian/Ubuntu

#### debian/control

```
Source: qemu
Section: misc
Priority: optional
Maintainer: Your Name <you@example.com>
Build-Depends: debhelper-compat (= 13),
               meson (>= 1.5.0),
               libglib2.0-dev

Package: qemu-system
Architecture: any
Depends: ${shlibs:Depends}, ${misc:Depends}
Description: QEMU full system emulation

Package: qemu-device-sdk
Section: devel
Architecture: all
Depends: ${misc:Depends},
         libglib2.0-dev (>= 2.56)
Description: QEMU device module development SDK
 Headers and configuration for building QEMU device modules.
```

#### debian/rules

```makefile
#!/usr/bin/make -f

%:
	dh $@

override_dh_auto_configure:
	./configure --enable-modules --prefix=/usr

override_dh_auto_build:
	$(MAKE)

override_dh_auto_install:
	$(MAKE) install DESTDIR=$(CURDIR)/debian/qemu-system
	$(MAKE) install-dev-sdk DESTDIR=$(CURDIR)/debian/qemu-device-sdk
```

### Fedora/RHEL (RPM)

#### qemu.spec

```spec
Name:           qemu
Version:        10.0.0
Release:        1%{?dist}
Summary:        QEMU is a FAST! processor emulator

License:        GPLv2
URL:            https://www.qemu.org
Source0:        https://download.qemu.org/qemu-%{version}.tar.xz

# Model loader patches
Patch0001:      0001-build-add-install-dev-sdk-target.patch
Patch0002:      0002-build-generate-pkgconfig-for-device-sdk.patch
Patch0003:      0003-docs-add-device-module-guide.patch

BuildRequires:  meson >= 1.5.0
BuildRequires:  gcc
BuildRequires:  glib2-devel

%description
QEMU is a fast processor emulator.

%package device-sdk
Summary:        QEMU device module development SDK
BuildArch:      noarch
Requires:       %{name} = %{version}-%{release}
Requires:       glib2-devel >= 2.56

%description device-sdk
SDK for building QEMU device modules as shared libraries.

%prep
%setup -q
%patch0001 -p1
%patch0002 -p1
%patch0003 -p1

%build
%configure --enable-modules
%make_build

%install
%make_install
make install-dev-sdk DESTDIR=%{buildroot}

%files
%{_bindir}/qemu-*
%{_libdir}/qemu/

%files device-sdk
%{_includedir}/qemu-device/
%{_libdir}/pkgconfig/qemu-device.pc
%doc docs/devel/device-modules.rst

%changelog
* Sat Feb 01 2026 Your Name <you@example.com> - 10.0.0-1
- Added device module SDK support
```

### Arch Linux (PKGBUILD)

```bash
pkgbase=qemu
pkgname=('qemu' 'qemu-device-sdk')
pkgver=10.0.0
pkgrel=1
arch=('x86_64')
url="https://www.qemu.org"
license=('GPL2')
makedepends=('meson' 'ninja' 'glib2')

source=(
    "https://download.qemu.org/qemu-$pkgver.tar.xz"
    "0001-build-add-install-dev-sdk-target.patch"
    "0002-build-generate-pkgconfig-for-device-sdk.patch"
    "0003-docs-add-device-module-guide.patch"
)

prepare() {
    cd qemu-$pkgver
    patch -Np1 -i ../0001-build-add-install-dev-sdk-target.patch
    patch -Np1 -i ../0002-build-generate-pkgconfig-for-device-sdk.patch
    patch -Np1 -i ../0003-docs-add-device-module-guide.patch
}

build() {
    cd qemu-$pkgver
    ./configure --prefix=/usr --enable-modules
    make
}

package_qemu() {
    pkgdesc='A generic and open source processor emulator'
    depends=('glib2')
    
    cd qemu-$pkgver
    make DESTDIR="$pkgdir" install
}

package_qemu-device-sdk() {
    pkgdesc='QEMU device module development SDK'
    depends=('qemu' 'glib2')
    arch=('any')
    
    cd qemu-$pkgver
    make DESTDIR="$pkgdir" install-dev-sdk
}
```

### Homebrew (macOS)

```ruby
class Qemu < Formula
  desc "Generic machine emulator and virtualizer"
  homepage "https://www.qemu.org"
  url "https://download.qemu.org/qemu-10.0.0.tar.xz"
  sha256 "..."
  
  depends_on "meson" => :build
  depends_on "ninja" => :build
  depends_on "glib"
  
  # Apply model loader patches
  patch do
    url "https://raw.githubusercontent.com/fvutils/qemu-model-loader/main/patches/v9.2/0001-build-add-install-dev-sdk-target.patch"
    sha256 "..."
  end
  
  patch do
    url "https://raw.githubusercontent.com/fvutils/qemu-model-loader/main/patches/v9.2/0002-build-generate-pkgconfig-for-device-sdk.patch"
    sha256 "..."
  end
  
  def install
    system "./configure", "--prefix=#{prefix}", "--enable-modules"
    system "make"
    system "make", "install"
    system "make", "install-dev-sdk"
  end
  
  test do
    system "#{bin}/qemu-system-x86_64", "--version"
    assert_predicate include/"qemu-device/qemu/module.h", :exist?
  end
end
```

---

## Testing

### Basic Validation

```bash
# 1. Check patches applied
cd qemu-source
git log --oneline | head -5

# 2. Check SDK installed
ls /usr/include/qemu-device/

# 3. Check pkg-config
pkg-config --exists qemu-device && echo "OK"

# 4. Build test module
cd qemu-model-loader/examples/minimal-sysbus
make
```

### Automated Testing

Use the provided test suite:

```bash
cd qemu-model-loader/tests
./run-all.sh
```

This runs:
1. Patch application test
2. SDK build test
3. Module build test
4. Module load test

### Integration in CI/CD

See [PATCH-INTEGRATION.md](PATCH-INTEGRATION.md) for CI/CD examples.

---

## Maintenance

### Updating Patches

When a new QEMU version is released:

```bash
cd qemu-model-loader

# 1. Test patches against new version
./tests/test-patch-apply.sh v10.1.0

# 2. If patches fail, update them
./scripts/update-patches.sh v9.2 v10.1

# 3. Test again
./tests/run-all.sh v10.1.0
```

### Version Compatibility

See [VERSION-MATRIX.md](VERSION-MATRIX.md) for supported versions.

**General rule**: Patches for v9.2 work with v10.x with minimal changes.

### Reporting Issues

If patches don't apply or SDK doesn't work:

1. Check [troubleshooting](#troubleshooting) section
2. File issue: https://github.com/fvutils/qemu-model-loader/issues
3. Include:
   - QEMU version
   - Patch application output
   - Build errors (if any)
   - Platform/distribution

---

## Troubleshooting

### Patches Don't Apply

**Problem**: `git am` fails with conflicts

**Solutions**:
1. Try 3-way merge: `git am -3 patch.patch`
2. Use different QEMU version
3. Check for updated patches
4. Report issue with QEMU version

### Build Fails After Patches

**Problem**: Compilation errors

**Solutions**:
1. Check meson version: `meson --version` (need >= 1.5.0)
2. Clean build: `rm -rf build && ./configure ...`
3. Check patch applied correctly: `git log`

### SDK Not Installed

**Problem**: `make install-dev-sdk` does nothing

**Solutions**:
1. Check `--enable-modules` was used
2. Try meson: `meson configure build -Dinstall_dev_sdk=true`
3. Check patches applied: `grep install-dev-sdk meson.build`

### pkg-config Not Working

**Problem**: `pkg-config --cflags qemu-device` fails

**Solutions**:
1. Check file exists: `ls /usr/lib/pkgconfig/qemu-device.pc`
2. Update PKG_CONFIG_PATH: `export PKG_CONFIG_PATH=/usr/local/lib/pkgconfig`
3. Check file syntax: `cat /usr/lib/pkgconfig/qemu-device.pc`

### Modules Won't Load

**Problem**: QEMU can't find device modules

**Solutions**:
1. Check SDK version matches QEMU
2. Rebuild modules
3. Set QEMU_MODULE_DIR: `export QEMU_MODULE_DIR=/path/to/modules`

---

## Support

- **Issues**: https://github.com/fvutils/qemu-model-loader/issues
- **Documentation**: See `docs/` directory
- **Examples**: See `examples/` directory
- **Tests**: See `tests/` directory
- **QEMU Mailing List**: qemu-devel@nongnu.org

---

## Summary

As a binary packager:

1. **Apply 3 patches** to QEMU source
2. **Build normally** with `--enable-modules`
3. **Run `make install-dev-sdk`** to install SDK
4. **Package SDK** as separate `-dev` or `-devel` package
5. **Test** with provided test suite
6. **Ship both packages** to users

Users get:
- QEMU with module support (runtime package)
- SDK to build custom devices (development package)

That's it! The patches are designed to be minimally invasive and easy to integrate.
