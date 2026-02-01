# Implementation Plan - QEMU Model Loader Patches

## Project Mission

**Maintain QEMU patches** that enable binary distributions to:
1. Install device development SDK alongside QEMU
2. Support dynamic device module loading
3. Allow third-party device development without QEMU source

**Target users**: Binary packagers (EDAPack/qemu-riscv, Linux distros, etc.)

## Current Status

✅ **Phase 0: Research & Design (COMPLETE)**
- Architecture analysis done
- SDK requirements documented
- API stability defined
- Design documents complete

✅ **Phase 6: EDAPack Integration (COMPLETE)**
- Integration documentation created
- CI/CD workflow example provided
- Build modifications documented
- Release process documented
- Usage instructions complete

## Implementation Phases

### Phase 1: Core Patches (Week 1-2)

**Goal**: Create minimal working patch set for QEMU v9.2

#### Tasks

1. **Patch 0001: Add install-dev-sdk Target**
   ```bash
   File: patches/v9.2/0001-build-add-install-dev-sdk-target.patch
   
   Changes:
   - Modify meson.build to add install-dev-sdk target
   - Install all headers from include/ to $(includedir)/qemu-device/
   - Install generated config-host.h
   - Install generated qapi headers
   - Create directory structure
   ```

2. **Patch 0002: Generate pkg-config File**
   ```bash
   File: patches/v9.2/0002-build-generate-qemu-device-pc.patch
   
   Changes:
   - Add qemu-device.pc.in template
   - Configure template during meson setup
   - Install to $(libdir)/pkgconfig/
   ```

3. **Patch 0003: Add Device Module Documentation**
   ```bash
   File: patches/v9.2/0003-docs-add-device-module-guide.patch
   
   Changes:
   - Add docs/devel/device-modules.rst
   - Document stable API
   - Provide build examples
   ```

#### Validation
- [ ] Patches apply cleanly to QEMU v9.2.0
- [ ] `make install-dev-sdk` works
- [ ] pkg-config file is correct
- [ ] Headers are complete
- [ ] Example device compiles and loads

#### Deliverables
```
patches/v9.2/
├── 0001-build-add-install-dev-sdk-target.patch
├── 0002-build-generate-qemu-device-pc.patch
├── 0003-docs-add-device-module-guide.patch
└── README.md
```

---

### Phase 2: SDK Packaging Tools (Week 2-3)

**Goal**: Create tools to package SDK from patched QEMU

#### Tasks

1. **SDK Creator Script**
   ```bash
   File: sdk-package/create-sdk.sh
   
   Features:
   - Package installed SDK into tarball
   - Generate platform-specific packages (deb, rpm, pkg)
   - Validate completeness
   - Sign packages (optional)
   ```

2. **SDK Verifier Script**
   ```bash
   File: sdk-package/verify-sdk.sh
   
   Checks:
   - All required headers present
   - Generated configs valid
   - pkg-config file correct
   - Directory structure proper
   ```

3. **Packaging Templates**
   ```
   sdk-package/templates/
   ├── qemu-device.pc.in         ← pkg-config template
   ├── debian/                   ← Debian packaging
   │   ├── control
   │   ├── rules
   │   └── copyright
   ├── rpm/                      ← RPM spec
   │   └── qemu-device-sdk.spec
   └── homebrew/                 ← Homebrew formula
       └── qemu-device-sdk.rb
   ```

#### Validation
- [ ] Can create tarball from installed SDK
- [ ] Can create .deb package
- [ ] Can create .rpm package
- [ ] Verification script catches issues
- [ ] Packages install cleanly

#### Deliverables
```
sdk-package/
├── create-sdk.sh
├── verify-sdk.sh
├── templates/
└── README.md
```

---

### Phase 3: Example Devices (Week 3-4)

**Goal**: Create reference device implementations

#### Tasks

1. **Minimal SysBus Device**
   ```bash
   examples/minimal-sysbus/
   ├── minimal.c              ← Device implementation
   ├── Makefile               ← Build script
   ├── test.sh                ← Load test
   └── README.md              ← Documentation
   ```
   
   Features:
   - Bare minimum device
   - Single MMIO region
   - No IRQs, no properties
   - ~100 lines of code

2. **UART Device**
   ```bash
   examples/uart-device/
   ├── uart.c                 ← Full UART implementation
   ├── uart.h
   ├── Makefile
   ├── test.sh
   └── README.md
   ```
   
   Features:
   - Complete character device
   - IRQ support
   - Chardev backend
   - Properties
   - ~500 lines of code

3. **PCI Device**
   ```bash
   examples/pci-device/
   ├── pci-example.c          ← PCI device
   ├── Makefile
   ├── test.sh
   └── README.md
   ```
   
   Features:
   - PCI configuration space
   - Multiple BARs
   - MSI support
   - ~300 lines of code

