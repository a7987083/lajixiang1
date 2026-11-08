# Guest Mode (Unity IL2CPP) — investigation branch

This directory is isolated from the repository's existing CyberSkin/VIPCrackPlugin baseline.

## Goal
Develop a separate iOS arm64 dylib to test a **local, non-member guest session** using the game's existing anonymous-session API, without editing the game's UnityFramework binary or altering the original login flow by default.

## Findings / baseline
- Earlier static experiment accidentally changed LoginView.NativeLogin instead of NativeCreate and reportedly entered the game briefly before crashing.
- Method RVAs reported in the earlier analysis (not revalidated on a fresh binary):
  - LoginView.NativeLogin: 0x214EC4C
  - LoginView.NativeCreate: 0x214EC84
  - Controller.FetchAnonymousToken: 0x213E514
  - Controller.ProceedToGame: 0x21386EC
  - Controller.RedirectUserBasedOnTier: 0x213A8D4
- Treat these offsets as *version-specific leads only*. Revalidate Mach-O UUID, IL2CPP metadata, function disassembly, call paths, and asynchronous callback ordering before writing hooks.

## Intended design
1. Identify the guest button or safely reuse a user-triggered Create Account action.
2. Request anonymous session credentials and wait for completion, instead of immediately branching to ProceedToGame.
3. Initialize a separate local guest profile/save namespace, if the runtime supports it.
4. Respect server-side subscription/entitlement decisions; do not fabricate account or membership grants.
5. Capture first real crash via .ips / unified logs, then instrument lifecycle transitions.

## Acceptance
- Original LOG IN behavior preserved.
- Guest entry is opt-in and restores cleanly.
- No scene transition before anonymous initialization completes.
- App stays stable for at least a full local gameplay session.
- Test on device; CI success is not device verification.

## Status
Branch setup only. No guest-mode dylib has been implemented, built, or device-tested yet.
