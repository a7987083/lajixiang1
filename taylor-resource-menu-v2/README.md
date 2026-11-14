# Taylor Resource Menu V2

Based on V1 branch `feature/taylor-resource-menu-v1` at commit `25575afc37b892dea094d56e289027412b4e78d9`.
V1 files/commits are retained unchanged. V2 has a separate branch, directory, and build artifact.

## Requested compatibility behavior

**Removed these three restrictions:** Bundle ID (not present in V1), CFBundleShortVersionString / CFBundleVersion (not present in V1), and UnityFramework LC_UUID (removed in V2).

**Still required before any resource menu is displayed:**
- Loaded `UnityFramework.framework/UnityFramework` is a 64-bit ARM64 Mach-O.
- Fixed API RVAs all fall within the expected executable `__TEXT` segment (VM address zero).
- `XLua.LuaEnv.Tick` RVA `0x3B65878` matches the 16-byte opcode signature from V1.
- Dobby successfully installs the Hook and returns an original-function trampoline.

The menu is activated **only after the Hook succeeds**. On a failed ABI/signature/Hook check no menu is created. No Bundle ID, game version/build or UUID is accessed by V2. Logging remains `Documents/TaylorResourceMenu.log`.

## Limitations and safety

Removing UUID does **not** make fixed RVAs universally compatible. Different binaries might share a Tick prefix while changing `self+0x10` or any of the five additional Lua API signatures. This V2 remains an *experimental*, signature-gated fixed-RVA implementation and is not a general game-version compatibility guarantee.

The V1 single-shot Lua operation, quantities 1–100, resource IDs, original anti-cheat check, 10-second request timeout, game-main-thread restriction, status text and save behavior are unchanged. No automatic mutation occurs without a button action.

The V1 device test status is unchanged: Hook execution, game resource changes, scene lifecycle and persistence are not verified by CI. CI checks compile, codesign, and offline source tests only.
