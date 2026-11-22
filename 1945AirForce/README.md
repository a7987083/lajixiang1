# 1945 Air Force GM — isolated runtime prototype

Source baseline: lajixiang1/main at 100a0b3669addb22e1fa811c5a48047f478b0cdd.
V3 reference: ZonoePatch-V2/ZonoePatch-V3 at 41835e7e7e4229bb8668352c0b3c5bb8cc5155f8.

## Scope
- Standalone UIKit GM overlay, draggable bubble.
- IL2CPP exports dynamically resolved from UnityFramework.
- Assembly/class/method/argument count resolver, overload guards.
- Static invoke via il2cpp_runtime_invoke; one System.Int32 parameter.
- Instance methods detected, but rejected pending verified object lifecycle. No fake success.
- No hardcoded RVA; no evidence of server-side persistence.

## Reuse
- V3MenuHost: scene-aware hosting pattern.
- V3UIComponents: visual components.
- V3ModuleResolver: dyld module discovery design.
- V3FeatureModels: future Action/NumberInput schema.
- xiuxianjiazu/XJGMMenu: standalone bubble pattern only.
- Do not reuse static Mach-O builder, signature rebuilding, runtime bytes patch writer, nor game-specific adapters.

## Manual test
1. Inject only this dylib in an authorized laboratory game build and sign the complete app.
2. Confirm launch, GM bubble, keyboard and drag, scene switching.
3. Resolve Assembly-CSharp / DataCheat / AddGem / 1000. Expected E107 for instance method.
4. Test one known harmless static System.Int32 method and verify effect externally.
5. Confirm invalid class E104, invalid method E105, overload E106, unsupported parameter E109 and managed exception E111.
6. Do not claim successful resource modification until server persistence is verified.

## Next
Validated instance singleton resolver, object lifetime management, multiple parameters and return-value handling. No automatic MonoBehaviour instantiation without explicit lifecycle evidence.

## Verification
Source committed; CI and physical device results must be checked separately.
