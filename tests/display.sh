#!/usr/bin/env bash
# The tests of the library that need a display server (Docker, the image
# `isocron-ui-display` of tools/display): a window of Wayland shown (120
# frames), and the counter played by a hand under Wayland (Weston in a
# window of Xvfb, the input of `xdotool`): six clicks, then five keys, the
# model they make. ISCC: the compiler (default: `iscc`).
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
cd "$here/.."
iscc="${ISCC:-iscc}"
out="$(mktemp -d)"
trap 'rm -r -- "$out"' EXIT
"$iscc" build examples/window.isc -o "$out/window"
"$iscc" build examples/counter_wayland.isc -o "$out/counter"
shown="$(tools/display/run.sh "$out/window.png" "$out/window" 120 | tail -1)"
[ "$shown" = "shown: true, frames: 120" ] || { echo "FAILED: window: $shown"; exit 1; }
played="$(python3 tools/display/play.py 480 320 click:1 click:1 click:1 click:2 click:4 click:1 key:Up key:Down key:Down key:s key:Up key:Escape -- "$out/counter" | tail -1)"
# +, +, +, −, a step of 10, + (12); up, down, down (2), a step of 1, up
[ "$played" = "(3, 1)" ] || { echo "FAILED: counter: $played"; exit 1; }
echo "ok: a window of Wayland, the counter played by a hand: $played"