#### Validation
- [ ] Each example compiles with SDK
- [ ] Modules load in QEMU
- [ ] Basic functionality works
- [ ] Documentation is clear
- [ ] Tests pass

#### Deliverables
```
examples/
├── minimal-sysbus/
├── uart-device/
├── pci-device/
├── test-all.sh
└── README.md
```

---

### Phase 4: Test Suite (Week 4-5)

**Goal**: Automated validation of patches and SDK

#### Tasks

1. **Patch Application Tests**
   ```bash
   tests/test-patch-apply.sh
   
   Tests:
   - Clone QEMU v9.2.0
   - Apply all patches
   - Verify clean application
   - Check for conflicts
   ```

2. **SDK Build Tests**
   ```bash
   tests/test-sdk-build.sh
   
   Tests:
   - Configure QEMU with patches
   - Build QEMU
   - Run install-dev-sdk
   - Verify SDK completeness
   - Validate pkg-config
   ```

3. **Module Build Tests**
   ```bash
   tests/test-module-build.sh
   
   Tests:
   - Use installed SDK
   - Build example modules
   - Check for warnings
   - Verify module structure
   ```

4. **Module Load Tests**
   ```bash
   tests/test-module-load.sh
   
   Tests:
   - Start QEMU with each module
   - Verify device registration
   - Check basic functionality
   - Test error cases
   ```

5. **Integration Tests**
   ```bash
   tests/test-integration.sh
   
   Tests:
   - Full workflow end-to-end
   - Multiple platforms
   - Different configurations
   ```

#### Validation
- [ ] All tests pass on Linux x86_64
- [ ] All tests pass on macOS ARM64
- [ ] Tests detect common issues
- [ ] CI/CD integration possible
- [ ] Clear failure messages

#### Deliverables
```
tests/
├── test-patch-apply.sh
├── test-sdk-build.sh
├── test-module-build.sh
├── test-module-load.sh
├── test-integration.sh
├── run-all.sh
└── README.md
```

---

### Phase 5: Documentation (Week 5-6)

**Goal**: Complete documentation for binary packagers

#### Tasks

1. **Packager Guide**
   ```
   docs/PACKAGER-GUIDE.md
   
   Sections:
   - Quick start for binary packagers
   - Applying patches
   - Building with SDK support
   - Creating SDK packages
   - Distribution strategies
   - Troubleshooting
   ```

2. **Patch Integration Guide**
   ```
   docs/PATCH-INTEGRATION.md
   
   Sections:
   - Automated integration (CI/CD)
   - Manual integration
   - Customization
   - Platform-specific notes
   - Version compatibility
   ```

3. **SDK Structure Specification**
   ```
   docs/SDK-STRUCTURE.md
   
   Sections:
   - Directory layout
   - Header organization
   - Generated file formats
   - pkg-config specification
   - Versioning scheme
   ```

4. **Device API Reference**
   ```
   docs/DEVICE-API.md
   
   Sections:
   - Stable API subset
   - Common patterns
   - Bus-specific APIs
   - Best practices
   - Migration guide
   ```

#### Validation
- [ ] Documentation is complete
- [ ] Examples work as shown
- [ ] Common questions answered
- [ ] Clear for target audience
- [ ] Follows QEMU style

#### Deliverables
```
docs/
├── PACKAGER-GUIDE.md
├── PATCH-INTEGRATION.md
├── SDK-STRUCTURE.md
├── DEVICE-API.md
├── EXAMPLES.md
└── design/            ← Existing design docs
```

---

### Phase 6: EDAPack Integration (Week 6-7)

**Goal**: Prove integration with real binary packager

#### Tasks

1. **EDAPack/qemu-riscv Integration**
   ```yaml
   Integration steps:
   1. Fork/clone EDAPack/qemu-riscv
   2. Add patch application to build
   3. Enable SDK installation
   4. Create SDK package
   5. Test with example devices
   6. Submit PR
   ```

2. **CI/CD Workflow**
   ```yaml
   .github/workflows/qemu-riscv-sdk.yml
   
   Jobs:
   - Apply patches
   - Build QEMU
   - Install SDK
   - Package SDK
   - Test examples
   - Upload artifacts
   ```

3. **Documentation**
   ```
   docs/integrations/EDAPACK.md
   
   Sections:
   - Integration overview
   - Build modifications
   - Release process
   - Usage instructions
   ```

#### Validation
- [ ] Builds successfully in EDAPack CI
- [ ] SDK packages are created
- [ ] Example devices work
- [ ] Documentation is clear
- [ ] PR accepted (or feedback incorporated)

