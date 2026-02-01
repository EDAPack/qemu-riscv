# SDK Packaging Tools

Tools for creating QEMU Device SDK packages from installed QEMU files.

## Scripts

### create-sdk.sh

Package installed SDK into various formats (tarball, deb, rpm, pkg).

**Usage:**
```bash
./create-sdk.sh --qemu-install /usr/local --output qemu-device-sdk.tar.gz

./create-sdk.sh --qemu-install /tmp/install/usr/local \
                --format deb \
                --output qemu-device-sdk_10.0.0_amd64.deb

./create-sdk.sh --qemu-install /usr/local \
                --format rpm \
                --output qemu-device-sdk.rpm
```

**Options:**
- `--qemu-install PATH` - Path to QEMU installation (required)
- `--output FILE` - Output package file (required)
- `--format FORMAT` - Package format: tarball, deb, rpm, pkg (default: tarball)
- `--version VERSION` - SDK version (auto-detected if not specified)
- `--arch ARCH` - Architecture (default: auto-detect)

**Prerequisites:**
- SDK must be installed first (`make install-dev-sdk`)
- For deb: `dpkg-deb` command
- For rpm: `rpmbuild` command

### verify-sdk.sh

Validate SDK installation completeness and correctness.

**Usage:**
```bash
./verify-sdk.sh /usr/local
./verify-sdk.sh --installed  # Check system installation
```

**Checks:**
- SDK directory structure
- Required headers present
- Generated config files
- pkg-config integration
- File permissions
- Basic header syntax

## Templates

### debian/

Debian package templates for creating `.deb` packages.

Files:
- `control` - Package metadata
- `rules` - Build rules
- `copyright` - License information
- `changelog` - Package changelog

**Usage with create-sdk.sh:**
```bash
./create-sdk.sh --qemu-install /usr/local \
                --format deb \
                --output qemu-device-sdk_10.0.0_amd64.deb
```

### rpm/

RPM spec file for creating `.rpm` packages.

Files:
- `qemu-device-sdk.spec` - RPM specification

**Usage with create-sdk.sh:**
```bash
./create-sdk.sh --qemu-install /usr/local \
                --format rpm \
                --output qemu-device-sdk.rpm
```

### homebrew/

Homebrew formula for macOS packaging.

Files:
- `qemu-device-sdk.rb` - Homebrew formula

**Manual usage:**
```bash
# Create tarball first
./create-sdk.sh --qemu-install /usr/local \
                --output qemu-device-sdk-10.0.0.tar.gz

# Calculate SHA256
shasum -a 256 qemu-device-sdk-10.0.0.tar.gz

# Update formula with SHA256 and URL
# Then install:
brew install --formula ./homebrew/qemu-device-sdk.rb
```

## Workflow

### For Binary Packagers

Complete workflow from QEMU build to SDK package:

```bash
# 1. Apply patches to QEMU
cd qemu
git am ../qemu-model-loader/patches/v9.2/*.patch

# 2. Configure and build QEMU
./configure --enable-modules --prefix=/usr/local
make -j$(nproc)

# 3. Install QEMU and SDK
make install DESTDIR=$PWD/install
make install-dev-sdk DESTDIR=$PWD/install

# 4. Create SDK package
cd ../qemu-model-loader/sdk-package
./create-sdk.sh --qemu-install ../qemu/install/usr/local \
                --output qemu-device-sdk-10.0.0.tar.gz

# 5. Verify package
tar tzf qemu-device-sdk-10.0.0.tar.gz | head -20

# 6. Test installation
mkdir test-install
tar xzf qemu-device-sdk-10.0.0.tar.gz -C test-install
./verify-sdk.sh test-install/usr
```

### For Linux Distributions

#### Debian/Ubuntu

```bash
# Build with DESTDIR
make install DESTDIR=$PWD/debian/qemu-device-sdk
make install-dev-sdk DESTDIR=$PWD/debian/qemu-device-sdk

# Create package
./create-sdk.sh --qemu-install $PWD/debian/qemu-device-sdk/usr/local \
                --format deb \
                --output qemu-device-sdk_10.0.0_amd64.deb

# Install
sudo dpkg -i qemu-device-sdk_10.0.0_amd64.deb
sudo apt-get install -f  # Fix dependencies
```

