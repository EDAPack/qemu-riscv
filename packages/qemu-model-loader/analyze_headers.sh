#!/bin/bash
echo "=== Headers needed for minimal device module ==="
echo

# Core device headers
echo "Core Device API Headers:"
find qemu/include -path "*/hw/core/*.h" -name "*.h" | sort

echo -e "\nQOM Headers:"
find qemu/include -path "*/qom/*.h" -name "*.h" | sort

echo -e "\nQEMU Utility Headers:"
find qemu/include -path "*/qemu/*.h" -name "*.h" | sort

echo -e "\nBus-specific Headers:"
find qemu/include -path "*/hw/sysbus.h" -o -path "*/hw/pci/*.h" -o -path "*/hw/isa/*.h" | sort

echo -e "\nTotal header count:"
find qemu/include -name "*.h" | wc -l
