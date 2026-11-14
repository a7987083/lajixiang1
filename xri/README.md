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

## P1 floating diagnostics UI (UIKit)
Source: `xri/src/XRIOverlay.mm`. Uses the H5GG floating-window interaction
model (independent scene-associated UIWindow, non-key initial presentation,
touch pass-through outside button/menu, dragging the floating bubble and menu).
The UI is our own native UIKit code, **not** H5GG's old UIWebView implementation
or its memory modification engine.

- Tap the round `XRI` bubble to open/close the panel.
- Scan the loaded image/export snapshot; show images, Lua/IL2CPP symbols.
- Filter names, copy complete JSON or save it in the host app's Caches folder.
- UI is initialized on the main thread; no global swizzling, private orientation
  APIs or periodic timers are used.
- Keyboard focus temporarily makes the overlay key only while editing the
  search field, restoring the previous key window afterward.

The UI does not imply Lua VM capture or resource modification. On stripped
frameworks, the exported-symbol detector may report unavailable symbols.

### H5GG reference
https://github.com/H5GG/H5GG — FloatWindow.h, FloatButton.h, makeWindow.h,
Tweak.mm. Used as a behavior reference, not copied code. Upstream is MIT.

### Verification
GitHub Actions compiles and signs the arm64 dylib; no device runtime evidence
yet. Touch pass-through, keyboard restoration, startup timing, orientation,
iPad scene behavior and game rendering require real-device tests.

## P2.1 — automatic lifecycle and export
- The tracer is initialized at dylib load. Image-add notifications schedule the
  hook installer on a dedicated serial queue; the dyld callback never patches
  code itself.
- Installation is idempotent by entry-point name. Already installed hooks are
  not installed again, and missing exports are retried when a new image loads.
- Hook activity is reported separately from successful API detection.
- Lua and IL2CPP export discovery is **not** equivalent to Lua VM event capture.
- The UI no longer has a manual start/stop toggle. A status view displays
  pending, partial, successful or failed installation.
- A single manual export writes **both** `snapshot.json` and `trace.json` to
  the active application's `Documents/XRI/` sandbox directory. Each write is
  atomic and replaces the previous version; no file I/O occurs inside hooks.
- The `xri_trace_start/stop` C symbols remain for compatibility with existing
  integrations, not as extra UI paths. The official UI never pauses capture.
- Inline hooks remain installed until process exit. Safe physical unhooking
  and exact target-game validation remain outstanding; do not represent a
  successful CI build as device verification.

## P2.5 — Trace search and resource observation

The same search field now filters image/export data and, on the trace tab,
VM events, Chunk names, execution call IDs, IL2CPP class/method names,
and manually bracketed resource-operation samples. The search filters
the display only; the exported `trace.json` retains the full bounded data.

To observe an operation, select **跟踪**, choose 钻石/金币/体力/其他,
tap **操作前**, perform one operation in the game, then tap **操作后**.
The resulting observation is included in the next JSON export under
`Documents/XRI/trace.json` → `resourceProbes`.

**P2.5 is not complete real-device validation.** Call-count deltas and
method names observed during a manually marked operation do not prove
that those calls changed currency. This tool does not read balances or
infer resource addresses. A genuine resource result requires target-game
binary and runtime evidence.

The fixed source version is `0.2.5-p2.5`. The core and tracer remain
separate; there is still one hook installer and one bounded trace buffer
set, with no added polling loop.
