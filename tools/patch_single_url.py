#!/usr/bin/env python3
from pathlib import Path
import hashlib

BASELINE_SHA256 = "90dd5288c91d14e404d74780d1b62a5b1a057dcc51a8defee2f78e6e6ea22f67"
TARGET_URL = b"https://app2.zonoeios.xyz/uploads/20260812/4de386e134d3f739c7f879ef883b04fc.png\0"

NOP = bytes.fromhex("1f2003d5")

def patch(src: Path, out: Path):
    b = bytearray(src.read_bytes())
    if hashlib.sha256(b).hexdigest() != BASELINE_SHA256:
        raise SystemExit("baseline SHA256 mismatch")
    if len(TARGET_URL) != 80:
        raise SystemExit("unexpected URL length")

    # Icon-specific encrypted-data block becomes raw URL storage.
    b[0x16180:0x16200] = TARGET_URL + b"\0" * (0x80 - len(TARGET_URL))

    # Disable the icon-string XOR decoder so it cannot overwrite the URL tail.
    b[0xF634:0xF638] = bytes.fromhex("c0035fd6")  # ret

    # Skip the original AES/base64 URL decrypt at this one call site.
    for off in range(0xEE94, 0xEEB8, 4):
        b[off:off+4] = NOP
    b[0xEEB8:0xEEBC] = bytes.fromhex("190080d2")  # mov x25,#0

    # NSString stringWithUTF8String:(0x16180) -> NSURL URLWithString:
    code = b"".join([
        bytes.fromhex("280000d0"),  # adrp x8,0x14000
        bytes.fromhex("00c146f9"),  # NSString class
        bytes.fromhex("e2950310"),  # adr x2,0x16180
        bytes.fromhex("fe0b0094"),  # stringWithUTF8String:
        bytes.fromhex("fa0300aa"),  # mov x26,x0
        bytes.fromhex("00d146f9"),  # NSURL class
        bytes.fromhex("e2031aaa"),  # mov x2,x26
        bytes.fromhex("32090094"),  # URLWithString:
    ])
    b[0xEEBC:0xEEDC] = code
    out.write_bytes(b)
    print("sha256", hashlib.sha256(b).hexdigest())

if __name__ == "__main__":
    import argparse
    ap = argparse.ArgumentParser()
    ap.add_argument("input")
    ap.add_argument("output")
    a = ap.parse_args()
    patch(Path(a.input), Path(a.output))
