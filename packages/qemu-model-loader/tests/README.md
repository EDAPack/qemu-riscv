# QEMU Model Loader Test Suite

Automated tests for validating patches, SDK, and device modules.

## Test Scripts

### run-all.sh

Run the complete test suite.

**Usage:**
```bash
./run-all.sh [qemu-version]
```

**Example:**
```bash
./run-all.sh master
./run-all.sh v9.2.0
```

**Environment Variables:**
- `SKIP_SDK_BUILD=1` - Skip expensive SDK build test

---

### test-patch-apply.sh

Test that patches apply cleanly to QEMU.

**Usage:**
```bash
./test-patch-apply.sh [qemu-version]
```

**What it tests:**
- Clones QEMU repository
- Applies patches from `patches/v9.2/`
- Checks for conflicts
- Verifies commits

**Duration:** ~2 minutes

---

### test-sdk-build.sh

Test building QEMU with SDK support.

**Usage:**
```bash
./test-sdk-build.sh [qemu-version]
```

**What it tests:**
- Applies patches
- Configures QEMU
- Builds QEMU
- Installs SDK
- Validates SDK structure
- Runs SDK verification

**Duration:** ~15-30 minutes (depending on system)

**Environment Variables:**
- `SKIP_BUILD=1` - Only test patch application, skip build

---

### test-module-build.sh

Test building example modules with SDK.

**Usage:**
```bash
./test-module-build.sh [sdk-path]
```

**Default SDK path:** `/usr/local`

**What it tests:**
- Checks SDK installation
- Builds all example modules
- Verifies module symbols
- Checks dependencies

**Duration:** ~1 minute

---

### test-module-load.sh

Test loading modules in QEMU.

**Usage:**
```bash
./test-module-load.sh [module-dir]
```

**Default module dir:** `../examples`

**What it tests:**
- Checks QEMU installation
- Finds built modules
- Loads each module in QEMU
- Verifies no errors

**Duration:** ~1 minute

---

### test-integration.sh

End-to-end integration test (all steps).

**Usage:**
```bash
./test-integration.sh [qemu-version]
```

**What it tests:**
1. Patch application
2. SDK build
3. Module build
4. Module loading

**Duration:** ~20-40 minutes

---

## Quick Start

### Run All Tests

```bash
cd tests
./run-all.sh
```

### Run Individual Test

```bash
cd tests
./test-patch-apply.sh master
```

### Run with Different QEMU Version

```bash
./run-all.sh v9.2.0
```

## Test Workflow

```
test-patch-apply.sh
        ↓
test-sdk-build.sh
        ↓
test-module-build.sh
        ↓
test-module-load.sh
```

Or run all at once:
```
test-integration.sh  (runs all 4 tests)
```

## Prerequisites

### For All Tests
- `git` - Clone QEMU repository
- `bash` - Run test scripts
- Internet connection - Download QEMU

### For SDK Build Tests
- `gcc` or `clang` - C compiler
- `make` - Build tool
- `meson` - Build system (>= 1.5.0)
- `ninja` - Build backend
- `pkg-config` - Package configuration
- `libglib2.0-dev` - GLib development files
- ~10GB disk space - For QEMU build

### For Module Tests
- SDK installed (from test-sdk-build.sh or system package)
- `gcc` - C compiler
- `libglib2.0-dev` - GLib development files

### For Loading Tests
- `qemu-system-arm` or `qemu-system-x86_64` - QEMU binaries
- Built modules (from test-module-build.sh)

## CI/CD Integration

### GitHub Actions

```yaml
name: Test QEMU Model Loader

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Install Dependencies
        run: |
          sudo apt update
          sudo apt install -y build-essential meson ninja-build \\
                              libglib2.0-dev pkg-config git \\
                              qemu-system-arm qemu-system-x86
      
      - name: Run Patch Test
        run: cd tests && ./test-patch-apply.sh master
      
      - name: Run SDK Build Test
        run: cd tests && ./test-sdk-build.sh master
        env:
          SKIP_BUILD: 0
      
      - name: Run Module Build Test
        run: cd tests && ./test-module-build.sh /tmp/sdk
      
      - name: Run Module Load Test
        run: cd tests && ./test-module-load.sh
```

### GitLab CI

```yaml
test:
  image: ubuntu:latest
  before_script:
    - apt update
    - apt install -y build-essential meson ninja-build libglib2.0-dev \\
                     pkg-config git qemu-system-arm qemu-system-x86
  script:
    - cd tests
    - ./run-all.sh master
  artifacts:
    when: on_failure
    paths:
      - tests/*.log
```

