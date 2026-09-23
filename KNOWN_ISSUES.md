# KNOWN_ISSUES

## KI-001 — v1 standalone target detection ineffective
Reproduction: inject v1 standalone alongside the supplied VIPCrackPlugin; little/no visible skin change.
Root cause: v1 assumed the menu could be reliably identified from UIWindow level/class/geometry. The supplied VIP plugin instead chooses targets inside global UIKit hooks and does not require a dedicated overlay UIWindow.
Fix in v2: removed target selection dependence on UIWindow heuristics. v2 observes whether VIP's own image/color hooks actually replaced a value, then overrides only those confirmed targets.
Status: fixed in code; v2 device verification pending.

## KI-002 — v1 derivative startup crash risk
Reproduction: inject `VIPCrackPlugin_Cyber.dylib` v1 when `CyberSkinStandalone.dylib` is not located exactly at the derivative's `@loader_path`.
Root cause: v1 inserted strong `LC_LOAD_DYLIB`; dyld can terminate before app startup if the dependency cannot be resolved.
Fix in v2: default patch command is `LC_LOAD_WEAK_DYLIB`. Missing/moved CyberSkin helper must no longer be a mandatory dyld dependency.
Status: fixed structurally; v2 device verification pending.

## KI-003 — Exact supplied-build offsets are version-specific
v2 supplied-build integration uses UUID `BA5FE867-6E15-3EC5-A68F-AE847E92EF26` before reading preferred VAs `0x16680`, `0x16718`, `0x16720`, `0x16728`, `0x16748`.
Risk: future/repacked VIPCrackPlugin builds may move these slots.
Mitigation: UUID mismatch disables exact-offset behavior; do not reuse offsets on another build.
Status: controlled by runtime UUID gate.

## KI-004 — Original external dependencies remain
The supplied VIPCrackPlugin contains existing external dylib dependencies, including `/Library/MobileSubstrate/DynamicLibraries/IGCheck0ver.dylib`. CyberSkin does not remove or emulate them.
Status: open/not in scope for skinning.

## KI-005 — v2 real-device behavior not yet verified
CI confirms compile/link/ad-hoc-sign and artifact generation. Required device checks: no startup crash, floating icon replacement, menu icon replacement, cyber color replacement, and no unrelated game-UI recoloring.
Status: open; next acceptance gate.
