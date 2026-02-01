#!/bin/bash
# create-sdk.sh - Package QEMU Device SDK from installation
#
# Usage:
#   ./create-sdk.sh --qemu-install /usr/local --output qemu-device-sdk.tar.gz
#   ./create-sdk.sh --qemu-install /usr/local --format deb --output qemu-device-sdk.deb

set -e

# Default values
QEMU_INSTALL=""
OUTPUT=""
FORMAT="tarball"
VERSION=""
ARCH=$(uname -m)
VERBOSE=0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Functions
log() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

die() {
    error "$*"
    exit 1
}

usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Package QEMU Device SDK from installed QEMU files.

OPTIONS:
    --qemu-install PATH     Path to QEMU installation (required)
                           Should contain include/qemu-device/
    
    --output FILE          Output file path (required)
    
    --format FORMAT        Package format (default: tarball)
                           Options: tarball, deb, rpm, pkg
    
    --version VERSION      SDK version (auto-detected if not specified)
    
    --arch ARCH           Architecture (default: $(uname -m))
    
    --verbose             Verbose output
    
    --help                Show this help

EXAMPLES:
    # Create tarball
    $0 --qemu-install /usr/local --output qemu-device-sdk-9.2.0.tar.gz
    
    # Create Debian package
    $0 --qemu-install /tmp/install/usr/local --format deb \\
       --output qemu-device-sdk_9.2.0_amd64.deb
    
    # Create from DESTDIR install
    $0 --qemu-install \$PWD/install/usr/local --output sdk.tar.gz

EOF
    exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --qemu-install)
            QEMU_INSTALL="$2"
            shift 2
            ;;
        --output)
            OUTPUT="$2"
            shift 2
            ;;
        --format)
            FORMAT="$2"
            shift 2
            ;;
        --version)
            VERSION="$2"
            shift 2
            ;;
        --arch)
            ARCH="$2"
            shift 2
            ;;
        --verbose)
            VERBOSE=1
            shift
            ;;
        --help)
            usage
            ;;
        *)
            die "Unknown option: $1 (use --help for usage)"
            ;;
    esac
done

# Validate arguments
[[ -z "$QEMU_INSTALL" ]] && die "Missing --qemu-install (required)"
[[ -z "$OUTPUT" ]] && die "Missing --output (required)"
[[ ! -d "$QEMU_INSTALL" ]] && die "QEMU install path does not exist: $QEMU_INSTALL"

# Validate SDK exists
SDK_INCLUDE="$QEMU_INSTALL/include/qemu-device"
[[ ! -d "$SDK_INCLUDE" ]] && die "SDK not found at $SDK_INCLUDE - did you run 'make install-dev-sdk'?"

# Auto-detect version if not specified
if [[ -z "$VERSION" ]]; then
    if [[ -f "$SDK_INCLUDE/config/config-host.h" ]]; then
        # Try to extract version from config
        VERSION=$(grep -m1 "QEMU_VERSION" "$SDK_INCLUDE/config/config-host.h" 2>/dev/null | cut -d'"' -f2 || echo "unknown")
    fi
    [[ -z "$VERSION" || "$VERSION" == "unknown" ]] && VERSION="10.0.0"
    log "Auto-detected version: $VERSION"
fi

log "Creating QEMU Device SDK package"
log "  Install path: $QEMU_INSTALL"
log "  Version: $VERSION"
log "  Format: $FORMAT"
log "  Output: $OUTPUT"

# Create temporary staging directory
STAGING=$(mktemp -d)
trap "rm -rf $STAGING" EXIT

log "Staging SDK files to $STAGING"

# Create SDK structure
mkdir -p "$STAGING/usr/include"
mkdir -p "$STAGING/usr/lib/pkgconfig"
mkdir -p "$STAGING/usr/share/doc/qemu-device-sdk"

# Copy headers
log "Copying headers..."
cp -r "$SDK_INCLUDE" "$STAGING/usr/include/" || die "Failed to copy headers"

# Copy pkg-config file
PKGCONFIG_SRC="$QEMU_INSTALL/lib/pkgconfig/qemu-device.pc"
PKGCONFIG_ALT="$QEMU_INSTALL/share/pkgconfig/qemu-device.pc"

if [[ -f "$PKGCONFIG_SRC" ]]; then
    cp "$PKGCONFIG_SRC" "$STAGING/usr/lib/pkgconfig/" || die "Failed to copy pkg-config"
elif [[ -f "$PKGCONFIG_ALT" ]]; then
    cp "$PKGCONFIG_ALT" "$STAGING/usr/lib/pkgconfig/" || die "Failed to copy pkg-config"
else
    warn "pkg-config file not found, generating basic version"
    cat > "$STAGING/usr/lib/pkgconfig/qemu-device.pc" << PKGEOF
prefix=/usr
includedir=\${prefix}/include
sdkincludedir=\${includedir}/qemu-device
configdir=\${sdkincludedir}/config

Name: QEMU Device SDK
Description: SDK for building QEMU device modules
Version: $VERSION
Requires: glib-2.0 >= 2.56
Cflags: -I\${sdkincludedir} -I\${configdir} -DBUILD_DSO
URL: https://www.qemu.org
PKGEOF
fi

# Create documentation
log "Creating documentation..."
cat > "$STAGING/usr/share/doc/qemu-device-sdk/README" << DOCEOF
QEMU Device Module SDK
======================

This package contains headers and configuration files needed to build
QEMU device modules as external shared libraries.

Version: $VERSION

Usage:
------

