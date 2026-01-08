#!/bin/sh -x

root=$(pwd)

#********************************************************************
#* Install required packages
#********************************************************************
if test $(uname -s) = "Linux"; then
    # Detect package manager
    if command -v apt-get >/dev/null 2>&1; then
        # Ubuntu/Debian
        DEBIAN_FRONTEND=noninteractive apt-get update
        DEBIAN_FRONTEND=noninteractive apt-get install -y \
            wget git gcc g++ make \
            python3 python3-pip python3-venv \
            libglib2.0-dev libpixman-1-dev zlib1g-dev \
            ninja-build pkg-config patchelf
    elif command -v yum >/dev/null 2>&1; then
        # CentOS/RHEL
        yum update -y
        yum install -y wget git gcc gcc-c++ make \
            python3 python3-pip \
            glib2-devel pixman-devel zlib-devel patchelf
        
        # Install meson and ninja via pip (more reliable than yum packages)
        pip3 install meson ninja
    fi

    if test -z $image; then
        image=linux
    fi
    
    # Try to set up Python path for manylinux if available
    if test -d /opt/python/cp312-cp312/bin; then
        export PATH=/opt/python/cp312-cp312/bin:$PATH
    fi
    
    rls_plat=${image}
    USE_PATCHELF=1
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
# Disable features not available/needed for portability
./configure \
    --target-list=riscv32-softmmu,riscv64-softmmu,riscv32-linux-user,riscv64-linux-user \
    --prefix=${root}/release/qemu-riscv \
    --disable-docs \
    --disable-guest-agent \
    --disable-vnc \
    --disable-sdl \
    --disable-gtk \
    --disable-opengl \
    --disable-slirp

if test $? -ne 0; then exit 1; fi

# Build
make -j$(nproc)
if test $? -ne 0; then exit 1; fi

# Install
make install
if test $? -ne 0; then exit 1; fi

#********************************************************************
#* Check and fix portability issues
#********************************************************************
cd ${root}/release/qemu-riscv

echo "=== Checking for portability issues ==="

# Check for shared library dependencies in binaries
for binary in bin/*; do
    if test -f "$binary" && test -x "$binary"; then
        echo "Checking $binary..."
        if command -v ldd >/dev/null 2>&1; then
            ldd "$binary" 2>/dev/null | grep -E "not found|${root}" && {
                echo "WARNING: Portability issue detected in $binary"
            } || true
        fi
        
        # Check for absolute rpaths that include the build/install path
        if command -v readelf >/dev/null 2>&1; then
            rpath=$(readelf -d "$binary" 2>/dev/null | grep -E "RPATH|RUNPATH" | grep -o '\[.*\]' | tr -d '[]')
            if echo "$rpath" | grep -q "${root}"; then
                echo "WARNING: Absolute RPATH detected in $binary: $rpath"
            fi
        fi
    fi
done

# Check for QEMU-specific shared libraries that may have been built
if test -d lib; then
    echo "Found lib directory with QEMU libraries"
    ls -la lib/ || true
fi

#********************************************************************
#* Fix RPATH issues with patchelf (Linux only)
#********************************************************************
if test "x${USE_PATCHELF}" = "x1"; then
    echo "=== Fixing RPATH with patchelf ==="
    
    # Check if we have shared libraries that need RPATH fixing
    if test -d lib; then
        for binary in bin/*; do
            if test -f "$binary" && test -x "$binary"; then
                # Check if binary links to libraries in our lib directory
                if ldd "$binary" 2>/dev/null | grep -q "lib/"; then
                    echo "Fixing RPATH for $binary"
                    # Set RPATH to use $ORIGIN (relative to binary location)
                    patchelf --set-rpath '$ORIGIN/../lib' "$binary" 2>/dev/null || {
                        echo "Warning: Could not set RPATH for $binary"
                    }
                    # Verify the change
                    echo "New RPATH:"
                    patchelf --print-rpath "$binary" 2>/dev/null || true
                fi
            fi
        done
        
        # Also fix RPATH for any shared libraries themselves
        if test -d lib; then
            for lib in lib/*.so*; do
                if test -f "$lib"; then
                    echo "Fixing RPATH for $lib"
                    patchelf --set-rpath '$ORIGIN' "$lib" 2>/dev/null || true
                fi
            done
        fi
    fi
fi

#********************************************************************
#* Final portability verification
#********************************************************************
echo "=== Final portability check ==="
for binary in bin/*; do
    if test -f "$binary" && test -x "$binary"; then
        echo "Final check for $binary:"
        if command -v ldd >/dev/null 2>&1; then
            ldd "$binary" 2>/dev/null | grep -E "not found|=>" | head -10 || true
        fi
        if command -v readelf >/dev/null 2>&1; then
            readelf -d "$binary" 2>/dev/null | grep -E "RPATH|RUNPATH" || echo "  No RPATH/RUNPATH"
        fi
    fi
done

#********************************************************************
#* Strip binaries
#********************************************************************
echo "=== Stripping binaries ==="
strip bin/* 2>/dev/null || true

#********************************************************************
#* Create release tarball
#********************************************************************
cd ${root}/release

tar czf qemu-riscv-${rls_plat}-${rls_version}.tar.gz qemu-riscv
if test $? -ne 0; then exit 1; fi

echo "Build complete: qemu-riscv-${rls_plat}-${rls_version}.tar.gz"
