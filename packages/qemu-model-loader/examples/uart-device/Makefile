# Makefile for example-uart device module

MODULE_NAME = example-uart
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
	@echo "  qemu-system-arm -M virt -device $(MODULE_NAME),chardev=uart0 \\"
	@echo "                  -chardev stdio,id=uart0"

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
	@echo "Testing UART module..."
	@echo "This will start QEMU with stdio connected to UART."
	@echo "Type characters to send to UART. Press Ctrl-A X to exit."
	@echo ""
	export QEMU_MODULE_DIR=$(shell pwd) && \
	qemu-system-arm -M virt -device $(MODULE_NAME),chardev=uart0 \
	                -chardev stdio,id=uart0,mux=on \
	                -nographic -serial none -monitor none || true

.PHONY: all clean install test