## Test Output

### Success

```
========================================
  Test Suite Summary
========================================

  patch: PASS
  sdk: PASS
  module_build: PASS
  module_load: PASS

Passed: 4
Failed: 0
Skipped: 0

✓ All tests passed!
```

### Failure

```
========================================
  Test Suite Summary
========================================

  patch: PASS
  sdk: FAIL
  module_build: SKIP
  module_load: SKIP

Passed: 1
Failed: 1
Skipped: 2

✗ Some tests failed.
```

## Troubleshooting

### Test Fails: Patch Application

**Problem:** Patches don't apply cleanly

**Solutions:**
- Try different QEMU version
- Check if patches need updating
- Look for conflicts in output

### Test Fails: SDK Build

**Problem:** Build errors

**Solutions:**
- Check dependencies installed
- Ensure enough disk space (~10GB)
- Check build logs in output

**Problem:** Configuration fails

**Solutions:**
- Install meson >= 1.5.0: `pip3 install meson`
- Install ninja: `sudo apt install ninja-build`

### Test Fails: Module Build

**Problem:** SDK not found

**Solutions:**
- Run test-sdk-build.sh first
- Or install qemu-device-sdk package
- Check: `ls /usr/local/include/qemu-device`

**Problem:** GLib errors

**Solutions:**
- Install: `sudo apt install libglib2.0-dev`
- Check: `pkg-config --cflags glib-2.0`

### Test Fails: Module Loading

**Problem:** QEMU not found

**Solutions:**
- Install: `sudo apt install qemu-system-arm qemu-system-x86`
- Check: `qemu-system-arm --version`

**Problem:** Module load errors

**Solutions:**
- Check QEMU version matches SDK
- Rebuild modules
- Check error output for details

## Advanced Usage

### Test Specific QEMU Commit

```bash
# Clone and checkout specific commit
git clone https://gitlab.com/qemu-project/qemu.git /tmp/qemu
cd /tmp/qemu
git checkout abc123

# Apply patches
git am /path/to/patches/v9.2/*.patch

# Continue testing...
```

### Test with Custom Patches

```bash
# Create custom patch directory
mkdir patches/custom
cp /path/to/my-patches/* patches/custom/

# Modify test script to use custom patches
PATCH_DIR=patches/custom ./test-patch-apply.sh
```

### Skip Expensive Tests

```bash
# Skip SDK build (useful for quick testing)
SKIP_SDK_BUILD=1 ./run-all.sh

# Or
export SKIP_SDK_BUILD=1
./run-all.sh
```

### Parallel Testing

```bash
# Run patch and module tests in parallel
./test-patch-apply.sh & 
./test-module-build.sh &
wait
```

## Test Development

### Adding New Tests

1. Create test script: `test-mytest.sh`
2. Make executable: `chmod +x test-mytest.sh`
3. Follow naming convention: `test-*.sh`
4. Use color output (GREEN/RED/YELLOW)
5. Exit 0 on success, 1 on failure
6. Add to `run-all.sh`

### Test Template

```bash
#!/bin/bash
# test-mytest.sh - Description

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo "Testing: My Feature"

# Test logic here
if [[ condition ]]; then
    echo -e "${GREEN}✓ Test passed${NC}"
    exit 0
else
    echo -e "${RED}✗ Test failed${NC}"
    exit 1
fi
```

## Continuous Integration

These tests are designed for CI/CD:

- **Fast feedback**: Patch test runs in ~2 minutes
- **Isolated**: Each test in temp directory
- **Configurable**: Environment variables for control
- **Detailed output**: Clear pass/fail with reasons
- **Exit codes**: 0 = success, 1 = failure

## Test Coverage

| Component | Test | Coverage |
|-----------|------|----------|
| Patches | test-patch-apply.sh | Patch format, conflicts |
| Build System | test-sdk-build.sh | configure, make, install |
| SDK | test-sdk-build.sh | Headers, configs, pkg-config |
| Examples | test-module-build.sh | Compilation, linking |
| Loading | test-module-load.sh | QEMU integration |
| End-to-End | test-integration.sh | Complete workflow |

## Support

- **Issues**: https://github.com/fvutils/qemu-model-loader/issues
- **Documentation**: See `../docs/` directory
- **CI Examples**: See `.github/workflows/` (if available)
