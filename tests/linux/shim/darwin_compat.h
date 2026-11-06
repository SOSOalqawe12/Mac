/* Forced into every file of the Linux (aarch64, under qemu-user) test build. */
#pragma once
#include <pthread.h>
#include <sys/mman.h>
#include <time.h>
#include <errno.h>
#include <fcntl.h>
#ifndef MAP_JIT
#define MAP_JIT 0
#endif
#ifndef F_BARRIERFSYNC
#define F_BARRIERFSYNC F_GETFL /* HV_FLUSH=2: a harmless fcntl that succeeds */
#endif
static inline void pthread_jit_write_protect_np(int on) { (void)on; }
static inline int pthread_cond_timedwait_relative_np(pthread_cond_t *cv, pthread_mutex_t *mu, const struct timespec *rel) {
    struct timespec ts;
    clock_gettime(CLOCK_REALTIME, &ts);
    ts.tv_sec += rel->tv_sec;
    ts.tv_nsec += rel->tv_nsec;
    if (ts.tv_nsec >= 1000000000L) ts.tv_sec++, ts.tv_nsec -= 1000000000L;
    return pthread_cond_timedwait(cv, mu, &ts);
}
