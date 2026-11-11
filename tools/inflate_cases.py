#!/usr/bin/env python3
"""The streams of zlib of tests/inflate, made by the zlib of Python, and the
list of their cases (tests/inflate_cases.txt: each name and the length of
its bytes); prints what tests/inflate_check.isc prints of the good ones (the
length and the FNV-1a of 64 bits of their bytes).

usage: tools/inflate_cases.py   (from the folder of the library)
"""
import random
import zlib

random.seed(7)


def fnv(b):
    h = 0xcbf29ce484222325
    for x in b:
        h = ((h ^ x) * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF
    return h


words = ["la", "bibliothèque", "des", "interfaces", "Isocron", "fenêtre", "texte", "glyphe", "ombre", "rectangle", "and", "the", "image", "pixel"]
text = " ".join(random.choice(words) for _ in range(30000)).encode()
rnd = bytes(random.getrandbits(8) for _ in range(40000))
# a gradient of rows filtered as PNG would (deltas): small values, long runs
grad = bytes((x * 3 + y) & 0xFF for y in range(300) for x in range(400))


def full_flush(data, parts):
    c = zlib.compressobj(6)
    out = b""
    step = len(data) // parts
    for i in range(parts):
        out += c.compress(data[i * step:(i + 1) * step if i < parts - 1 else len(data)])
        out += c.flush(zlib.Z_FULL_FLUSH)
    return out + c.flush()


streams = [
    ("empty", b"", zlib.compress(b"", 6)),
    ("hello", b"hello, hello, hello!", zlib.compress(b"hello, hello, hello!", 1)),
    ("stored", (rnd + rnd)[:70000], None),
    ("text9", text, zlib.compress(text, 9)),
    ("text1", text, zlib.compress(text, 1)),
    ("random", rnd, zlib.compress(rnd, 6)),
    ("zeros", bytes(300000), zlib.compress(bytes(300000), 9)),
    ("gradient", grad, zlib.compress(grad, 6)),
    ("flushed", text[:50000], full_flush(text[:50000], 5)),
]
out = []
for name, data, z in streams:
    if z is None:
        z = zlib.compress(data, 0)
    open("tests/inflate/" + name + ".z", "wb").write(z)
    out.append("%s %d %d" % (name, len(data), fnv(data)))
# damaged streams: a checksum, the end cut, a header, a block of type 3
z = bytearray(zlib.compress(text[:5000], 6))
z[-1] ^= 1
open("tests/inflate/badsum.z", "wb").write(z)
z = zlib.compress(text[:5000], 6)
open("tests/inflate/truncated.z", "wb").write(z[:len(z) // 2])
open("tests/inflate/badheader.z", "wb").write(b"\x78\x9d" + z[2:])
z = bytearray(zlib.compress(text[:5000], 6))
z[2] = (z[2] & ~6) | 6
open("tests/inflate/badtype.z", "wb").write(z)
open("tests/inflate_cases.txt", "w").write("".join("%s %d\n" % (n, len(d)) for n, d, _ in streams) + "badsum 5000\ntruncated 5000\nbadheader 5000\nbadtype 5000\n")
print("\n".join(out))
