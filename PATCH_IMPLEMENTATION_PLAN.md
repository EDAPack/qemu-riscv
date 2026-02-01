# Plan: Create Working Patches for QEMU v9.2.0 SDK Installation

## Objective
Create actual working patches that add device SDK installation support to QEMU v9.2.0, replacing the template patches in `packages/qemu-model-loader/patches/v9.2/`.

## Prerequisites
- Local QEMU v9.2.0 source tree
- Understanding of QEMU's meson build system
- Ability to test builds locally

## Phase 1: Setup Local QEMU Environment (15 min)

### Step 1.1: Clone QEMU v9.2.0
```bash
cd /tmp
git clone --branch v9.2.0 https://gitlab.com/qemu-project/qemu.git qemu-v9.2.0
cd qemu-v9.2.0
```

### Step 1.2: Create Working Branch
```bash
git checkout -b sdk-patches
```

### Step 1.3: Build Baseline QEMU
```bash
mkdir build
cd build
../configure --target-list=riscv32-softmmu,riscv64-softmmu
make -j$(nproc)
# Verify it builds successfully
```

## Phase 2: Implement SDK Installation Feature (45 min)

### Step 2.1: Add Meson Option
**File:** `meson_options.txt`

Find end of file (currently ~384 lines) and add:
```meson
option('install_dev_sdk', type: 'boolean', value: false,
       description: 'Install device development SDK (headers and configs)')
```

**Why:** This allows users to opt-in to SDK installation with `-Dinstall_dev_sdk=true`

### Step 2.2: Add SDK Installation Rules
**File:** `meson.build`

Find the section after `if have_tools` that installs qemu-plugin.h (around line 4335-4340).

Add after that block:
```meson
###########################
# Device Module SDK       #
###########################

if get_option('install_dev_sdk')
  # Install all public API headers needed for device development
  install_subdir('include/qemu',
                 install_dir: get_option('includedir') / 'qemu-device',
                 strip_directory: false,
                 exclude_files: ['osdep.h.inc'])
  
  install_subdir('include/qom',
                 install_dir: get_option('includedir') / 'qemu-device',
                 strip_directory: false)
  
  install_subdir('include/hw',
                 install_dir: get_option('includedir') / 'qemu-device',
                 strip_directory: false)
  
  install_subdir('include/exec',
                 install_dir: get_option('includedir') / 'qemu-device',
                 strip_directory: false)
  
  install_subdir('include/sysemu',
                 install_dir: get_option('includedir') / 'qemu-device',
                 strip_directory: false)
  
  install_subdir('include/chardev',
                 install_dir: get_option('includedir') / 'qemu-device',
                 strip_directory: false)
  
  install_subdir('include/io',
                 install_dir: get_option('includedir') / 'qemu-device',
                 strip_directory: false)
  
  install_subdir('include/migration',
                 install_dir: get_option('includedir') / 'qemu-device',
                 strip_directory: false)
  
  install_subdir('include/monitor',
                 install_dir: get_option('includedir') / 'qemu-device',
                 strip_directory: false)
  
  # Install generated configuration files
  install_data(meson.current_build_dir() / 'config-host.h',
               install_dir: get_option('includedir') / 'qemu-device')
  
  # Install generated QAPI headers (subdirectory with all files)
  install_subdir(meson.current_build_dir() / 'qapi',
                 install_dir: get_option('includedir') / 'qemu-device',
                 strip_directory: false,
                 exclude_directories: ['trace'])
endif
```

**Why:** This installs all necessary headers to `<prefix>/include/qemu-device/`

### Step 2.3: Add pkg-config File
**Create new file:** `qemu-device.pc.in`

```
prefix=@PREFIX@
exec_prefix=${prefix}
includedir=${prefix}/include
libdir=${prefix}/lib

Name: qemu-device
Description: QEMU Device Development SDK
Version: @VERSION@
Cflags: -I${includedir}/qemu-device
```

**Update meson.build** (after SDK section):
```meson
if get_option('install_dev_sdk')
  # ... existing code ...
  
  # Generate and install pkg-config file
  pkg = import('pkgconfig')
  pkg.generate(
    name: 'qemu-device',
    description: 'QEMU Device Development SDK',
    version: meson.project_version(),
    variables: [
      'includedir=${prefix}/include',
    ],
    subdirs: ['qemu-device'],
  )
endif
```

**Why:** Allows `pkg-config --cflags qemu-device` to work

### Step 2.4: Test Local Build
```bash
# Reconfigure with SDK option
cd build
rm -rf *
../configure --target-list=riscv32-softmmu,riscv64-softmmu
meson configure -Dinstall_dev_sdk=true
make -j$(nproc)
DESTDIR=/tmp/qemu-install make install

# Verify SDK was installed
ls -la /tmp/qemu-install/usr/local/include/qemu-device/
ls -la /tmp/qemu-install/usr/local/lib/pkgconfig/qemu-device.pc
```

## Phase 3: Generate Proper Patches (10 min)

### Step 3.1: Commit Changes
```bash
cd /tmp/qemu-v9.2.0
git add meson.build meson_options.txt qemu-device.pc.in
git commit -m "build: add install-dev-sdk target for device module development

Add a new build option 'install_dev_sdk' that installs headers and
configuration files needed for building QEMU device modules as
external shared libraries.

This enables binary distributions to provide a device development SDK
without shipping the full source code."
```

