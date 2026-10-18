// LD_PRELOAD: bytes asked of malloc, calloc and realloc, printed at exit.
//   cc -O2 -shared -fPIC tools/count_malloc.c -o count_malloc.so -ldl
//   LD_PRELOAD=./count_malloc.so ./respond_c
// realloc counts its whole new size, so a growing buffer counts more than
// it takes; the call count is exact.
#define _GNU_SOURCE
#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
static unsigned long long total, calls;
static void *(*real_malloc)(size_t);
static void *(*real_calloc)(size_t, size_t);
static void *(*real_realloc)(void *, size_t);
static char boot[4096]; static size_t boot_used;
static void init(void) {
    real_malloc = dlsym(RTLD_NEXT, "malloc");
    real_calloc = dlsym(RTLD_NEXT, "calloc");
    real_realloc = dlsym(RTLD_NEXT, "realloc");
}
void *malloc(size_t n) { if (!real_malloc) init(); total += n; calls++; return real_malloc(n); }
void *calloc(size_t a, size_t b) {
    if (!real_calloc) { void *p = boot + boot_used; boot_used += (a * b + 15) & ~15; return p; }
    total += a * b; calls++; return real_calloc(a, b);
}
void *realloc(void *p, size_t n) { if (!real_realloc) init(); total += n; calls++; return real_realloc(p, n); }
void free(void *p) {
    static void (*real_free)(void *);
    if ((char *)p >= boot && (char *)p < boot + sizeof boot) return;
    if (!real_free) real_free = dlsym(RTLD_NEXT, "free");
    real_free(p);
}
__attribute__((destructor)) static void report(void) {
    char buf[128];
    int k = snprintf(buf, sizeof buf, "malloc bytes %llu calls %llu\n", total, calls);
    if (write(2, buf, (size_t)k) < 0) {}
}
