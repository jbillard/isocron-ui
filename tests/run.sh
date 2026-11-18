#!/usr/bin/env bash
# The tests of the library: the scenes of `tests/scenes.isc` drawn by the
# interpreter and by the compiled program, both byte for byte the images of
# `tests/reference/`. `tests/run.sh --update` writes those images again (to
# look at before committing them). ISCC: the compiler (default: `iscc`).
# ISC_TEST_JOBS: how many interpretations and compilations at once (default
# 2: those of the editor take 2.1 and 2.3 GiB, two of them fit the 6 GiB of
# a heavy job of isocron's `tools/heavy.sh one`; one after the other, they
# took 22 minutes, 62 % compiling and 37 % interpreting).
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
# (the programs read their files from the root of the repository)
cd "$here/.."
iscc="${ISCC:-iscc}"
jobs_max="${ISC_TEST_JOBS:-2}"
update=0
[ "${1:-}" = "--update" ] && update=1
out="$(mktemp -d)"
trap 'rm -r -- "$out"' EXIT
mkdir "$out/interp" "$out/compiled"

# a job in the background, at most `jobs_max` at once; its exit status
# kept in `$out/<name>.status`, its output in `$out/<name>.log`
running=0
job() {
    local name="$1"
    shift
    ( set +e; "$@" > "$out/$name.log" 2>&1; echo $? > "$out/$name.status" ) &
    running=$((running + 1))
    if [ "$running" -ge "$jobs_max" ]; then
        wait -n || true
        running=$((running - 1))
    fi
}
scenes_interp() { "$iscc" run "$here/scenes.isc" "$out/interp" > "$out/interp.txt"; }
scenes_compiled() { "$iscc" build "$here/scenes.isc" -o "$out/scenes" && "$out/scenes" "$out/compiled" > "$out/compiled.txt"; }
check_interp() { "$iscc" run "$1" > "$out/$2.got"; }
check_compiled() { "$iscc" build "$1" -o "$out/$2" && "$out/$2" > "$out/$2.built"; }

job scenes.interp scenes_interp
job scenes.compiled scenes_compiled
# the programs of checks, each interpreted and compiled, the largest first
# (the longest jobs started first)
checks=""
[ "$update" = 1 ] || checks="$(ls -S "$here"/*_check.isc)"
for t in $checks; do
    name="$(basename "$t" .isc)"
    job "$name.interp" check_interp "$t" "$name"
    job "$name.compiled" check_compiled "$t" "$name"
done
wait

fail=0
for s in "$out"/*.status; do
    if [ "$(cat "$s")" != 0 ]; then
        name="$(basename "$s" .status)"
        echo "FAILED: $name exited with $(cat "$s"): $(tail -3 "$out/$name.log")"
        fail=1
    fi
done
[ "$fail" = 0 ] || exit 1
cmp "$out/interp.txt" "$out/compiled.txt" || { echo "interpreted and compiled differ"; diff "$out/interp.txt" "$out/compiled.txt"; exit 1; }
if [ "$update" = 1 ]; then
    mkdir -p "$here/reference"
    cp "$out/compiled/"*.png "$here/reference/"
    echo "reference images written: $(ls "$here/reference" | tr '\n' ' ')"
    exit 0
fi
# the programs of checks: their outputs, interpreted and compiled, are those
# of their `.out` files
for t in $checks; do
    want="${t%.isc}.out"
    name="$(basename "$t" .isc)"
    got="$(cat "$out/$name.got")"
    built="$(cat "$out/$name.built")"
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
