# CHANGELOG_DEV

## 2026-09-23 — v3
- Device feedback for v2 derivative: no startup crash, but visuals remained unchanged.
- Recovered the actual VIP replacement-resource path from `UIImageView -setImage:` IMP `0xD870`: when VIP selects a target, it loads replacement image bytes from global `NSData` preferred VA `0x16678`, calls `+[UIImage imageWithData:]`, then invokes the saved original `setImage:` IMP.
- Confirmed all three UIColor hooks return the cached replacement UIColor from preferred VA `0x16680` when VIP's internal matcher succeeds.
- Confirmed VIP refresh routines later rewrite both `0x16678` and `0x16680`, explaining why outer-hook substitutions can be ineffective or overwritten.
- Reworked v3 to directly own/reassert those two exact VIP resource globals instead of inferring UI targets from UIWindow or final UIImage differences.
- v3 generates cyber icon PNG data in-process and writes it into VIP's `NSData` slot; theme color is written into VIP's `UIColor` slot. Reassert timer runs on the main queue so later VIP network/config refreshes are overridden again.
- Exact UUID gate remains `BA5FE867-6E15-3EC5-A68F-AE847E92EF26`; unknown builds do not dereference supplied-build offsets.
- Added diagnostic logs: exact VIP discovery, generated PNG size, and `reassert icon=1 color=1` status.
- Changed build to MRC for explicit runtime object ownership. First v3 MRC compile failed because `objc_storeStrong` was undeclared; added a compatibility declaration and rebuilt successfully.
- Source commit built: `51abf0c49ff981a65b88dfb352941c6730c13791`.
- Actions Run `35836242669`: success. Artifact `10739566699`: `CyberSkinStandalone-v3`.
- `CyberSkinStandalone_v3.dylib`: SHA-256 `9419c81aef26df03dd9f7f6c3e9c0c252e6477695d8c2eb4e535e95d32f0abbe`.
- `VIPCrackPlugin_Cyber_v3.dylib`: SHA-256 `35a80cd71baae133a783f313a58e48caee9e4fb61ab559f3bcd88f633db30037`.
- v3 derivative weak dependency name now exactly matches the delivered helper filename: `@loader_path/CyberSkinStandalone_v3.dylib`.
- v3 real-device verification: pending.

## 2026-09-23 — v2
- Real-device feedback for v1: standalone produced little/no visible effect; derivative crashed at launch.
- Reworked standalone v2 to chain after VIPCrackPlugin's actual hooks and changed derivative dependency to weak loading.
- Actions Run `35832535796`: success, Artifact `10738062034`.
- Device feedback: derivative no longer crashed, but visual appearance remained unchanged.

## 2026-09-23 — v1
- Identified supplied `VIPCrackPlugin.dylib` and recovered major UIKit hooks.
- Built first independent skin and strong-load derivative experiment.
- Actions Run `35830125612`: success, but real-device acceptance failed.
