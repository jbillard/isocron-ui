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
# ten tasks: their list scrolled to its end by the wheel, the tick at (80,
# 288) is the last task's (the fourth's without the wheel)
words="Un Deux Trois Quatre Cinq Six Sept Huit"
typing="$(for w in $words; do printf 'type:%s key:Return ' "$w"; done)"
scrolled="$(cd "$out" && python3 "$here/../tools/display/play.py" 520 420 clickat:211,124 $typing wheel:260,250,10 clickat:80,288 endserver -- "$out/todo" | tail -1)"
[ "$scrolled" = "[[x] Écrire la bibliothèque, [ ] Taper du texte dans un champ, [ ] Un, [ ] Deux, [ ] Trois, [ ] Quatre, [ ] Cinq, [ ] Six, [ ] Sept, [x] Huit]" ] || { echo "FAILED: scrolled: $scrolled"; exit 1; }
# the field edited by the pointer and its menu: a double click selects the
# word under it (replaced), Ctrl+A, the right button, "Copier", End, the
# menu again, "Coller"
edited="$(cd "$out" && python3 "$here/../tools/display/play.py" 520 420 clickat:211,124 "type:Bonjour le monde" dblclickat:140,124 type:la key:ctrl+a rclickat:211,124 clickat:311,170 key:End rclickat:211,124 clickat:311,198 key:Return endserver -- "$out/todo" | tail -1)"
[ "$edited" = "[[x] Écrire la bibliothèque, [ ] Taper du texte dans un champ, [ ] Bonjour la mondeBonjour la monde]" ] || { echo "FAILED: edited: $edited"; exit 1; }
# a screen of scale 2 (Weston's output twice the pixels): the list drawn
# at it, a click at the place of the field in pixels, a word typed
scaled2="$(cd "$out" && PLAY_SCALE=2 python3 "$here/../tools/display/play.py" 520 420 clickat:422,248 type:Pain key:Return endserver -- "$out/todo" | tail -1)"
[ "$scaled2" = "[[x] Écrire la bibliothèque, [ ] Taper du texte dans un champ, [ ] Pain]" ] || { echo "FAILED: scale 2: $scaled2"; exit 1; }
# the clipboard of the session: a text copied in the field read by another
# program (wl-paste), a text of another program (wl-copy) pasted after it;
# then copied and pasted again in the field (its own selection, read
# without the compositor)
shared="$(cd "$out" && python3 "$here/../tools/display/play.py" 520 420 clickat:211,124 "type:Vers dehors" key:ctrl+a key:ctrl+c "paste:$out/pasted.txt" "copy:Du dehors é" key:End key:ctrl+v key:ctrl+a key:ctrl+c key:End key:ctrl+v key:Return endserver -- "$out/todo" | tail -1)"
[ "$(cat "$out/pasted.txt")" = "Vers dehors" ] || { echo "FAILED: the selection read by wl-paste: $(cat "$out/pasted.txt")"; exit 1; }
[ "$shared" = "[[x] Écrire la bibliothèque, [ ] Taper du texte dans un champ, [ ] Vers dehorsDu dehors éVers dehorsDu dehors é]" ] || { echo "FAILED: clipboard: $shared"; exit 1; }
# X11 (Xvfb, no manager of windows: the window at (0, 0)): the same tasks
# typed, added and ticked; the clipboard shared with xclip; a density of
# 144 dots per inch (Xft.dpi): the window 1.5 times larger, a click at the
# place of the field in pixels
x11tasks="$(cd "$out" && PLAY_X11=1 python3 "$here/../tools/display/play.py" 520 420 clickat:211,124 type:Lait key:Return type:Pain clickat:411,124 clickat:80,174 clickat:211,124 type:Thex key:BackSpace key:Return endserver -- "$out/todo" | tail -1)"
[ "$x11tasks" = "[[ ] Écrire la bibliothèque, [ ] Taper du texte dans un champ, [ ] Lait, [ ] Pain, [ ] The]" ] || { echo "FAILED: X11 tasks: $x11tasks"; exit 1; }
x11shared="$(cd "$out" && PLAY_X11=1 python3 "$here/../tools/display/play.py" 520 420 clickat:211,124 "type:Vers dehors" key:ctrl+a key:ctrl+c "paste:$out/x11pasted.txt" "copy:Du dehors é" key:End key:ctrl+v key:ctrl+a key:ctrl+c key:End key:ctrl+v key:Return endserver -- "$out/todo" | tail -1)"
[ "$(cat "$out/x11pasted.txt")" = "Vers dehors" ] || { echo "FAILED: the selection read by xclip: $(cat "$out/x11pasted.txt")"; exit 1; }
[ "$x11shared" = "[[x] Écrire la bibliothèque, [ ] Taper du texte dans un champ, [ ] Vers dehorsDu dehors éVers dehorsDu dehors é]" ] || { echo "FAILED: X11 clipboard: $x11shared"; exit 1; }
x11dpi="$(cd "$out" && PLAY_X11=1 PLAY_DPI=144 python3 "$here/../tools/display/play.py" 780 630 clickat:316,186 type:Pain key:Return endserver -- "$out/todo" | tail -1)"
[ "$x11dpi" = "[[x] Écrire la bibliothèque, [ ] Taper du texte dans un champ, [ ] Pain]" ] || { echo "FAILED: X11 at 144 dpi: $x11dpi"; exit 1; }
# dead keys of the keyboard: ^ then e, ¨ then i, ´ then e, under Wayland
# and under X11, in the table us(intl) of Xvfb (Shift+6 the dead
# circumflex; the key of the apostrophe the dead acute, with Shift the dead
# diaeresis), which Weston takes from its server
deadkeys="clickat:211,124 key:shift+6 key:e key:shift+dead_acute key:i key:dead_acute key:e key:Return endserver"
deadwl="$(cd "$out" && PLAY_XKB=us:intl python3 "$here/../tools/display/play.py" 520 420 $deadkeys -- "$out/todo" | tail -1)"
[ "$deadwl" = "[[x] Écrire la bibliothèque, [ ] Taper du texte dans un champ, [ ] êïé]" ] || { echo "FAILED: dead keys under Wayland: $deadwl"; exit 1; }
deadx="$(cd "$out" && PLAY_X11=1 PLAY_XKB=us:intl python3 "$here/../tools/display/play.py" 520 420 $deadkeys -- "$out/todo" | tail -1)"
[ "$deadx" = "[[x] Écrire la bibliothèque, [ ] Taper du texte dans un champ, [ ] êïé]" ] || { echo "FAILED: dead keys under X11: $deadx"; exit 1; }
echo "ok: a window of Wayland, the counter played by a hand: $played; the tasks typed: $tasks; scrolled: $scrolled; edited: $edited; the clipboard shared: $shared; X11: $x11tasks, $x11shared, $x11dpi; dead keys: $deadwl, $deadx"
