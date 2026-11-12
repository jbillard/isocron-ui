#!/usr/bin/env python3
"""The icons of the editor of examples/scripted/editor.ui.xml, drawn here
(lines and circles, 4 x 4 samples a pixel) and written as PNG files: each
in grey (`NAME.png`) and in white (`NAME_on.png`), 24 pixels square.

    python3 tools/icons.py examples/scripted/icons
"""
import math, os, struct, sys, zlib

SIZE = 24
SS = 4


def png(path, w, h, px):
    raw = b''.join(b'\x00' + b''.join(bytes(px[y * w + x]) for x in range(w)) for y in range(h))
    def chunk(t, d):
        return struct.pack('>I', len(d)) + t + d + struct.pack('>I', zlib.crc32(t + d) & 0xffffffff)
    with open(path, 'wb') as f:
        f.write(b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 6, 0, 0, 0)) + chunk(b'IDAT', zlib.compress(raw, 9)) + chunk(b'IEND', b''))


def seg_dist(px, py, ax, ay, bx, by):
    dx, dy = bx - ax, by - ay
    l = dx * dx + dy * dy
    t = 0.0 if l == 0 else max(0.0, min(1.0, ((px - ax) * dx + (py - ay) * dy) / l))
    return math.hypot(px - ax - t * dx, py - ay - t * dy)


def draw(shapes):
    """the coverage of each pixel by the shapes: ('line', ax, ay, bx, by),
    ('ring', cx, cy, r), ('dot', cx, cy, r), all of the width 1.5"""
    cov = []
    half = 0.75
    for y in range(SIZE):
        for x in range(SIZE):
            n = 0
            for sy in range(SS):
                for sx in range(SS):
                    px = x + (sx + 0.5) / SS
                    py = y + (sy + 0.5) / SS
                    hit = False
                    for s in shapes:
                        if s[0] == 'line' and seg_dist(px, py, *s[1:]) <= half:
                            hit = True
                        elif s[0] == 'ring' and abs(math.hypot(px - s[1], py - s[2]) - s[3]) <= half:
                            hit = True
                        elif s[0] == 'dot' and math.hypot(px - s[1], py - s[2]) <= s[3]:
                            hit = True
                        if hit:
                            break
                    n += hit
            cov.append(n / (SS * SS))
    return cov


def box(x0, y0, x1, y1):
    return [('line', x0, y0, x1, y0), ('line', x1, y0, x1, y1), ('line', x1, y1, x0, y1), ('line', x0, y1, x0, y0)]


ICONS = {
    # two sheets, the front one with its corner folded
    'files': [('line', 8, 3.5, 15, 3.5), ('line', 15, 3.5, 19, 7.5), ('line', 19, 7.5, 19, 17.5), ('line', 19, 17.5, 8, 17.5), ('line', 8, 17.5, 8, 3.5),
              ('line', 15, 3.5, 15, 7.5), ('line', 15, 7.5, 19, 7.5), ('line', 5, 7, 5, 20.5), ('line', 5, 20.5, 15, 20.5)],
    # a lens and its handle
    'search': [('ring', 10.5, 10.5, 6), ('line', 15, 15, 20.5, 20.5)],
    # three commits of two branches
    'branch': [('ring', 7, 5.5, 2.2), ('ring', 7, 18.5, 2.2), ('ring', 17, 7.5, 2.2), ('line', 7, 7.7, 7, 16.3), ('line', 17, 9.7, 17, 11), ('line', 17, 11, 9, 15.5)],
    # four squares, one apart
    'blocks': box(4, 10, 10, 16) + box(10, 10, 16, 16) + box(4, 16, 10, 22) + box(13, 3, 19, 9),
    # nothing: the place of a chevron beside a file
    'blank': [],
    # the chevrons of a folder closed and open (shown at 16 pixels)
    'closed': [('line', 9, 6, 15, 12), ('line', 15, 12, 9, 18)],
    'open': [('line', 6, 9, 12, 15), ('line', 12, 15, 18, 9)],
    # a wheel: its hub and eight teeth
    'gear': [('ring', 12, 12, 3)] + [('line', 12 + 5.5 * math.cos(a), 12 + 5.5 * math.sin(a), 12 + 8.5 * math.cos(a), 12 + 8.5 * math.sin(a)) for a in [k * math.pi / 4 for k in range(8)]] + [('ring', 12, 12, 6)],
}

out = sys.argv[1]
os.makedirs(out, exist_ok=True)
for name, shapes in ICONS.items():
    cov = draw(shapes)
    for suffix, rgb in [('', (133, 133, 133)), ('_on', (255, 255, 255))]:
        px = [(rgb[0], rgb[1], rgb[2], int(round(c * 255))) for c in cov]
        png(os.path.join(out, f'{name}{suffix}.png'), SIZE, SIZE, px)
print(' '.join(sorted(os.listdir(out))))
