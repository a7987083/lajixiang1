# ROADMAP

## Phase 1 — Cyber skin v1
- [x] Recover original UIKit hook registration and exact replacement IMP addresses.
- [x] Design independent runtime overlay detector and cyber renderer.
- [x] Add reversible Mach-O companion-load patcher for original VIPCrackPlugin.
- [ ] GitHub Actions build green.
- [ ] Real-device verify floating icon replacement.
- [ ] Real-device verify menu icon replacement and color scope.

## Next task
Run v1 on a target app containing the original floating menu. Capture screenshots and crash/system logs if any; tighten overlay recognition and per-control icon rules from runtime evidence.
