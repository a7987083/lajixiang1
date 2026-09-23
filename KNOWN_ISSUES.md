# KNOWN_ISSUES

## KI-001 — Runtime scope not yet device-verified
Reproduction: inject standalone skin into an app with one or more elevated UIWindow instances.
Risk: unrelated elevated windows may be styled.
Mitigation in v1: exclude keyboard/text-effects/remote/input-set/alert window classes and require elevated/compact/named overlay characteristics.
Next validation: screenshot plus class/window-level diagnostic logging on device.
Status: open.

## KI-002 — Original derivative has companion dependency
`VIPCrackPlugin_Cyber.dylib` requires `CyberSkinStandalone.dylib` beside it because the original binary has no source and v1 intentionally avoids invasive in-place ARM64 routine replacement.
Verified: patched Mach-O advertises `@loader_path/CyberSkinStandalone.dylib`; file length is unchanged and the inserted command is before first section file offset `0x8000`.
Status: by design; revisit only if single-file packaging becomes a hard requirement.

## KI-003 — Original external dependencies remain
The supplied VIPCrackPlugin contains existing external dylib dependencies, including `/Library/MobileSubstrate/DynamicLibraries/IGCheck0ver.dylib`. v1 does not alter them.
Status: open/not in scope for skinning.

## KI-004 — Device behavior not yet verified
CI confirms arm64 compile/link/sign and artifact generation, but no real-device UI or crash validation has been performed yet.
Status: open; next acceptance gate.
