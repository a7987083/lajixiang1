# ROADMAP

## Phase 1 — Cyber skin v1
- [x] Recover original UIKit hook registration and exact replacement IMP addresses.
- [x] Build first independent skin and derivative loader experiment.
- [x] GitHub Actions build green (`35830125612`).
- [x] Real-device acceptance attempted.
- [x] Record failures: standalone little/no visible effect; strong-load derivative startup crash.

## Phase 2 — Exact VIP hook chaining v2
- [x] Recover supplied-build UUID and runtime theme/original-IMP slots.
- [x] Replace UIWindow heuristic targeting with direct observation of VIP's own image/color replacements.
- [x] Add UUID gate for every supplied-build preferred-VA dereference.
- [x] Change derivative companion dependency from strong `LC_LOAD_DYLIB` to `LC_LOAD_WEAK_DYLIB`.
- [x] Fix first CI compiler error without changing SDK/deployment target.
- [x] GitHub Actions build green (`35832535796`), Artifact `10738062034`.
- [ ] Real-device verify v2 does not crash.
- [ ] Verify floating icon replacement.
- [ ] Verify menu icon replacement.
- [ ] Verify cyber color scope and confirm game UI is unaffected.

## Next task
Inject `CyberSkinStandalone.dylib` v2 alongside the original supplied VIPCrackPlugin first. If that passes, test `VIPCrackPlugin_Cyber_v2.dylib` with the same helper present. For any remaining failure, capture the app crash log or `[CyberSkin]` console lines before changing code again.
