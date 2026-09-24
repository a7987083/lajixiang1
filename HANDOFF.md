# HANDOFF

## Baseline
Original user-supplied `VIPCrackPlugin.dylib`: arm64 Mach-O, SHA-256 `90dd5288c91d14e404d74780d1b62a5b1a057dcc51a8defee2f78e6e6ea22f67`, UUID `BA5FE867-6E15-3EC5-A68F-AE847E92EF26`.

For embedded-icon work, do **not** start from the original binary. Use the exact v9 baseline:

- SHA-256: `4ebd1fa612040b5c4db5d929a122c05871cb9b4b794cdb13ac989641afe0ad01`
- This baseline already carries the working icon URL/MD5 chain and the v9 color changes.

## Verified runtime history
- v8: replacement icon worked on device; color did not change.
- v9: frozen baseline for v11 embedded-icon work.
- v10: title experiment `Check0ver Team` -> `taobaozonoe`; real-device result: title did not change. Do not use v10 as the embedded baseline.
- v11: embedded JPEG/PNG icon method succeeded on device.

## v11 successful implementation

Image slot:

```text
0x16800 .. 0x17fff
capacity = 6144 bytes
```

The slot is zero-filled in the exact v9 baseline.

Patch `0xEEF8..0xEF0F` so the final image bytes come from the embedded slot through `+[NSData dataWithBytes:length:]` instead of the network NSData constructor.

Patch `0xDC1C` from the old remote-image MD5 failure branch to NOP so the now-obsolete remote validation result does not reach `_exit(111)`.

Do not modify the rest of the image display chain:

```text
embedded bytes
→ NSData
→ global replacement data at 0x16678
→ UIImage imageWithData:
→ original setImage: path
```

## Reproducible patcher

Use:

```text
tools/patch_embedded_icon_v11.py
```

It requires:
- exact v9 SHA-256
- JPEG or PNG
- encoded image <= 6144 bytes

Recommended preprocessing: 120x120. PNG alpha is supported.

## Verified outputs

JPEG v11:
- output SHA-256 `573ca474c3c8b4a9c4c3503d93f9b0866fb39e16740538c1d8808413060671bc`
- embedded JPEG 4518 bytes

PNG v11:
- output SHA-256 `6919c9b448b5c9f89db8d411397c09e8626e7a63088cbd5121729e6db1072c02`
- embedded PNG 5395 bytes

Both outputs were regenerated from v9 with the documented algorithm and matched the successful binaries byte-for-byte.

## Do not regress

- Do not reintroduce companion dylibs.
- Do not rewrite the AES/Base64 URL initialization chain as v4/v5 did.
- Do not base embedded-icon work on v10.
- Do not expand the Mach-O solely to store icon bytes; use the verified 6144-byte zero region when the encoded icon fits.

Full technical record: `docs/V11_EMBEDDED_ICON_SUCCESS.md`.
