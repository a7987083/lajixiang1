# XRI known issues — current

- **P3.3 target-only:** native `luaD_precall` instrumentation requires exact Taylor 1.8.9-69 UnityFramework UUID and an instruction check; other versions gracefully skip this hook.
- **Normal-return scope:** a Lua error may longjmp past the native hook return; events omitted and TLS is restored at the next protected-call boundary if one exists. Do not claim all C callbacks are covered.
- **Performance:** all callbacks are counted; only one in sixteen callback event rows is retained outside a marked resource window. During manually marked windows, aggregation includes all observed returns; max 256 distinct callbacks, with overflow flag.
- **Method identity:** `nativeCallback` on IL2CPP records is same-thread nesting, not proof the callback is a particular generated C# wrapper. Direct generated calls may bypass `il2cpp_runtime_invoke`.
- **P4 comparisons:** manual windows are not causal experiments by themselves. Operation duration and background game activity may differ; normalization is by observed callbacks, not game ticks.
- **P5 blocked:** no verified gold/gem/energy business method or signature; no runtime resource value or server persistence evidence. No mutation endpoint should be introduced based on frequency ranking.
- **CI vs device:** a green CI build is not a successful injection, runtime hook test, gameplay change or server persistence verification.
- **Existing legacy docs:** root `HANDOFF.md`, `ROADMAP.md`, and `PROJECT_STATE.json` describe CyberSkin, not XRI. XRI-specific docs live in `xri/`.
