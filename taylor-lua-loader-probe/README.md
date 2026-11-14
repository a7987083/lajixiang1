# Taylor's Secret 1.8.9-69 — Read-only Lua Loader Probe

Target UnityFramework SHA256: d7ebc545a1568bdf78f026b86cd4fe6b1df77509f165621cd29546de3fbf29ae
Target UUID: CC89F3E2-E288-3FBF-AB96-1FD4E58F047A
Target: Solar.Runtime.LuaComponent.CustomLuaLoader(ref string), RVA 0x3A195FC, return byte[].

Only hooks matching UUID and with Substrate/Dobby available. Original method and return are unchanged. Logs module name before/after, byte count, first eight bytes, up to 3000 entries. No Lua code executed; no script body dumped. Log: Documents/TaylorLuaLoaderProbe.log.
Device unverified. Inject before the first Lua script load. Build on macOS with sh build_macos.sh.
