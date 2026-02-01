# Integration Examples

This directory contains integration guides and examples for incorporating the QEMU Device SDK patches into various binary distribution systems.

## Available Integrations

### [EDAPACK.md](./EDAPACK.md)

Complete integration guide for EDAPack/qemu-riscv binary distribution.

**Contents:**
- Step-by-step integration instructions
- Build script modifications
- SDK packaging strategies
- CI/CD integration
- Testing procedures
- Troubleshooting guide

**Target Audience:** Binary packagers, particularly EDAPack maintainers

### [github-actions-example.yml](./github-actions-example.yml)

Reference GitHub Actions workflow demonstrating automated QEMU+SDK builds.

**Features:**
- Patch validation
- Multi-platform builds (Linux, macOS)
- SDK installation and testing
- Example device compilation
- Package creation
- Artifact management
- Release automation

**Target Audience:** CI/CD engineers, DevOps teams

## Quick Start

### For Binary Packagers

1. Read [EDAPACK.md](./EDAPACK.md) for integration overview
2. Review your build system requirements
3. Follow the integration steps for your platform
4. Adapt the examples to your specific needs
5. Test with the provided validation procedures

### For CI/CD Integration

1. Copy [github-actions-example.yml](./github-actions-example.yml) to your `.github/workflows/`
2. Adjust paths and versions to match your setup
3. Configure any platform-specific requirements
4. Test the workflow on a branch
5. Enable for your main branches

## Integration Workflow

```
1. Choose Integration Method
   ├─ Manual Integration → Follow EDAPACK.md
   └─ Automated (CI/CD) → Use github-actions-example.yml

2. Prepare Your Repository
   ├─ Add SDK patches
   ├─ Modify build scripts
   └─ Update documentation

3. Test Integration
   ├─ Apply patches
   ├─ Build QEMU with SDK
   ├─ Compile example device
   └─ Verify functionality

4. Package SDK
   ├─ Create distribution package
   ├─ Generate metadata
   └─ Upload artifacts

5. Deploy
   ├─ Update release notes
   ├─ Publish packages
   └─ Announce availability
```

## Supported Platforms

| Platform | Status | Example |
|----------|--------|---------|
| **Linux x86_64** | ✅ Tested | EDAPACK.md, github-actions-example.yml |
| **macOS ARM64** | ✅ Tested | github-actions-example.yml |
| **macOS x86_64** | ⚠️ Should work | Adapt macOS example |
| **Windows** | 🔄 Planned | Coming in future version |

## Common Integration Patterns

### Pattern 1: Patch During Build

Apply patches as part of your standard QEMU build process:

```bash
# In your build script
cd qemu-source
for patch in /path/to/patches/*.patch; do
    patch -p1 < "$patch"
done
./configure --enable-dev-sdk
make && make install && make install-dev-sdk
```

**Best for:** Simple integrations, manual builds

### Pattern 2: Pre-Patched Source

Maintain a pre-patched QEMU fork:

```bash
# One-time setup
git clone https://gitlab.com/qemu-project/qemu.git
cd qemu
git checkout -b with-sdk v9.2.0
git am /path/to/patches/*.patch
git push origin with-sdk

# Normal builds
git clone -b with-sdk your-repo/qemu.git
cd qemu
./configure --enable-dev-sdk
make && make install && make install-dev-sdk
```

**Best for:** Regular releases, version control

### Pattern 3: CI/CD Automation

Fully automated in continuous integration:

```yaml
# See github-actions-example.yml for complete example
jobs:
  build:
    steps:
      - checkout
      - apply-patches
      - build-qemu
      - install-sdk
      - test-examples
      - package-sdk
      - upload-artifacts
```

**Best for:** Professional distributions, frequent updates

## Customization Guide

### Adjusting Installation Paths

Change SDK installation location:

```bash
./configure \
    --prefix=/your/custom/path \
    --includedir=/your/custom/path/include \
    --libdir=/your/custom/path/lib
```

