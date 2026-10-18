// respond, the DTO shape in C: a port of cpp/respond.cpp VARIANT 0. Each
// name and sku is its own malloc, the item list another, the rendering a
// growing malloc buffer; all of it freed at the end of each request.
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifndef BENCH_N
#define BENCH_N 1600000
#endif

static inline uint64_t xs_next(uint64_t x) {
    x ^= x << 13;
    x ^= x >> 7;
    x ^= x << 17;
    return x;
}

static inline uint64_t xs_mod(uint64_t x, uint64_t k) { return x % k; }

typedef struct { char *p; size_t len, cap; } Str;

static void str_push(Str *s, char c) {
    if (s->len == s->cap) {
        s->cap = s->cap ? s->cap * 2 : 16;
        s->p = realloc(s->p, s->cap);
    }
    s->p[s->len++] = c;
}

static void str_append(Str *s, const char *t, size_t n) {
    if (s->len + n > s->cap) {
        while (s->len + n > s->cap) s->cap = s->cap ? s->cap * 2 : 16;
        s->p = realloc(s->p, s->cap);
    }
    memcpy(s->p + s->len, t, n);
    s->len += n;
}

static void str_lit(Str *s, const char *t) { str_append(s, t, strlen(t)); }

static void str_int(Str *s, long long v) {
    char buf[24];
    int n = snprintf(buf, sizeof buf, "%lld", v);
    str_append(s, buf, (size_t)n);
}

typedef struct { Str sku; int qty, price; } Item;
typedef struct { int64_t id; Str user; Item *items; long long n; } Resp;

// A user name of 3..10 letters; one in eight carries a quote or a backslash.
static Str name_of(uint64_t seed) {
    Str s = {0};
    uint64_t r = xs_next(seed);
    long long n = 3 + (long long)xs_mod(r, 8);
    int odd = xs_mod(r >> 8, 8) == 0;
    for (long long i = 0; i < n; i++) {
        r = xs_next(r);
        if (odd && i == 1) str_push(&s, xs_mod(r, 2) == 0 ? '"' : '\\');
        else str_push(&s, (char)('a' + xs_mod(r, 26)));
    }
    return s;
}

// A stock keeping unit: two letters and four digits.
static Str sku_of(uint64_t seed) {
    Str s = {0};
    uint64_t r = xs_next(seed);
    str_push(&s, (char)('A' + xs_mod(r, 26)));
    str_push(&s, (char)('A' + xs_mod(r >> 8, 26)));
    for (int i = 0; i < 4; i++) { r = xs_next(r); str_push(&s, (char)('0' + xs_mod(r, 10))); }
    return s;
}

static Item *make_items(uint64_t seed, long long n) {
    Item *t = malloc(sizeof(Item) * (size_t)n);
    uint64_t r = seed;
    for (long long i = 0; i < n; i++) {
        r = xs_next(r);
        t[i].sku = sku_of(r);
        t[i].qty = (int)(1 + xs_mod(r >> 8, 5));
        t[i].price = (int)(100 + xs_mod(r >> 16, 99900));
    }
    return t;
}

static void emit_str(Str *out, const Str *s) {
    str_push(out, '"');
    for (size_t i = 0; i < s->len; i++) {
        char c = s->p[i];
        if (c == '"' || c == '\\') str_push(out, '\\');
        str_push(out, c);
    }
    str_push(out, '"');
}

static Str render(const Resp *resp) {
    Str out = {0};
    str_lit(&out, "{\"id\":");
    str_int(&out, resp->id);
    str_lit(&out, ",\"user\":");
    emit_str(&out, &resp->user);
    str_lit(&out, ",\"items\":[");
    long long total = 0;
    for (long long i = 0; i < resp->n; i++) {
        const Item *it = &resp->items[i];
        if (i > 0) str_push(&out, ',');
        str_lit(&out, "{\"sku\":");
        emit_str(&out, &it->sku);
        str_lit(&out, ",\"qty\":");
        str_int(&out, it->qty);
        str_lit(&out, ",\"price\":");
        str_int(&out, it->price);
        str_push(&out, '}');
        total += (long long)it->qty * it->price;
    }
    str_lit(&out, "],\"total\":");
    str_int(&out, total);
    str_push(&out, '}');
    return out;
}

static uint64_t fnv(const Str *s) {
    uint64_t h = 14695981039346656037ull;
    for (size_t i = 0; i < s->len; i++) h = (h ^ (unsigned char)s->p[i]) * 1099511628211ull;
    return h;
}

// One request: the response object and its rendering are both temporaries.
static uint64_t handle(uint64_t seed, long long *len) {
    uint64_t r = xs_next(seed);
    long long n = 1 + (long long)xs_mod(r, 8);
    Resp resp = { (int64_t)xs_mod(r >> 4, 1000000), name_of(r >> 8), make_items(r >> 16, n), n };
    Str out = render(&resp);
    *len = (long long)out.len;
    uint64_t h = fnv(&out);
    free(out.p);
    for (long long i = 0; i < n; i++) free(resp.items[i].sku.p);
    free(resp.items);
    free(resp.user.p);
    return h;
}

int main(void) {
    uint64_t seed = 12345, h = 0;
    long long bytes = 0;
    for (long long i = 0; i < BENCH_N; i++) {
        seed = xs_next(seed);
        long long l = 0;
        uint64_t hh = handle(seed, &l);
        h = h ^ (hh * 31 + (uint64_t)i);
        bytes += l;
    }
    printf("%lld\n%lld\n%llu\n", (long long)BENCH_N, bytes, (unsigned long long)h);
    return 0;
}
