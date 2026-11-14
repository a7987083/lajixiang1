# XRI P2 — Runtime tracing handoff

## Repository
- Repository: `a7987083/lajixiang1`
- Branch: `feature/xri-universal`
- Stable baseline: P1 UI at `a98e1bbd38f80728557d415d967ce38e10f61c25`
- Existing CyberSkin implementation/build is intentionally untouched.

## Implemented in P2
- `xri/include/XRITrace.h`: C ABI for start/stop/clear/snapshot.
- `xri/src/XRITrace.cpp`: read-only VM lifecycle and Lua Chunk observer.
- `xri/src/XRIOverlay.mm`: automatic trace status, event views, JSON copy and export.
- `.github/workflows/xri.yml`: arm64 iOS signed dylib artifact.
- Exact API signatures for `xluaL_loadbuffer(lua_State*,const char*,int,const char*)`,
  `luaL_loadbufferx(lua_State*,const char*,size_t,const char*,const char*)`,
  `luaL_newstate()`, and `lua_close(lua_State*)`.
- Fixed capacity: last 256 chunks and last 128 VM lifecycle events.
- Captures Chunk name, declared length, bounded prefix FNV-1a64, return code
  and state pointer. Does not store Lua source/bytecode or modify Lua stack.
- Avoids duplicate nested loadbuffer events on the same thread.

## Runtime preconditions and limitations
- Official CI artifact **bundles a statically linked Dobby provider**, pinned to
  `jmpews/Dobby` commit `5dfc8546954ce3b3198132ab13fddb89ee92cdd7`.
  The included Apache-2.0 license is packaged as `DOBBY-LICENSE.txt`.
  Non-official builds without `XRI_BUNDLED_DOBBY` still require an already
  loaded compatible provider; start returns 0 when unavailable.
- Targets are exact exported symbols in already loaded candidate images;
  stripped symbols, different Lua backends and libraries outside the
  allowlist may not be instrumented.
- Start after Lua VM initialization does not reconstruct older VM creation
  or previously loaded Chunk events.
- Pausing disables recording but does **not** unpatch inline hooks.
  Removal of installed hooks is intentionally not attempted without
  ownership and concurrency guarantees. Repeated start does not double-hook.
- Callback writes and Lua stack mutations are prohibited.
- Event state pointers are observation identifiers, **not** callable handles.
- Chunk hash is only of the first 1 MiB and should not be used as a
  full-content integrity digest if `hashTruncated == true`.
- UI trace tab displays the latest bounded events on demand; no polling.
- This stage does not promise gold/gem hook discovery or resource modification.

## Evidence, testing, next phase
- CI verifies compilation, arm64 linkage, ad-hoc signing, exported symbols
  and Artifact upload.
- No injection, real-device or game version testing completed.
- Next: real-device Lua VM/Chunk observations and Hook restoration safety
  tests on the exact game binary. P3 cross-language bridging must not begin
  with unverified VM ABI or incomplete Hook lifecycle evidence.

## P2.3 — protected Lua execution boundaries
- Adds a fifth target: exact exported `lua_pcallk`, with the Lua 5.3/5.4
  compatible signature (Lua state, nargs, nresults, errfunc, context,
  continuation). Does not assume `lua_resume` ABI is portable between 5.3/5.4.
- Records observed protected-call completion with state pointer, thread ID,
  argument count, expected result count, error handler index, return status,
  monotonic duration and sequence number.
- Last 512 events are stored; total and evicted-count metrics are exported.
- No Lua stack reads/writes, lua_Debug layout assumptions, lua_sethook
  interference, or unsafe string dereferencing are introduced.
- Exports records under `executions` and `executionStats` in the existing
  `Documents/XRI/trace.json`. The floating trace tab shows execution events
  independently from VM and script loader events.
- This is **a protected-call boundary observer**, not a complete Lua VM
  instruction/function profiler. Lua-to-Lua internal calls and calls bypassing
  the exported API remain unobserved. A zero count is not evidence of no Lua
  execution; check the installed `lua_pcallk` Hook first.
- To obtain per-function names, source locations or internal VM callbacks,
  the next iteration must verify the target Lua ABI and select a safe
  instrumentation strategy with device-level evidence.
- P2.2 detailed Hook inspection is deliberately skipped at user request;
  existing diagnostic fields remain in JSON. P2.4 follows below; P2.5 observation support is described below; no target-game runtime validation yet.

## P2.4 — conservative Lua / IL2CPP correlation

- Observes the real exported `il2cpp_runtime_invoke` entry, only if the
  four public metadata exports also resolve from the **same image**:
  `il2cpp_method_get_name`, `il2cpp_method_get_class`,
  `il2cpp_class_get_name`, `il2cpp_class_get_namespace`.
- A TLS context is opened before `lua_pcallk` calls its original trampoline
  and closed when it returns. `callId` in `executions` pairs with
  `protectedCallId` in `bridges`; method records are collected only for
  `il2cpp_runtime_invoke` calls occurring during the same-thread Lua scope.
