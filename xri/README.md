# XRI — XLua Resource Inspector

## Current scope (P3.2)
Independent, read-only iOS arm64 tracer. It installs Dobby inline hooks on
exported Lua and IL2CPP entry points, collects bounded execution/registration
events, and correlates events observed in manually marked operation windows.
It **does not** modify game resources or claim that callback registration
equals callback execution. Exact supported target and ABI limitations are
documented in `P3_2_BINARY_AUDIT.md`.

## Historical P1 scope
The original P1 module did not install hooks, decode Lua scripts, enumerate
Lua states, patch memory, or change game resources. Later P2/P3 stages
extended runtime observation while preserving the public P1 scanner API.

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

The historical P2.5 source version was `0.2.5-p2.5`. The core and tracer remain
separate; there is still one hook installer and one bounded trace buffer
set, with no added polling loop.

## P3.1 — Energy/control differential observation

P3 reuses P2.5's operation marker rather than installing new hooks.

1. Choose **跟踪 → 对照 → 操作前**. Perform a similar ordinary UI
   action *without* changing energy, then press **操作后**.
2. Choose **体力 → 操作前**. Spend/restore energy and press **操作后**.
3. Export both snapshots using **导出 JSON**. In
   `Documents/XRI/trace.json` inspect `resourceProbes[].methodCounts`
   and `resourceComparisons[].methodDeltas`.

The analyzer records per-method frequencies live while the marker is
active, so old individual bridge events being evicted no longer truncates
method aggregation. It retains at most 256 distinct method names per
window; `methodAggregationOverflow` signals capacity loss.
Method frequency normalization uses recorded Lua protected calls as the
denominator. This is a **candidate signal**, not proof a method causes
a resource change; games using direct xLua-generated wrappers can bypass
`il2cpp_runtime_invoke` entirely. P3 does not read or change balances.

## P3.2 — Native callback registration, not execution
The target Mach-O export `lua_pushcclosure` can register a callback
directly invoked later by the Lua VM; the game's `luaD_precall`
contains a confirmed ARM64 indirect branch `blr x23`.
The unified tracer observes registration only and records a bounded
`cFunctionRegistrations` array plus `cFunctionRegistrationStats`
(total registrations, retained distinct callbacks and overflow count).
These rows identify callback pointer, owner image and image-relative
offset. They do **not** prove a call happened, identify Lua source
functions, or resolve the mapped managed C# method. Do not treat
`lua_pushcclosure` as a complete Lua-to-C# execution trace.

The current core source version is `0.3.2-p3`. No arbitrary
per-callback hooks or VM stack reads are enabled.

## P3.3–P4 — Target-gated callback execution evidence (2026-11-14)

The only internal Lua-VM hook added is `luaD_precall` on **exact** Taylor's Secret 1.8.9-69 UnityFramework UUID. The loader validates both UUID and expected `blr x23` ARM64 instruction. Without a match this hook is **not installed**. Other seven symbol-driven observers retain their prior behavior.

`trace.json` adds `cFunctionExecutions`, `cFunctionExecutionStats`, `bridges[].nativeCallback`, and `resourceProbes[].callbackCounts`. Native events mean callbacks **returned normally**, not that a currency method has been identified or that a resource changed. Only sampled individual events are retained outside active manual windows; during marked windows bounded per-callback counts are collected. `xri/tools/analyze_trace.py` produces a reproducible read-only candidate report, and `test_analyze_trace.py` provides synthetic unit tests.

**P5 is intentionally not implemented** until a real target-game trace, verified callback-to-method ABI mapping, actual resource data flow and controlled test preconditions are available. See `xri/HANDOFF.md`, `xri/KNOWN_ISSUES.md` and `xri/PROJECT_STATE.json`.
