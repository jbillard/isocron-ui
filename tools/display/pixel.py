#!/usr/bin/env python3
"""The colour of the pixel (X, Y) of a PNG (8 bits, RGB or RGBA), as `r g b`.
usage: pixel.py FILE.png X Y"""
import struct
import sys
import zlib


def main():
    path, x, y = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
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
    at = 0
    for row in range(y + 1):
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
        prev = line
    print(prev[x * bpp], prev[x * bpp + 1], prev[x * bpp + 2])


main()
