#!/bin/sh
set -eu
SDK="$(xcrun --sdk iphoneos --show-sdk-path)"
CLANG="$(xcrun --find clang)"
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
python3 - <<'PY'
from pathlib import Path
import json
s=Path('ResourceOperation.lua').read_text().replace('%','%%')
s=s.replace('__RESOURCE_ID__','%d').replace('__RESOURCE_AMOUNT__','%d')
Path('ResourceOperation.h').write_text('static const char kResourceOperation[] =\n'+'\n'.join(json.dumps(x,ensure_ascii=False) for x in s.splitlines(keepends=True))+';\n')
PY
"$CLANG" -arch arm64 -isysroot "$SDK" -miphoneos-version-min=12.0 -Os \
  -Wall -Wextra -Werror -fvisibility=hidden -c TaylorRuntime.c -o TaylorRuntime.o
"$CLANG" -arch arm64 -isysroot "$SDK" -miphoneos-version-min=12.0 -Os \
  -Wall -Wextra -Werror -Wno-deprecated-declarations -fobjc-arc -fvisibility=hidden \
  -c TaylorMenu.m -o TaylorMenu.o
"$CLANG" -arch arm64 -isysroot "$SDK" -miphoneos-version-min=12.0 \
  -dynamiclib -Wl,-install_name,@rpath/TaylorResourceMenu-V1.dylib \
  TaylorRuntime.o TaylorMenu.o .deps/build/libdobby.a -lc++ \
  -framework UIKit -framework Foundation -framework CoreGraphics -o TaylorResourceMenu-V1.dylib
codesign --force -s - TaylorResourceMenu-V1.dylib
codesign --verify --strict TaylorResourceMenu-V1.dylib
file TaylorResourceMenu-V1.dylib
shasum -a 256 TaylorResourceMenu-V1.dylib > SHA256SUMS.txt
cat SHA256SUMS.txt
otool -L TaylorResourceMenu-V1.dylib
cp .deps/Dobby/LICENSE Dobby-LICENSE.txt
