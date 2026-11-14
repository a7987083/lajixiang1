# XRI universal roadmap (2026-11-14)

- [x] P1/P2 — image/exports, Lua VM/chunk/protected-call read-only tracing.
- [x] P3.2/P3.3 — native callback registration and UUID-gated normal callback returns.
- [x] P3.5 architecture — isolate exact-runtime internal ABI adapter; generic public-export fallback.
- [ ] P3.5 acceptance — two different games or xLua builds, including unknown-ABI fallback and lifecycle.
- [x] P3.6 partial — correlate protected Lua call, native callback and reflective IL2CPP invocation.
- [ ] P3.6 full Lua function graph — requires verified Lua debug ABI and non-destructive hook ownership.
- [x] P4 — custom operation markers, per-window aggregation, normalized offline candidate scoring.
- [ ] P4 acceptance — independent gaming baseline/sample replication and false-positive study.
- [x] P5 evidence ingestion — manually entered before/after/restart values explicitly labeled user-reported.
- [ ] P5 resource mutation proof — ABI, parameters, return, instance and data-flow independently verified.
- [x] P6 export — portable JSON **non-executable** candidate manifests with evidence gates.
- [ ] P6 executable action profiles — blocked until P5 evidence plus device and persistence results.
