#!/bin/sh
set -eu
SDK="$(xcrun --sdk iphoneos --show-sdk-path)"
CLANG="$(xcrun --find clang)"
"$CLANG" -arch arm64 -isysroot "$SDK" -miphoneos-version-min=12.0 -Os -Wall -Wextra -Werror -fvisibility=hidden -dynamiclib -Wl,-install_name,@rpath/LuaRuntimeHookV3.dylib LuaRuntimeHookV3.c -o LuaRuntimeHookV3.dylib
