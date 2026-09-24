# KNOWN_ISSUES

## KI-010 — v11 embedded image capacity is fixed
The verified in-place slot is `0x16800..0x17fff`, exactly 6144 bytes.
Images larger than 6144 encoded bytes must be resized/re-encoded before patching. The verified target size is 120x120.
Status: controlled by `tools/patch_embedded_icon_v11.py`, which rejects oversized images.

## KI-011 — Embedded v11 intentionally bypasses the old remote-image MD5 failure branch
The old `W23` validation result corresponds to the remote image integrity path and can reach `_exit(111)` at `0xDCD0`.
For the embedded-image path, `0xDC1C` is NOP so that obsolete remote validation cannot terminate the process.
This patch is specific to the exact v9 baseline and should not be generalized to unrelated versions.
Status: device verified as part of the successful v11 embedded-icon method.

## KI-009 — v10 title replacement did not change the visible title
Static decode of the replacement-title block produced `taobaozonoe`, but real-device feedback showed the visible title remained unchanged.
Conclusion: the visible title is controlled by another path or overwritten later.
Status: deferred. v10 is not the baseline for v11 work.

## KI-008 — v8 color unchanged
Device result: v8 successfully replaced the icon, but theme color did not change.
Fix work was placed into v9. Embedded-icon work must preserve the v9 baseline and not mix further color experiments into the verified icon path.
Status: separate acceptance track.

## KI-007 — Remote image MD5 mismatch caused deliberate process exit
The original remote path computes MD5 and calls `_exit(111)` when the expected checks fail.
v8 synchronized expected MD5 for the remote image path. v11 replaces the actual image source with embedded bytes and suppresses only the obsolete remote-failure branch.
Status: understood.

## KI-006 — Original external dependencies remain
The supplied VIPCrackPlugin retains its original dependencies, including `/Library/MobileSubstrate/DynamicLibraries/IGCheck0ver.dylib`.
Status: unchanged.

## KI-005 — Exact supplied-build offsets are version-specific
All offsets documented here apply to UUID `BA5FE867-6E15-3EC5-A68F-AE847E92EF26` and the exact v9 SHA-256 baseline recorded in `PROJECT_STATE.json`.
Status: controlled by exact baseline SHA gate.
