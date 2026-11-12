# Hollywood Crush Lua Runtime Hook V3 (explicit action testing)

## Scope
Uses the previously device-verified V1.1 hook path. V3 has **no automatic resource modifications**.
The four Lua commands and 3903-byte `_MOD` bootstrap were recovered from the original Mach-O. The bootstrap source is identity-checked by SHA-256 at build time. Their gameplay effects have NOT been device verified.

## Floating menu (UIKit, inspired by H5GG's floating-button concept)

The V3 dylib includes its own lightweight UIKit overlay. No H5GG binaries, HTML, JavaScript bridge, or network calls are bundled. The implementation references H5GG's publicly documented window/button concept but copies no upstream source.

- Draggable **H** bubble; tap to expand/collapse the panel
- Buttons: **金币 +10**, **钻石 +10**, **无限能量：开启**, **无限能量：关闭**
- The menu only calls the exported queue request APIs. The game Lua action remains on the hooked Lua thread.
- The separate UIWindow is deliberately not made key; hit testing outside the bubble/panel passes through to the game.
- UI runtime behavior, touch passthrough and game-scene compatibility require device verification.

## Usage
Inject **only** LuaRuntimeHookV3.dylib (remove V1 and V2 dylibs).

Log: `<AppDataContainer>/Documents/LuaHookV3.log`.
After launching the game, look for `installed pcall` and `preflight rc=0 READY`.

### Manual command file
Using the app sandbox file manager, create `Documents/LuaHookV3.command` with exactly one:
- `gold` => `if _MOD then _MOD.addItem("gold", 10) end`
- `gem` => `if _MOD then _MOD.addItem("gem", 10) end`
- `energy_on` => `if _MOD then _MOD.infEnergy = true; _MOD.tick() end`
- `energy_off` => `if _MOD then _MOD.infEnergy = false; _MOD.tick() end`

The file is polled no more than once per second **inside an observed Lua pcall hook**, so it will not run when Lua is idle. The file is deleted once its command is accepted into the single-slot queue. No arbitrary Lua text is evaluated from this file. Only one queued action is allowed at a time.

### Exported explicit request APIs
- `int LuaHookV3_RequestGold(void)`
- `int LuaHookV3_RequestGem(void)`
- `int LuaHookV3_RequestEnergy(int enabled)`
- `int LuaHookV3_RetryInstall(void)`
- `int LuaHookV3_IsInstalled(void)`

The caller only queues an action; execution occurs after the original `lua_pcall` on that Lua thread.
All successful Lua executions are logged with the Lua return code. Game balance/network persistence is not confirmed by a zero return code.

## Risk and verification
- Experimental build. V1.1 game runtime Hook has been verified; V3 commands have not.
- `_MOD` is supplied by the recovered 3903-byte bootstrap, not assumed to be a base-game global. V3 now loads it in the observed Lua thread after `xyd` becomes a table and binds to the successfully initialized Lua state. Without evidence that it exists, V3 cannot call its addItem/tick implementation. V3 now rejects commands when `_MOD` is absent and drops a queued command if its required callable function is absent (no permanently blocked queue). If `lua_pcall` never fires again, requests cannot execute.
- Energy-on changes Lua game state and is **not** automatically reverted. Use `energy_off` to request restoration; this only reverses the Lua flag, not necessarily other game state.
- Explicitly test on a disposable local save/offline account; unknown server validation or network sync may exist.

## Field finding (2026-11-13)

Device logs showed `preflight rc=0 ABSENT _MOD type=nil`, followed by one queued gold action and many rejected requests. This proves the hooked Lua state did not expose a global `_MOD` at that time. In the original implementation, `_MOD` could be an injected helper created by the mod dylib, **not** an API provided by the base game. Static Lua plaintext alone does not provide the implementation of `_MOD.addItem` or `_MOD.tick`.

Fix: distinguish Lua hook availability from mod-helper availability; report missing `_MOD` in UI, reject uncallable requests and free the queue. Do not claim this change implements the missing mod helper. Full behavior requires finding how the original dylib defines/loads `_MOD` and whether that functionality can be reused legitimately.

## V3.2 recovered bootstrap integration

- Embeds exact recovered `MOD_bootstrap_recovered.lua` with SHA-256 gate `1d6114bb9d01eec56bef3360b535d85d789590451b52216744bee5cf50fa9f8a`.
- If `_MOD` is not yet present, first checks `type(xyd)=='table'` in the current Lua VM; otherwise delays initialization. Never executes Lua on a UIKit or background thread.
- Re-checks `_MOD.addItem` and `_MOD.tick` after bootstrap. Binds one active Lua state and avoids duplicate bootstrap from other states.
- Calls `_MOD.tick()` periodically on observed Lua calls (not a timer thread) to install delayed resource wrappers and refresh the infinite-energy option.
- The default `freeze` and `infEnergy` options are false; buttons are the only explicit resource-action triggers.
- If bootstrap cannot execute or xyd is missing, button requests remain unavailable rather than pretending to succeed. Real server persistence or resource changes remain unverified.
