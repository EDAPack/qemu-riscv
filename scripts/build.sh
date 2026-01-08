#!/bin/sh -x

root=$(pwd)

#********************************************************************
#* Install required packages
#********************************************************************
if test $(uname -s) = "Linux"; then
    yum update -y
    yum install -y wget git gcc gcc-c++ make \
        python3 python3-pip ninja-build \
        glib2-devel pixman-devel zlib-devel \
        libfdt-devel libslirp-devel

    if test -z $image; then
        image=linux
    fi
    export PATH=/opt/python/cp312-cp312/bin:$PATH
    
    # Install meson via pip
    pip3 install meson
    
    rls_plat=${image}
elif test $(uname -s) = "Darwin"; then
    # macOS - dependencies installed via brew in CI
    if test -z $image; then
        image=macos-$(uname -m)
    fi
    
    # Install meson via pip
    pip3 install meson --break-system-packages || pip3 install meson
    
    rls_plat=${image}
fi

#********************************************************************
#* Validate environment variables
#********************************************************************
if test -z $qemu_latest_rls; then
  echo "qemu_latest_rls not set"
  env
  exit 1
fi

#********************************************************************
#* Calculate version information
#********************************************************************
if test -z ${rls_version}; then
    qemu_version=$(echo $qemu_latest_rls | sed -e 's/^v//')
    rls_version=${qemu_version}

    if test "x${BUILD_NUM}" != "x"; then
        rls_version="${rls_version}.${BUILD_NUM}"
    fi
fi

#********************************************************************
#* Download and build QEMU
#********************************************************************
cd ${root}

# Create build directory
rm -rf build
mkdir -p build
cd build

# Clone QEMU repository
if test "${qemu_latest_rls}" = "master"; then
    git clone --depth 1 --branch master https://gitlab.com/qemu-project/qemu.git
else
    git clone --depth 1 --branch ${qemu_latest_rls} https://gitlab.com/qemu-project/qemu.git
fi

cd qemu

# Configure QEMU for RISC-V targets only
# Build static binaries when possible for better portability
./configure \
    --target-list=riscv32-softmmu,riscv64-softmmu,riscv32-linux-user,riscv64-linux-user \
    --prefix=${root}/release/qemu-riscv \
    --disable-docs \
    --disable-guest-agent \
    --disable-vnc \
    --disable-sdl \
    --disable-gtk \
    --disable-opengl \
    --enable-slirp

if test $? -ne 0; then exit 1; fi

# Build
make -j$(nproc)
if test $? -ne 0; then exit 1; fi

# Install
make install
if test $? -ne 0; then exit 1; fi

#********************************************************************
#* Strip binaries
#********************************************************************
cd ${root}/release/qemu-riscv
strip bin/* 2>/dev/null || true

#********************************************************************
#* Create release tarball
#********************************************************************
cd ${root}/release

tar czf qemu-riscv-${rls_plat}-${rls_version}.tar.gz qemu-riscv
if test $? -ne 0; then exit 1; fi

echo "Build complete: qemu-riscv-${rls_plat}-${rls_version}.tar.gz"