Update pkg-config search path:

```bash
export PKG_CONFIG_PATH=/your/custom/path/lib/pkgconfig:$PKG_CONFIG_PATH
```

### Custom Package Naming

Adapt package names for your distribution:

```bash
# Example: Debian package
PACKAGE_NAME="your-qemu-dev_${VERSION}_amd64"

# Example: RPM package  
PACKAGE_NAME="your-qemu-devel-${VERSION}.x86_64"

# Example: Homebrew formula
PACKAGE_NAME="your-qemu-sdk@${VERSION}"
```

### Platform-Specific Adjustments

**Linux:**
- Standard paths work well
- Use system pkg-config
- Standard .so module format

**macOS:**
- May need code signing for modules
- Use Homebrew paths: `/opt/homebrew/...`
- Use .dylib for modules (or .so with proper flags)

**BSD:**
- Similar to Linux
- Check pkg-config location
- May need different compiler flags

## Testing Your Integration

### Basic Tests

```bash
# 1. Verify patches apply
cd qemu-source
for p in patches/*.patch; do patch -p1 --dry-run < $p; done

# 2. Verify SDK installs
make install-dev-sdk
ls /path/to/sdk/include/qemu-device/

# 3. Verify pkg-config
pkg-config --exists qemu-device && echo "OK"

# 4. Build example device
cd examples/minimal-sysbus
make
```

### Integration Tests

See `../../tests/` directory for comprehensive test suite:
- `test-patch-apply.sh` - Patch application
- `test-sdk-build.sh` - SDK building
- `test-module-build.sh` - Module compilation
- `test-module-load.sh` - Runtime testing

## Contributing New Integrations

Have you integrated QEMU Device SDK with another distribution system?

### How to Contribute

1. **Create integration guide**
   - Copy `EDAPACK.md` as template
   - Document your specific integration
   - Include working examples
   - Add troubleshooting section

2. **Add CI/CD example** (if applicable)
   - Provide workflow file
   - Document any special requirements
   - Include test procedures

3. **Submit pull request**
   - Place files in this directory
   - Update this README
   - Reference in main README.md

### Template Structure

```markdown
# [Your System] Integration Guide

## Overview
Brief description of the system and integration goals

## Prerequisites
What's needed before starting

## Integration Steps
Step-by-step instructions

## Testing
How to verify the integration

## Troubleshooting
Common issues and solutions

## Maintenance
How to keep integration updated
```

## Requested Integrations

Community-requested integrations we'd like to see:

- [ ] **Buildroot** - Embedded Linux build system
- [ ] **Yocto/OpenEmbedded** - Embedded distribution framework
- [ ] **Gentoo Portage** - Source-based package manager
- [ ] **FreeBSD Ports** - BSD package system
- [ ] **vcpkg** - C++ package manager
- [ ] **Conan** - C/C++ package manager
- [ ] **Nix/NixOS** - Declarative package manager

Want to contribute one? See "Contributing" above!

## Support

### For Integration Help

- 📖 See [PACKAGER-GUIDE.md](../PACKAGER-GUIDE.md)
- 🔧 See [PATCH-INTEGRATION.md](../PATCH-INTEGRATION.md)
- 💬 Open an issue: https://github.com/mballance/qemu-model-loader/issues
- 📧 Contact maintainers (see main README)

### For System-Specific Issues

- Check your distribution's documentation
- Consult distribution maintainers
- Review CI logs for detailed errors

## References

- [Main Project README](../../README.md)
- [Packager Guide](../PACKAGER-GUIDE.md)
- [Patch Integration Guide](../PATCH-INTEGRATION.md)
- [SDK Structure](../SDK-STRUCTURE.md)
- [Example Devices](../../examples/)
- [Test Suite](../../tests/)

## License

Integration guides and examples are provided under the MIT License.
QEMU patches remain under GPL v2 (see LICENSE file).
