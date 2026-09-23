# ROADMAP

## Phase 1 — Cyber skin v1
- [x] Recover major UIKit hook registration.
- [x] Build first independent skin and derivative loader experiment.
- [x] CI green (`35830125612`).
- [x] Device acceptance attempted: standalone little/no effect; derivative startup crash.

## Phase 2 — VIP hook chaining v2
- [x] Recover exact supplied-build UUID and runtime IMP/theme slots.
- [x] Replace strong dependency with weak loading.
- [x] CI green (`35832535796`).
- [x] Device acceptance attempted: derivative no crash, but appearance still unchanged.

## Phase 3 — Direct VIP resource-slot control v3
- [x] Recover actual icon replacement `NSData *` slot at preferred VA `0x16678`.
- [x] Confirm replacement `UIColor *` slot at preferred VA `0x16680`.
- [x] Confirm VIP async refresh rewrites both resources.
- [x] Generate cyber PNG data and cyber UIColor inside helper.
- [x] Reassert both exact VIP resources on the main queue.
- [x] Preserve UUID gate before preferred-VA access.
- [x] Add diagnostic logs for helper load/resource-slot success.
- [x] Make derivative weak dependency filename exactly match `CyberSkinStandalone_v3.dylib`.
- [x] GitHub Actions build green (`35836242669`), Artifact `10739566699`.
- [ ] Real-device verify `exact VIP build found`.
- [ ] Verify `reassert icon=1 color=1` appears.
- [ ] Verify floating/menu icon changes.
- [ ] Verify theme color changes without startup crash.

## Next acceptance
For derivative mode put `VIPCrackPlugin_Cyber_v3.dylib` and `CyberSkinStandalone_v3.dylib` in the same loader directory. If visuals still do not change, collect only the `[CyberSkin:v3]` log lines first; those now distinguish helper-not-loaded, UUID mismatch, and successful slot override.
