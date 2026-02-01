# Documentation Index

## 📖 Reading Order

### For First-Time Readers
1. **[README.md](README.md)** - Start here for project overview
2. **[SUMMARY.md](SUMMARY.md)** - High-level findings and architecture
3. **[QUICK_REFERENCE.md](QUICK_REFERENCE.md)** - Practical examples and templates

### For Technical Deep Dive
1. **[dynamic-device-loading-design.md](dynamic-device-loading-design.md)** - Complete technical design

### For Implementation
1. **[QUICK_REFERENCE.md](QUICK_REFERENCE.md)** - Code templates
2. **[build-example.sh](build-example.sh)** - Build automation script

## 📄 Document Descriptions

### README.md (11KB)
**Purpose**: Project introduction and quick start guide  
**Audience**: Everyone  
**Contents**:
- Project overview
- Key findings summary
- Quick start example
- Architecture diagram
- Use cases
- Status and roadmap

### dynamic-device-loading-design.md (17KB)
**Purpose**: Complete technical design and analysis  
**Audience**: Architects, implementers, QEMU contributors  
**Contents**:
- QEMU architecture analysis
- QOM and device model deep dive
- Module loading system details
- Implementation design
- Complete working examples
- Security considerations
- Phase-by-phase implementation plan

### SUMMARY.md (8.3KB)
**Purpose**: Executive summary and quick reference  
**Audience**: Decision makers, developers seeking overview  
**Contents**:
- Key findings
- Architecture overview
- Quick start guide
- Benefits and challenges
- Proof of concept outline

### QUICK_REFERENCE.md (9.5KB)
**Purpose**: Developer cheat sheet  
**Audience**: Device module developers  
**Contents**:
- Minimal working templates
- Build commands
- Common patterns (IRQs, DMA, timers, etc.)
- API reference
- Troubleshooting guide
- Debugging tips

### build-example.sh (8.7KB)
**Purpose**: Automated build and test workflow  
**Audience**: Developers wanting to try it out  
**Contents**:
- Complete example UART device source
- Build automation
- Test scripts
- Verification steps
- Usage examples

## 🎯 By Use Case

### "I want to understand if this is possible"
→ Read: [SUMMARY.md](SUMMARY.md)

### "I want to see the big picture"
→ Read: [README.md](README.md)

### "I want to understand the technical details"
→ Read: [dynamic-device-loading-design.md](dynamic-device-loading-design.md)

### "I want to build a device module right now"
→ Read: [QUICK_REFERENCE.md](QUICK_REFERENCE.md)  
→ Run: `./build-example.sh`

### "I want to see a complete example"
→ Read: [dynamic-device-loading-design.md](dynamic-device-loading-design.md) (section: "Example: Complete Custom Device Module")  
→ Run: `./build-example.sh`

### "I want to understand QEMU's architecture"
→ Read: [dynamic-device-loading-design.md](dynamic-device-loading-design.md) (section: "Current QEMU Device Architecture")

### "I want to know what changed in QEMU"
→ Answer: Nothing! Read [SUMMARY.md](SUMMARY.md) for the key finding

## 📊 Document Sizes

| File | Size | Time to Read |
|------|------|--------------|
| README.md | 11KB | 5-10 min |
| SUMMARY.md | 8.3KB | 5 min |
| QUICK_REFERENCE.md | 9.5KB | 10 min (reference) |
| dynamic-device-loading-design.md | 17KB | 20-30 min |
| build-example.sh | 8.7KB | 5 min (scan) |

**Total**: ~54KB of documentation

## 🗂️ By Topic

### Architecture & Design
- [dynamic-device-loading-design.md](dynamic-device-loading-design.md)
- [SUMMARY.md](SUMMARY.md)

### Quick Start & Usage
- [README.md](README.md)
- [SUMMARY.md](SUMMARY.md)
- [build-example.sh](build-example.sh)

### API Reference & Examples
- [QUICK_REFERENCE.md](QUICK_REFERENCE.md)
- [dynamic-device-loading-design.md](dynamic-device-loading-design.md) (example section)

### Build System
- [build-example.sh](build-example.sh)
- [QUICK_REFERENCE.md](QUICK_REFERENCE.md) (Makefile section)

## 🔍 Finding Specific Information

