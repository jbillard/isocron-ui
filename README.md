# isocron-ui

A library of graphical interfaces written in Isocron, after GPUI (the library
of the editor Zed): everything drawn on the processor by Isocron code, a
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

- `src/app.isc`: `run` and `runWith` (the texts of the menu of a field),
  `loadFont` (the file of `--font=`, `DejaVuSans.ttf` beside the program or
  in the current folder, then a font of the system), `fail` (a box of
  messages under Windows). The library keeps what the hand does to the
  interface itself: the place under the pointer and its shape, the clicks
  counted (double, triple), drags, the boxes that scroll (the wheel, their
  scrollbars), the caret blinking, the menu of a field (the right button),
  the clipboard (that of the system: Windows, the selection of a Wayland
  session, the selection `CLIPBOARD` of X11, read from and given to the
  other programs), the density of the
  screen (sizes in units of 96 dots per
  inch, multiplied by it). Its steps are one pure function (`step`), tested
  without a screen.
- `src/input.isc`: the inputs (`Click`, `Drag`, `Release`, `Hover`,
  `Text`, `Key` with its modifiers, `Paste`) and the effects (`Copy`,
  `AskPaste`).
- `src/edit.isc`: the text of a field (`Editing`: its caret and selection)
  and how the keys, the pointer and the clipboard change it (`edited`).
- `src/widgets.isc`: the components, those of the plate: `button`
  (primary, secondary), `iconButton`, `textField` (its hint, its ring of
  focus), `checkbox`, `radio`, `toggle`, `slider`, `progress`, `segments`,
  `avatar`, `badge`, `tooltip`.
- `src/ui.isc`: the elements (`Div` and its `Style`, a part of flexbox;
  `Label`, a text cut in lines; `Input`, the line of a field) and their
  layout (`placeFrame`: what draws them and the places the pointer
  reaches); `Image`, a PNG file read (`png.decode`) drawn in its box. A
  box that clips or scrolls places only the children it shows: a long list
  costs the rows in sight.

## Below

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
  window and its image sent in strips, the table of the keyboard, the
  pointers of the font `cursor`, the selection, the density of `Xft.dpi`).

## Tests and examples

`tests/run.sh` (with `ISCC` the compiler) draws the scenes of
`tests/scenes.isc` interpreted and compiled, compares them byte for byte
with `tests/reference/`, and runs the checks of `tests/*_check.isc`.
`tests/display.sh` plays a hand under Wayland (Weston in Docker, the image
of `tools/display`, `xdotool`) and under X11 (Xvfb in the same image). The examples: `examples/minimal.isc`,
`examples/todo_app.isc` (a list of tasks), `examples/gallery.isc` (the
plate: everything the library draws), `examples/counter_window.isc` and
`examples/gallery_window.isc` (Windows).