#### Deliverables
```
docs/integrations/
├── EDAPACK.md
└── github-actions-example.yml
```

---

### Phase 7: Multi-Version Support (Week 7-8)

**Goal**: Support multiple QEMU versions

#### Tasks

1. **Port to QEMU v9.1**
   ```bash
   patches/v9.1/
   ├── 0001-*.patch
   ├── 0002-*.patch
   └── 0003-*.patch
   ```

2. **Port to QEMU master**
   ```bash
   patches/master/
   ├── 0001-*.patch
   ├── 0002-*.patch
   └── 0003-*.patch
   ```

3. **Version Update Script**
   ```bash
   scripts/update-patches.sh
   
   Usage:
   ./scripts/update-patches.sh v9.2 v9.3
   
   Actions:
   - Rebase patches
   - Resolve conflicts
   - Run tests
   - Commit results
   ```

4. **Version Compatibility Matrix**
   ```
   docs/VERSION-MATRIX.md
   
   QEMU Version | Patches | Tested | Notes
   -------------|---------|--------|-------
   v9.2.0       | ✓       | ✓      | Stable
   v9.1.x       | ✓       | ✓      | Backport
   v10.0-rc     | ✓       | ~      | Preview
   master       | ✓       | ~      | Development
   ```

#### Validation
- [ ] Patches apply to each version
- [ ] Tests pass on each version
- [ ] SDK works on each version
- [ ] Migration path documented
- [ ] Update script works

#### Deliverables
```
patches/
├── v9.1/
├── v9.2/
├── v10.0/
├── master/
└── README.md

scripts/
└── update-patches.sh
```

---

### Phase 8: Upstream Preparation (Week 8-9)

**Goal**: Prepare patches for QEMU upstream submission

#### Tasks

1. **Patch Refinement**
   - Follow QEMU coding style strictly
   - Add detailed commit messages
   - Split into logical commits
   - Add Signed-off-by lines

2. **Upstream Branch**
   ```bash
   patches/upstream/
   ├── v1/                    ← First submission
   │   ├── 0000-cover-letter.patch
   │   ├── 0001-*.patch
   │   ├── 0002-*.patch
   │   └── 0003-*.patch
   └── v2/                    ← After feedback
   ```

3. **Submission Materials**
   ```
   patches/upstream/
   ├── cover-letter.txt       ← Series overview
   ├── submission-notes.txt   ← How to review
   └── testing-notes.txt      ← Test results
   ```

4. **Upstream Documentation**
   ```
   docs/UPSTREAM.md
   
   Sections:
   - Submission process
   - Review cycle
   - Expected feedback
   - Incorporation timeline
   ```

#### Validation
- [ ] Patches follow QEMU style
- [ ] Commit messages are clear
- [ ] Cover letter is compelling
- [ ] Testing is documented
- [ ] Ready for review

#### Deliverables
```
patches/upstream/
└── v1/
    ├── 0000-cover-letter.patch
    ├── 0001-build-add-install-dev-sdk-target.patch
    ├── 0002-build-generate-qemu-device-pc.patch
    └── 0003-docs-add-device-module-guide.patch

docs/UPSTREAM.md
```

---

## Repository Organization

### Final Structure

```
qemu-model-loader/
├── README.md                      ← Project overview (updated)
├── PROJECT-README.md              ← This file
├── CHANGELOG.md                   ← Version history
├── LICENSE                        ← GPLv2 for patches, MIT for scripts
│
├── patches/                       ← MAIN DELIVERABLE
│   ├── v9.1/
│   ├── v9.2/                      ← Primary focus
│   ├── v10.0/
│   ├── master/
│   ├── upstream/                  ← Upstream submissions
│   └── README.md
│
├── sdk-package/                   ← SDK packaging tools
│   ├── create-sdk.sh
│   ├── verify-sdk.sh
│   ├── templates/
│   │   ├── qemu-device.pc.in
│   │   ├── debian/
│   │   ├── rpm/
│   │   └── homebrew/
│   └── README.md
│
├── docs/                          ← Documentation
│   ├── PACKAGER-GUIDE.md          ← For binary distributors
│   ├── PATCH-INTEGRATION.md       ← CI/CD integration
│   ├── SDK-STRUCTURE.md           ← SDK specification
│   ├── DEVICE-API.md              ← API reference
│   ├── VERSION-MATRIX.md          ← Version compatibility
│   ├── UPSTREAM.md                ← Upstream submission
│   ├── integrations/              ← Integration examples
│   │   └── EDAPACK.md
│   └── design/                    ← Design documents
│       ├── dynamic-device-loading-design.md
│       ├── SDK-REQUIREMENTS.md
│       ├── BINARY-SDK-SUMMARY.md
│       └── ...
│
├── examples/                      ← Example device modules
│   ├── minimal-sysbus/
│   │   ├── minimal.c
│   │   ├── Makefile
│   │   ├── test.sh
│   │   └── README.md
│   ├── uart-device/
│   ├── pci-device/
│   ├── test-all.sh
│   └── README.md
│
├── tests/                         ← Validation suite
│   ├── test-patch-apply.sh
│   ├── test-sdk-build.sh
│   ├── test-module-build.sh
│   ├── test-module-load.sh
│   ├── test-integration.sh
│   ├── run-all.sh
│   └── README.md
│
└── scripts/                       ← Maintenance utilities
    ├── update-patches.sh          ← Rebase patches
    ├── release.sh                 ← Create releases
    ├── prepare-upstream.sh        ← Format for upstream
    └── README.md
```

