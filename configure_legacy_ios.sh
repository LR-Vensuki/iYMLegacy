#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
cd "$ROOT"

SDK=${SDK:-$(xcrun --sdk iphoneos --show-sdk-path)}
CC=${CC:-clang}
OBJC=${OBJC:-clang}
CXX=${CXX:-clang++}
INSTALL_NAME_TOOL=${INSTALL_NAME_TOOL:-install_name_tool}

"$ROOT/autogen.sh"

CC="$CC" \
OBJC="$OBJC" \
CXX="$CXX" \
INSTALL_NAME_TOOL="$INSTALL_NAME_TOOL" \
CFLAGS="${CFLAGS:-} -arch armv7 -isysroot $SDK -miphoneos-version-min=6.0" \
OBJCFLAGS="${OBJCFLAGS:-} -fobjc-arc -arch armv7 -isysroot $SDK -miphoneos-version-min=6.0" \
LDFLAGS="${LDFLAGS:-} -arch armv7 -isysroot $SDK -miphoneos-version-min=6.0" \
./configure --host=arm-apple-darwin11

printf '%s\n' "Configured for legacy iOS SDK: $SDK"
printf '%s\n' "Build with: make -C src iYMLegacy iYMLegacy.app iYMLegacy.ipa"
