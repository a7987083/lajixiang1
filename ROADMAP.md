# ROADMAP

## Phase 1 — Cyber skin v1
- [x] Recover original UIKit hook registration and exact replacement IMP addresses.
- [x] Design independent runtime overlay detector and cyber renderer.
- [x] Add reversible Mach-O companion-load patcher for original VIPCrackPlugin.
- [x] GitHub Actions build green (`35830125612`).
- [ ] Real-device verify floating icon replacement.
- [ ] Real-device verify menu icon replacement and color scope.

## Next task
Inject either `CyberSkinStandalone.dylib` alone, or place it beside `VIPCrackPlugin_Cyber.dylib` and inject the derivative. Capture screenshots and crash/system logs if any; tighten overlay recognition and per-control icon rules from runtime evidence.
