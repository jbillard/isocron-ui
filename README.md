# isocron-ui

A library of graphical interfaces written in Isocron, after GPUI (the library
of the editor Zed): everything drawn on the processor by Isocron code, in a
window of Windows (the module `win32`), of Wayland or of X11 (the module
`unix`, no C library: each protocol spoken on its socket), the same
application on all three. Under Linux, Wayland when `WAYLAND_DISPLAY` names
a compositor, else the server of X11 of `DISPLAY`. The design and its plan:
`docs/proposals/gui.md` of the Isocron repository (D631).

## An application

An application is written in the manner of Elm: a model of any type, a view
(the elements of a model) and an update (the model after an input of the
hand, and what it asks of the system). `examples/minimal.isc`, a button
counting its clicks:

```isc
import { runWith, loadFont, fail } from "../src/app";
import { Input, Effect, Click, Hover } from "../src/input";
import { Element, Div, Auto, style } from "../src/ui";
import { button } from "../src/widgets";

type Model = { count: i64, hover: i64 };

function view(m: Model): Element {
    return Div({ ...style(), padding: 20.0f32 }, [button(`${m.count} clics`, 1, true, Auto, { hovered: m.hover == 1, pressed: false })]);
}

function update(m: Model, i: Input): [Model, Effect[]] {
    return match (i) {
        Click(place, x, y, at, clicks, mods) => [{ ...m, count: m.count + 1 }, []] as const,
        Hover(place) => [{ ...m, hover: place }, []] as const,
        _ => [m, []] as const,
    };
}

action main(args: string[k]): i32 {
    return match (loadFont(args)) {
        Ok(f) => {
            const end = runWith("Exemple", 320, 120, ["Couper", "Copier", "Coller", "Tout sélectionner"], f, { count: 0, hover: -1 }, view, update);
            print(end.count);
            return 0;
        },
        Err(e) => {
            fail("Exemple", e);
            return 1;
        },
    };
}
```

## What the library does for an application

