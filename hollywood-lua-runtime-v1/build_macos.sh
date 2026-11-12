#!/bin/sh
set -eu
SDK="$(xcrun --sdk iphoneos --show-sdk-path)"
CLANG="$(xcrun --find clang)"
"$CLANG" -arch arm64 -isysroot "$SDK" -miphoneos-version-min=12.0 -Os -Wall -Wextra -fvisibility=hidden -dynamiclib -Wl,-install_name,@rpath/LuaRuntimeHookV1.dylib LuaRuntimeHookV1.c -o LuaRuntimeHookV1.dylib
