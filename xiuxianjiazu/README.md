# 修仙家族 GM 独立菜单（第一阶段）

Branch: \`xiuxianjiazu\`. Separate from the existing CyberSkin module and workflows.

## Scope

- Compact ivory/tan UIKit overlay inspired by the provided screenshot; floating draggable GM button, collapsible window
- Searchable item, skill, attribute tabs; editable quantity; manual GM command tab
- No invented catalog: data must be supplied by an IL2CPP adapter at runtime
- No fake success: action cannot execute without an attached executor; successful executor return means request accepted locally, **not** server-side grant
- The original game GM window is accessed only through the explicit **原生 GM** switch; all other overlay features remain separate from the game's prefab.
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


## Automatic catalog export and dropdown (current version)
- During normal gameplay, the menu retries loading **both** \`ItemTmpl.configs\` and \`SkillInfo.configs\` every three seconds until loaded (up to 60 attempts); no fake IDs or fabricated catalog entries.
- Complete valid catalog rows are persisted atomically to \`Documents/XiuxianjiazuGM/items.json\` and \`Documents/XiuxianjiazuGM/skills.json\` in the game's app sandbox. Each contains \`[{"id":123,"name":"..."}]\`.
- "搜索物品" text field filters the **already exported** list; directly beneath it is a collapsible selector. Only the first 200 matching entries are rendered, while the full catalog is retained in memory and JSON. Switching to the 功法 tab uses the separate \`SkillInfo\` list.
- Selecting an entry displays its real numeric ID and keeps the GM action surface unchanged. The game server's acceptance of any GM command remains unverified.
- Runtime catalog enumeration and UI interaction still need **device testing**. The build pipeline checks arm64 compilation, signing, and artifact packaging only.


## Export diagnostics and manual retry (2026-11-21)
- Added per-catalog UI state: item and skill export results are recorded separately. E101-E210 are surfaced directly in the overlay instead of a generic "not loaded" status.
- Added a **重新导出** action on the item/skill panels; it remains functional even when the 60 automatic startup retries are exhausted.
- The export bridge now publishes each attempt via `XJGMReportExport(category, result, saved)`. A successful runtime catalog read and successful JSON persistence are separately reported; failed sandbox writes show E109 without falsely claiming a saved file.
- The UI no longer overwrites a failed export code with a generic waiting message after reload. Empty catalogs are not marked as ready.
- The original game GM request sending path remains unchanged. iPhone runtime behavior and server-side outcomes are still unverified.


## Original game GM window switch (2026-11-21)

- The overlay header includes an **原生 GM** switch. ON resolves `GameUI.get_Instance()` from `gameCore.dll` and invokes the original `GameUI.OpenGMView()`; OFF invokes `GameUI.CloseView("GMView")`.
- The call uses IL2CPP method lookup and `il2cpp_runtime_invoke`, runs on the UIKit/Unity main thread, and requires the exact uploaded UnityFramework UUID. It does not use the hard-coded `OpenGMView` RVA.
- When ON succeeds locally, the large overlay panel hides while the floating bubble remains, so it does not cover the game's GMView. The request is submitted locally; actual view appearance and close behavior still require device verification. The isolated arm64 Actions build completed successfully (run 44816231515).
