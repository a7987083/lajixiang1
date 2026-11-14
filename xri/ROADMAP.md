# XRI evidence roadmap

- [x] P1 / P2 — image and Lua API snapshot, VM/chunk/protected calls, bounded trace export.
- [x] P3.1 — manual window aggregation and comparison.
- [x] P3.2 — native callback registration provenance, exact Taylor ARM64 binary audit.
- [x] P3.3 implementation — target-gated native callback normal-return records and per-window counts.
- [ ] P3.3 device acceptance — confirm hook installed, nonzero real callback events, no crash/latency regression on target UUID.
- [x] P3.4 observation — same-thread native callback to IL2CPP runtime-invoke association.
- [ ] P3.4 method identification — verify real callback -> business function via static xrefs + runtime observations.
- [x] P4 offline tooling — normalized control/differential evidence report; synthetic unit tests.
- [ ] P4 resource evidence — actual values before/after, caller, callback, parameters, storage/sync paths verified on real target.
- [ ] P5 controlled mutation — only after exact method ABI, reversible test design, and data-flow evidence. Verify in-game change and persistence separately.
