#!/usr/bin/env python3
from pathlib import Path
import hashlib

BASELINE_SHA256 = "90dd5288c91d14e404d74780d1b62a5b1a057dcc51a8defee2f78e6e6ea22f67"
TARGET_URL = b"https://app2.zonoeios.xyz/uploads/20260812/4de386e134d3f739c7f879ef883b04fc.png\0"
CYAN_COLOR_ENCODED = bytes.fromhex("25062070240e067b280d1d031b1901080204022d013a3f6b3d6b306d07246f59")
NOP = bytes.fromhex("1f2003d5")


def patch(src: Path, out: Path):
    original = src.read_bytes()
    b = bytearray(original)
    if hashlib.sha256(original).hexdigest() != BASELINE_SHA256:
        raise SystemExit("baseline SHA256 mismatch")
    if len(TARGET_URL) != 80:
        raise SystemExit("unexpected URL length")

    # v5: keep the plugin's original XOR/Base64/AES initialization fully intact.
    # Store the fixed URL in mapped __TEXT header slack (read-only at runtime is fine).
    if any(b[0x4000:0x4000 + len(TARGET_URL)]):
        raise SystemExit("reserved header slack is not zero")
    b[0x4000:0x4000 + len(TARGET_URL)] = TARGET_URL

    # Replace only the final NSString -> NSURL construction stage.
    # Original decrypted URL in x25 is still produced/retained/released normally.
    b[0xEEBC:0xEEDC] = b"".join([
        bytes.fromhex("280000d0"),  # adrp x8, 0x14000
        bytes.fromhex("00c146f9"),  # NSString class
        bytes.fromhex("e289fa10"),  # adr x2, 0x4000
        bytes.fromhex("fe0b0094"),  # +stringWithUTF8String:
        bytes.fromhex("fa0300aa"),  # mov x26, x0
        bytes.fromhex("00d146f9"),  # NSURL class
        bytes.fromhex("e2031aaa"),  # mov x2, x26
        bytes.fromhex("32090094"),  # +URLWithString:
    ])

    # x26 is now an autoreleased NSString. The original code expected a retained
    # object in x26 and explicitly released it; remove that release to avoid over-release.
    b[0xEF28:0xEF30] = NOP + NOP

    # Theme color remains a data-only change; original decoder stays untouched.
    b[0x162C8:0x162E8] = CYAN_COLOR_ENCODED

    out.write_bytes(b)
    print("sha256", hashlib.sha256(b).hexdigest())
    print("changed_bytes", sum(a != c for a, c in zip(original, b)))


if __name__ == "__main__":
    import argparse
    ap = argparse.ArgumentParser()
    ap.add_argument("input")
    ap.add_argument("output")
    a = ap.parse_args()
    patch(Path(a.input), Path(a.output))