### Device Types
- **SysBus devices**: QUICK_REFERENCE.md (minimal template)
- **PCI devices**: QUICK_REFERENCE.md (PCI template)
- **All types**: dynamic-device-loading-design.md (TypeInfo section)

### Build Instructions
- **Quick build**: QUICK_REFERENCE.md (build commands)
- **Full example**: build-example.sh
- **Makefile template**: QUICK_REFERENCE.md (Makefile section)

### QEMU Internals
- **QOM system**: dynamic-device-loading-design.md (QOM section)
- **Module loading**: dynamic-device-loading-design.md (module system)
- **Device registration**: dynamic-device-loading-design.md (registration flow)

### Troubleshooting
- **Common errors**: QUICK_REFERENCE.md (errors table)
- **Debugging**: QUICK_REFERENCE.md (debugging section)

## 📋 Checklists

### Before Building a Module
- [ ] Read QUICK_REFERENCE.md
- [ ] Have QEMU source available
- [ ] Have GLib development libraries
- [ ] Understand device type (SysBus, PCI, etc.)

### Implementing a Device
- [ ] Define TYPE_MY_DEVICE
- [ ] Create device state struct
- [ ] Implement MemoryRegionOps
- [ ] Create TypeInfo
- [ ] Add type_init() and module_obj()
- [ ] Build with -DBUILD_DSO
- [ ] Test with QEMU

### Testing a Module
- [ ] Set QEMU_MODULE_DIR
- [ ] Run `qemu -device mydevice,help`
- [ ] Verify in `info qtree` monitor command
- [ ] Test device functionality
- [ ] Check error handling

## 🚀 Quick Access

### Essential Commands
```bash
# Build a module
gcc -fPIC -DBUILD_DSO -shared -o hw-mydevice.so mydevice.c \
    -I/path/to/qemu/include $(pkg-config --cflags --libs glib-2.0)

# Use module
export QEMU_MODULE_DIR=$(pwd)
qemu-system-x86_64 -device mydevice

# Run example
./build-example.sh
```

### Essential Includes
```c
#define BUILD_DSO
#include "qemu/osdep.h"
#include "qemu/module.h"
#include "hw/sysbus.h"  // or hw/pci/pci.h
#include "qom/object.h"
```

### Essential Macros
```c
type_init(register_function)
module_obj(TYPE_MY_DEVICE)
OBJECT_DECLARE_SIMPLE_TYPE(MyState, MY_DEVICE)
```

## 📚 External References

### QEMU Documentation
- QOM: `qemu/docs/devel/qom.rst`
- QDEV: `qemu/docs/devel/qdev-api.rst`
- Device Usage: `qemu/docs/qdev-device-use.txt`

### QEMU Source
- Module System: `qemu/util/module.c`
- Type System: `qemu/qom/object.c`
- Device Monitor: `qemu/system/qdev-monitor.c`

### Example Devices
- Simple: `qemu/hw/misc/debugexit.c`
- Educational: `qemu/hw/misc/edu.c`
- Complex: `qemu/hw/block/fdc-isa.c`

## 💡 Tips

- Start with SUMMARY.md for quick understanding
- Use QUICK_REFERENCE.md while coding
- Refer to dynamic-device-loading-design.md for details
- Run build-example.sh to see it work
- Keep README.md bookmarked for common commands

## 🎓 Learning Path

```
Day 1: Understanding
├── README.md (overview)
└── SUMMARY.md (architecture)

Day 2: Deep Dive
└── dynamic-device-loading-design.md (complete design)

Day 3: Practice
├── QUICK_REFERENCE.md (while coding)
└── build-example.sh (hands-on)

Day 4+: Build Your Device
└── QUICK_REFERENCE.md (reference)
```

## ✅ Completion Checklist

After reading all documents, you should be able to:
- [ ] Explain how QEMU loads modules
- [ ] Understand QOM type system
- [ ] Write a basic device implementation
- [ ] Build a device as a shared library
- [ ] Load and test your module in QEMU
- [ ] Debug module loading issues
- [ ] Understand ABI considerations

---

**Navigation**: [README](README.md) | [Design](dynamic-device-loading-design.md) | [Summary](SUMMARY.md) | [Reference](QUICK_REFERENCE.md) | [Build](build-example.sh)
