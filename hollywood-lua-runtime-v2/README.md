# Hollywood Crush LuaRuntimeHook V2 — read-only inventory

Derived from the device-verified V1.1 pcall hook path. **Install V2 instead of V1.1**; never load both hooks simultaneously.

## Behavior
- Waits for UnityFramework, installs an inline hook using an already-loaded MSHookFunction or DobbyHook.
- Performs four bounded read-only inventory snapshots on observed Lua pcall calls, scheduled at 0/5/15/30 seconds after the first observed call. No cross-thread Lua API invocation.
- Inspects existing package.loaded, package.preload and _G tables without require(), changing global state, or calling game methods.
- Filters names for gold, gem, diamond, energy, player, reward, award, currency, userdata, coin, stamina, and power.
- Records type/name only; does **not** log balances, user values, tokens or credentials.
- Caps results to 100 entries, table traversal to 10,000 / 200 keys, and output to 7,000 bytes.

## Build
On macOS with Xcode iPhoneOS SDK:
`cd hollywood-lua-runtime-v2 && sh build_macos.sh`

## Log
`<AppDataContainer>/Documents/LuaHookV2.log`. Look for `read-only Lua module inventory completed` and `inventory: ...`. Old V1 logs remain unchanged.

## Limitations
- A successful V1.1 probe confirms Lua execution, **not** the presence of a particular player model.
- Snapshots can occur before game modules initialize, so empty output does not prove absence. If Lua pcall stops firing, some scheduled snapshots will not execute.
- Static symbol names and C API are assumed compatible with the exact game's build. Dynamic injection has not been verified for V2.
- V2 contains no currency, energy, save-data or network mutations.

## V2.1 diagnosis

- One scan each at +0, +5, +15 and +30 seconds, only after the original Lua pcall returns in its own thread.
- The first returned line includes `scan_count`, `package_type`, `package_loaded_keys`, `package_preload_keys`, and `global_keys`.
- A nonzero table-key count with `scan_count=0` means no *name matches* in scanned tables, not that Lua is absent.
- Keep only V2.1 installed; do not inject V1/V1.1 or the prior V2 together.
