// The floor in C of bench/text.isc: the same steps written as C writes them
// (a font read in place, loops, buffers of the stack), for the same line:
// the outlines of its glyphs (lines one part, curves `steps` parts), their
// coverage (the accumulation of font-rs: each part drawn row by row into a
// buffer of areas, each row added up from its left), the line laid out
// (glyphs of `cmap`, advances, kerning, a sprite of each glyph that draws
// something). Each line: the step, the nanoseconds of one glyph (of one
// line for the last), a checksum, as bench/text.isc prints them.
// usage: text <rounds>   (cc -O2 -ffp-contract=off text.c -o text -lm)
#include <math.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

// min and max as comparisons (fminf and fmaxf of the libm are calls: their
// treatment of NaN, which these values never are)
static inline float lessf(float a, float b) { return a < b ? a : b; }
static inline float moref(float a, float b) { return a > b ? a : b; }

static uint8_t *B;
static long glyf, loca, hmtx, cmap, kern;
static int longLoca, upem, metrics, kernPairs;

static int u16(long p) { return (B[p] << 8) | B[p + 1]; }
static int s16(long p) { return (int16_t)u16(p); }
static long u32(long p) { return ((long)B[p] << 24) | ((long)B[p + 1] << 16) | (B[p + 2] << 8) | B[p + 3]; }

static long table(const char *tag) {
    int n = u16(4);
    for (int i = 0; i < n; i++) {
        long r = 12 + 16 * i;
        if (!memcmp(B + r, tag, 4)) return u32(r + 8);
    }
    return 0;
}

typedef struct { float x, y; uint8_t on, last; } Pt;
typedef struct { float x0, y0, x1, y1; } Seg;

static int points(int g, int depth, Pt *out) {
    long a = longLoca ? u32(loca + 4 * g) : 2 * u16(loca + 2 * g);
    long z = longLoca ? u32(loca + 4 * g + 4) : 2 * u16(loca + 2 * g + 2);
    if (z == a || depth > 8) return 0;
    long at = glyf + a;
    int contours = s16(at);
    if (contours >= 0) {
        int n = contours ? u16(at + 10 + 2 * (contours - 1)) + 1 : 0;
        long p = at + 10 + 2 * contours;
        p += 2 + u16(p);
        uint8_t fl[n > 0 ? n : 1];
        for (int i = 0; i < n;) {
            uint8_t f = B[p++];
            int t = 1;
            if (f & 8) t += B[p++];
            while (t-- && i < n) fl[i++] = f;
        }
        int v = 0;
        for (int i = 0; i < n; i++) {
            if (fl[i] & 2) { int d = B[p++]; v += (fl[i] & 16) ? d : -d; }
            else if (!(fl[i] & 16)) { v += s16(p); p += 2; }
            out[i].x = (float)v;
        }
        v = 0;
        for (int i = 0; i < n; i++) {
            if (fl[i] & 4) { int d = B[p++]; v += (fl[i] & 32) ? d : -d; }
            else if (!(fl[i] & 32)) { v += s16(p); p += 2; }
            out[i].y = (float)v;
            out[i].on = fl[i] & 1;
            out[i].last = 0;
        }
        for (int k = 0; k < contours; k++) out[u16(at + 10 + 2 * k)].last = 1;
        return n;
    }
    int m = 0;
    long c = at + 10;
    for (;;) {
        int flags = u16(c), cg = u16(c + 2);
        int words = flags & 1;
        int dx = words ? s16(c + 4) : (int8_t)B[c + 4];
        int dy = words ? s16(c + 6) : (int8_t)B[c + 5];
        long after = c + (words ? 8 : 6);
        float xx = 1, xy = 0, yx = 0, yy = 1;
        if (flags & 8) { xx = yy = s16(after) / 16384.0f; after += 2; }
        else if (flags & 64) { xx = s16(after) / 16384.0f; yy = s16(after + 2) / 16384.0f; after += 4; }
        else if (flags & 128) { xx = s16(after) / 16384.0f; xy = s16(after + 2) / 16384.0f; yx = s16(after + 4) / 16384.0f; yy = s16(after + 6) / 16384.0f; after += 8; }
        int offsets = flags & 2;
        int k = points(cg, depth + 1, out + m);
        for (int i = m; i < m + k; i++) {
            float x = out[i].x, y = out[i].y;
            out[i].x = xx * x + yx * y + (offsets ? (float)dx : 0.0f);
            out[i].y = xy * x + yy * y + (offsets ? (float)dy : 0.0f);
        }
        m += k;
        if (!(flags & 32)) break;
        c = after;
    }
    return m;
}

static Pt pts[4096];

