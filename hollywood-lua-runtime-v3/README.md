# Hollywood Crush Lua Runtime Hook V3 (explicit action testing)

## Scope
Uses the previously device-verified V1.1 hook path. V3 has **no automatic resource modifications**.
The four Lua commands were provided as previously recovered static plaintext; their gameplay effects have NOT been device verified.

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
- `_MOD` might not be present in every Lua state/environment; pending actions remain queued until a callable target is found. If `lua_pcall` never fires again, commands cannot execute.
- Energy-on changes Lua game state and is **not** automatically reverted. Use `energy_off` to request restoration; this only reverses the Lua flag, not necessarily other game state.
- Explicitly test on a disposable local save/offline account; unknown server validation or network sync may exist.
