# Pets Harbor Resource Menu V1

Input analyzed: Pet's Harbor 1.1.9 build 16. UnityFramework SHA-256 `83924fd70be09c9cb3a73e59119cc1f09b12f388caf9b1b0f0e2e447859a9b61`. This records the analyzed input, not a runtime allowlist.

## Requested behavior

- New branch: `feature/petsharbor-resource-menu-v1`, based on Taylor's completed-build branch at `25575afc37b892dea094d56e289027412b4e78d9`.
- No reading of the current App Bundle ID. No version/Build gate. No UnityFramework UUID gate. No instruction-signature gate or fixed game function RVA table.
- Resolve IL2CPP exports from loaded images, enumerate the `XLua.LuaEnv` class and select `Tick()` and the `DoString(System.String, ..., ...)` overload through method metadata. Hook the actual Tick method pointer using statically linked Dobby.
- After original Tick, execute explicit menu requests on the main thread using `il2cpp_runtime_invoke(DoString, currentEnv, ...)`. Managed DoString owns its Lua lock and stack restoration. No cached LuaEnv, raw lua_State or assumed LuaEnv field offsets.
- Missing runtime methods, loading game objects, invalid input, runtime exceptions and request timeouts produce status messages; no App identity/age restrictions are added.

## UI and operation

Inject only `PetsResourceMenu-V1.dylib`, then tap the draggable `P` bubble. Enter a quantity 1–100, choose 增加钻石 / 增加体力 / 增加星星, or 刷新余额. Inline numeric input has a Done toolbar. Dobby is embedded; no second Dobby/Substrate dylib is required.

The verified bytecode call is:

```lua
ModuleManager.PropertySystem:CheckChangeData(
  id, amount, nil, ECheckerboardType.Main, FunctionSource.GM
)
```

IDs: diamond=1, energy=2, star=3. The exact argument order was recovered from `UIGMTools.lua`, original line 1486. `PropertySystem.CheckChangeData` line 790 enters CheckMainChangeData line 843 and ChangeProperty line 292. The property table defines these IDs independently. This package does not contain Taylor's GM.lua; no GM.AddItem is called.

Readiness uses rawget on ModuleManager to avoid instantiating modules in an unrelated/incomplete VM. Operations are one-shot and report actual before/after values. No automatic resource mutations, forced saves, forced server requests, anti-cheat modifications or purchase simulation. Original resource logic and save lifecycle remain active. No version gate does NOT establish compatibility with another app or version.

## ABI and lifecycle

- The analyzed binary exports the required public `il2cpp_*` APIs; symbol definitions were checked in its Mach-O symbol table.
- Target metadata v31 contains `XLua.LuaEnv`, two DoString overloads with 3 parameters, and a zero-argument Tick. These were parsed from target metadata rather than copied from Taylor's address map.
- Native Hook uses MethodInfo's leading methodPointer and the arm64 instance-call ABI `(self, MethodInfo*)`.
- runtime_invoke reference arguments are object pointers. The returned object[] has the normal arm64 IL2CPP array layout. Result type and length are handled before copying UTF-16 into a UTF-8 UI buffer. These ABI/runtime assumptions still require real-device confirmation.
- One queued request, 10 second cancellation; no stale instance pointer retained across ticks; managed errors are captured as exceptions and displayed. Export `PetsResourceDisable()` cancels pending actions and makes the trampoline inert until restart.
- Overlay uses the game UIWindowScene on iOS 13+, passes outside touches through, temporarily obtains key-window status while entering a number and restores the previous key window afterward.

## Build / validation

Run `sh build_macos.sh` on macOS. Dobby pinned at `5dfc8546954ce3b3198132ab13fddb89ee92cdd7`, Apache-2.0 license included in the artifact. Darwin SymbolResolver is enabled because DobbyCodePatch needs it.

Our sources compile with -Wall -Wextra -Werror; the build signs ad hoc and checks the produced signature. These are build checks, not game startup restrictions. `python3 test_operation.py` with lupa.lua53 tests mock Lua behavior and absence of the three requested app gates; it does not execute the real game. CI and device status are recorded in root PROJECT_STATE.json / HANDOFF.md.

Log: Documents/PetsResourceMenu.log. To uninstall, remove this injected dylib/load command and re-sign the IPA. Runtime Hook permissions depend on the actual injection/signing environment.
