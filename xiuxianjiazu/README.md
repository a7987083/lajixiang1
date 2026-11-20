# 修仙家族 GM 独立菜单（第一阶段）

Branch: \`xiuxianjiazu\`. Separate from the existing CyberSkin module and workflows.

## Scope

- Compact ivory/tan UIKit overlay inspired by the provided screenshot; floating draggable GM button, collapsible window
- Searchable item, skill, attribute tabs; editable quantity; manual GM command tab
- No invented catalog: data must be supplied by an IL2CPP adapter at runtime
- No fake success: action cannot execute without an attached executor; successful executor return means request accepted locally, **not** server-side grant
- Does **not** call empty \`OpenGMView\`, nor depend on original GM Prefab
- No off-target injection, SDK upgrade or changes to existing baseline files

## Adapter API

The standalone dylib exports:

\`\`\`c
typedef int (*XJGMExecutor)(const char *kind, int32_t id, int32_t count, const char *arg);
void XJGMSetExecutor(XJGMExecutor executor);
int XJGMSetEntries(const char *category, const char *json);
\`\`\`

\`category\` is \`item\`, \`skill\`, or \`attr\`.
\`json\` is \`[{"id":123,"name":"名称"}]\`.
\`kind\` passed to the executor is \`item\`, \`skill\`, \`attr\`, or \`command\`.

The caller must inspect the **target version**'s real IL2CPP object lifecycle, metadata and GM command protocol before implementing the adapter. The previously supplied game's \`C2S_GMComand\` has \`typeStr\` and \`params1\`, but the correct command strings, parameters, and server authorization have not been validated.

## Verification

Requires GitHub Actions iOS/macOS build. Real-device injection, rendering and game-side GM effects are not yet verified.


## Item ID and original GM request (current phase)

- The '查物品ID' control accepts a decimal positive ID and queries \`config.export.excel.ItemTmpl.Find(int)\` using the original IL2CPP runtime. A matching name and actual ID are returned from the game, never from a hardcoded sample.
- Select the returned item, set quantity, and press Execute. The adapter instantiates \`xxjz.game.C2S_GMComand\` and calls its original setters and \`GameApp.Send\`.
- The request type string and route are taken from the exact target Mach-O's original metadata slots, after validating UUID \`316950d2-5cd5-32b9-a2df-ffbf3d3b8d11\`. The binary is limited to the uploaded game version.
- The executor returns local submission status only. Whether the game server accepts GM commands requires device-side verification; no client-side bypass of server authorization is implemented.
- Skill/attribute/command actions remain deliberately unavailable until their payload semantics are verified.
- **Test order**: verify GM window visible, look up a known item ID and a deliberately invalid ID, select a valid item, request quantity 1, then verify both in-game inventory and server response before claiming success.


## Catalog read failure fix (2026-11-20)

- Fixed IL2CPP `runtime_invoke` reference arguments: managed object references must be passed as object pointers, not the address of local object-pointer variables. Applies to the `ValueCollection.CopyTo` array argument and original GM command's object/string arguments.
- Now unboxes and checks `ItemTmpl.get_IsConfigsEmpty()`. Error E102 means the game catalog is not loaded. UI displays distinct E101-E108 error phases instead of the earlier ambiguous generic message.
- Build success establishes only compilation/link/signing. Live IL2CPP enumeration and server-side GM authorization remain **unverified on device**.
