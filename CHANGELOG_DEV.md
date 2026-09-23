# CHANGELOG_DEV

## 2026-09-23
- Identified supplied `VIPCrackPlugin.dylib` as arm64 Mach-O; SHA-256 `90dd5288c91d14e404d74780d1b62a5b1a057dcc51a8defee2f78e6e6ea22f67`.
- Recovered hook registration: `UIWindow setWindowLevel:` -> `0x8A4`, `UIColor colorWithRed:...` -> `0xD5C8`, hue -> `0xD64C`, CGColor -> `0xD710`, `UIButton layoutSubviews` -> `0xD798`, `UIImageView setImage:` -> `0xD870` (preferred VA).
- Added independent `CyberSkinStandalone.mm` with delayed runtime hooks and procedural neon icon.
- Added non-destructive Mach-O patcher that inserts one `LC_LOAD_DYLIB` into header slack only.
- Added macOS/iPhoneOS GitHub Actions build and patch-invariant tests.
- Build/CI/device verification: pending at initial commit.
