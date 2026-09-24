# CHANGELOG_DEV

## 2026-09-24 — v11 embedded icon (device verified)
- User requested removing the permanent remote-image URL requirement and embedding the icon directly in the dylib.
- Frozen baseline: v9 SHA-256 `4ebd1fa612040b5c4db5d929a122c05871cb9b4b794cdb13ac989641afe0ad01`.
- Found a zero-filled 6144-byte region at `0x16800..0x17fff` that can hold the complete encoded icon without changing Mach-O file size or load-command layout.
- Replaced the remote image-data constructor at `0xEEF8..0xEF0F` with an in-memory `+[NSData dataWithBytes:length:]` path using embedded bytes at `0x16800`.
- Replaced `CBZ W23, 0xDCD0` at `0xDC1C` with NOP for the embedded path so the obsolete remote-image MD5 result cannot reach `_exit(111)`.
- JPEG reference: 120x120, 4518 bytes; output SHA-256 `573ca474c3c8b4a9c4c3503d93f9b0866fb39e16740538c1d8808413060671bc`.
- PNG reference: 120x120 RGBA, 5395 bytes; output SHA-256 `6919c9b448b5c9f89db8d411397c09e8626e7a63088cbd5121729e6db1072c02`.
- Added `tools/patch_embedded_icon_v11.py` and `docs/V11_EMBEDDED_ICON_SUCCESS.md`.
- Reproduction check: regenerating both binaries from v9 plus their extracted embedded image bytes produced byte-for-byte identical outputs and identical SHA-256 hashes.
- User device feedback: embedded-icon method succeeded.

## 2026-09-24 — v10
- User requested title change `Check0ver Team` -> `taobaozonoe`.
- Recovered `UINavigationItem -setTitle:` replacement path and the XOR-obfuscated title data block.
- v10 changed only the 14-byte replacement-title block.
- Real-device result: title did not change. Title experiment is not part of the accepted v11 baseline.

## 2026-09-24 — v9
- v8 device result: replacement icon works, but theme color remained unchanged.
- v9 keeps v8 icon/URL/MD5 path unchanged, replaces the default encrypted color so it decrypts to `#00FFFF`, and prevents runtime config from overwriting the color source.
- v9 SHA-256: `4ebd1fa612040b5c4db5d929a122c05871cb9b4b794cdb13ac989641afe0ad01`.
- v9 is the accepted baseline for v11 embedded-icon work.

## 2026-09-24 — v8
- Root cause of v7 icon-time process exit identified: plugin validates replacement image MD5 and calls `_exit(111)` on mismatch.
- New image MD5 verified as `4de386e134d3f739c7f879ef883b04fc`.
- v8 synchronized URL, runtime/default expected MD5, fallback MD5, and runtime locks.
- User device result: icon replacement succeeded; color did not change.

## Earlier history
- v1/v2/v3 were exploratory companion/resource-slot approaches.
- v4/v5 modified too much control flow and crashed.
- v6 changed only the default URL data and had no visible effect because runtime config overwrote it.
- v7 locked URL config but icon-time MD5 validation triggered `_exit(111)`.
