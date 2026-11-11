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

Tests: `tests/run.sh` (with `ISCC` the compiler) draws the scenes of
`tests/scenes.isc` interpreted and compiled, and compares them byte for byte
with `tests/reference/`.

Example: `iscc build examples/cards.isc -o cards && ./cards cards.png`.
