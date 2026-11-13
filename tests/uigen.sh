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
# the same for the view of the editor compiled (examples/editor)
"$iscc" run tools/uigen/uigen.isc examples/editor/editor.ui.xml "$out/editor_view.isc" > /dev/null
sed "s|$out/editor_view.isc|examples/editor/editor_view.isc|" "$out/editor_view.isc" | cmp -s - examples/editor/editor_view.isc || { echo "FAILED: examples/editor/editor_view.isc is not what uigen makes"; diff <(sed "s|$out/editor_view.isc|examples/editor/editor_view.isc|" "$out/editor_view.isc") examples/editor/editor_view.isc | head; exit 1; }
fault() {
    got="$("$iscc" run tools/uigen/uigen.isc "tests/uigen/$1.ui.xml" "$out/x.isc" 2>&1 || true)"
    [ "$got" = "$2" ] || { echo "FAILED: tests/uigen/$1.ui.xml: $got"; exit 1; }
}
fault tag 'tests/uigen/tag.ui.xml:3: the element <label> is unknown (box, row, column, text, button, iconbutton, field, checkbox, toggle, progress, each, slot)'
fault attr 'tests/uigen/attr.ui.xml:2: the attribute `colour` is unknown for a box'
fault value 'tests/uigen/value.ui.xml:2: `large` is not a value of `gap` (a number)'
fault class 'tests/uigen/class.ui.xml:2: the class `b` is not in the styles'
fault syntax 'tests/uigen/syntax.ui.xml:4: `</row>` closes `text`'
fault state 'tests/uigen/state.style:5: `.a:checked` is not a class (`.name`, `.name:hover`, `.name:active`, `.name:focus`)'
fault property 'tests/uigen/badstyle.style:3: the property `margin` is unknown (width, height, direction, gap, padding, padX, padY, justify, align, stretch, background, border, borderColor, radius, shadowBlur, shadowY, shadowColor, clip, scroll, cursor, focusable, tip, outline, outlineColor, borderTop, borderRight, borderBottom, borderLeft, floating, moves, minWidth, maxWidth, folds, radiusTopLeft, radiusTopRight, radiusBottomRight, radiusBottomLeft, under, spreadX, barWidth, barColor, barHoverColor, barRadius, barInset, opacity)'
# made, then refused by iscc: the model has no field `nothing`
"$iscc" run tools/uigen/uigen.isc tests/uigen/field.ui.xml tests/uigen/field_view.isc > /dev/null
checked="$("$iscc" check tests/uigen/field_view.isc 2>&1 || true)"
rm -f tests/uigen/field_view.isc
echo "$checked" | grep -q 'nothing' || { echo "FAILED: a field unknown not refused by iscc: $checked"; exit 1; }
# the states of a class (:hover, :active): a box with a message takes them
# after the model's `hover` and `pressed` (those of the generic
# application); a box without one keeps its classes alone; checked by iscc
"$iscc" run tools/uigen/uigen.isc tests/uigen/hover.ui.xml tests/uigen/hover_view.isc > /dev/null
made="$(cat tests/uigen/hover_view.isc)"
hran="$("$iscc" run tests/uigen/hover_main.isc 2>&1 || true)"
rm -f tests/uigen/hover_view.isc
[ "$hran" = "42 2" ] || { echo "FAILED: the box under the pointer did not take its state :hover (#2A2A2B, gap 2): $hran"; exit 1; }
echo "$made" | grep -qF '(m.pressed == (7) ? (m.hover == (7) ? { ...cls_a__active(cls_a__hover(cls_a(style()))), width: Px(20.0f32), onClick: 7 } : { ...cls_a__active(cls_a(style())), width: Px(20.0f32), onClick: 7 }) : (m.hover == (7) ? { ...cls_a__hover(cls_a(style())), width: Px(20.0f32), onClick: 7 } : { ...cls_a(style()), width: Px(20.0f32), onClick: 7 }))' || { echo "FAILED: the states of a box with a message: $(echo "$made" | grep -m1 'm.pressed')"; exit 1; }
echo "$made" | grep -qF 'm.hover == ((8 + m.items.length)) ? { ...cls_a__hover(cls_b(cls_a(style()))), onClick: (8 + m.items.length) }' || { echo "FAILED: the states of a box of two classes: $(echo "$made" | grep -m2 'm.pressed' | tail -1)"; exit 1; }
[ "$(echo "$made" | grep -c 'm.pressed')" = 2 ] || { echo "FAILED: a box without a message takes the states"; exit 1; }
echo "ok: the views made from todo.ui.xml and editor.ui.xml up to date; 7 faulty files refused at their lines; a field unknown refused by iscc ($(echo "$checked" | head -1)); the states of classes made and checked"
