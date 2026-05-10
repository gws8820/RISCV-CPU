/*
 * CoreMark portme implementation for RISC-V bare-metal (RV32IM, 100MHz)
 */
#include "coremark.h"
#include "core_portme.h"
#include <stdarg.h>

#if VALIDATION_RUN
volatile ee_s32 seed1_volatile = 0x3415;
volatile ee_s32 seed2_volatile = 0x3415;
volatile ee_s32 seed3_volatile = 0x66;
#endif

#if PERFORMANCE_RUN
volatile ee_s32 seed1_volatile = 0x0;
volatile ee_s32 seed2_volatile = 0x0;
volatile ee_s32 seed3_volatile = 0x66;
#endif

#if PROFILE_RUN
volatile ee_s32 seed1_volatile = 0x8;
volatile ee_s32 seed2_volatile = 0x8;
volatile ee_s32 seed3_volatile = 0x8;
#endif

volatile ee_s32 seed4_volatile = ITERATIONS;
volatile ee_s32 seed5_volatile = 0;

static CORETIMETYPE start_time_val, stop_time_val;

static CORETIMETYPE read_cycle64(void)
{
    uint32_t hi, lo, hi2;
    __asm__ volatile ("rdcycleh %0" : "=r"(hi));
    __asm__ volatile ("rdcycle  %0" : "=r"(lo));
    __asm__ volatile ("rdcycleh %0" : "=r"(hi2));
    if (hi != hi2) {
        __asm__ volatile ("rdcycle %0" : "=r"(lo));
        hi = hi2;
    }
    return ((CORETIMETYPE)hi << 32) | lo;
}

void start_time(void) { start_time_val = read_cycle64(); }
void stop_time(void)  { stop_time_val  = read_cycle64(); }

CORE_TICKS get_time(void)
{
    return stop_time_val - start_time_val;
}

secs_ret time_in_secs(CORE_TICKS ticks)
{
    return (secs_ret)ticks / (secs_ret)100000000ULL;
}

ee_u32 default_num_contexts = 1;

void portable_init(core_portable *p, int *argc, char *argv[])
{
    (void)argc;
    (void)argv;
    p->portable_id = 1;
}

void portable_fini(core_portable *p)
{
    p->portable_id = 0;
}

/* ee_printf -> vprintf (provided by syscalls.c) */
extern int vprintf(const char *fmt, va_list ap);

int ee_printf(const char *fmt, ...)
{
    va_list ap;
    va_start(ap, fmt);
    int r = vprintf(fmt, ap);
    va_end(ap);
    return r;
}
