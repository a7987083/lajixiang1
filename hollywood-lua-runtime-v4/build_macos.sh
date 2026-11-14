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
DOBBY_COMMIT=5dfc8546954ce3b3198132ab13fddb89ee92cdd7
if [ ! -d .deps/Dobby/.git ]; then
  mkdir -p .deps
  git clone https://github.com/jmpews/Dobby.git .deps/Dobby
fi
git -C .deps/Dobby checkout --detach "$DOBBY_COMMIT"
cmake -S .deps/Dobby -B .deps/build -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DCMAKE_SYSTEM_NAME=iOS -DCMAKE_SYSTEM_PROCESSOR=arm64 -DCMAKE_OSX_ARCHITECTURES=arm64 \
  -DCMAKE_OSX_SYSROOT="$SDK" -DCMAKE_OSX_DEPLOYMENT_TARGET=12.0 \
  -DCMAKE_BUILD_TYPE=Release -DDOBBY_DEBUG=OFF -DPlugin.SymbolResolver=ON \
  -DPlugin.ImportTableReplace=OFF -DDOBBY_BUILD_EXAMPLE=OFF -DDOBBY_BUILD_TEST=OFF
cmake --build .deps/build --target dobby_static --parallel 3
"$CLANG" -arch arm64 -isysroot "$SDK" -miphoneos-version-min=12.0 -Os -Wall -Wextra -Werror -fobjc-arc -fvisibility=hidden -dynamiclib -Wl,-install_name,@rpath/LuaRuntimeHookV4.dylib LuaRuntimeHookV4.c LuaFloatingMenuV4.m  .deps/build/libdobby.a -lc++ -framework UIKit -framework Foundation -framework CoreGraphics -o LuaRuntimeHookV4.dylib
codesign --force -s - LuaRuntimeHookV4.dylib
codesign --verify --strict LuaRuntimeHookV4.dylib
shasum -a 256 LuaRuntimeHookV4.dylib > SHA256SUMS.txt
cp .deps/Dobby/LICENSE Dobby-LICENSE.txt
