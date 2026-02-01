# QEMU Model Loader - Version Compatibility Matrix

## Supported QEMU Versions

| QEMU Version | Patches | Status | Tested | Notes |
|--------------|---------|--------|--------|-------|
| v10.0.x      | v9.2    | ✓ Stable | ✓ | Recommended |
| v9.2.x       | v9.2    | ✓ Stable | ✓ | Fully supported |
| v9.1.x       | v9.2    | ⚠ Beta  | ~ | May need adjustments |
| master       | v9.2    | ⚠ Dev   | ~ | For testing only |

## Patch Versions

- **v9.2**: Current stable (recommended)
- **v9.1**: Backport (if needed)
- **v10.0**: Forward port (when available)

## Platform Support

| Platform | Status | Tested |
|----------|--------|--------|
| Linux x86_64 | ✓ | ✓ |
| Linux ARM64 | ✓ | ✓ |
| macOS x86_64 | ✓ | ~ |
| macOS ARM64 | ⚠ | - |
| Windows | ⚠ | - |

## Update Policy

New QEMU versions tested within 2 weeks of release.  
Patches updated as needed for compatibility.