### Step 3.2: Generate Patch Files
```bash
git format-patch -1 HEAD
# Creates: 0001-build-add-install-dev-sdk-target-for-device-module-.patch

# Copy to project
cp 0001-*.patch ~/projects/edapack/qemu-riscv-loader/packages/qemu-model-loader/patches/v9.2/
```

### Step 3.3: Clean Up Old Template Patches
```bash
cd ~/projects/edapack/qemu-riscv-loader/packages/qemu-model-loader/patches/v9.2/
# Backup old patches
mkdir old_templates
mv 0001-build-add-install-dev-sdk-target.patch old_templates/
mv 0002-build-generate-pkgconfig-for-device-sdk.patch old_templates/
mv 0003-docs-add-device-module-guide.patch old_templates/

# Keep only README and new patch
ls -la
# Should show: 0001-build-add-install-dev-sdk-target-for-device-module-.patch README.md old_templates/
```

## Phase 4: Validate with Build Script (20 min)

### Step 4.1: Test with Local Build Script
```bash
cd ~/projects/edapack/qemu-riscv-loader

# Set environment to use v9.2.0
export qemu_latest_rls="v9.2.0"
export BUILD_NUM="test"
export image="linux"

# Run build script
./scripts/build.sh 2>&1 | tee /tmp/build-test.log

# Check for success
grep "=== Applying model-loader patches ===" /tmp/build-test.log -A 20
grep "=== Installing device SDK ===" /tmp/build-test.log -A 10
```

### Step 4.2: Verify Patch Application
```bash
# Check build log for patch success
grep "patching file" /tmp/build-test.log
grep "FAILED" /tmp/build-test.log  # Should be empty

# Check SDK installation
ls -la release/qemu-riscv/include/qemu-device/
ls -la release/qemu-riscv/lib/pkgconfig/qemu-device.pc
```

### Step 4.3: Test Module Build
```bash
cd examples/custom-timer

# Update Makefile to use local QEMU
export PKG_CONFIG_PATH=~/projects/edapack/qemu-riscv-loader/release/qemu-riscv/lib/pkgconfig

# Try to build module
make clean && make

# Should succeed and create hw-custom-timer.so
ls -lh hw-custom-timer.so
```

## Phase 5: Update CI and Documentation (15 min)

### Step 5.1: Update Package
```bash
cd ~/projects/edapack/qemu-riscv-loader

# Stage changes
git add packages/qemu-model-loader/patches/v9.2/

# Commit
git commit -m "Update QEMU v9.2.0 patches with working implementation

Replace template patches with actual tested patches that:
- Add install_dev_sdk meson option
- Install device development headers to include/qemu-device/
- Generate qemu-device.pc for pkg-config
- Verified to apply cleanly to QEMU v9.2.0

Tested locally with full build and module compilation."
```

### Step 5.2: Update Documentation
Update `packages/qemu-model-loader/patches/v9.2/README.md`:
- Document exact QEMU version (v9.2.0)
- Add testing instructions
- Note: patches ARE actual working patches, not templates

### Step 5.3: Update Example README
Update `examples/custom-timer/README.md`:
- Remove "patches don't apply" warnings
- Add "now working" status
- Update build instructions

### Step 5.4: Push and Test CI
```bash
git push origin mballance/loader

# Monitor CI
gh run watch $(gh run list --branch mballance/loader --limit 1 --json databaseId --jq '.[0].databaseId')

# Download and verify artifact
gh run download <run-id> -n qemu-riscv-ubuntu-24.04-x86_64
tar xzf qemu-riscv-*.tar.gz
ls qemu-riscv/include/qemu-device/  # Should show headers!
```

## Phase 6: Final Validation (10 min)

### Step 6.1: Test Complete Workflow
```bash
# Download CI artifact
cd /tmp/test-final
gh run download <latest-run> -n qemu-riscv-ubuntu-24.04-x86_64
tar xzf qemu-riscv-*.tar.gz

# Copy example
cp -r ~/projects/edapack/qemu-riscv-loader/examples/custom-timer .
cd custom-timer

# Build module
make

# Test loading
export QEMU_MODULE_DIR=$PWD
./qemu-riscv/bin/qemu-system-riscv64 -device help | grep custom-timer

# Should show: "custom-timer  Custom Timer Device (Loadable Module Example)"
```

### Step 6.2: Document Success
Create final summary in `examples/custom-timer/SUCCESS.md`:
- Patches now working
- SDK installation verified
- Module builds successfully
- Device loads in QEMU

## Expected Outcomes

✅ Working patches for QEMU v9.2.0
✅ SDK headers installed in artifacts
✅ pkg-config integration works
✅ Custom-timer example builds
✅ Module loads in QEMU
✅ Complete documentation

## Time Estimate
- Phase 1: 15 min
- Phase 2: 45 min
- Phase 3: 10 min  
- Phase 4: 20 min
- Phase 5: 15 min
- Phase 6: 10 min
**Total: ~2 hours**

## Risk Mitigation

**Risk:** Meson syntax errors
**Mitigation:** Test each change incrementally with `meson configure`

**Risk:** Missing headers
**Mitigation:** Reference existing QEMU device includes, test with simple module

**Risk:** CI still fails
**Mitigation:** Test locally first, verify exact QEMU version match

## Success Criteria

1. `git apply` succeeds with no errors
2. `make install-dev-sdk` completes successfully
3. Headers exist in `include/qemu-device/`
4. pkg-config file is created
5. Custom-timer example builds
6. Module loads in QEMU without errors

