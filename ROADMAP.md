# ROADMAP

## Phase 8 — URL + image integrity
- [x] Replace icon URL with `https://ios.zonoeios.xyz/1c.png`.
- [x] Synchronize runtime/default and fallback image MD5 to `4de386e134d3f739c7f879ef883b04fc`.
- [x] Preserve original MD5 validation and `_exit(111)` behavior.
- [x] Real-device verify replacement icon works.

## Phase 9 — Theme color
- [x] Recover runtime color source path and final `UIColor *` slot.
- [x] Generate encrypted color source that decrypts to `#00FFFF`.
- [x] Prevent runtime configuration from overwriting the color source.
- [ ] Real-device verify the menu theme changes to cyan while icon remains correct.

## Phase 10 — Title
- [x] Recover `UINavigationItem -setTitle:` hook at `0x9110`.
- [x] Recover replacement-title XOR block at file offset `0x15190` and decoder `0xF250`.
- [x] Replace decoded `Check0ver Team` with `taobaozonoe` using only 14 data bytes.
- [x] Verify Mach-O dependencies unchanged.
- [ ] Real-device verify title shows `taobaozonoe`.

## Current acceptance
Test v10 as one file. Expected: working replacement icon from v8, cyan theme from v9, and title `taobaozonoe`. If one item fails, isolate that chain without changing the already verified icon/MD5 path.


## Phase 11 — Original GM window toggle
- [x] Add a native GM switch to the overlay header.
- [x] Resolve `GameUI.OpenGMView` / `CloseView("GMView")` through IL2CPP metadata instead of a fixed RVA.
- [x] Hide the large overlay panel after opening so it does not cover the game's GMView.
- [x] Confirm the arm64 iOS Actions build on the isolated feature branch (run 44816231515; source commit 7880a711c1cd7ca84f032655ed586a0929256f4f).
- [ ] Verify open, close, and no-crash behavior on the target iPhone and exact game build.
