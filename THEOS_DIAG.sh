#!/bin/sh
set -eu
printf '%s\n' "THEOS=${THEOS:-<unset>}"
printf '%s\n' "--- SDK ---"
test -n "${THEOS:-}" && ls -ld "$THEOS/sdks/iPhoneOS6.1.sdk"
printf '%s\n' "--- install-name tools ---"
command -v install_name_tool 2>/dev/null || true
command -v llvm-install-name-tool 2>/dev/null || true
if [ -n "${THEOS:-}" ]; then
  find "$THEOS/toolchain" -type f \( -name 'install_name_tool' -o -name '*install_name_tool' -o -name 'llvm-install-name-tool' \) -print 2>/dev/null | head -20 || true
fi
printf '%s\n' "--- project ---"
for f in Makefile src/Info.plist src/iYMLegacyConfig.h libs/libcurl.dylib libs/libssl.dylib libs/libcrypto.dylib cYandexMusic/curl/curl.h; do
  if [ -e "$f" ]; then printf 'OK %s\n' "$f"; else printf 'MISSING %s\n' "$f"; fi
done
