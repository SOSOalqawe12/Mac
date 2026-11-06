/* Linux test build: Apple silicon's 24 MHz mach_absolute_time, from CLOCK_MONOTONIC. */
#pragma once
#include <stdint.h>
#include <time.h>
typedef struct { uint32_t numer, denom; } mach_timebase_info_data_t;
static inline int mach_timebase_info(mach_timebase_info_data_t *t) { t->numer = 125; t->denom = 3; return 0; }
static inline uint64_t mach_absolute_time(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (uint64_t)ts.tv_sec * 24000000ull + (uint64_t)ts.tv_nsec * 3 / 125;
}
