# Hollywood Crush LuaRuntimeHook V1

Independent, read-only Lua runtime probe; does not modify gold, gems, energy or game data.

Build on macOS with Xcode iPhoneOS SDK:

    cd hollywood-lua-runtime-v1
    sh build_macos.sh

The dylib looks for lua_pcall and Lua C API symbols in UnityFramework and uses an already-loaded MSHookFunction or DobbyHook runtime. It runs the fixed Lua expression "return 1 + 1" once in the Lua calling thread and restores the stack.

Exports: LuaHookV1_RetryInstall(), LuaHookV1_IsInstalled().

Limitations: not device verified; constructor schedules bounded retries (60 attempts / 30 seconds) until UnityFramework and a hook runtime are available. The exported RetryInstall can also be invoked manually if initialization takes longer; host runtime ABI and lua_pcallk must be checked. No currency/energy API is implemented. Injection/signing and rollback remain the operator's responsibility. This source is a diagnostic derivative of the previously supplied V1.

## On-device log file

All `[LuaHookV1]` messages are appended to the game data container:

```text
<AppDataContainer>/Documents/LuaHookV1.log
```

The path is constructed from the process `HOME` environment variable. Lines include local timestamp and are appended (not overwritten). The file is created with `0600` permissions. Console `stderr` output is preserved as a fallback. If the game has a different sandbox layout or `HOME` is missing, only the console output is guaranteed.

For an IPA-installed app, locate its **data container**, not its `.app` bundle. V1 writes `loaded`, installation failures/success, and the one-time read-only probe result. No resource changes are made.

## V1.1 startup diagnostics

- Replaces constructor-time hook with detached worker retries (500 ms interval, max 30 seconds).
- Resolves the exact loaded UnityFramework image path via dyld image enumeration before dlsym; falls back to RTLD_DEFAULT.
- Logs the per-symbol pointer presence for pcall, loadbuffer, gettop, settop and tolstring on failure, plus the image count.
- Does not interpret 'Lua API unavailable' alone as proof that Lua is missing: load order, symbol visibility and Lua ABI remain separate hypotheses.
