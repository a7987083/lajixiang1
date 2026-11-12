# Hollywood Crush LuaRuntimeHook V1

Independent, read-only Lua runtime probe; does not modify gold, gems, energy or game data.

Build on macOS with Xcode iPhoneOS SDK:

    cd hollywood-lua-runtime-v1
    sh build_macos.sh

The dylib looks for lua_pcall and Lua C API symbols in UnityFramework and uses an already-loaded MSHookFunction or DobbyHook runtime. It runs the fixed Lua expression "return 1 + 1" once in the Lua calling thread and restores the stack.

Exports: LuaHookV1_RetryInstall(), LuaHookV1_IsInstalled().

Limitations: not device verified; manual RetryInstall is needed if UnityFramework or the hook runtime loads after this dylib; host runtime ABI and lua_pcallk must be checked. No currency/energy API is implemented. Injection/signing and rollback remain the operator's responsibility. This source is a diagnostic derivative of the previously supplied V1.
