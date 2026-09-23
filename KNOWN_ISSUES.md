# KNOWN_ISSUES

## KI-001 — v1 standalone target detection ineffective
Root cause: UIWindow/class/geometry heuristics did not match how VIPCrackPlugin selects targets.
Status: superseded by v3 direct resource-slot control for the exact supplied build.

## KI-002 — v1 derivative startup crash risk
Root cause: strong `LC_LOAD_DYLIB` companion dependency.
Fix: derivative now uses `LC_LOAD_WEAK_DYLIB`.
Status: structurally fixed; v2 device feedback confirmed startup no longer crashed.

## KI-003 — v2 visual unchanged
Device feedback: derivative no longer crashed, but UI remained visually unchanged.
Root cause found in v3 analysis: the VIP plugin owns replacement resources in global object slots and rewrites them asynchronously; outer UIKit hook chaining is not a reliable place to persistently override its skin.
Fix in v3: directly reassert VIP `NSData *` slot `0x16678` and `UIColor *` slot `0x16680`.
Status: fixed in code; v3 device verification pending.

## KI-004 — Companion filename/path must match
Because the derivative uses weak loading, a missing helper silently leaves the original appearance unchanged rather than crashing.
v3 fixes the previous naming ambiguity by encoding `@loader_path/CyberSkinStandalone_v3.dylib`, exactly matching the delivered helper filename.
Status: controlled; both files still need to be in the same loader directory for derivative mode.

## KI-005 — Exact supplied-build offsets are version-specific
v3 only dereferences `0x16678/0x16680/0x16718` after matching UUID `BA5FE867-6E15-3EC5-A68F-AE847E92EF26`.
Status: controlled by runtime UUID gate.

## KI-006 — Original external dependencies remain
The supplied VIPCrackPlugin retains its original dependencies, including `/Library/MobileSubstrate/DynamicLibraries/IGCheck0ver.dylib`.
Status: out of scope for skinning.

## KI-007 — v3 device behavior pending
CI confirms compile/link/ad-hoc-sign and artifact generation. Required device checks: helper actually loads, logs show `reassert icon=1 color=1`, icon changes, theme color changes, no startup crash.
Status: open.
