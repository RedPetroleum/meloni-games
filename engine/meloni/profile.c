// Lua profiler for the desktop runner (meloni-run --profile): counts the VM instructions per frame in
// _update and _draw, samples in which functions they are spent and counts the calls of C functions.
// On the device Lua runs many times slower than on a PC, so instruction counts say more about the
// cost there than the PC's clock. The device never switches it on.
#define MEL_INTERNAL
#include "meloni.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define SAMPLE 100   // instructions between two samples
#define SLOTS  4096  // functions seen, hash table (power of two)
#define HEAVY  5     // heaviest frames listed in the report

typedef struct
{
    const void *key; // Lua function: source of its chunk, C function: the function itself
    int line;        // Lua: line where the function is defined, C: -1
    char name[40], where[72];
    uint32_t self, incl, calls, stamp;
} entry_t;

static int from_frame;  // 0 = off
static bool active;
static int phase;       // see mel_profile_phase
static uint32_t frame, frames, sample_no;
static uint64_t instr[3], ccalls[3];
static uint64_t frame_instr;
static struct { uint32_t frame; uint64_t instr; } heavy[HEAVY];
static entry_t *slots;
static int used;

void mel_set_profile(int from)
{
    from_frame = from > 0 ? from : 0;
}

static entry_t *lookup(const void *key, int line)
{
    uint32_t h = (uint32_t)(uintptr_t)key * 2654435761u ^ (uint32_t)line * 40503u;
    for (int i = 0; i < SLOTS; i++)
    {
        entry_t *e = &slots[(h + i) & (SLOTS - 1)];
        if (e->key == key && e->line == line)
            return e;
        if (!e->key)
        {
            if (used >= SLOTS * 3 / 4)
                return NULL;
            used++;
            e->key = key, e->line = line;
            return e;
        }
    }
    return NULL;
}

static void hook(lua_State *L, lua_Debug *ar)
{
    if (!phase || frame < (uint32_t)from_frame)
        return;
    if (ar->event == LUA_HOOKCOUNT)
    {
        instr[phase] += SAMPLE;
        frame_instr += SAMPLE;
        sample_no++;
        lua_Debug a;
        for (int level = 0; lua_getstack(L, level, &a); level++)
        {
            lua_getinfo(L, "S", &a);
            if (a.what[0] == 'C')
                continue;
            entry_t *e = lookup(a.source, a.linedefined);
            if (!e)
                continue;
            if (!e->where[0])
            {
                lua_getinfo(L, "n", &a);
                snprintf(e->name, sizeof(e->name), "%s", a.name ? a.name : a.what[0] == 'm' ? "(main chunk)" : "?");
                snprintf(e->where, sizeof(e->where), "%s:%d", a.short_src, a.linedefined);
            }
            if (level == 0)
                e->self++;
            if (e->stamp != sample_no) // count recursive functions once per sample
                e->stamp = sample_no, e->incl++;
        }
    }
    else if (ar->event == LUA_HOOKCALL || ar->event == LUA_HOOKTAILCALL)
    {
        lua_getinfo(L, "Sf", ar);
        if (ar->what[0] == 'C')
        {
            ccalls[phase]++;
            entry_t *e = lookup((const void *)(uintptr_t)lua_tocfunction(L, -1), -1);
            if (e)
            {
                if (!e->name[0])
                {
                    lua_getinfo(L, "n", ar);
                    snprintf(e->name, sizeof(e->name), "%s", ar->name ? ar->name : "?");
                }
                e->calls++;
            }
        }
        lua_pop(L, 1);
    }
}

void mel_profile_start(lua_State *L)
{
    active = false;
    if (!from_frame)
        return;
    if (!slots && !(slots = malloc(SLOTS * sizeof(entry_t))))
        return;
    memset(slots, 0, SLOTS * sizeof(entry_t));
    used = 0;
    phase = 0;
    frame = frames = sample_no = 0;
    frame_instr = 0;
    memset(instr, 0, sizeof(instr));
    memset(ccalls, 0, sizeof(ccalls));
    memset(heavy, 0, sizeof(heavy));
    lua_sethook(L, hook, LUA_MASKCOUNT | LUA_MASKCALL, SAMPLE);
    active = true;
}

// Keeps the HEAVY frames with the most instructions
static void end_frame(void)
{
    if (!frames)
        return;
    for (int i = 0; i < HEAVY; i++)
        if (frame_instr > heavy[i].instr)
        {
            memmove(&heavy[i + 1], &heavy[i], (HEAVY - 1 - i) * sizeof(heavy[0]));
            heavy[i].frame = frame, heavy[i].instr = frame_instr;
            break;
        }
    frame_instr = 0;
}

void mel_profile_phase(int p)
{
    if (!active)
        return;
    if (p == 1)
    {
        if (frame >= (uint32_t)from_frame)
            end_frame();
        frame++;
        if (frame >= (uint32_t)from_frame)
            frames++;
    }
    phase = p;
}

static int by_incl(const void *a, const void *b)
{
    const entry_t *x = a, *y = b;
    return (y->line >= 0 ? (int)y->incl : -1) - (x->line >= 0 ? (int)x->incl : -1);
}

static int by_calls(const void *a, const void *b)
{
    const entry_t *x = a, *y = b;
    return (y->line < 0 ? (int)y->calls : -1) - (x->line < 0 ? (int)x->calls : -1);
}

void mel_profile_report(void)
{
    if (!active || !frames)
        return;
    end_frame();
    char line[200];
    double n = frames;
    double total = (double)(instr[1] + instr[2]) / SAMPLE;
    snprintf(line, sizeof(line), "profile: frames %d-%u, Lua instructions per frame: _update %.0f, _draw %.0f",
             from_frame, frame, instr[1] / n, instr[2] / n);
    mel_plat_log(line);
    snprintf(line, sizeof(line), "profile: C function calls per frame: _update %.0f, _draw %.0f", ccalls[1] / n, ccalls[2] / n);
    mel_plat_log(line);
    for (int i = 0; i < HEAVY && heavy[i].instr; i++)
    {
        snprintf(line, sizeof(line), "profile: heavy frame %u: %llu instructions", heavy[i].frame,
                 (unsigned long long)heavy[i].instr);
        mel_plat_log(line);
    }

    mel_plat_log("profile: C functions, calls per frame");
    qsort(slots, SLOTS, sizeof(entry_t), by_calls);
    for (int i = 0; i < 15 && slots[i].key && slots[i].line < 0; i++)
    {
        snprintf(line, sizeof(line), "profile: %9.1f  %s", slots[i].calls / n, slots[i].name);
        mel_plat_log(line);
    }

    mel_plat_log("profile: Lua functions, share of all instructions with callees / own");
    qsort(slots, SLOTS, sizeof(entry_t), by_incl);
    for (int i = 0; i < 40 && slots[i].key && slots[i].line >= 0 && total > 0; i++)
    {
        snprintf(line, sizeof(line), "profile: %5.1f%% %5.1f%%  %-22s %s", slots[i].incl * 100 / total,
                 slots[i].self * 100 / total, slots[i].name, slots[i].where);
        mel_plat_log(line);
    }
    active = false; // the table is sorted now, lookups would no longer find anything
}
