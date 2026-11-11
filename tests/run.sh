#!/usr/bin/env bash
# The tests of the library: the scenes of `tests/scenes.isc` drawn by the
# interpreter and by the compiled program, both byte for byte the images of
# `tests/reference/`. `tests/run.sh --update` writes those images again (to
# look at before committing them). ISCC: the compiler (default: `iscc`).
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
# (the programs read their files from the root of the repository)
cd "$here/.."
iscc="${ISCC:-iscc}"
out="$(mktemp -d)"
trap 'rm -r -- "$out"' EXIT
mkdir "$out/interp" "$out/compiled"
"$iscc" run "$here/scenes.isc" "$out/interp" > "$out/interp.txt"
"$iscc" build "$here/scenes.isc" -o "$out/scenes"
"$out/scenes" "$out/compiled" > "$out/compiled.txt"
cmp "$out/interp.txt" "$out/compiled.txt" || { echo "interpreted and compiled differ"; diff "$out/interp.txt" "$out/compiled.txt"; exit 1; }
if [ "${1:-}" = "--update" ]; then
    mkdir -p "$here/reference"
    cp "$out/compiled/"*.png "$here/reference/"
    echo "reference images written: $(ls "$here/reference" | tr '\n' ' ')"
    exit 0
fi
fail=0
# the programs of checks: their outputs, interpreted and compiled, are those
# of their `.out` files
for t in "$here"/*_check.isc; do
    want="${t%.isc}.out"
    name="$(basename "$t" .isc)"
    got="$("$iscc" run "$t")"
    "$iscc" build "$t" -o "$out/$name"
    built="$("$out/$name")"
    if [ "$got" != "$(cat "$want")" ] || [ "$built" != "$got" ]; then
        echo "FAILED: $name (interpreted, compiled, or both, differ from $(basename "$want"))"
        fail=1
    fi
done
for f in "$out/compiled/"*.png; do
    name="$(basename "$f")"
    if ! cmp -s "$f" "$here/reference/$name"; then
        echo "FAILED: $name differs from its reference"
        fail=1
    fi
done
[ "$fail" = 0 ] && echo "ok: $(wc -l < "$out/compiled.txt") scenes and $(ls "$here"/*_check.isc | wc -l) checks, interpreted = compiled = reference"
exit "$fail"