---

## Timeline

| Phase | Duration | Deliverable |
|-------|----------|-------------|
| 0. Research & Design | Complete | Design documents |
| 1. Core Patches | 2 weeks | QEMU patches |
| 2. SDK Packaging | 1 week | Packaging scripts |
| 3. Example Devices | 1 week | Reference implementations |
| 4. Test Suite | 1 week | Automated tests |
| 5. Documentation | 1 week | User guides |
| 6. EDAPack Integration | 1 week | Real-world validation |
| 7. Multi-Version | 1 week | Version support |
| 8. Upstream Prep | 1 week | Submission ready |
| **Total** | **~9 weeks** | **Production ready** |

---

## Success Criteria

### Phase 1-5 Success (MVP)
- [ ] Patches apply cleanly to QEMU v9.2.0
- [ ] `make install-dev-sdk` creates complete SDK
- [ ] pkg-config file works correctly
- [ ] Example device compiles with SDK
- [ ] Example device loads in QEMU
- [ ] Tests pass on Linux x86_64

### Phase 6 Success (Real-World)
- [ ] EDAPack/qemu-riscv integrates patches
- [ ] SDK package is created in their CI
- [ ] Example works with their QEMU build
- [ ] Documentation is sufficient

### Phase 7-8 Success (Production)
- [ ] Multiple QEMU versions supported
- [ ] Tests pass on multiple platforms
- [ ] Ready for upstream submission
- [ ] Documentation complete

### Upstream Success (Long-term)
- [ ] Patches submitted to qemu-devel@
- [ ] Review feedback incorporated
- [ ] Patches merged into QEMU
- [ ] No longer need patch maintenance

---

## Risk Mitigation

### Risk: Patches don't apply cleanly
**Mitigation**: Test against multiple QEMU commits, provide update script

### Risk: SDK size too large
**Mitigation**: Benchmark size, optimize if needed, provide compression

### Risk: ABI breaks across versions
**Mitigation**: Document stable API subset, version SDK with QEMU

### Risk: Upstream rejects patches
**Mitigation**: Early feedback, incremental submission, alternative patch approach

### Risk: Binary packagers don't adopt
**Mitigation**: Make integration trivial, provide CI templates, demonstrate value

---

## Next Immediate Steps

1. **Create repository structure**
   ```bash
   mkdir -p patches/{v9.2,master}
   mkdir -p sdk-package/{templates/{debian,rpm}}
   mkdir -p examples/{minimal-sysbus,uart-device,pci-device}
   mkdir -p tests scripts docs/integrations
   ```

2. **Move existing docs**
   ```bash
   mv *-design.md SDK-REQUIREMENTS.md docs/design/
   mv QUICK_REFERENCE.md docs/DEVICE-API.md
   ```

3. **Start Phase 1**
   ```bash
   cd /tmp
   git clone https://gitlab.com/qemu-project/qemu.git
   cd qemu
   git checkout v9.2.0
   
   # Start creating patches...
   ```

---

## Questions to Resolve

1. **Patch granularity**: One big patch or multiple small patches?
   - **Decision**: Multiple logical patches (easier to review/maintain)

2. **SDK versioning**: Separate from QEMU version?
   - **Decision**: Follow QEMU version (SDK 9.2.x for QEMU 9.2.x)

3. **Platform support**: All platforms or subset?
   - **Decision**: Start with Linux/macOS, add Windows later

4. **Upstream strategy**: Submit now or after field testing?
   - **Decision**: Field test with EDAPack first, then upstream

---

## Summary

**Purpose**: Maintain QEMU patches for device module SDK support

**Primary Users**: Binary packagers like EDAPack/qemu-riscv

**Main Deliverable**: Patch set + SDK packaging tools

**Timeline**: ~9 weeks to production-ready

**Success Metric**: EDAPack/qemu-riscv ships QEMU with SDK support

**End Goal**: Patches merged upstream, no longer need maintenance
