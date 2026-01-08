# qemu-riscv

Binary build of QEMU configured for RISC-V targets. This build provides portable 
QEMU binaries for RISC-V system and user-mode emulation.

## Supported Targets

This build includes the following QEMU targets:
- `riscv32-softmmu` - RISC-V 32-bit system emulation
- `riscv64-softmmu` - RISC-V 64-bit system emulation
- `riscv32-linux-user` - RISC-V 32-bit Linux user-mode emulation
- `riscv64-linux-user` - RISC-V 64-bit Linux user-mode emulation

## Release Scheme

qemu-riscv provides weekly builds of QEMU top-of-trunk. These releases
are generally marked as pre-release.

qemu-riscv also provides tagged builds of QEMU releases.

The latest most-stable build is tagged 'latest'.

## Supported Platforms

Binary releases are provided for:
- Linux x86_64 (manylinux2014, manylinux_2_28, manylinux_2_34)
- Linux aarch64 (manylinux_2_28, manylinux_2_34)
- macOS arm64 (Apple Silicon)

## Usage

Download the appropriate tarball for your platform from the releases page, extract it, and add the `bin` directory to your PATH:

```bash
tar xzf qemu-riscv-<platform>-<version>.tar.gz
export PATH=$(pwd)/qemu-riscv/bin:$PATH
```

Then you can use the QEMU RISC-V binaries:

```bash
qemu-system-riscv64 --version
qemu-riscv64 --version
```

## Building Locally

You can build locally using CMake:

```bash
mkdir build
cd build
cmake ..
make
```

Or use the build script directly:

```bash
export qemu_latest_rls=master  # or a specific tag like v9.2.0
./scripts/build.sh
```
