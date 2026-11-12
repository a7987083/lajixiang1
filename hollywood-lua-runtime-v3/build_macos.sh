#!/bin/sh
set -eu
SDK="$(xcrun --sdk iphoneos --show-sdk-path)"
CLANG="$(xcrun --find clang)"
python3 - <<'PY'
from pathlib import Path
import hashlib, json
p = Path("MOD_bootstrap_recovered.lua")
data = p.read_bytes()
expected = "1d6114bb9d01eec56bef3360b535d85d789590451b52216744bee5cf50fa9f8a"
digest = hashlib.sha256(data).hexdigest()
if digest != expected:
    raise SystemExit(f"recovered bootstrap identity mismatch: {digest}")
src = data.decode("ascii")
body = "\n".join("    " + json.dumps(line) for line in src.splitlines(keepends=True))
Path("LuaBootstrapV3.h").write_text(
    "/* Generated from exact recovered MOD bootstrap. */\n"
    "static const char kLuaBootstrap[] =\n" + body + ";\n"
)
print("Verified bootstrap bytes:", len(data), "sha256:", digest)
PY
"$CLANG" -arch arm64 -isysroot "$SDK" -miphoneos-version-min=12.0 -Os -Wall -Wextra -Werror -fobjc-arc -fvisibility=hidden -dynamiclib -Wl,-install_name,@rpath/LuaRuntimeHookV3.dylib LuaRuntimeHookV3.c LuaFloatingMenuV3.m -framework UIKit -framework Foundation -framework CoreGraphics -o LuaRuntimeHookV3.dylib
