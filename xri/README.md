# XRI — XLua Resource Inspector

## Scope (P1)
Independent, read-only iOS arm64 diagnostics dylib. It does **not** install hooks,
decode Lua scripts, enumerate Lua states, patch memory, or change game resources.

### Public C ABI
```c
#include "XRI.h"
size_t needed = xri_snapshot_json(NULL, 0);
char *buffer = malloc(needed);
if (buffer && xri_snapshot_json(buffer, needed) == needed) {
    // buffer contains a NUL-terminated JSON snapshot
}
free(buffer);
```
The caller owns the buffer. Snapshot collection runs synchronously. Images
may change between calls; do not interpret snapshots as atomic with dyld loads.

### JSON fields
- `schemaVersion`: 1
- `capabilities`: explicit implemented vs unimplemented behavior
- `images`: candidate image path, UUID, runtime load address, dyld slide
- `exports`: observed exact C exports, owning image, load-relative offset
- `detected`: **export visibility indicators**, not definitive framework
  identification. A stripped, statically linked or renamed xLua build may
  return false even when the framework is present.

An export's `loadRelativeOffset` is `function_address - mach_header_address`;
this is *not* an absolute VA, file offset, or portable version-independent RVA.

### Build and outputs
GitHub Actions: `.github/workflows/xri.yml`
Artifact: `XRI-P1-ios-arm64` containing the signed
`XLuaResourceInspector.dylib`, ZIP and SHA-256 manifest.

Existing CyberSkin build workflow is intentionally unchanged.

## P2 roadmap
Add event-driven lifecycle handling and a verified Lua VM/Chunk observer with
thread affinity, bounded collection and safe teardown. Hook installation and
resource editing are not included in P1.

## Verification boundaries
CI compilation and signature checks do not constitute injection or device
verification. Target-game ABI support must be verified against its exact
Mach-O UUID and exports before enabling any active instrumentation.
