# Makefile for minimal-sysbus device module

# Module name
MODULE_NAME = minimal-sysbus
MODULE_FILE = hw-$(MODULE_NAME).so

# Source files
SOURCES = $(MODULE_NAME).c
OBJECTS = $(SOURCES:.c=.o)

# Compiler and flags
CC = gcc
CFLAGS = -Wall -Wextra -O2 -fPIC
CFLAGS += $(shell pkg-config --cflags qemu-device 2>/dev/null || echo "-I/usr/include/qemu-device -I/usr/include/qemu-device/config -DBUILD_DSO")
CFLAGS += $(shell pkg-config --cflags glib-2.0)

LDFLAGS = -shared
LIBS = $(shell pkg-config --libs glib-2.0)

# Default target
all: $(MODULE_FILE)

# Build module
$(MODULE_FILE): $(OBJECTS)
	@echo "Linking $@..."
	$(CC) $(LDFLAGS) -o $@ $^ $(LIBS)
	@echo "Built: $@"
	@echo ""
	@echo "To use:"
	@echo "  export QEMU_MODULE_DIR=\$$(pwd)"
	@echo "  qemu-system-arm -M virt -device $(MODULE_NAME)"

# Compile source
%.o: %.c
	@echo "Compiling $<..."
	$(CC) $(CFLAGS) -c -o $@ $<

# Clean
clean:
	rm -f $(OBJECTS) $(MODULE_FILE)

# Install (for testing)
install: $(MODULE_FILE)
	@echo "Installing to ~/.local/lib/qemu/"
	@mkdir -p ~/.local/lib/qemu
	@cp $(MODULE_FILE) ~/.local/lib/qemu/
	@echo "Installed. Set: export QEMU_MODULE_DIR=~/.local/lib/qemu"

# Test
test: $(MODULE_FILE)
	@echo "Testing module load..."
	@echo "This will attempt to start QEMU with the device."
	@echo "Press Ctrl-C to exit."
	@echo ""
	export QEMU_MODULE_DIR=$(shell pwd) && \
	qemu-system-arm -M virt -device $(MODULE_NAME) -nographic -serial none || true

# Help
help:
	@echo "Targets:"
	@echo "  all      - Build the module (default)"
	@echo "  clean    - Remove built files"
	@echo "  install  - Install to ~/.local/lib/qemu/"
	@echo "  test     - Test module loading"
	@echo "  help     - Show this help"

.PHONY: all clean install test help
