#!/usr/bin/env bash
# The tests of the library that need a display server (Docker, the image
# `isocron-ui-display` of tools/display): a window of Wayland shown (120
# frames), the counter and the list of tasks played by a hand under
# Wayland (Weston in a window of Xvfb, the input of `xdotool`: clicks, keys,
# text typed through the table of the keyboard), the models they make.
# ISCC: the compiler (default: `iscc`).
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
# the list of tasks (an application of src/app.isc): a click in its field,
# a word typed and Enter, a word and the button that adds, a task ticked,
# a word corrected by Backspace; the tasks printed when Weston stops
"$iscc" build examples/todo_app.isc -o "$out/todo"
cp tests/fonts/DejaVuSans.ttf "$out/"
tasks="$(cd "$out" && python3 "$here/../tools/display/play.py" 520 420 clickat:211,124 type:Lait key:Return type:Pain clickat:411,124 clickat:80,174 clickat:211,124 type:Thex key:BackSpace key:Return endserver -- "$out/todo" | tail -1)"
[ "$tasks" = "[[ ] Écrire la bibliothèque, [ ] Taper du texte dans un champ, [ ] Lait, [ ] Pain, [ ] The]" ] || { echo "FAILED: tasks: $tasks"; exit 1; }
echo "ok: a window of Wayland, the counter played by a hand: $played; the tasks typed: $tasks"
