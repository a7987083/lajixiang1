# Taylor Resource Menu V1

Target: Taylor's Secret `com.mergegames.taylorsecret`, 1.8.9 build 69, iOS arm64.
UnityFramework SHA-256: `d7ebc545a1568bdf78f026b86cd4fe6b1df77509f165621cd29546de3fbf29ae`.
UUID: `CC89F3E2-E288-3FBF-AB96-1FD4E58F047A`.

Inject **only TaylorResourceMenu-V1.dylib** into the matching decrypted IPA using the existing signing/injection workflow. Dobby is statically linked; no separate Dobby/Substrate dylib is required. This does not add an injection entitlement or make inline hooking work on every signing environment. Failure to allocate executable trampoline memory is reported rather than treated as success. Remove the injected library/load command and re-sign to uninstall.

Tap the draggable `T` bubble. Enter an integer quantity 1–100, then choose 增加钻石 / 增加体力 / 增加星星. 刷新余额 is read-only. No resource mutations occur automatically. The menu shows real before/after values; OK confirms only the local immediate delta, not cloud acceptance. Original validation and normal saving remain active. Log: `Documents/TaylorResourceMenu.log`.

## Implementation

Based on `feature/taylor-lua-loader-probe` at `67935a7a996ee0c996f278ca2103f029755bd3e5`; Hollywood V3 overlay is a UI reference only. Existing sources and stable commits are preserved.

- Statically linked upstream jmpews/Dobby commit `5dfc8546954ce3b3198132ab13fddb89ee92cdd7`; Apache-2.0 license included in build artifact.
- Match UUID and the first 16 instruction bytes before installing a hook on `XLua.LuaEnv.Tick` RVA `0x3B65878`.
- Call original Tick first. On main thread only, obtain the live state from that call's `self+0x10`. Never retain an instance/Lua state between ticks.
- Queue one explicit command; 10 second expiry and cancel; only an environment with GM, PropertySystem, UserData.Property consumes it. New game states are automatically checked without keeping a stale pointer.
- Readiness scripts are read-only, at most once per second when idle. Requests execute once, using `GM.AddItem(id, amount)` and original resource validation. No anti-cheat changes, no forced cloud requests, no periodic resource additions.
- Native APIs validated against this binary: xlua load-buffer wrapper `0x328EF4C` (int size); pcall wrapper `0x328EE04`; gettop `0x3246608`; settop `0x3246624`; tolstring `0x3247518`. Address semantics are RVA from __TEXT VA=0, slide resolved using the loaded header.
- Stack height is saved and restored for load/success/error paths. Lua errors remain protected. UI obtains copied status text only and never calls Lua.
- Input temporarily makes the overlay key; ending input restores the game key window. Background touches pass to the game. Scene-aware on iOS 13+.
- Export `TaylorResourceDisable()` cancels requests and makes the hook inert; no runtime unpatch while callers may be active. Restart to re-enable.

## Verification

CI builds on macos-15 against the available iPhoneOS SDK, targets iOS 12+ arm64, compiles our sources with -Wall -Wextra -Werror, signs ad hoc, verifies signature, and publishes dependencies/hashes. Source harness tests operation behavior against mocked game objects, not against the actual iOS binary. Exact game execution, UI, inline hook permissions, scene resets, restart persistence, and server acceptance remain device-unverified.

Run `sh build_macos.sh` in this directory on macOS. Source test: `python3 test_operation.py` with `lupa.lua53` installed. Dobby source build may require CMake compatibility policy flag for current CMake; no SDK/compiler upgrades are required.

## Current build status

Source/mock checks passed. User explicitly approved publishing source and offsets to this public repository. CI build/signature verification pending. Local Linux host has no Apple SDK; game/device verification remains pending.
