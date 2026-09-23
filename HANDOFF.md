# HANDOFF

## Baseline
Input: user-supplied `VIPCrackPlugin.dylib`, arm64 Mach-O, SHA-256 `90dd5288c91d14e404d74780d1b62a5b1a057dcc51a8defee2f78e6e6ea22f67`, UUID `BA5FE867-6E15-3EC5-A68F-AE847E92EF26`.

## Static call chain
Constructor at preferred VA `0x8194` installs Objective-C IMP replacements through helper `0x8788`. Relevant hooks: UIColor class methods at `0xD5C8/0xD64C/0xD710`, UIButton layout `0xD798`, UIImageView `setImage:` `0xD870`.

The important v3 finding is the plugin's own replacement resources:
- preferred VA `0x16678`: `NSData *` used by `UIImageView -setImage:` hook when a target image matches; hook calls `+[UIImage imageWithData:]` from this slot and then invokes saved original `setImage:`.
- preferred VA `0x16680`: cached replacement `UIColor *` returned by the three UIColor hooks when the internal color matcher succeeds.
- VIP async refresh code rewrites both slots later (`0xEF20` and `0xEF88` paths), so one-shot outer-hook replacements may be overwritten.

## Runtime feedback history
- v1 standalone: little/no visible effect.
- v1 derivative: startup crash from strong companion load path.
- v2 derivative: no startup crash, but visual appearance unchanged.

## v3 implementation
- Exact UUID-gated integration only for the supplied VIP build.
- No UIWindow guessing for the main path.
- Generates a procedural cyber icon, encodes it to PNG `NSData`, and directly stores it into VIP slot `0x16678`.
- Generates cyber cyan `UIColor` and directly stores it into VIP slot `0x16680`.
- Reasserts both resources every 500 ms on the main queue because VIP may refresh them asynchronously.
- Diagnostic logs report exact image discovery, resource creation, and `reassert icon/color` status.
- If the exact VIP build is not present, a conservative UIKit fallback remains for standalone use.
- Derivative weak-load path exactly matches delivered helper filename: `@loader_path/CyberSkinStandalone_v3.dylib`.

## Current build state
- Source commit built: `51abf0c49ff981a65b88dfb352941c6730c13791`
- Actions Run: `35836242669` — success
- Artifact: `10739566699` (`CyberSkinStandalone-v3`)
- `CyberSkinStandalone_v3.dylib` SHA-256: `9419c81aef26df03dd9f7f6c3e9c0c252e6477695d8c2eb4e535e95d32f0abbe`
- `VIPCrackPlugin_Cyber_v3.dylib` SHA-256: `35a80cd71baae133a783f313a58e48caee9e4fb61ab559f3bcd88f633db30037`
- v3 runtime/device verification: pending.

## Acceptance
For modified mode, both `VIPCrackPlugin_Cyber_v3.dylib` and `CyberSkinStandalone_v3.dylib` must be present in the same loader directory. Expected logs include `exact VIP build found`, `resources ready`, and `reassert icon=1 color=1`.
