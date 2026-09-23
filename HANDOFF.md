# HANDOFF

## Baseline
Input: user-supplied `VIPCrackPlugin.dylib`, arm64 Mach-O, SHA-256 `90dd5288c91d14e404d74780d1b62a5b1a057dcc51a8defee2f78e6e6ea22f67`, UUID `BA5FE867-6E15-3EC5-A68F-AE847E92EF26`.

## Static call chain
Constructor at preferred VA `0x8194` installs Objective-C IMP replacements through helper `0x8788`. Relevant supplied-build hooks: UIColor class-method hooks at `0xD5C8/0xD64C/0xD710`, UIButton layout hook `0xD798`, UIImageView `setImage:` hook `0xD870`.

The supplied build stores its runtime replacement UIColor at preferred VA `0x16680`. It stores UIKit original IMPs at `0x16718` (`colorWithRed`), `0x16720` (`colorWithHue`), `0x16728` (`colorWithCGColor`) and `0x16748` (`UIImageView setImage:`). These offsets are only used after matching the exact Mach-O UUID.

## v1 runtime feedback
- `CyberSkinStandalone` v1: little/no visible effect. Overlay-window heuristics were too restrictive and did not reflect how VIPCrackPlugin chooses its targets.
- `VIPCrackPlugin_Cyber` v1: startup crash. The derivative introduced a strong `LC_LOAD_DYLIB @loader_path/CyberSkinStandalone.dylib`, so a helper installed elsewhere can make dyld abort before constructors.

## v2 implementation
- Standalone installs on the first main-queue turn so VIPCrackPlugin's constructor-installed hooks are already current.
- Image path: call VIP's current `UIImageView setImage:` hook first; if the final `UIImageView.image` differs from the incoming UIImage, VIP itself selected/replaced that image. v2 then calls VIP's saved UIKit original IMP (`0x16748`) directly with the generated cyber icon. No UIWindow guessing is required for target identification.
- Color path: call VIP's current UIColor hook first; if the returned UIColor is VIP's exact cached replacement color (`0x16680`), v2 returns cyber cyan instead. Cyber colors are created through VIP's saved UIKit original color IMP, avoiding recursion.
- A matched image marks its actual window for secondary label/button/switch styling.
- Derivative patcher now inserts `LC_LOAD_WEAK_DYLIB`; missing helper must not become a dyld startup failure.

## Current build state
- Source commit built: `c8b46c52a6ff199925b2e3b39b9d4d7f893e0296`
- Actions Run: `35832535796` — success
- Artifact: `10738062034` (`CyberSkinStandalone-v2`)
- `CyberSkinStandalone.dylib` SHA-256: `2356177adec1a1ef8c5bef8689dea5db6b02b981ffd29377bdb6101eb7fdcd93`
- `VIPCrackPlugin_Cyber_v2.dylib` SHA-256: `f7bc0dac6cd8611ff87e36afceeebbf9b939d2f5035c02a69518dbd752ae2632`
- v2 runtime/device verification: pending.

## Risks / acceptance
- Exact-offset mode intentionally supports only the supplied UUID; a changed VIPCrackPlugin build must be re-located rather than reusing offsets.
- The original VIPCrackPlugin retains all original external dependencies, including `IGCheck0ver.dylib`.
- CI ad-hoc signing is not the final IPA signing step.
- Acceptance requires: no startup crash, floating icon changed, menu icon(s) changed, theme color changed, and no unintended game-UI recoloring.