1. Install this SDK package
2. Build your device module:

   gcc \$(pkg-config --cflags qemu-device) \\
       -fPIC -shared mydevice.c \\
       -o hw-mydevice.so \\
       \$(pkg-config --libs glib-2.0)

3. Load the module:

   export QEMU_MODULE_DIR=\$(pwd)
   qemu-system-x86_64 -device mydevice

Documentation:
--------------

See QEMU documentation for device module development:
- docs/devel/device-modules.rst in QEMU source
- https://www.qemu.org/docs/

Support:
--------

- QEMU mailing list: qemu-devel@nongnu.org
- Issues: https://gitlab.com/qemu-project/qemu/-/issues

DOCEOF

# Count files
FILE_COUNT=$(find "$STAGING" -type f | wc -l)
SDK_SIZE=$(du -sh "$STAGING" | cut -f1)
log "Staged $FILE_COUNT files ($SDK_SIZE)"

# Create package based on format
case "$FORMAT" in
    tarball)
        log "Creating tarball..."
        tar czf "$OUTPUT" -C "$STAGING" . || die "Failed to create tarball"
        ;;
        
    deb)
        log "Creating Debian package..."
        
        # Create DEBIAN control directory
        mkdir -p "$STAGING/DEBIAN"
        
        # Determine package name
        DEB_ARCH="$ARCH"
        case "$ARCH" in
            x86_64) DEB_ARCH="amd64" ;;
            aarch64) DEB_ARCH="arm64" ;;
            armv7l) DEB_ARCH="armhf" ;;
        esac
        
        # Calculate installed size (in KB)
        INSTALLED_SIZE=$(du -sk "$STAGING/usr" | cut -f1)
        
        # Create control file
        cat > "$STAGING/DEBIAN/control" << DEBEOF
Package: qemu-device-sdk
Version: $VERSION
Section: devel
Priority: optional
Architecture: $DEB_ARCH
Depends: libglib2.0-dev (>= 2.56)
Maintainer: QEMU Project <qemu-devel@nongnu.org>
Installed-Size: $INSTALLED_SIZE
Description: QEMU Device Module Development SDK
 Headers and configuration files for building QEMU device modules
 as external shared libraries.
 .
 This package enables developers to create custom device models for
 QEMU without modifying or recompiling QEMU itself.
Homepage: https://www.qemu.org
DEBEOF

        # Build package
        dpkg-deb --build "$STAGING" "$OUTPUT" || die "Failed to create deb package"
        ;;
        
    rpm)
        log "Creating RPM package..."
        
        # Create RPM structure
        RPM_ROOT=$(mktemp -d)
        trap "rm -rf $RPM_ROOT" EXIT
        
        mkdir -p "$RPM_ROOT"/{BUILD,RPMS,SOURCES,SPECS,SRPMS}
        
        # Create tarball for RPM
        TARBALL="$RPM_ROOT/SOURCES/qemu-device-sdk-$VERSION.tar.gz"
        tar czf "$TARBALL" -C "$STAGING" . || die "Failed to create source tarball"
        
        # Create spec file
        cat > "$RPM_ROOT/SPECS/qemu-device-sdk.spec" << RPMEOF
Name:           qemu-device-sdk
Version:        $VERSION
Release:        1%{?dist}
Summary:        QEMU Device Module Development SDK
License:        GPLv2
URL:            https://www.qemu.org
Source0:        %{name}-%{version}.tar.gz
BuildArch:      $ARCH
Requires:       glib2-devel >= 2.56

%description
Headers and configuration files for building QEMU device modules
as external shared libraries.

%prep
%setup -q -c

%install
mkdir -p %{buildroot}
cp -a * %{buildroot}/

%files
/usr/include/qemu-device/
/usr/lib/pkgconfig/qemu-device.pc
/usr/share/doc/qemu-device-sdk/

%changelog
* $(date "+%a %b %d %Y") QEMU Project <qemu-devel@nongnu.org> - $VERSION-1
- Initial SDK package
RPMEOF

        # Build RPM
        rpmbuild --define "_topdir $RPM_ROOT" -bb "$RPM_ROOT/SPECS/qemu-device-sdk.spec" || die "Failed to create RPM"
        
        # Copy RPM to output
        cp "$RPM_ROOT/RPMS/$ARCH/qemu-device-sdk-$VERSION-"*.rpm "$OUTPUT" || die "Failed to copy RPM"
        ;;
        
    pkg)
        log "Creating macOS package..."
        die "macOS pkg format not yet implemented"
        ;;
        
    *)
        die "Unknown format: $FORMAT"
        ;;
esac

# Verify output exists
[[ ! -f "$OUTPUT" ]] && die "Output file was not created: $OUTPUT"

OUTPUT_SIZE=$(du -h "$OUTPUT" | cut -f1)
log "Successfully created: $OUTPUT ($OUTPUT_SIZE)"

# Show next steps
cat << EOF

${GREEN}Package created successfully!${NC}

Next steps:
-----------

1. Test the package:
   
   # For tarball:
   tar tzf $OUTPUT | head -20
   
   # For deb:
   dpkg -c $OUTPUT
   
   # For rpm:
   rpm -qlp $OUTPUT

2. Install and test:
   
   # For tarball:
   sudo tar xzf $OUTPUT -C /
   
   # For deb:
   sudo dpkg -i $OUTPUT
   
   # For rpm:
   sudo rpm -i $OUTPUT

3. Verify installation:
   
   pkg-config --cflags qemu-device
   pkg-config --modversion qemu-device
   ls /usr/include/qemu-device/

4. Build a test module (see docs/PACKAGER-GUIDE.md)

EOF
