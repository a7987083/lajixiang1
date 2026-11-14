# P3.2 — Exact target binary and native xLua bridge audit

## Input evidence
- User-provided archive `归档(5).zip`: `UnityFramework` (150859024 bytes) and
  `global-metadata.dat` (18005932 bytes).
- Image: Mach-O 64-bit ARM64 dynamic library, UUID
  `CC89F3E2-E288-3FBF-AB96-1FD4E58F047A`.
- UnityFramework SHA-256:
  `d7ebc545a1568bdf78f026b86cd4fe6b1df77509f165621cd29546de3fbf29ae`.
- global-metadata.dat SHA-256:
  `e915547090ff9ea594bca4432ac5e722411ef033b45f78b9f38ec3c2b7475f68`.

## Actual exported symbols (image-relative VA, NOT portable offsets)
| Export | Image-relative address |
| --- | --- |
| `lua_pushcclosure` | `0x03247CE0` |
| `lua_pcallk` | `0x032492A0` |
| `luaD_precall` | `0x032534D8` |
| `luaD_call` | `0x03253A30` |
| `xlua_tocsobj_safe` | `0x0328EC18` |
| `xlua_pushcsobj` | `0x0328F628` |
| `il2cpp_runtime_invoke` | `0x032A9040` |

Verified from the Mach-O export trie. These addresses are **evidence only**,
and are not compiled into the universal XRI hook resolver.

## ARM64 verified control flow
- `lua_pushcclosure+0x10`: `mov x21, x1` (C callback pointer),
  `+0x18`: `cbz w2` (upvalue count);
  parameter convention is `(lua_State*, lua_CFunction, int)`.
- `luaD_call+0x3C`: calls `luaD_precall`,
  and only takes the `luaV_execute` branch when the precall returns 0.
- `luaD_precall+0x2D8` (image-relative `0x032537B0` approximate
  disassembly continuation): the **confirmed instruction** at
  `0x032537AC` is `blr x23`, i.e. an indirect native C callback
  invocation following an optional debug hook. This supplies binary-level
  evidence that Lua C callbacks can execute without calling the exported
  `il2cpp_runtime_invoke` API.
- A registered function pointer alone does not identify which managed
  `MethodInfo` / generated C# wrapper it corresponds to.

## P3.2 implemented scope
- Observe `lua_pushcclosure` through the **existing** Hook installer, using
  exact exported symbol resolution. No fixed-offset patch and no added
  per-callback hooks.
- Keep up to 512 distinct callback pointers, count repeated registrations,
  and export actual runtime owning image name and load-relative offset.
- `cFunctionRegistrations` are **registration events**, not call events.
  `cFunctionRegistrationStats.overflow` counts omitted registrations once
  the distinct-pointer bound is reached.
- No `lua_sethook` override, no internal Lua stack dereferences, no
  `Il2CppClass` or `MethodInfo` layout assumptions.
- Registration after injection only. Code that registered before injection
  is not retrospectively reconstructed.

## Boundary and next step
P3.2 is a safe registration-provenance stage. It does not complete
`Lua -> generated C# Wrapper -> managed target method` execution correlation.
P3.3 must validate callback execution instrumentation against the same
Mach-O UUID (including ABI, recursion and VM lifetime) before it hooks any
internal VM entry or invokes `lua_getinfo`/stack APIs. Real-device runtime
confirmation of the P3.2 registration feed remains pending.
