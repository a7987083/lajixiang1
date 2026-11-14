# ROADMAP

## Phase 8 — URL + image integrity
- [x] Replace icon URL with `https://ios.zonoeios.xyz/1c.png`.
- [x] Synchronize runtime/default and fallback image MD5 to `4de386e134d3f739c7f879ef883b04fc`.
- [x] Preserve original MD5 validation and `_exit(111)` behavior.
- [x] Real-device verify replacement icon works.

## Phase 9 — Theme color
- [x] Recover runtime color source path and final `UIColor *` slot.
- [x] Generate encrypted color source that decrypts to `#00FFFF`.
- [x] Prevent runtime configuration from overwriting the color source.
- [ ] Real-device verify the menu theme changes to cyan while icon remains correct.

## Phase 10 — Title
- [x] Recover `UINavigationItem -setTitle:` hook at `0x9110`.
- [x] Recover replacement-title XOR block at file offset `0x15190` and decoder `0xF250`.
- [x] Replace decoded `Check0ver Team` with `taobaozonoe` using only 14 data bytes.
- [x] Verify Mach-O dependencies unchanged.
- [ ] Real-device verify title shows `taobaozonoe`.

## Current acceptance
Test v10 as one file. Expected: working replacement icon from v8, cyan theme from v9, and title `taobaozonoe`. If one item fails, isolate that chain without changing the already verified icon/MD5 path.


## Taylor resource menu V1 (2026-11-14)
- Branch: feature/taylor-resource-menu-v1; baseline: 67935a7a996ee0c996f278ca2103f029755bd3e5.
- Source: taylor-resource-menu-v1/README.md covers ABI/RVAs, lifecycle and build steps.
- Tick hook uses the live LuaEnv only on the game main thread; explicit one-shot GM.AddItem for IDs 1/2/3, balance verification, input and feedback. Embedded pinned Dobby.
- Local checks: Lua 5.3 mock behavior harness, shell syntax and diff checks passed. These do not prove game behavior.
- Public source publication explicitly approved by user. CI build/signature verification completed; see latest completed-build section. Real device and cloud persistence unverified.
- Next: inspect Actions result, deliver dylib, verify device hook installation and before/after resource values, then scene/reset/relaunch persistence.


### Taylor V1 completed build — 2026-11-14
- Built source: a4e7537d2975e6bddb82d364f47d129f806ac2b5. Actions Run 43574080410: success. Artifact 14106015108.
- Initial link failure `_DobbySymbolResolver` fixed by enabling Dobby's required Darwin symbol-resolver component; pinned dependency and SDK unchanged.
- iOS arm64 compile, ad-hoc signing and `codesign --verify --strict` passed. No dynamic Dobby/Substrate dependency.
- Dylib SHA-256: 2650d6b3df218fcc2e258f93b8a12c85af673f1fa984359384b38962c6fb6da8. Downloaded artifact hash matches CI output.
- Delivered binary: TaylorResourceMenu-V1.dylib (142080 bytes). Device/runtime/scene reset/cloud acceptance still unverified.


## Pets Harbor resource menu V1 — 2026-11-15
- New branch feature/petsharbor-resource-menu-v1; base Taylor completed-build commit 25575afc37b892dea094d56e289027412b4e78d9. Taylor implementation preserved.
- User explicitly requested no Bundle ID access, version/Build verification or UnityFramework UUID verification; new runtime has none of these gates and no instruction-signature gate.
- Resolve IL2CPP exports and XLua.LuaEnv methods dynamically; hook live Tick; invoke managed DoString on the current main-thread instance. No game native function RVAs/raw Lua state offsets.
- Actual Petsharbor script calls ModuleManager.PropertySystem:CheckChangeData(id, amount, nil, ECheckerboardType.Main, FunctionSource.GM). IDs 1/2/3. No Taylor GM.AddItem dependency.
- Lua 5.3 mock behavior and source gate audit passed; shell syntax/diff checks passed. CI pending, real device unverified.
- Implementation/ABI/evidence/build instructions: petsharbor-resource-menu-v1/README.md. Next: CI build, inspect signed dylib, deliver for device tests.
