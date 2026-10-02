#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
cd "$ROOT"

sh -n autogen.sh
sh -n VERIFY_SOURCE.sh

if command -v plutil >/dev/null 2>&1; then
    plutil -lint src/Info.plist
else
    python3 - <<'PY2'
import plistlib
with open("src/Info.plist", "rb") as f:
    plistlib.load(f)
print("Info.plist: OK")
PY2
fi

for f in cYandexMusic/*.c; do
    clang -fsyntax-only -std=gnu11 -I./cYandexMusic "$f"
done

printf '%s\n' "Source checks passed."
