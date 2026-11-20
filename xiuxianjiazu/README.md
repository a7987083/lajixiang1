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
