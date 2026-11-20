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


## Xiuxianjiazu GM window toggle branch
- Feature branch: `xiuxianjiazu-gm-window-toggle`.
- Stable source baseline: `c00f81e86af8fb49359bd491fd824b0f98411b54` on `xiuxianjiazu`. The repository branch tip had moved to `42187ca7d7b326834c67e5503c7f5d70681bc5bb`; this feature branch intentionally does not include that later code change.
- Toggle ON resolves `GameUI.get_Instance` and invokes `OpenGMView`; OFF invokes `CloseView("GMView")`. Runtime lookup is restricted to `gameCore.dll`, main thread, and the matching UnityFramework UUID.
- Current acceptance: source review complete; macOS Actions build and iPhone UI behavior pending. Opening hides the standalone panel to avoid obscuring the original GM view; the bubble remains to reopen controls.
