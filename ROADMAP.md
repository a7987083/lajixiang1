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
- [ ] Keep color behavior under separate device acceptance; do not modify it while testing embedded icons.

## Phase 10 — Title
- [x] Recover `UINavigationItem -setTitle:` hook and replacement-title data.
- [x] Build v10 static-title experiment (`Check0ver Team` -> `taobaozonoe`).
- [x] Real-device result: title did not change.
- [ ] Title work deferred. Do not use v10 as the embedded-icon baseline.

## Phase 11 — Embedded icon (verified success)
- [x] Freeze v9 as the embedded-icon baseline (`4ebd1fa6...fe0ad01`).
- [x] Identify zero-filled `0x16800..0x17fff` region (6144 bytes).
- [x] Replace remote NSData creation with `+[NSData dataWithBytes:length:]` path.
- [x] Store complete encoded JPEG/PNG bytes directly in the dylib.
- [x] Disable only the old remote-image MD5 failure branch at `0xDC1C` for this embedded path.
- [x] Preserve v9 icon/color configuration and all unrelated control flow.
- [x] Build JPEG v11 and PNG v11 variants.
- [x] Byte-for-byte reproduce both successful dylibs from the documented patch algorithm.
- [x] User confirmed embedded-icon method works on device.

## Current accepted path
Use `success/v11-embedded-icon` and `tools/patch_embedded_icon_v11.py`.

Requirements for an embedded image:
- JPEG or PNG
- preferably 120x120
- encoded size <= 6144 bytes

Do not base new embedded builds on v10. Start from the exact v9 SHA-256 documented in `docs/V11_EMBEDDED_ICON_SUCCESS.md`.