#### Fedora/RHEL

```bash
# Build with DESTDIR
make install DESTDIR=$PWD/buildroot
make install-dev-sdk DESTDIR=$PWD/buildroot

# Create package
./create-sdk.sh --qemu-install $PWD/buildroot/usr/local \
                --format rpm \
                --output qemu-device-sdk-10.0.0.rpm

# Install
sudo rpm -i qemu-device-sdk-10.0.0.rpm
# or
sudo dnf install qemu-device-sdk-10.0.0.rpm
```

### For CI/CD

#### GitHub Actions

```yaml
- name: Build QEMU with SDK
  run: |
    cd qemu
    ./configure --enable-modules
    make -j$(nproc)
    make install DESTDIR=install
    make install-dev-sdk DESTDIR=install

- name: Package SDK
  run: |
    cd qemu-model-loader/sdk-package
    ./create-sdk.sh \
      --qemu-install ../../qemu/install/usr/local \
      --output ../../qemu-device-sdk.tar.gz

- name: Upload SDK
  uses: actions/upload-artifact@v3
  with:
    name: qemu-device-sdk
    path: qemu-device-sdk.tar.gz
```

#### GitLab CI

```yaml
package-sdk:
  script:
    - cd qemu
    - ./configure --enable-modules
    - make -j$(nproc)
    - make install DESTDIR=install
    - make install-dev-sdk DESTDIR=install
    - cd ../qemu-model-loader/sdk-package
    - ./create-sdk.sh --qemu-install ../../qemu/install/usr/local
                      --output ../../qemu-device-sdk.tar.gz
  artifacts:
    paths:
      - qemu-device-sdk.tar.gz
```

## Testing SDK Packages

### Verify Package Contents

**Tarball:**
```bash
tar tzf qemu-device-sdk.tar.gz
```

**Debian:**
```bash
dpkg -c qemu-device-sdk.deb
dpkg -I qemu-device-sdk.deb  # Show package info
```

**RPM:**
```bash
rpm -qlp qemu-device-sdk.rpm
rpm -qip qemu-device-sdk.rpm  # Show package info
```

### Install and Test

```bash
# Install package (method depends on format)
sudo dpkg -i qemu-device-sdk.deb  # Debian
sudo rpm -i qemu-device-sdk.rpm   # RPM
tar xzf qemu-device-sdk.tar.gz -C / # Tarball

# Verify installation
./verify-sdk.sh --installed

# Test pkg-config
pkg-config --exists qemu-device
pkg-config --cflags qemu-device
pkg-config --modversion qemu-device

# Build test module (see examples/ directory)
cd ../examples/minimal-sysbus
make
```

## Troubleshooting

### Package Creation Fails

**Problem:** `create-sdk.sh` fails with "SDK not found"

**Solution:**
- Ensure `make install-dev-sdk` was run
- Check that `--qemu-install` path is correct
- Verify `$PATH/include/qemu-device` exists

### Package Size Too Large

**Problem:** Package is larger than expected

**Solution:**
- This is normal - SDK includes ~1300 headers
- Typical size: 10-15 MB uncompressed, 3-5 MB compressed
- Use compression: `tar czf` for tarballs

### pkg-config Not Working

**Problem:** `pkg-config --cflags qemu-device` fails

**Solution:**
- Ensure package installed to standard location
- Check PKG_CONFIG_PATH: `export PKG_CONFIG_PATH=/usr/local/lib/pkgconfig`
- Verify .pc file exists: `ls /usr/lib/pkgconfig/qemu-device.pc`

### Missing Headers

**Problem:** Some headers are missing from package

**Solution:**
- Check QEMU build was complete
- Verify patches applied correctly
- Re-run `make install-dev-sdk`
- Use `./verify-sdk.sh` to identify missing files

## Support

- **Issues**: https://github.com/fvutils/qemu-model-loader/issues
- **Examples**: See `../examples/` directory
- **Documentation**: See `../docs/PACKAGER-GUIDE.md`
