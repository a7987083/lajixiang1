#!/bin/sh
set -eu
SDK="$(xcrun --sdk iphoneos --show-sdk-path)"
"$(xcrun --find clang)" -arch arm64 -isysroot "$SDK" -miphoneos-version-min=12.0 -Os -Wall -Wextra -Werror -fvisibility=hidden -dynamiclib -Wl,-install_name,@rpath/TaylorLuaLoaderProbe.dylib TaylorLuaLoaderProbe.c -o TaylorLuaLoaderProbe.dylib
codesign --force -s - TaylorLuaLoaderProbe.dylib
file TaylorLuaLoaderProbe.dylib
shasum -a 256 TaylorLuaLoaderProbe.dylib
