# HANDOFF

## Baseline
Input: user-supplied `VIPCrackPlugin.dylib`, arm64 Mach-O, SHA-256 `90dd5288c91d14e404d74780d1b62a5b1a057dcc51a8defee2f78e6e6ea22f67`.

## Static call chain
Constructor at preferred VA `0x8194` installs Objective-C IMP replacements through helper `0x8788`. Image replacement enters `UIImageView -setImage:` replacement `0xD870`; it eventually creates a replacement `UIImage` from runtime `NSData` and calls the saved original IMP. Theme colors are intercepted by UIColor class-method replacements and select a runtime replacement UIColor.

## Implementation choice
Do not overwrite the recovered ARM64 routines. `VIPCrackPlugin_Cyber.dylib` adds only `LC_LOAD_DYLIB @loader_path/CyberSkinStandalone.dylib`. The standalone dylib delays hook installation to the main queue so that when dependency-loaded, it chains after VIPCrackPlugin's constructor-installed UIKit IMPs.

## Current build state
- Source commit built: `661485c4339fafa65bbe8b5ee7c1cbb1ea43306f`
- Actions Run: `35830125612` — success
- Artifact: `10736327933`
- `CyberSkinStandalone.dylib` SHA-256: `f1ef05d25d97b0c089979872bd159a6204138c452b2ce893923ce2a722072def`
- `VIPCrackPlugin_Cyber.dylib` SHA-256: `940ae555cc26a1093526a591d05d271088e80bd18325ce331142afad0d519d3b`
- Runtime/device verification: not performed yet.

## Risks
- Overlay-window heuristics may select an unrelated elevated window; runtime screenshots are required.
- All compact square UIImageViews inside a detected menu may receive the same cyber emblem in v1.
- Original VIPCrackPlugin still depends on its own original external libraries; this project does not remove or emulate those dependencies.
- Ad-hoc signing in CI is not a substitute for final IPA resigning.
