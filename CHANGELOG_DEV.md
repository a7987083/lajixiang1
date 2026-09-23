# CHANGELOG_DEV

## 2026-09-23
- Identified supplied `VIPCrackPlugin.dylib` as arm64 Mach-O; SHA-256 `90dd5288c91d14e404d74780d1b62a5b1a057dcc51a8defee2f78e6e6ea22f67`.
- Recovered hook registration: `UIWindow setWindowLevel:` -> `0x8A4`, `UIColor colorWithRed:...` -> `0xD5C8`, hue -> `0xD64C`, CGColor -> `0xD710`, `UIButton layoutSubviews` -> `0xD798`, `UIImageView setImage:` -> `0xD870` (preferred VA).
- Added independent `CyberSkinStandalone.mm` with delayed runtime hooks and procedural neon icon.
- Added non-destructive Mach-O patcher that inserts one `LC_LOAD_DYLIB` into header slack only.
- Added macOS/iPhoneOS GitHub Actions build.
- Source commit built: `661485c4339fafa65bbe8b5ee7c1cbb1ea43306f`.
- Actions Run `35830125612`: success.
- Artifact `10736327933`: `CyberSkinStandalone-v1`.
- Built `CyberSkinStandalone.dylib`: arm64 Mach-O, SHA-256 `f1ef05d25d97b0c089979872bd159a6204138c452b2ce893923ce2a722072def`.
- Generated derivative `VIPCrackPlugin_Cyber.dylib`: SHA-256 `940ae555cc26a1093526a591d05d271088e80bd18325ce331142afad0d519d3b`; verified new `@loader_path/CyberSkinStandalone.dylib` dependency and unchanged file length.
- Runtime/device verification: not yet performed.
