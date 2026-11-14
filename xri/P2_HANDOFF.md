# XRI P2 — Runtime tracing handoff

## Repository
- Repository: `a7987083/lajixiang1`
- Branch: `feature/xri-universal`
- Stable baseline: P1 UI at `a98e1bbd38f80728557d415d967ce38e10f61c25`
- Existing CyberSkin implementation/build is intentionally untouched.

## Implemented in P2
- `xri/include/XRITrace.h`: C ABI for start/stop/clear/snapshot.
- `xri/src/XRITrace.cpp`: read-only VM lifecycle and Lua Chunk observer.
- `xri/src/XRIOverlay.mm`: trace tab, trace toggle, JSON copy and export.
- `.github/workflows/xri.yml`: arm64 iOS signed dylib artifact.
- Exact API signatures for `xluaL_loadbuffer(lua_State*,const char*,int,const char*)`,
  `luaL_loadbufferx(lua_State*,const char*,size_t,const char*,const char*)`,
  `luaL_newstate()`, and `lua_close(lua_State*)`.
- Fixed capacity: last 256 chunks and last 128 VM lifecycle events.
- Captures Chunk name, declared length, bounded prefix FNV-1a64, return code
  and state pointer. Does not store Lua source/bytecode or modify Lua stack.
- Avoids duplicate nested loadbuffer events on the same thread.

## Runtime preconditions and limitations
- **Optional DobbyHook provider must already be loaded** and export the
  compatible `DobbyHook` symbol; this dylib does not bundle Dobby.
- With no provider, `xri_trace_start()` returns 0 with an explicit reason.
  UI remains useful for P1 export analysis.
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
- Next: a tested, version-pinned inline-hook provider with explicit
  uninstall support and integration tests; then real Lua VM / Chunk test
  evidence before P3 cross-language bridging.