static int outline(int g, int steps, Seg *out) {
    int n = points(g, 0, pts), m = 0, first = 0;
    for (int i = 0; i < n; i++) {
        int last = i;
        while (!pts[last].last) last++;
        for (int j = first; j <= last; j++) {
            int nx = j == last ? first : j + 1, pv = j == first ? last : j - 1;
            Pt p = pts[j], q = pts[nx], r = pts[pv];
            if (p.on) {
                if (q.on) out[m++] = (Seg){p.x, p.y, q.x, q.y};
                continue;
            }
            float ax = r.on ? r.x : (r.x + p.x) * 0.5f, ay = r.on ? r.y : (r.y + p.y) * 0.5f;
            float bx = q.on ? q.x : (q.x + p.x) * 0.5f, by = q.on ? q.y : (q.y + p.y) * 0.5f;
            for (int s = 0; s < steps; s++) {
                float t0 = (float)s / steps, t1 = (float)(s + 1) / steps, u0 = 1 - t0, u1 = 1 - t1;
                out[m++] = (Seg){u0 * u0 * ax + 2 * u0 * t0 * p.x + t0 * t0 * bx, u0 * u0 * ay + 2 * u0 * t0 * p.y + t0 * t0 * by,
                                 u1 * u1 * ax + 2 * u1 * t1 * p.x + t1 * t1 * bx, u1 * u1 * ay + 2 * u1 * t1 * p.y + t1 * t1 * by};
            }
        }
        first = last + 1;
        i = last;
    }
    return m;
}

typedef struct { int x, y, w, h; float *mask; } Sprite;

static Seg segs[8192];
static float acc[1 << 16];

// font-rs: a part drawn into the buffer of areas `a` of rows of `width`
static void line(float *a, int width, int h, float x0, float y0, float x1, float y1) {
    if (y0 == y1) return;
    float dir = 1;
    if (y0 > y1) { dir = -1; float t = x0; x0 = x1; x1 = t; t = y0; y0 = y1; y1 = t; }
    float dxdy = (x1 - x0) / (y1 - y0);
    int ylo = (int)floorf(y0), yhi = (int)ceilf(y1);
    if (yhi > h) yhi = h;
    for (int y = ylo; y < yhi; y++) {
        float *row = a + (long)y * width;
        float ya = moref((float)y, y0), yb = lessf((float)(y + 1), y1);
        float xa = x0 + (ya - y0) * dxdy, xb = x0 + (yb - y0) * dxdy;
        float d = (yb - ya) * dir;
        float lo = lessf(xa, xb), hi = moref(xa, xb);
        float lof = floorf(lo), hic = ceilf(hi);
        int i0 = (int)lof, i1 = (int)hic;
        if (i1 <= i0 + 1) {
            float xmf = 0.5f * (xa + xb) - lof;
            row[i0] += d - d * xmf;
            row[i0 + 1] += d * xmf;
        } else {
            float s = 1.0f / (hi - lo), x0f = lo - lof;
            float a0 = 0.5f * s * (1 - x0f) * (1 - x0f);
            float x1f = hi - hic + 1, am = 0.5f * s * x1f * x1f;
            row[i0] += d * a0;
            if (i1 == i0 + 2) row[i0 + 1] += d * (1 - a0 - am);
            else {
                float a1 = s * (1.5f - x0f);
                row[i0 + 1] += d * (a1 - a0);
                for (int x = i0 + 2; x < i1 - 1; x++) row[x] += d * s;
                float a2 = a1 + (i1 - i0 - 3) * s;
                row[i1 - 1] += d * (1 - a2 - am);
            }
            row[i1] += d * am;
        }
    }
}

static Sprite rasterize(int g, float em, float fx, float *mask) {
    int steps = em > 32 ? 8 : 4;
    int n = outline(g, steps, segs);
    float k = em / upem;
    float l = 1e30f, t = 1e30f, r = -1e30f, b = -1e30f;
    int m = 0;
    for (int i = 0; i < n; i++) {
        Seg s = {fx + segs[i].x0 * k, -segs[i].y0 * k, fx + segs[i].x1 * k, -segs[i].y1 * k};
        if (s.y0 == s.y1) continue;
        segs[m++] = s;
        l = lessf(l, lessf(s.x0, s.x1)); t = lessf(t, lessf(s.y0, s.y1));
        r = moref(r, moref(s.x0, s.x1)); b = moref(b, moref(s.y0, s.y1));
    }
    if (m == 0) { mask[0] = 0; return (Sprite){0, 0, 1, 1, mask}; }
    l = floorf(l); t = floorf(t);
    int w = (int)ceilf(r) - (int)l, h = (int)ceilf(b) - (int)t;
    if (w < 1) w = 1;
    if (h < 1) h = 1;
    int width = w + 2;
    memset(acc, 0, sizeof(float) * width * h);
    for (int i = 0; i < m; i++) line(acc, width, h, segs[i].x0 - l, segs[i].y0 - t, segs[i].x1 - l, segs[i].y1 - t);
    for (int y = 0; y < h; y++) {
        float c = 0;
        for (int x = 0; x < w; x++) {
            c += acc[y * width + x];
            mask[y * w + x] = lessf(1.0f, fabsf(c));
        }
    }
    return (Sprite){(int)l, (int)t, w, h, mask};
}

