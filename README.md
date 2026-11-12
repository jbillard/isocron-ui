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

## Interfaces in files

A view can also be described in XML, its styles in a file in the manner of
CSS, both read at compile time: `tools/uigen` turns them into the module of
Isocron that builds its elements, which `iscc` then compiles with the
program. An element, an attribute, a property, a value or a class the
generator does not know is refused at its file and line; the expressions
`{...}` are given to `iscc` as they are (a field of the model or a message
that does not exist is an error of compilation, on a line that names the
line of the XML). `examples/todo.ui.xml` and `examples/todo.style` describe
the view of the list of tasks, the same pixels as the one in code
(`tests/uigen_check.isc`):

```xml
<view function="view" model="Model" styles="todo.style" import="./todo: Model, ADD, hand">
  <column class="card">
    <text size="18" color="#111827">Tâches</text>
    <row class="line" gap="8">
      <field edit="{m.field}" focused="{m.focused}" hint="Nouvelle tâche" id="FIELD"/>
      <button id="ADD" hand="{hand(m, ADD)}">Ajouter</button>
    </row>
    <each items="{m.items}" as="it" index="k"> ... </each>
  </column>
</view>
```

```css
.card { width: 400; padding: 16; gap: 10; background: #FFFFFF; radius: 12; shadowColor: rgba(0, 0, 0, 0.18); }
```

```
iscc run tools/uigen/uigen.isc examples/todo.ui.xml examples/todo_view.isc
iscc build examples/todo_xml_app.isc -o todo_xml_app
```

The elements: `box`, `row`, `column`, `text` (`{expr}` in its text),
`button`, `iconbutton`, `field`, `checkbox`, `toggle`, `progress`, `each`
(its child for each element of an array), `slot` (elements made by code).
The attributes of a box and the properties of a class are those of
`Style`; a text has `size`, `color` and `textAlign`; `class` names classes,
`id` the message of a click. `src/xml.isc` and `src/css.isc` read the files.

## Interfaces read when the program starts

The generic application (`examples/scripted_app.isc`, the module
`src/scripted.isc`) compiles nothing of an interface: it reads, when it
starts, a view in XML (the vocabulary of `uigen`), one or more files of
styles and one or more scripts of Lua, run by the machine of Lua of the
library (`src/lua_*.isc`: the part of Lua 5.4 an interface needs, its
tables, closures, metatables, the libraries `string`, `table` and `math`,
a collector). The values `{...}`
are expressions of Lua, made functions once when the files are read (an
error in one is told at its line of the XML); a click runs the Lua of
`onclick`; a field is the text of a global of Lua (`bind`). The elements
are made again after each input. `examples/scripted/` holds the list of
tasks so written (here in part), the same pixels as the one in code
(`tests/scripted_check.isc`):

```xml
<view title="Isocron : tâches (Lua)" width="448" height="380" styles="todo.style" script="todo.lua" onclose="report()">
  <box class="ground" onclick="">
    <column class="card">
      <row class="line" gap="8">
        <field bind="newTask" hint="Nouvelle tâche" onenter="add()"/>
        <button onclick="add()">Ajouter</button>
      </row>
      <each items="{tasks}" as="it" index="k">
        <row class="task">
          <checkbox checked="{it.done}" onclick="toggle(k)"/>
          <text size="13" color="{it.done and '#9CA3AF' or '#111827'}">{it.text}</text>
        </row>
      </each>
      <text size="12" color="#6B7280">{leftText()}</text>
    </column>
  </box>
</view>
```

```lua
tasks = { { text = "Écrire la bibliothèque", done = true } }
newTask = ""
function add()
  if newTask ~= "" then
    tasks[#tasks + 1] = { text = newTask, done = false }
    newTask = ""
  end
end
function toggle(k) tasks[k].done = not tasks[k].done end
```

```
iscc build examples/scripted_app.isc -o scripted_app
./scripted_app examples/scripted/todo.ui.xml
```

The root `<view>` takes `title`, `width`, `height`, `styles` and `script`
(files beside it, separated by spaces), `images` (the files of PNG an
expression may name), `menu`, `onclose` and `onkey`; without an argument
the application reads `app.ui.xml`. In an `<each>`, `as` and `index` name
an element of the sequence and its index (from 1). The hand of a
component, the focus of a field and the messages of the places are kept by
the application. A file the application does not understand is refused at
its file and line; an error of Lua while it runs is shown above the
interface. Besides the vocabulary of `uigen`:

