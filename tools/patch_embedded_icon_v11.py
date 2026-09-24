#!/usr/bin/env python3
from pathlib import Path
import argparse
import hashlib
import struct

V9_SHA256 = "4ebd1fa612040b5c4db5d929a122c05871cb9b4b794cdb13ac989641afe0ad01"

EMBED_OFF = 0x16800
EMBED_CAP = 0x1800  # 6144 bytes: 0x16800..0x17fff

NOP = bytes.fromhex("1f2003d5")
ADR_X2_16800 = bytes.fromhex("42c80310")
BL_DATA_WITH_BYTES_LENGTH = bytes.fromhex("f8090094")  # BL 0x116e0 from 0xef00
MOV_X29_X29 = bytes.fromhex("fd031daa")
BL_RETAIN_AUTORELEASED = bytes.fromhex("73080094")      # BL 0x110d4 from 0xef08
MOV_X28_X0 = bytes.fromhex("fc0300aa")


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def image_type(data: bytes) -> str:
    if data.startswith(b"\xff\xd8\xff"):
        return "jpeg"
    if data.startswith(b"\x89PNG\r\n\x1a\n"):
        return "png"
    raise SystemExit("image must be JPEG or PNG")


def encode_movz_x3_imm16(value: int) -> bytes:
    if not (0 <= value <= 0xFFFF):
        raise SystemExit("image length does not fit MOVZ X3,#imm16")
    # MOVZ Xd,#imm16,LSL#0: 0xD2800000 | (imm16 << 5) | Rd
    insn = 0xD2800000 | (value << 5) | 3
    return struct.pack("<I", insn)


def patch(v9_path: Path, image_path: Path, out_path: Path) -> None:
    src = v9_path.read_bytes()
    image = image_path.read_bytes()

    if sha256(src) != V9_SHA256:
        raise SystemExit(
            "baseline SHA-256 mismatch; use exact v9 "
            "VIPCrackPlugin_RuntimeURL_MD5_Color_v9.dylib"
        )

    kind = image_type(image)
    if len(image) > EMBED_CAP:
        raise SystemExit(
            f"prepared image too large: {len(image)} bytes > {EMBED_CAP}; "
            "resize/re-encode first (120x120 is the verified target size)"
        )

    if any(src[EMBED_OFF:EMBED_OFF + EMBED_CAP]):
        raise SystemExit("v9 embedded-image slack is not zero; refuse to overwrite")

    b = bytearray(src)

    # v11 verified path: old remote-image MD5 failure branch would reach _exit(111).
    # The embedded-image path owns its bytes locally, so suppress only that branch.
    b[0xDC1C:0xDC20] = NOP

    # Replace remote NSData fetch result with +[NSData dataWithBytes:length:].
    b[0xEEF8:0xEEFC] = ADR_X2_16800
    b[0xEEFC:0xEF00] = encode_movz_x3_imm16(len(image))
    b[0xEF00:0xEF04] = BL_DATA_WITH_BYTES_LENGTH
    b[0xEF04:0xEF08] = MOV_X29_X29
    b[0xEF08:0xEF0C] = BL_RETAIN_AUTORELEASED
    b[0xEF0C:0xEF10] = MOV_X28_X0

    # Embed complete encoded image and keep the rest of the fixed slot zero-filled.
    b[EMBED_OFF:EMBED_OFF + EMBED_CAP] = b"\0" * EMBED_CAP
    b[EMBED_OFF:EMBED_OFF + len(image)] = image

    out_path.write_bytes(b)

    print("baseline_sha256", V9_SHA256)
    print("image_type", kind)
    print("image_bytes", len(image))
    print("image_md5", hashlib.md5(image).hexdigest())
    print("image_sha256", sha256(image))
    print("output_sha256", sha256(b))
    print("output_bytes", len(b))


def main() -> None:
    ap = argparse.ArgumentParser(
        description="Create the verified v11 embedded-icon dylib from exact v9 baseline"
    )
    ap.add_argument("v9_dylib", type=Path)
    ap.add_argument("image", type=Path)
    ap.add_argument("output", type=Path)
    args = ap.parse_args()
    patch(args.v9_dylib, args.image, args.output)


if __name__ == "__main__":
    main()
