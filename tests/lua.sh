#!/usr/bin/env bash
# The interpreter of Lua of the library (src/lua.isc) against the reference
# interpreter (Lua 5.4 of its authors, in the image `isocron-ui-lua` of
# tools/lua/ref): each script of tests/lua run by both, their outputs the
# same byte for byte; the scripts whose name ends in `_mine` (what this Lua
# does otherwise: its strings are texts of UTF-8) give their `.out`.
# ISCC: the compiler (default: `iscc`).
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
cd "$here/.."
iscc="${ISCC:-iscc}"
out="$(mktemp -d)"
trap 'rm -r -- "$out"' EXIT
docker image inspect isocron-ui-lua > /dev/null 2>&1 || docker build -q -t isocron-ui-lua tools/lua/ref > /dev/null
"$iscc" build tools/lua/run.isc -o "$out/run"
cd "$here/lua"
n=0
for f in *.lua; do
    name="${f%.lua}"
    mine="$("$out/run" "$f" 2>&1 || true)"
    if [ "${name%_mine}" != "$name" ]; then
        [ "$mine" = "$(cat "$name.out")" ] || { echo "FAILED: $f differs from $name.out"; diff <(echo "$mine") "$name.out" | head; exit 1; }
    else
        ref="$(docker run --rm -v "$PWD:/work:ro" isocron-ui-lua "$f" 2>&1 || true)"
        [ "$mine" = "$ref" ] || { echo "FAILED: $f differs from the reference"; diff <(echo "$ref") <(echo "$mine") | head; exit 1; }
    fi
    n=$((n + 1))
done
echo "ok: $n scripts of Lua, the same output as the reference interpreter (or their .out)"
