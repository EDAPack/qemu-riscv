#!/bin/bash
# Check what's actually needed from build directory

echo "=== Checking for generated/build-time headers ==="
echo

# Look for config headers
echo "Config headers typically in build dir:"
echo "  - config-host.h"
echo "  - config-target.h (for each target)"
echo "  - qemu-version.h"
echo "  - generated headers from build system"
echo

# Check what osdep.h includes that comes from build
echo "osdep.h requires (from build):"
grep -E "include.*config|include.*qemu-version" qemu/include/qemu/osdep.h

echo -e "\nChecking QOM macros:"
grep -A5 "OBJECT_DECLARE" qemu/include/qom/object.h | head -20

echo -e "\nChecking for target-specific defines:"
grep -n "COMPILING_PER_TARGET\|CONFIG_TARGET" qemu/include/qemu/osdep.h | head -10