- `onkey="..."` of the view: Lua given the keys (`key`: `Enter`,
  `Escape`, `Backspace`, `Tab`, `Left`, `Up`, `Right`, `Down`, `Delete`,
  `Home`, `End` or the character, a letter held with Ctrl in small;
  `ctrl`, `shift`, `alt`) before the field with the focus: a true value
  takes the key (`if ctrl and key == "p" then ... return true end`).
- `<field autofocus="true">`: the field takes the focus when it appears.
- `.name:hover` and `.name:active` in the styles: the class of a box with
  `onclick` or `ondrag` under the pointer, pressed (refused by `uigen`).
- `ondrag="..."` of a box: Lua run as the pointer moves with the button
  held after a press on it, `dx` and `dy` the distance since the press
  (`onclick="from = width" ondrag="width = from + dx"`).
- `<image src="icon.png" width="16" height="16">`: an image of PNG read
  with the view (`src="{expr}"`: one of `images`).
- `font="mono"` of a text (and of a class): the second font of the
  application, of fixed width (Consolas under Windows, else DejaVu Sans
  Mono beside it or in the folders of the system; `--mono=file`).
- `host.readFile(path, done)` and `host.listFolder(path, done)` in Lua: the
  file or the folder read after the input that asked it (by the loop of
  the window: the effects `ReadText`, `ListFolder`), `done` then called
  with its text, or the sequence of its names (those of folders ending
  with `/`), or with nil and the reason; asked while the scripts start,
  read at once.

## Its files

- `src/app.isc`: `run` and `runWith` (the texts of the menu of a field),
  `runWithFonts` (several fonts: a text of the face `k` drawn with the
  `k`-th, `TextStyle.face`), `loadMonoFont`,
  `loadFont` (the file of `--font=`; under Windows Segoe UI, the font of
  its own windows; else, or without it, `DejaVuSans.ttf` beside the program
  or in the current folder, then a font of the system), `fail` (a box of
  messages under Windows); the loops of Windows, Wayland and X11.
- `src/input.isc`: the inputs (`Click`, `Drag`, `Release`, `Hover`, `Text`,
  `Key` with its modifiers, `Paste`, `Focus`, `Viewport`, `Tick`,
  `TextRead`, `FolderListed`) and the effects (`Copy`, `AskPaste`,
  `Animate`, `ReadText`, `ListFolder`).
- `src/edit.isc`: the text of a field (`Editing`: its caret and selection)
  and how the keys, the pointer and the clipboard change it (`edited`).
- `src/widgets.isc`: the components, those of the plate: `button`
  (primary, secondary), `iconButton`, `textField` (its hint, its ring of
  focus), `checkbox`, `radio`, `toggle` and `toggleAt` (its knob sliding),
  `slider`, `progress`, `segments`, `avatar`, `badge`, `tooltip`;
  `withTip`; `uniformList`.
- `src/scripted.isc`: an interface read when the program starts (XML,
  styles, Lua); `src/lua_parse.isc`, `src/lua_code.isc`, `src/lua_vm.isc`,
  `src/lua_text.isc`: the machine of Lua (its parser, its code of
  registers, the machine and its library, its texts and patterns).
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
Segoe UI under Windows, else `DejaVuSans.ttf` beside them or in the current
folder (`tests/fonts/`).

- `minimal.isc`: the button above; prints its clicks at the end.
- `todo_app.isc` (`todo.isc`): a list of tasks: a field, tasks ticked and
  removed, a list that scrolls, the clipboard, the keyboard alone; prints
  its tasks at the end. `todo_xml_app.isc`: the same, its view made from
  `todo.ui.xml` and `todo.style` (`todo_view.isc`). `scripted_app.isc`:
  the generic application, any interface of XML, styles and Lua
  (`scripted/todo.ui.xml`: the same list of tasks).
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
keyboards, the view made from XML, the generic application).
`tests/lua.sh` runs the scripts of `tests/lua/` by the machine of Lua and
compares their output with that of the reference interpreter (or their
`.out`). `tests/uigen.sh` checks the
generator (its module up to date, faulty files refused at their lines).
`tests/display.sh` plays a hand under Wayland (Weston in
Docker, the image of `tools/display`, `xdotool`), under X11 (Xvfb in the
same image) and under sway at a fractional scale (the image of
`tools/display/sway`), and runs every example of Linux; the programs of
Windows are played in its machine.
