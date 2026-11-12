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
# the keyboard alone: Tab to the field, a word, Tab to Ajouter, Enter (the
# task added), Tab to the box of the first task, Space (unticked); under
# Wayland and under X11
keys="move:300,300 key:Tab type:Lait key:Tab key:Return key:Tab key:space endserver"
tabwl="$(cd "$out" && python3 "$here/../tools/display/play.py" 520 420 $keys -- "$out/todo" | tail -1)"
[ "$tabwl" = "[[ ] Écrire la bibliothèque, [ ] Taper du texte dans un champ, [ ] Lait]" ] || { echo "FAILED: the keyboard under Wayland: $tabwl"; exit 1; }
tabx="$(cd "$out" && PLAY_X11=1 python3 "$here/../tools/display/play.py" 520 420 $keys -- "$out/todo" | tail -1)"
[ "$tabx" = "[[ ] Écrire la bibliothèque, [ ] Taper du texte dans un champ, [ ] Lait]" ] || { echo "FAILED: the keyboard under X11: $tabx"; exit 1; }
# the long list (100 000 tasks, the rows in sight alone built): 50 notches
# of the wheel (2000 units: row 45 at the top), a click on the box of the
# task 48; under Wayland and under X11
"$iscc" build examples/long_list_app.isc -o "$out/long"
longwl="$(cd "$out" && python3 "$here/../tools/display/play.py" 520 420 wheel:260,250,50 clickat:62,200 endserver -- "$out/long" | tail -1)"
[ "$longwl" = "[47]" ] || { echo "FAILED: the long list under Wayland: $longwl"; exit 1; }
longx="$(cd "$out" && PLAY_X11=1 python3 "$here/../tools/display/play.py" 520 420 wheel:260,250,50 clickat:62,200 endserver -- "$out/long" | tail -1)"
[ "$longx" = "[47]" ] || { echo "FAILED: the long list under X11: $longx"; exit 1; }
# selections made by a hand: a double click in "deux" whose pointer moves
# while its button is held (the whole word kept: before, the part before
# the pointer alone), a drag across words, Shift+Left three times, a triple
# click whose pointer moves (the whole text); each replaced by a word typed;
# under Wayland and under X11
selections="clickat:211,124 type:un\ deux\ trois dblmoveat:108,124 type:DEUX key:Return type:un\ deux\ trois drag:93,124,150,124 type:X key:Return type:un\ deux\ trois key:shift+Left key:shift+Left key:shift+Left type:a key:Return type:abc\ def tplmoveat:100,124 type:Tout key:Return endserver"
want="[[x] Écrire la bibliothèque, [ ] Taper du texte dans un champ, [ ] un DEUX trois, [ ] unXois, [ ] un deux tra, [ ] Tout]"
selwl="$(cd "$out" && eval python3 "$here/../tools/display/play.py" 520 420 $selections -- "$out/todo" | tail -1)"
[ "$selwl" = "$want" ] || { echo "FAILED: selections under Wayland: $selwl"; exit 1; }
selx="$(cd "$out" && eval PLAY_X11=1 python3 "$here/../tools/display/play.py" 520 420 $selections -- "$out/todo" | tail -1)"
[ "$selx" = "$want" ] || { echo "FAILED: selections under X11: $selx"; exit 1; }
# the live gallery: the pointer resting over "?" (its tooltip drawn after
# half a second: its colour read in the screenshot), "Animer" clicked (the
# bar filled in a second by the frames of the loop), the switch clicked
# (its knob slid); under Wayland and under X11
"$iscc" build examples/gallery_app.isc -o "$out/gallery"
for mode in wayland x11; do
    x=""; [ "$mode" = x11 ] && x=1
    live="$(cd "$out" && PLAY_X11=$x python3 "$here/../tools/display/play.py" 1280 800 move:586,48 wait:0.8 "shot:$out/tip-$mode.png" clickat:84,48 wait:1.3 clickat:520,48 wait:0.5 endserver -- "$out/gallery" | tail -1)"
    [ "$live" = "(1, 1, true)" ] || { echo "FAILED: the animations under $mode: $live"; exit 1; }
    tip="$(python3 "$here/../tools/display/pixel.py" "$out/tip-$mode.png" 612 82)"
    [ "$tip" = "17 24 39" ] || { echo "FAILED: the tooltip under $mode: $tip"; exit 1; }