static int glyphOf(long c) {
    int segsX2 = u16(cmap + 6), n = segsX2 / 2;
    long ends = cmap + 14, starts = ends + segsX2 + 2, deltas = starts + segsX2, ranges = deltas + segsX2;
    for (int s = 0; s < n; s++) {
        if (u16(ends + 2 * s) >= c) {
            if (u16(starts + 2 * s) > c) return 0;
            int delta = u16(deltas + 2 * s), range = u16(ranges + 2 * s);
            if (!range) return (c + delta) % 65536;
            int g = u16(ranges + 2 * s + range + 2 * (c - u16(starts + 2 * s)));
            return g ? (g + delta) % 65536 : 0;
        }
    }
    return 0;
}

static int advance(int g) { return u16(hmtx + 4 * (g < metrics ? g : metrics - 1)); }

static int kerning(int left, int right) {
    long key = (long)left * 65536 + right;
    int lo = 0, hi = kernPairs;
    while (lo < hi) {
        int mid = (lo + hi) / 2;
        long k = u32(kern + 6 * mid);
        if (k == key) return s16(kern + 6 * mid + 4);
        if (k < key) lo = mid + 1; else hi = mid;
    }
    return 0;
}

static long now(void) {
    struct timespec t;
    clock_gettime(CLOCK_MONOTONIC, &t);
    return t.tv_sec * 1000000000L + t.tv_nsec;
}

// the line: its glyphs as sprites, each its own mask (as the primitives of
// the Isocron line, one array each)
static int layout(const long *cps, int n, float em, float x, float y, Sprite *out) {
    int gs[256];
    for (int i = 0; i < n; i++) gs[i] = glyphOf(cps[i]);
    float k = em / upem, pen = x;
    int base = (int)floorf(y + 0.5f), m = 0;
    for (int i = 0; i < n; i++) {
        float step = (advance(gs[i]) + (i + 1 < n ? kerning(gs[i], gs[i + 1]) : 0)) * k;
        float q = floorf(pen * 4 + 0.5f) * 0.25f, whole = floorf(q);
        float tmp[4096];
        Sprite s = rasterize(gs[i], em, q - whole, tmp);
        if (s.w > 1 || s.h > 1 || tmp[0] > 0) {
            s.mask = malloc(sizeof(float) * s.w * s.h);
            memcpy(s.mask, tmp, sizeof(float) * s.w * s.h);
            s.x += (int)whole;
            s.y += base;
            out[m++] = s;
        }
        pen += step;
    }
    return m;
}

int main(int argc, char **argv) {
    long rounds = argc > 1 ? atol(argv[1]) : 200;
    FILE *f = fopen("tests/fonts/DejaVuSans.ttf", "rb");
    if (!f) { perror("font"); return 1; }
    fseek(f, 0, SEEK_END);
    long size = ftell(f);
    fseek(f, 0, SEEK_SET);
    B = malloc(size);
    if (fread(B, 1, size, f) != (size_t)size) return 1;
    fclose(f);
    long head = table("head"), hhea = table("hhea"), cm = table("cmap"), kt = table("kern");
    glyf = table("glyf"); loca = table("loca"); hmtx = table("hmtx");
    upem = u16(head + 18); longLoca = s16(head + 50) == 1; metrics = u16(hhea + 34);
    // the subtable (3, 1) of format 4
    for (int i = 0; i < u16(cm + 2); i++) {
        long sub = cm + u32(cm + 8 + 8 * i);
        if (u16(cm + 4 + 8 * i) == 3 && u16(cm + 6 + 8 * i) == 1 && u16(sub) == 4) cmap = sub;
    }
    kern = kt + 18; kernPairs = u16(kt + 10);
    const char *s = "Une ligne de texte, comme dans une interface dense";
    long cps[256];
    int n = 0;
    for (const char *p = s; *p; p++) cps[n++] = (unsigned char)*p;
    int gs[256];
    for (int i = 0; i < n; i++) gs[i] = glyphOf(cps[i]);
    long o = 0, t0 = now();
    for (long r = 0; r < rounds; r++) {
        o = 0;
        for (int i = 0; i < n; i++) o += outline(gs[i], 4, segs);
    }
    long t1 = now();
    printf("outline %g %ld\n", (double)(t1 - t0) / (rounds * n), o);
    static float mask[1 << 16];
    long a = 0;
    t0 = now();
    for (long r = 0; r < rounds; r++) {
        a = 0;
        for (int i = 0; i < n; i++) { Sprite sp = rasterize(gs[i], 14.0f, 0.25f, mask); a += sp.w * sp.h; }
    }
    t1 = now();
    printf("rasterize %g %ld\n", (double)(t1 - t0) / (rounds * n), a);
    Sprite out[256];
    int m = 0;
    t0 = now();
    for (long r = 0; r < rounds; r++) {
        m = layout(cps, n, 14.0f, 10.0f, 20.0f, out);
        for (int i = 0; i < m; i++) free(out[i].mask);
    }
    t1 = now();
    printf("line %g %d\n", (double)(t1 - t0) / rounds, m);
    return 0;
}
