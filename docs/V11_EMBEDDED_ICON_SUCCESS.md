# v11 Embedded Icon — Verified Success Path

Date: 2026-09-24

Branch: `success/v11-embedded-icon`

## Baseline

Use the already-working v9 binary as the only baseline:

- File: `VIPCrackPlugin_RuntimeURL_MD5_Color_v9.dylib`
- SHA-256: `4ebd1fa612040b5c4db5d929a122c05871cb9b4b794cdb13ac989641afe0ad01`
- Architecture: arm64 Mach-O
- File size: 124512 bytes

Do not apply this method on v4/v5/v6/v7/v8 or on the original binary directly.

## Device result

User device feedback confirmed the v11 embedded-icon approach works. The icon no longer depends on a live remote image URL.

Two generated reference outputs:

- `VIPCrackPlugin_Embedded_JPG_v11.dylib`
  - SHA-256: `573ca474c3c8b4a9c4c3503d93f9b0866fb39e16740538c1d8808413060671bc`
  - Embedded image: JPEG 120x120, 4518 bytes
  - Embedded image MD5: `83853ad862b62e87b80f42e74cbdc7aa`
  - Embedded image SHA-256: `5d27a92d98de9bfac9a4781443b33b109f136a6aecf1c17756a9d4a248c0c860`

- `VIPCrackPlugin_Embedded_PNG_v11.dylib`
  - SHA-256: `6919c9b448b5c9f89db8d411397c09e8626e7a63088cbd5121729e6db1072c02`
  - Embedded image: PNG 120x120 with alpha, 5395 bytes
  - Embedded image MD5: `f137b8d9dfb54209d6cfdce6d4634e14`
  - Embedded image SHA-256: `1e39149dd42bec7f0b2cbefece22cc9d43de350460ae4f86f9959dbff6420202`

## Why this works

v9 already has the stable icon URL / expected-MD5 / color locking behavior. v11 leaves that known-good state intact and only changes the final image source.

Original v9 image-load path around `0xEEF8` calls the network NSData constructor after creating an NSURL. v11 replaces that call site with an in-memory `NSData` construction path:

```text
embedded bytes at 0x16800
        ↓
+[NSData dataWithBytes:length:]
        ↓
result retained by existing runtime path
        ↓
0x16678 replacement NSData slot
        ↓
+[UIImage imageWithData:]
```

The image bytes are stored in the existing zero-filled range:

```text
0x16800 .. 0x17FFF
```

Available capacity: `0x1800` = 6144 bytes.

The binary size and Mach-O load-command layout therefore remain unchanged.

## Exact binary changes relative to v9

### 1. Disable the remote-image MD5 failure branch

At file/preferred offset `0xDC1C`:

```asm
v9:   CBZ W23, 0xDCD0
v11:  NOP
```

Bytes:

```text
B7 05 00 34
→
1F 20 03 D5
```

This prevents the old remote-image MD5 result from reaching the plugin's `_exit(111)` path after the image source has been changed to embedded bytes.

### 2. Replace network NSData creation

v9 around `0xEEF8`:

```asm
BL  network NSData constructor
MOV X29, X29
BL  objc_retainAutoreleasedReturnValue
MOV X28, X0
B   0xEF10
```

v11 uses:

```asm
ADR X2, 0x16800
MOV X3, #embedded_image_length
BL  0x116E0
MOV X29, X29
BL  0x110D4
MOV X28, X0
```

For the verified JPEG build (4518 bytes):

```text
0xEEF8: 42 C8 03 10   ADR X2, 0x16800
0xEEFC: C3 34 82 D2   MOV X3, #0x11A6
0xEF00: F8 09 00 94   BL 0x116E0
0xEF04: FD 03 1D AA
0xEF08: 73 08 00 94
0xEF0C: FC 03 00 AA
```

For the verified PNG build (5395 bytes), only the `MOV X3,#length` immediate changes.

### 3. Embed image bytes

Write the complete encoded JPEG/PNG file at `0x16800` and zero-fill the rest of the 6144-byte slot.

The prepared image must satisfy:

- JPEG or PNG
- preferably 120x120 for this UI
- total encoded file size <= 6144 bytes

## Important behavior

- No image URL availability is required after embedding.
- The previous v9 URL string may still be constructed as an NSURL by the surrounding original code, but there is no remote image fetch at the patched call site.
- v9 color behavior remains unchanged.
- v10 title experiment is intentionally not part of this baseline.
- The image validation exit branch is disabled only for the embedded-image path; do not generalize this patch to unrelated builds.

## Reproduction

Use `tools/patch_embedded_icon_v11.py` on an exact v9 binary and a pre-optimized image <= 6144 bytes.

Example:

```bash
python3 tools/patch_embedded_icon_v11.py \
  VIPCrackPlugin_RuntimeURL_MD5_Color_v9.dylib \
  icon.png \
  VIPCrackPlugin_Embedded.dylib
```

The patcher performs:

- exact v9 SHA-256 gate
- image-format gate
- 6144-byte capacity gate
- zero-slack verification
- instruction replacement
- embedded-data write
- output SHA-256 reporting

## Acceptance checks

1. Game launches normally.
2. Floating/menu icon appears using the embedded image.
3. The icon still appears if the former remote image URL is unavailable.
4. v9 theme-color behavior remains unchanged.
5. No startup or icon-generation exit occurs.
