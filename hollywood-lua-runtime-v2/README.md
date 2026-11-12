# Hollywood Crush LuaRuntimeHook V2 — read-only inventory

Derived from the device-verified V1.1 pcall hook path. **Install V2 instead of V1.1**; never load both hooks simultaneously.

## Behavior
- Waits for UnityFramework, installs an inline hook using an already-loaded MSHookFunction or DobbyHook.
- On the first observed Lua pcall, compiles and runs one bounded read-only Lua inventory chunk on that Lua thread.
- Inspects existing package.loaded and _G tables without require(), changing global state, or calling game methods.
- Filters names for gold, gem, diamond, energy, player, reward, award, currency, userdata.
- Records type/name only; does **not** log balances, user values, tokens or credentials.
- Caps results to 100 entries, table traversal to 10,000 / 200 keys, and output to 7,000 bytes.

## Build
On macOS with Xcode iPhoneOS SDK:
`cd hollywood-lua-runtime-v2 && sh build_macos.sh`

## Log
`<AppDataContainer>/Documents/LuaHookV2.log`. Look for `read-only Lua module inventory completed` and `inventory: ...`. Old V1 logs remain unchanged.

## Limitations
- A successful V1.1 probe confirms Lua execution, **not** the presence of a particular player model.
- The snapshot can occur before game modules initialize, so empty output does not prove absence.
- Static symbol names and C API are assumed compatible with the exact game's build. Dynamic injection has not been verified for V2.
- V2 contains no currency, energy, save-data or network mutations.
