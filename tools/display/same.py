#!/usr/bin/env python3
"""The pixels of two PNG files (8 bits, RGB or RGBA) compared, their colour
alone: prints how many differ (0: the same image) and their box.
usage: same.py A.png B.png"""
import struct
import sys
import zlib


def load(path):
    d = open(path, "rb").read()
    i, idat = 8, b""
    while i < len(d):
        n = struct.unpack(">I", d[i:i + 4])[0]
        kind, body = d[i + 4:i + 8], d[i + 8:i + 8 + n]
        if kind == b"IHDR":
            w, h, depth, colour = struct.unpack(">IIBB", body[:10])
        elif kind == b"IDAT":
            idat += body
        i += 12 + n
    raw = zlib.decompress(idat)
    bpp = 4 if colour == 6 else 3
    stride = w * bpp
    prev = bytearray(stride)
    rows = []
    at = 0
    for _ in range(h):
        f = raw[at]
        line = bytearray(raw[at + 1:at + 1 + stride])
        at += 1 + stride
        for k in range(stride):
            a = line[k - bpp] if k >= bpp else 0
            b = prev[k]
            c = prev[k - bpp] if k >= bpp else 0
            if f == 1:
                line[k] = (line[k] + a) & 255
            elif f == 2:
                line[k] = (line[k] + b) & 255
            elif f == 3:
                line[k] = (line[k] + (a + b) // 2) & 255
            elif f == 4:
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                line[k] = (line[k] + (a if pa <= pb and pa <= pc else (b if pb <= pc else c))) & 255
        rows.append([tuple(line[x * bpp:x * bpp + 3]) for x in range(w)])
        prev = line
    return w, h, rows


wa, ha, a = load(sys.argv[1])
wb, hb, b = load(sys.argv[2])
if (wa, ha) != (wb, hb):
    print("sizes %dx%d and %dx%d" % (wa, ha, wb, hb))
    sys.exit(1)
diff = [(x, y) for y in range(ha) for x in range(wa) if a[y][x] != b[y][x]]
print(len(diff), (min(p[0] for p in diff), min(p[1] for p in diff), max(p[0] for p in diff), max(p[1] for p in diff)) if diff else "")
