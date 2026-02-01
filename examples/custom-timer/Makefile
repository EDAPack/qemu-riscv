QEMU_DIR := $(CURDIR)/qemu-riscv
OUTPUT := hw-custom-timer.so

all: $(OUTPUT)
	@echo "=== Module built: $(OUTPUT) ==="
	@echo "Usage: export QEMU_MODULE_DIR=$(CURDIR)"
	@echo "       ./qemu-riscv/bin/qemu-system-riscv64 -M virt -device custom-timer"

$(OUTPUT): custom-timer.c
	gcc -fPIC -DBUILD_DSO -shared -Wall -Wextra \
		-I$(QEMU_DIR)/include/qemu-device \
		$$(pkg-config --cflags glib-2.0) \
		-o $@ $< \
		$$(pkg-config --libs glib-2.0)

clean:
	rm -f $(OUTPUT)

test: $(OUTPUT)
	QEMU_MODULE_DIR=$(CURDIR) ./qemu-riscv/bin/qemu-system-riscv64 -M virt -device custom-timer -nographic
