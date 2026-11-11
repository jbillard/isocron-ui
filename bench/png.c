// The floor in C of bench/png.isc: the same decoding written as C writes it
// (the chunks walked in place, the data of the IDATs gathered, inflated by
// zlib's `uncompress`, the filters undone in place, the pixels converted to
// 0xAARRGGBB), for the files of bench/pngimages (8 bits a sample: colour,
// colour and alpha, palette; not interlaced). Prints as bench/png.isc.
// usage: png FILE ROUNDS
// (cc -O2 png.c -o png /usr/lib/x86_64-linux-gnu/libz.so.1: zlib's header
// is not installed, its one function declared here)
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

int uncompress(unsigned char *dest, unsigned long *destLen, const unsigned char *source, unsigned long sourceLen);

static uint32_t be(const uint8_t *p) { return ((uint32_t)p[0] << 24) | ((uint32_t)p[1] << 16) | ((uint32_t)p[2] << 8) | p[3]; }

static uint64_t now(void) {
    struct timespec t;
    clock_gettime(CLOCK_MONOTONIC, &t);
    return (uint64_t)t.tv_sec * 1000000000u + t.tv_nsec;
}

static int w, h, kind;

static uint32_t *decode(const uint8_t *f, long n) {
    static const int channels[7] = {1, 0, 3, 1, 2, 0, 4};
    uint32_t palette[256];
    for (int i = 0; i < 256; i++) palette[i] = 0xFF000000u;
    uint8_t *data = malloc(n);
    long used = 0, at = 8;
    while (at + 12 <= n) {
        long len = be(f + at);
        uint32_t t = be(f + at + 4);
        const uint8_t *b = f + at + 8;
        if (t == 0x49484452) { w = be(b); h = be(b + 4); kind = b[9]; }
        else if (t == 0x504C5445) { for (long i = 0; i < len / 3; i++) palette[i] = 0xFF000000u | (b[3 * i] << 16) | (b[3 * i + 1] << 8) | b[3 * i + 2]; }
        else if (t == 0x74524E53 && kind == 3) { for (long i = 0; i < len; i++) palette[i] = (palette[i] & 0xFFFFFF) | ((uint32_t)b[i] << 24); }
        else if (t == 0x49444154) { memcpy(data + used, b, len); used += len; }
        else if (t == 0x49454E44) break;
        at += 12 + len;
    }
    int c = channels[kind], s = w * c, bpp = c;
    unsigned long size = (unsigned long)h * (s + 1);
    uint8_t *raw = malloc(size);
    if (uncompress(raw, &size, data, used) != 0) { fprintf(stderr, "inflate failed\n"); exit(1); }
    free(data);
    // the filters undone in place, each row then moved before its filter byte
    uint8_t *rows = malloc((size_t)h * s);
    for (int y = 0; y < h; y++) {
        uint8_t ft = raw[y * (s + 1)];
        const uint8_t *in = raw + y * (s + 1) + 1;
        uint8_t *o = rows + (size_t)y * s, *up = y ? o - s : NULL;
        switch (ft) {
        case 0: memcpy(o, in, s); break;
        case 1: for (int x = 0; x < s; x++) o[x] = in[x] + (x >= bpp ? o[x - bpp] : 0); break;
        case 2: for (int x = 0; x < s; x++) o[x] = in[x] + (up ? up[x] : 0); break;
        case 3: for (int x = 0; x < s; x++) o[x] = in[x] + (((x >= bpp ? o[x - bpp] : 0) + (up ? up[x] : 0)) >> 1); break;
        case 4: for (int x = 0; x < s; x++) {
                int a = x >= bpp ? o[x - bpp] : 0, b = up ? up[x] : 0, cc = x >= bpp && up ? up[x - bpp] : 0;
                int p = a + b - cc, pa = abs(p - a), pb = abs(p - b), pc = abs(p - cc);
                o[x] = in[x] + (pa <= pb && pa <= pc ? a : (pb <= pc ? b : cc));
            } break;
        }
    }
    free(raw);
    uint32_t *px = malloc((size_t)w * h * 4);
    for (long i = 0; i < (long)w * h; i++) {
        const uint8_t *p = rows + i * c;
        px[i] = kind == 3 ? palette[p[0]] : kind == 2 ? 0xFF000000u | (p[0] << 16) | (p[1] << 8) | p[2] : ((uint32_t)p[3] << 24) | (p[0] << 16) | (p[1] << 8) | p[2];
    }
    free(rows);
    return px;
}

int main(int argc, char **argv) {
    FILE *fp = fopen(argv[1], "rb");
    fseek(fp, 0, SEEK_END);
    long n = ftell(fp);
    fseek(fp, 0, SEEK_SET);
    uint8_t *f = malloc(n);
    if (fread(f, 1, n, fp) != (size_t)n) return 1;
    fclose(fp);
    int rounds = atoi(argv[2]);
    uint64_t best = ~0ull, sum = 0;
    for (int r = 0; r < rounds; r++) {
        uint64_t t0 = now();
        uint32_t *px = decode(f, n);
        uint64_t t1 = now();
        if (t1 - t0 < best) best = t1 - t0;
        sum += px[(long)w * h / 2] + (uint64_t)w;
        free(px);
    }
    printf("%s: %dx%d, %g ms, %g Mpixels/s, checksum %llu\n", argv[1], w, h, best / 1e6, (double)w * h / best * 1e3, (unsigned long long)sum);
    return 0;
}