- **Layout**: boxes (`Div` and its `Style`: a part of flexbox, sizes as
  their content, in units or as shares; padding, gaps, alignment), texts
  cut in lines (`Label`), the line of a field (`Input`), images (`Image`, a
  PNG file read by `png.decode`, drawn in its box, bilinear), primitives
  drawn in a box (`Canvas`, as GPUI's `canvas`).
- **The pointer**: the place under it, its shape (an arrow, a hand over a
  place a click reaches, a bar over a field), clicks counted (double,
  triple), drags; the boxes that scroll (the wheel, their scrollbars in a
  gutter of their own: a click in its track, its thumb dragged).
- **The keyboard**: the focus moved by Tab and Shift+Tab over the boxes
  `focusable` (the components: buttons, boxes, fields) in the order of the
  view, a ring drawn around the one that has it, Enter and Space clicking
  it, Escape giving it back; dead keys composed under Wayland and X11 (`^`
  then `e`: `ê`; Windows composes them itself).
- **Fields of text** (`src/edit.isc`): the caret blinking, a selection by the
  keys (Shift with the arrows, Home, End, by words with Ctrl) and by the
  pointer (a click, Shift and a click, a drag; a double click takes a word,
  a drag after it whole words; a triple click the whole text), Ctrl+A, C, X
  and V, the menu of a field (the right button: cut, copy, paste, select
  all, its texts given by the application).
- **The clipboard of the system**: that of Windows, the selection of a
  Wayland session (`wl_data_device`, its text written into the pipe of the
  program that pastes it), the selection `CLIPBOARD` of X11 (in parts,
  INCR, past 64 KiB), read from and given to the other programs.
- **Long lists** (GPUI's `uniform_list`): `uniformList` builds the rows in
  sight alone; the model is told where its box is (`Viewport`). 100 000
  tasks laid out in 0.3 to 0.4 ms.
- **Tooltips**: the style `tip` of a box with a message, shown when the
  pointer rests half a second over it, hidden by a press.
- **Animations** in the manner of Elm: the effect `Animate` asks the next
  frame, the model is told its time by `Tick` (about every 16 ms) and asks
  again while it moves.
- **The density of the screen**: sizes in units of 96 dots per inch,
  multiplied by it: under Windows that of its screen (`GetDpiForWindow`),
  under Wayland the scale of the screen or the fractional scale of the
  window (`wp_fractional_scale_v1` and `wp_viewporter`: 1.5 is drawn at 1.5
  pixels a unit, sharp), under X11 `Xft.dpi`.
- **Drawing**: the images of the glyphs kept from one frame to the next
  (the atlas of GPUI); under X11 the image sent through a memory shared with
  the server (MIT-SHM), in strips without it.

Its steps are one pure function (`step` of `src/app.isc`), tested without a
screen.

## Its files

- `src/app.isc`: `run` and `runWith` (the texts of the menu of a field),
  `loadFont` (the file of `--font=`, `DejaVuSans.ttf` beside the program or
  in the current folder, then a font of the system), `fail` (a box of
  messages under Windows); the loops of Windows, Wayland and X11.
- `src/input.isc`: the inputs (`Click`, `Drag`, `Release`, `Hover`, `Text`,
  `Key` with its modifiers, `Paste`, `Focus`, `Viewport`, `Tick`) and the
  effects (`Copy`, `AskPaste`, `Animate`).
- `src/edit.isc`: the text of a field (`Editing`: its caret and selection)
  and how the keys, the pointer and the clipboard change it (`edited`).
- `src/widgets.isc`: the components, those of the plate: `button`
  (primary, secondary), `iconButton`, `textField` (its hint, its ring of
  focus), `checkbox`, `radio`, `toggle` and `toggleAt` (its knob sliding),
  `slider`, `progress`, `segments`, `avatar`, `badge`, `tooltip`;
  `withTip`; `uniformList`.
- `src/ui.isc`: the elements and their layout (`placeFrame`: what draws
  them and the places the pointer and the keyboard reach). A box that clips
  or scrolls places only the children it shows.
- `src/atlas.isc`: the images of the glyphs kept.
- `src/paint.isc`: the primitives of a scene drawn on the processor by
  tiles: rectangles with rounded corners and borders, their shadows, glyphs,
  images (bilinear), clips; the formulas of the shaders of GPUI in `f32`.
- `src/font.isc`, `src/text.isc`: a font of TrueType read, its glyphs drawn
  with an exact coverage, kerning, lines and paragraphs.
- `src/png.isc`, `src/inflate.isc`: PNG files written and read (every file
  of the standard, checked against the decoder of Go on the PngSuite).
- `src/wayland.isc`, `src/xkb.isc`, `src/cursors.isc`: the protocol of
  Wayland, its keyboard, the images of the pointer drawn when the
  compositor does not draw them (at the scale of the screen).
- `src/x11.isc`: the core protocol of X11 (the cookie of `.Xauthority`, the
  window and its image, the table of the keyboard, the pointers of the font
  `cursor`, the selection, the density of `Xft.dpi`, MIT-SHM).

## Examples

Each is built by `iscc build examples/NAME.isc -o NAME` (for Windows: with
`--target x86_64-windows --subsystem windows`); the applications read
`DejaVuSans.ttf` beside them or in the current folder (`tests/fonts/`).

- `minimal.isc`: the button above; prints its clicks at the end.
- `todo_app.isc` (`todo.isc`): a list of tasks: a field, tasks ticked and
  removed, a list that scrolls, the clipboard, the keyboard alone; prints
  its tasks at the end.
- `long_list_app.isc` (`long_list.isc`): 100 000 tasks (or the number
  given) in a long list; prints those ticked.
- `gallery_app.isc` (`gallery_live.isc`, `gallery_plate.isc`): the plate of
  everything the library draws, under a band of live components (tooltips,
  a bar filled in a second, a switch that slides).
- `gallery.isc`: the plate written to the PNG file given; `cards.isc` and
  `hello_text.isc` (shadows and borders, text at several sizes) the same.
- `counter_wayland.isc` (`counter.isc`) and `window.isc`: a counter and a
  scene in a window of Wayland, by the module alone (no `runWith`).
- `counter_window.isc` and `gallery_window.isc`: the counter and the plate
  in a window of Windows (`win32`, no `runWith`).

## Tests

`tests/run.sh` (with `ISCC` the compiler) draws the scenes of
`tests/scenes.isc` interpreted and compiled, compares them byte for byte
with `tests/reference/`, and runs the checks of `tests/*_check.isc` (the
editing of a field, the steps of the list of tasks, the long list, the
tooltips and animations, X11, Wayland, PNG, the inflater, text, fonts,
keyboards). `tests/display.sh` plays a hand under Wayland (Weston in
Docker, the image of `tools/display`, `xdotool`), under X11 (Xvfb in the
same image) and under sway at a fractional scale (the image of
`tools/display/sway`), and runs every example of Linux; the programs of
Windows are played in its machine.
