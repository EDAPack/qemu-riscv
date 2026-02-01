# Makefile for example-pci device module

MODULE_NAME = example-pci
MODULE_FILE = hw-$(MODULE_NAME).so

SOURCES = $(MODULE_NAME).c
OBJECTS = $(SOURCES:.c=.o)

CC = gcc
CFLAGS = -Wall -Wextra -O2 -fPIC
CFLAGS += $(shell pkg-config --cflags qemu-device 2>/dev/null || echo "-I/usr/include/qemu-device -I/usr/include/qemu-device/config -DBUILD_DSO")
CFLAGS += $(shell pkg-config --cflags glib-2.0)

LDFLAGS = -shared
LIBS = $(shell pkg-config --libs glib-2.0)

all: $(MODULE_FILE)

$(MODULE_FILE): $(OBJECTS)
	@echo "Linking $@..."
	$(CC) $(LDFLAGS) -o $@ $^ $(LIBS)
	@echo "Built: $@"
	@echo ""
	@echo "To use:"
	@echo "  export QEMU_MODULE_DIR=\$$(pwd)"
	@echo "  qemu-system-x86_64 -M pc -device $(MODULE_NAME)"

%.o: %.c
	@echo "Compiling $<..."
	$(CC) $(CFLAGS) -c -o $@ $<

clean:
	rm -f $(OBJECTS) $(MODULE_FILE)

install: $(MODULE_FILE)
	@mkdir -p ~/.local/lib/qemu
	@cp $(MODULE_FILE) ~/.local/lib/qemu/
	@echo "Installed to ~/.local/lib/qemu/"

test: $(MODULE_FILE)
	@echo "Testing PCI module..."
	@echo "This will start QEMU with the PCI device."
	@echo "Press Ctrl-C to exit."
	@echo ""
	export QEMU_MODULE_DIR=$(shell pwd) && \
	qemu-system-x86_64 -M pc -device $(MODULE_NAME) -nographic -serial none || true

.PHONY: all clean install test
