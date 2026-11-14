# HANDOFF

## Baseline
Input: user-supplied `VIPCrackPlugin.dylib`, arm64 Mach-O, SHA-256 `90dd5288c91d14e404d74780d1b62a5b1a057dcc51a8defee2f78e6e6ea22f67`, UUID `BA5FE867-6E15-3EC5-A68F-AE847E92EF26`.

## Verified runtime history
- v8: real-device icon replacement works. Color remained unchanged.
- v9: carries v8 icon/URL/MD5 behavior and adds locked `#00FFFF` theme; device verification pending.
- v10: based on v9, adds title replacement `Check0ver Team` -> `taobaozonoe`; device verification pending.

## v10 title chain
`UINavigationItem -setTitle:` replacement starts at preferred VA `0x9110`.
The hook decodes `Authentication` from static block `0x15168`, tests `containsString:`, then decodes replacement title from static block `0x15190` with decoder `0xF250`.
Decoder semantics for the 14-byte title block: `decoded[i] = encoded[i] ^ (0x41 + i)`, then NUL terminator.
v10 replaces only file offsets `0x15190..0x1519D`; decoded result is `taobaozonoe` plus NUL padding.

## Current artifact
- v9 SHA-256: `4ebd1fa612040b5c4db5d929a122c05871cb9b4b794cdb13ac989641afe0ad01`
- v10 SHA-256: `7825c5511e9f36306e5726f37a2944bc783e08262d6223e0cf6f0d605e57b9cf`
- v10 changes exactly 14 bytes relative to v9.
- Mach-O dependency list is unchanged.

## Acceptance
Verify on device that v10 keeps the working replacement icon, preserves v9 color behavior, and shows `taobaozonoe` where the plugin previously showed `Check0ver Team`.


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
- Lua 5.3 mock behavior and source gate audit passed; shell syntax/diff checks passed. CI build/signature verification succeeded; see completed-build section. Real device unverified.
- Implementation/ABI/evidence/build instructions: petsharbor-resource-menu-v1/README.md. Next: CI build, inspect signed dylib, deliver for device tests.


### Pets Harbor V1 completed build — 2026-11-15
- Built commit b57d9875d06c1434588945396ea27f53b4e689f3; Actions Run 43619681186 succeeded; Artifact 14123512947.
- Signed iOS arm64 dylib, 142528 bytes, SHA-256 a62cc0fa23a7fd60e8065093a572426ddcf46692d5c63b5bdcacbf548beba3c1; downloaded ZIP and dylib hashes match CI. No dynamic Dobby/Substrate dependency.
- New implementation has no Bundle ID access, version/Build, UUID, instruction-signature gates or fixed game function RVA map. New source audit and binary import/string audit passed. These do not prove cross-game compatibility.
- Export discovery + live LuaEnv.Tick + managed DoString bridge is compiled, not yet device-tested. Single file PetsResourceMenu-V1.dylib delivered; P bubble / three resources / 1–100 quantity input.
- Next: device test readiness, before/after values, numeric keyboard, scene reset and relaunch. Cloud acceptance remains unverified.
