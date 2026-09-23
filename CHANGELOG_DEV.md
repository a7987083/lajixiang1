# CHANGELOG_DEV

## 2026-09-23 — v2
- Real-device feedback for v1: standalone produced little/no visible effect; derivative crashed at launch.
- Root cause for standalone: v1 relied on overlay-window heuristics, but supplied VIPCrackPlugin skins UIKit globally and does not guarantee a dedicated overlay UIWindow.
- Root cause/risk for derivative: v1 inserted a strong `LC_LOAD_DYLIB @loader_path/CyberSkinStandalone.dylib`; a different injected-file location can cause dyld startup abort before app code runs.
- Recovered exact supplied-build runtime anchors: UUID `BA5FE867-6E15-3EC5-A68F-AE847E92EF26`; VIP theme UIColor slot preferred VA `0x16680`; saved UIKit IMP slots `0x16718` (colorWithRed), `0x16720` (colorWithHue), `0x16728` (colorWithCGColor), `0x16748` (UIImageView setImage).
- Reworked standalone v2 to chain after VIPCrackPlugin's actual hooks. Image replacement is detected when VIP changes the final UIImage object; v2 then calls VIP's saved UIKit original IMP and writes the cyber icon. Color replacement is detected by VIP's exact cached replacement UIColor and then substituted with cyber cyan.
- Added UUID gating before any supplied-build preferred-VA dereference. Unknown VIP builds stay in safe fallback mode.
- Changed derivative patcher default from strong `LC_LOAD_DYLIB` to `LC_LOAD_WEAK_DYLIB` so a missing/moved helper does not make dyld terminate the process.
- First v2 CI attempt failed at ARC integer-to-Objective-C pointer cast; fixed with a `void *` slot plus `__bridge`. Also removed iOS 15-only `systemCyanColor` fallback to preserve iOS 13 deployment target.
- Source commit built: `c8b46c52a6ff199925b2e3b39b9d4d7f893e0296`.
- Actions Run `35832535796`: success. Artifact `10738062034`: `CyberSkinStandalone-v2`.
- `CyberSkinStandalone.dylib`: arm64 Mach-O, SHA-256 `2356177adec1a1ef8c5bef8689dea5db6b02b981ffd29377bdb6101eb7fdcd93`.
- `VIPCrackPlugin_Cyber_v2.dylib`: SHA-256 `f7bc0dac6cd8611ff87e36afceeebbf9b939d2f5035c02a69518dbd752ae2632`; new CyberSkin dependency is weak.
- v2 real-device verification: pending.

## 2026-09-23 — v1
- Identified supplied `VIPCrackPlugin.dylib` as arm64 Mach-O; SHA-256 `90dd5288c91d14e404d74780d1b62a5b1a057dcc51a8defee2f78e6e6ea22f67`.
- Recovered hook registration: `UIWindow setWindowLevel:` -> `0x8A4`, `UIColor colorWithRed:...` -> `0xD5C8`, hue -> `0xD64C`, CGColor -> `0xD710`, `UIButton layoutSubviews` -> `0xD798`, `UIImageView setImage:` -> `0xD870` (preferred VA).
- Added independent `CyberSkinStandalone.mm` with delayed runtime hooks and procedural neon icon.
- Added initial Mach-O companion-load patcher and macOS/iPhoneOS GitHub Actions build.
- Actions Run `35830125612`: success, but subsequent real-device acceptance failed as recorded above.