- The correlation is labelled `same_thread_nested`, **not** an asserted
  wrapper/function identity. Thread-switching and generated direct C# wrappers
  are not observed. Zero bridge events does not prove no Lua->C# activity.
- No method arguments or returned values are dereferenced, no game resources
  are mutated, and no `MethodInfo` or `Il2CppClass` field offsets are assumed.
  Public metadata getter APIs provide class/namespace/method strings.
- The existing single Hook installer owns this additional hook; there is no
  second engine, polling thread, or fallback-to-guessed-offset path.
- `trace.json` adds `bridges`, `bridgeStats` (last 256 and total/evicted
  counts), and `executions[].callId`. Existing export paths are unchanged.
- Runtime/dylib load/injection and real-device event capture are **unverified**.
  P2.5 resource-operation validation has not started.

## P2.5 — trace search and manual resource-operation observation

- The existing search field now filters VM, Chunk, Lua protected calls,
  IL2CPP bridge records and P2.5 operation samples. Matching is textual
  and case/diacritic insensitive; raw JSON export remains **unfiltered**.
- In the existing **跟踪** tab, choose 钻石 / 金币 / 体力 / 其他,
  click **操作前**, perform the game operation, then click **操作后**.
  This adds an observation window, not a new hook.
- The C ABI `xri_resource_probe_begin(kind)` and
  `xri_resource_probe_end()` delimit windows using the existing event
  sequence and execution/bridge counters. At most 24 completed samples
  are retained; 20 method identifiers per sample are shown. Existing
  callback buffers remain bounded.
- `trace.json` exports `resourceProbes`, `activeResourceProbe` and
  `resourceValidation: observation_only_no_currency_value_read`.
  Samples explicitly report `calls_observed_unverified_resource` or
  `no_calls_observed_unverified_resource`.
- **No balance or currency value is read or inferred.** Counting calls
  while a diamond/gold/energy action occurs is not proof of the observed
  method being responsible for resource change. Real device testing
  and verified game data/ABI are required for true resource validation.
- This release intentionally does **not** add speculative currency-value
  hooks, a second hook engine or a separate search index.

## P3.1 — live bounded aggregation and energy/control differential
- Live aggregation counts each observed `il2cpp_runtime_invoke` during the
  user-marked operation **inside the same existing hook callback**, before
  the 256-record bridge ring can evict the event.
- The per-window aggregate keys on namespace + class + method name, capped
  at 256 distinct names. `methodAggregationOverflow` reports calls to
  additional unseen method names; `matchedMethodCount` counts all observed
  bridge invocations in the marked window, not merely the retained tail.
  Method overloads with the same display name remain merged.
- Completed `resourceProbes[].methodCounts` retains bounded per-method
  frequencies independent of `bridges` ring eviction. Existing
  `observedMethods` compatibility list now contains the 20 most frequent
  names instead of arbitrary tail events.
- A user-labelled **other** sample is a baseline. Every subsequent
  user-labelled **energy** sample is paired with the nearest *earlier*
  other baseline, until a new baseline is captured. JSON exports
  `resourceComparisons[].methodDeltas` with both rates normalized per
  1,000 recorded Lua protected-call boundaries. No baseline means no
  comparison is generated. Both windows must contain Lua calls to set
  `comparisonReady=true`.
- UI displays top methods from per-operation aggregation plus top
  positive normalized delta methods, explicitly labelled observational
  not causal. Raw JSON retains full bounded aggregate and comparison data.
- Operational test: first record **对照** while performing a normal
  similar UI action (no energy change), then record **体力** while actually
  spending or restoring energy; export `Documents/XRI/trace.json`.
- Existing prior P2.5 JSON cannot reconstruct method counts already
  evicted; P3 needs a fresh real-device sample.
- Real-device resource/balance change, direct generated-wrapper invocation
  coverage, causal method identification, and on-device UI performance
  **remain unverified**.

## P3.2 — Target verified xLua C callback registration

- Actual reference image in user supplied archive:
  `UnityFramework`, UUID `CC89F3E2-E288-3FBF-AB96-1FD4E58F047A`.
  See `xri/P3_2_BINARY_AUDIT.md` for actual ARM64 instructions and
  verified export addresses.
- The exact target shows `luaD_precall` executing a C callback with
  `blr x23` at image-relative `0x032537AC`. Thus the earlier assumption
  that every Lua-to-native path calls `il2cpp_runtime_invoke` is false.
- Existing HookManager/installer now observes `lua_pushcclosure` for
  callback registration provenance, with a single bounded 512-address
  registry. Results include runtime image and load-relative address;
  all entries are explicitly labelled registration **not execution**.
- No guessed per-MethodInfo offsets, arbitrary wrapper function Hook,
  Lua stack reads, or internal VM ABI assumptions were added.
- A registration does **not** prove that its CFunction ran or which
  managed MethodInfo it represents. P3.3 needs further validated
  instrumentation to claim execution-level bridging.
- CI build is not a real-device validation.
