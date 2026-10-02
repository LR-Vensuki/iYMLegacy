#!/bin/sh
set -eu

APP="${1:?missing app path}"
EXE="$APP/iYMLegacy"

if [ ! -x "$EXE" ]; then
    echo "ERROR: application executable not found: $EXE" >&2
    exit 1
fi

mkdir -p "$APP/libs"
cp -a "$(dirname "$0")/../libs/." "$APP/libs/"

TOOL="${INSTALL_NAME_TOOL:-}"

if [ -z "$TOOL" ] && command -v install_name_tool >/dev/null 2>&1; then
    TOOL="$(command -v install_name_tool)"
fi

if [ -z "$TOOL" ] && command -v llvm-install-name-tool >/dev/null 2>&1; then
    TOOL="$(command -v llvm-install-name-tool)"
fi

if [ -z "$TOOL" ] && [ -n "${THEOS:-}" ] && [ -d "$THEOS/toolchain" ]; then
    TOOL="$(
        find "$THEOS/toolchain" -type f             \( -name 'install_name_tool' -o -name 'llvm-install-name-tool' -o -name '*install_name_tool' \)             -perm -111 -print -quit 2>/dev/null || true
    )"
fi

if [ -z "$TOOL" ]; then
    echo "ERROR: install-name tool not found." >&2
    echo "Set INSTALL_NAME_TOOL=/full/path/to/install_name_tool and rerun make package." >&2
    echo "Diagnostic:" >&2
    echo "  find \"${THEOS:-$HOME/theos}/toolchain\" -type f \( -name 'install_name_tool' -o -name 'llvm-install-name-tool' -o -name '*install_name_tool' \) -print" >&2
    exit 1
fi

echo "Using install-name tool: $TOOL"

# Rewrite dependencies in the executable.
"$TOOL" -change /usr/lib/libcurl.4.dylib     @executable_path/libs/libcurl.dylib "$EXE" 2>/dev/null || true
"$TOOL" -change /usr/lib/libssl.0.9.8.dylib     @executable_path/libs/libssl.dylib "$EXE" 2>/dev/null || true
"$TOOL" -change /usr/lib/libcrypto.0.9.8.dylib     @executable_path/libs/libcrypto.dylib "$EXE" 2>/dev/null || true
"$TOOL" -change /usr/lib/libgcc_s.1.dylib     @executable_path/libs/libgcc_s.1.dylib "$EXE" 2>/dev/null || true

# Rewrite dependencies inside bundled legacy dylibs.
"$TOOL" -change /usr/lib/libcrypto.0.9.8.dylib     @loader_path/libcrypto.dylib "$APP/libs/libssl.dylib" 2>/dev/null || true
"$TOOL" -change /usr/lib/libgcc_s.1.dylib     @loader_path/libgcc_s.1.dylib "$APP/libs/libssl.dylib" 2>/dev/null || true
"$TOOL" -change /usr/lib/libcrypto.0.9.8.dylib     @loader_path/libcrypto.dylib "$APP/libs/libcurl.dylib" 2>/dev/null || true

echo "Staged application: $APP"
