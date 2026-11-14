# XRI developer changelog

## 2026-11-14 — P3.3/P3.4/P4 observation implementation
- Audited original `feature/xri-universal` HEAD `c3586528207e1473df12ee4c82c94b97c7b1e876`, CI success.
- Reopened Taylor UnityFramework and disassembled actual `luaD_precall` function and indirect native invocation.
- Added target-UUID/instruction gated `luaD_precall` normal-return observer in existing Dobby hook installer.
- Added bounded callback events, per-resource operation counts and JSON/UI status.
- Added same-thread callback scope annotation for IL2CPP `runtime_invoke` (not exact mapping).
- Added sampling outside resource windows for game-thread overhead; protected-call TLS restoration.
- Added read-only evidence analyzer and synthetic tests to XRI CI build.
- Preserved all existing read-only behavior; no resource mutator or offset patch created.
- Build and device statuses must be read from latest workflow and user logs separately.
