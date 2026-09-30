// Web-Plattform der Meloni-Engine: Exporte für den Browser-Player (web/core.js).
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include "meloni.h"

void mel_plat_log(const char *msg) { fprintf(stderr, "%s\n", msg); }
int64_t mel_plat_time_us(void)
{
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (int64_t)ts.tv_sec * 1000000 + ts.tv_nsec / 1000;
}
void *mel_plat_realloc(void *ptr, size_t size)
{
    if (size == 0) { free(ptr); return NULL; }
    return realloc(ptr, size);
}

static int16_t audio_buf[4096 * 2];

__attribute__((export_name("web_init"))) int web_init(const char *game, const char *save) { return mel_init(game, save); }
__attribute__((export_name("web_frame"))) int web_frame(uint32_t b) { return mel_frame(b); }
__attribute__((export_name("web_fb"))) const uint16_t *web_fb(void) { return mel_framebuffer(); }
__attribute__((export_name("web_audio"))) int16_t *web_audio(int frames) { mel_audio_mix(audio_buf, frames); return audio_buf; }
__attribute__((export_name("web_quit"))) void web_quit(void) { mel_quit(); mel_shutdown(); }
__attribute__((export_name("web_alloc"))) void *web_alloc(int n) { return malloc(n); }

// setjmp/longjmp support for LLVM 18 (Wasm exception handling). Same logic as Emscripten's
// emscripten_setjmp.c; longjmp itself comes from wasi-libc's libsetjmp (__wasm_longjmp).
typedef struct { uintptr_t id; uint32_t label; } TableEntry;
static uint32_t temp_ret0;
void setTempRet0(uint32_t v) { temp_ret0 = v; }
uint32_t getTempRet0(void) { return temp_ret0; }

TableEntry *saveSetjmp(uintptr_t *env, uint32_t label, TableEntry *table, uint32_t size)
{
    static uintptr_t setjmp_id = 0;
    setjmp_id++;
    *env = setjmp_id;
    for (uint32_t i = 0; i < size; i++)
    {
        if (table[i].id == 0)
        {
            table[i].id = setjmp_id;
            table[i].label = label;
            table[i + 1].id = 0;
            setTempRet0(size);
            return table;
        }
    }
    size *= 2;
    table = realloc(table, sizeof(TableEntry) * (size + 1));
    table = saveSetjmp(env, label, table, size);
    setTempRet0(size);
    return table;
}

uint32_t testSetjmp(uintptr_t id, TableEntry *table, uint32_t size)
{
    for (uint32_t i = 0; i < size; i++)
    {
        uintptr_t curr = table[i].id;
        if (curr == 0) break;
        if (curr == id) return table[i].label;
    }
    return 0;
}
