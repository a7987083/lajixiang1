# lajixiang1 — CyberSkin

Two deliverables for the supplied `VIPCrackPlugin.dylib` baseline.

- `VIPCrackPlugin_Cyber.dylib`: byte-preserving derivative of the supplied original. Only the Mach-O header/load-command area is changed to add `LC_LOAD_DYLIB @loader_path/CyberSkinStandalone.dylib`; original `__TEXT`/`__DATA` behavior remains intact. Use it together with `CyberSkinStandalone.dylib` in the same loader directory.
- `CyberSkinStandalone.dylib`: independent UIKit runtime skin. It detects likely floating/menu windows, applies dark cyber panels with neon cyan/magenta accents, and replaces compact square menu/floating images with a procedurally rendered cyber hex/circuit icon.

Baseline SHA-256: `90dd5288c91d14e404d74780d1b62a5b1a057dcc51a8defee2f78e6e6ea22f67`.

## Why the derivative is companion-loaded

The supplied dylib has no source. Static analysis identified its `UIImageView -setImage:` replacement at preferred VA `0xD870` and its UIColor replacements at `0xD5C8`, `0xD64C`, `0xD710`. Replacing those large ARM64 routines in place would be high risk and would destroy the original rollback surface. The derivative therefore preserves all original code and adds one reversible dependency command.

## Runtime scope

The standalone layer avoids global UIColor replacement. It limits styling to windows that look like overlays (elevated window level or menu/overlay/float/plugin-like class names), and excludes keyboard/text-effect/remote input windows.

## Compatibility target

- arm64
- minimum deployment target iOS 13.0
- UIKit/Foundation/QuartzCore/CoreGraphics only
- no Substrate/Dobby/ElleKit dependency in the standalone skin

## Validation status

CI validates compile/link/sign, exact original baseline hash, new dependency presence, and verifies that the derivative patch changes only pre-`0x8000` Mach-O header/load-command bytes. Device behavior still requires real-device verification.
