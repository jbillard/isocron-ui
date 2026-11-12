#!/usr/bin/env bash
# The generator of views (tools/uigen): the module of the list of tasks it
# makes from examples/todo.ui.xml the one in the repository (made again
# whenever they change); faulty files refused at their file and line; an
# expression naming a field the model has not refused by iscc. (That the
# view made draws the same pixels as the one written in code:
# tests/uigen_check.isc, run by tests/run.sh.)
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
cd "$here/.."
iscc="${ISCC:-iscc}"
out="$(mktemp -d)"
trap 'rm -r -- "$out"' EXIT
"$iscc" run tools/uigen/uigen.isc examples/todo.ui.xml "$out/todo_view.isc" > /dev/null
sed "s|$out/todo_view.isc|examples/todo_view.isc|" "$out/todo_view.isc" | cmp -s - examples/todo_view.isc || { echo "FAILED: examples/todo_view.isc is not what uigen makes"; diff <(sed "s|$out/todo_view.isc|examples/todo_view.isc|" "$out/todo_view.isc") examples/todo_view.isc | head; exit 1; }
fault() {
    got="$("$iscc" run tools/uigen/uigen.isc "tests/uigen/$1.ui.xml" "$out/x.isc" 2>&1 || true)"
    [ "$got" = "$2" ] || { echo "FAILED: tests/uigen/$1.ui.xml: $got"; exit 1; }
}
fault tag 'tests/uigen/tag.ui.xml:3: the element <label> is unknown (box, row, column, text, button, iconbutton, field, checkbox, toggle, progress, each, slot)'
fault attr 'tests/uigen/attr.ui.xml:2: the attribute `colour` is unknown for a box'
fault value 'tests/uigen/value.ui.xml:2: `large` is not a value of `gap` (a number)'
fault class 'tests/uigen/class.ui.xml:2: the class `b` is not in the styles'
fault syntax 'tests/uigen/syntax.ui.xml:4: `</row>` closes `text`'
fault property 'tests/uigen/badstyle.style:3: the property `margin` is unknown (width, height, direction, gap, padding, padX, padY, justify, align, stretch, background, border, borderColor, radius, shadowBlur, shadowY, shadowColor, clip, scroll, cursor, focusable, tip, outline, outlineColor)'
# made, then refused by iscc: the model has no field `nothing`
"$iscc" run tools/uigen/uigen.isc tests/uigen/field.ui.xml tests/uigen/field_view.isc > /dev/null
checked="$("$iscc" check tests/uigen/field_view.isc 2>&1 || true)"
rm -f tests/uigen/field_view.isc
echo "$checked" | grep -q 'nothing' || { echo "FAILED: a field unknown not refused by iscc: $checked"; exit 1; }
echo "ok: the view made from todo.ui.xml up to date; 6 faulty files refused at their lines; a field unknown refused by iscc ($(echo "$checked" | head -1))"