done
# large texts through the clipboard: 588 895 bytes of another program
# pasted (X11: by xsel, in parts, INCR; Wayland: a pipe), 828 890 copied and
# read by another (xclip, given in parts; wl-paste); their lengths and CRCs
"$iscc" build tests/clip_app.isc -o "$out/clip"
for mode in wayland x11; do
    x=""; [ "$mode" = x11 ] && x=1
    big="$(cd "$out" && PLAY_X11=$x ISC_UI_TRACE=1 python3 "$here/../tools/display/play.py" 400 200 move:200,100 copyseq:100000 wait:0.5 key:ctrl+v wait:3 key:ctrl+c "paste:$out/big-$mode.txt" endserver -- "$out/clip" 70000)"
    [ "$(echo "$big" | tail -1)" = "(588895, 3239055117)" ] || { echo "FAILED: a large paste under $mode: $(echo "$big" | tail -1)"; exit 1; }
    [ "$(python3 -c "import sys, zlib; b = open(sys.argv[1], 'rb').read(); print(len(b), zlib.crc32(b))" "$out/big-$mode.txt")" = "828890 2854953365" ] || { echo "FAILED: a large copy under $mode"; exit 1; }
    if [ "$mode" = x11 ]; then
        [ "$(echo "$big" | grep -c 'X11 INCR part')" -gt 100 ] || { echo "FAILED: the paste under X11 not in parts"; exit 1; }
    fi
done
# the image of X11 by MIT-SHM (the trace says it is used) and in strips:
# the same pixels
shm="$(cd "$out" && PLAY_X11=1 ISC_UI_TRACE=1 python3 "$here/../tools/display/play.py" 520 420 move:20,20 "shot:$out/shm.png" endserver -- "$out/todo" | grep -c 'MIT-SHM, true')"
[ "$shm" = 1 ] || { echo "FAILED: MIT-SHM not used"; exit 1; }
(cd "$out" && PLAY_X11=1 ISC_UI_NO_SHM=1 python3 "$here/../tools/display/play.py" 520 420 move:20,20 "shot:$out/strips.png" endserver -- "$out/todo" > /dev/null)
cmp -s "$out/shm.png" "$out/strips.png" || { echo "FAILED: MIT-SHM and the strips differ"; exit 1; }
# a fractional scale (sway, image isocron-ui-sway: wp_fractional_scale_v1
# and wp_viewporter, an output of 520 by 420 units at 1.5): the window
# drawn at 780 by 630 pixels, the same as the scene of the list at 1.5
# (tests/reference/todo150start.png); a click at (80, 174) units, the box
# of the first task (untick); the trace says the fractional scale is used.
# Without it (Weston, above), the integer scale
fractional="$(cd "$out" && ISC_UI_TRACE=1 python3 "$here/../tools/display/sway.py" 520 420 "shot:$out/sway.png" clickat:80,174 endserver -- "$out/todo")"
[ "$(echo "$fractional" | grep -c 'Wayland fractional scale, true')" = 1 ] || { echo "FAILED: no fractional scale under sway"; exit 1; }
[ "$(echo "$fractional" | tail -1)" = "[[ ] Écrire la bibliothèque, [ ] Taper du texte dans un champ]" ] || { echo "FAILED: a click at a fractional scale: $(echo "$fractional" | tail -1)"; exit 1; }
[ "$(python3 "$here/../tools/display/same.py" "$out/sway.png" "$here/reference/todo150start.png")" = "0 " ] || { echo "FAILED: the image at a fractional scale differs"; exit 1; }
echo "ok: a window of Wayland, the counter played by a hand: $played; the tasks typed: $tasks; scrolled: $scrolled; edited: $edited; the clipboard shared: $shared; X11: $x11tasks, $x11shared, $x11dpi; dead keys: $deadwl, $deadx; the keyboard: $tabwl, $tabx; the long list: $longwl, $longx; selections: $selwl, $selx; the live gallery: tooltips and animations; large clipboards; MIT-SHM and strips the same; a fractional scale of 1.5 under sway, the same pixels"
