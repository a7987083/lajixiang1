# KNOWN_ISSUES

## KI-008 — v8 color unchanged
Device result: v8 successfully replaced the icon, but theme color did not change.
Root cause: the shipped v8 binary retained the original encrypted color block and runtime color overwrite path.
Fix in v9: replace the encrypted color source so it decrypts to `#00FFFF` and prevent runtime configuration from overwriting the color source.
Status: fixed in binary; device verification pending.

## KI-009 — v10 title replacement pending device verification
v10 changes only the 14-byte XOR-obfuscated replacement-title block at file offset `0x15190`.
Static decode verifies `taobaozonoe`.
Status: device verification pending.

## KI-007 — image MD5 mismatch caused deliberate process exit
The plugin computes MD5 for downloaded replacement image data and calls `_exit(111)` when neither runtime nor fallback expected MD5 matches.
v8 synchronizes expected MD5 with the new image MD5 `4de386e134d3f739c7f879ef883b04fc` while preserving validation.
Status: device verified indirectly by successful icon replacement.

## KI-006 — Original external dependencies remain
The supplied VIPCrackPlugin retains its original dependencies, including `/Library/MobileSubstrate/DynamicLibraries/IGCheck0ver.dylib`.
Status: unchanged.

## KI-005 — Exact supplied-build offsets are version-specific
All offsets documented here apply to UUID `BA5FE867-6E15-3EC5-A68F-AE847E92EF26`.
Status: controlled by exact baseline tracking.
