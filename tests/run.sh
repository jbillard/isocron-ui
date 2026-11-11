#!/usr/bin/env bash
# The tests of the library: the scenes of `tests/scenes.isc` drawn by the
# interpreter and by the compiled program, both byte for byte the images of
# `tests/reference/`. `tests/run.sh --update` writes those images again (to
# look at before committing them). ISCC: the compiler (default: `iscc`).
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
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
for f in "$out/compiled/"*.png; do
    name="$(basename "$f")"
    if ! cmp -s "$f" "$here/reference/$name"; then
        echo "FAILED: $name differs from its reference"
        fail=1
    fi
done
[ "$fail" = 0 ] && echo "ok: $(wc -l < "$out/compiled.txt") scenes, interpreted = compiled = reference"
exit "$fail"
