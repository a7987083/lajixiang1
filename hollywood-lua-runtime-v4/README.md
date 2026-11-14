# Hollywood Lua V4 — Bundled Dobby + Runtime Feedback

Baseline: V3 in `feature/hollywood-lua-runtime-v1` at `9c928382dae3b22eacb19def605906eb20de5283`.

- Dobby statically linked at pinned commit `5dfc8546954ce3b3198132ab13fddb89ee92cdd7`; Darwin symbol resolver enabled. Does not require external `MSHookFunction` or `DobbyHook`.
- Records actual Dobby return code, original trampoline and target address, without treating installed library as installed Hook.
- Displays Hook availability, _MOD state, request acceptance and eventual Lua execution response inside H menu; log is `Documents/LuaHookV4.log`.
- V3 Lua bootstrap hash, Lua API resolution, explicit actions and all game-side scripts retained.
- V3 command file is renamed to `Documents/LuaHookV4.command`.
- Build and ad hoc signature on macos-15 with iPhoneOS arm64 via `sh build_macos.sh`.
- Hook cannot be guaranteed on stock iOS because static Dobby does not confer executable page rights.
- `EXECUTED` means Lua returned successfully, NOT confirmed currency change or save persistence; device not tested.
