# isocron-ui

A library of graphical interfaces written in Isocron, after GPUI (the library
of the editor Zed). The design and its plan: `docs/proposals/gui.md` of the
Isocron repository (D631).

Written so far:

- `src/paint.isc`: the primitives of a scene drawn on the processor:
  rectangles with rounded corners and borders, their shadows (sharp or
  blurred), composed in their order; the formulas of the shaders of GPUI,
  in `f32`, the same bits on every target and for any number of threads.
- `src/png.isc`: PNG files (CRC-32, Adler-32, zlib with stored blocks).
- `src/wayland.isc`: a client of Wayland over the module `unix` of Isocron
  (no C library): the wire, the globals, a toplevel window, its image in
  memory shared with the compositor, its frames.

Tests: `tests/run.sh` (with `ISCC` the compiler) draws the scenes of
`tests/scenes.isc` interpreted and compiled, and compares them byte for byte
with `tests/reference/`.

Examples: `iscc build examples/cards.isc -o cards && ./cards cards.png` (a
scene in a PNG file); `examples/window.isc`, a window of Wayland showing a
scene for a number of frames. Without a screen: `docker build -t
isocron-ui-display tools/display`, then `tools/display/run.sh shot.png
./window 120` runs it against a Weston without a screen and writes a
screenshot.
