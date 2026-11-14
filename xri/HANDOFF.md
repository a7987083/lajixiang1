# XRI handoff — evidence-gated progression

## Stable baseline and current branch
- Repository: `a7987083/lajixiang1`
- Branch: `feature/xri-universal`
- Original P3.2 baseline: `c3586528207e1473df12ee4c82c94b97c7b1e876`.
- Development HEAD at documentation generation: `d96bc71fe7b35e91d43e57b0c4492e09ee0f573d`. Check `git rev-parse HEAD` for current head.
- XRI sources: `xri/src/XRI.cpp`, `XRITrace.cpp`, `XRIOverlay.mm`.
- Existing CyberSkin files and root-level HANDOFF/PROJECT_STATE are **different projects**; do not derive XRI state from them.

## Exact tested static binary
- UnityFramework 150859024 bytes, SHA-256 `d7ebc545a1568bdf78f026b86cd4fe6b1df77509f165621cd29546de3fbf29ae`.
- UUID `CC89F3E2-E288-3FBF-AB96-1FD4E58F047A`.
- Metadata SHA-256 `e915547090ff9ea594bca4432ac5e722411ef033b45f78b9f38ec3c2b7475f68`.
- `luaD_precall` image-relative VA 0x032534D8. At 0x032537AC ARM64 instruction `blr x23` (opcode `0xD63F02E0`).
- Target TValue +0x8 type tag, light C function 0x16 stores callback directly, CClosure 0x26 stores callback at closure +0x18. All require exact UUID and opcode checks.

## Implemented paths
- Single Dobby hook installer: exported Lua VM/chunk, `lua_pushcclosure`, `lua_pcallk`, IL2CPP reflection invoke.
- P3.3: an optional target-UUID gated `luaD_precall` hook; records callbacks only after normal return, not all entries (longjmp may bypass).
- P3.4: TLS native callback scope attached to `il2cpp_runtime_invoke` records. Scope means same-thread nesting, NOT an exact generated wrapper mapping.
- P4: `cFunctionExecutions`, `callbackCounts`, normalized read-only sample differential and `xri/tools/analyze_trace.py`.
- UI still contains only observation and export functions. No game-resource mutation path.

## Validation distinction
- GitHub Actions compiles arm64 dylib and runs synthetic Python evidence unit tests; this is not device or behavior validation.
- No current target game run, no before/after balances, no persistence or server confirmation.
- Missing live evidence: active luaD_precall hook status, resource-marked callback counts, candidate address-owner-offset verification and gameplay value changes.

## Collect evidence
1. Inject **only** XRI dylib in Taylor's Secret 1.8.9-69; confirm UUID matches and `luaD_precall` installed in `trace.json.hooks`.
2. In XRI **跟踪**, perform `其他` control before/after, then one `体力` test, then `金币` and `钻石` tests, one operation each.
3. Export `Documents/XRI/trace.json` and `snapshot.json`; do not send identifiers or login secrets.
4. Run `python3 xri/tools/analyze_trace.py trace.json --snapshot snapshot.json --output evidence.json`.
5. Confirm specific candidate in exact binary and runtime before implementing a controlled, reversible mutation. Never infer function signatures from a single address or frequency delta.

## Risks and known limits
See `xri/KNOWN_ISSUES.md`. Do not copy confirmed values to a different Mach-O UUID.
