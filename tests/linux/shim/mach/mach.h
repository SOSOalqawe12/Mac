/* Linux test build: the few Mach calls the engine makes, as stand-ins. */
#pragma once
#include <stdint.h>
#include <sys/resource.h>
#include <mach/mach_time.h>
typedef int kern_return_t;
typedef unsigned mach_port_t;
typedef unsigned mach_msg_type_number_t;
typedef uintptr_t vm_address_t;
typedef int vm_prot_t;
typedef int *thread_info_t;
#define KERN_SUCCESS 0
#define KERN_FAILURE 5
#define FALSE 0
#define VM_FLAGS_ANYWHERE 1
#define VM_INHERIT_NONE 2
#define THREAD_BASIC_INFO 3
typedef struct { struct { int seconds, microseconds; } user_time, system_time; } thread_basic_info_data_t;
#define THREAD_BASIC_INFO_COUNT 4
static inline mach_port_t mach_task_self(void) { return 1; }
static inline mach_port_t mach_thread_self(void) { return 2; }
static inline kern_return_t mach_port_deallocate(mach_port_t t, mach_port_t p) { (void)t, (void)p; return KERN_SUCCESS; }
static inline kern_return_t thread_info(mach_port_t th, int flavor, thread_info_t out, mach_msg_type_number_t *n) {
    (void)th, (void)flavor, (void)n;
    struct rusage ru;
    getrusage(RUSAGE_THREAD, &ru);
    thread_basic_info_data_t *t = (thread_basic_info_data_t *)out;
    t->user_time.seconds = (int)ru.ru_utime.tv_sec, t->user_time.microseconds = (int)ru.ru_utime.tv_usec;
    t->system_time.seconds = (int)ru.ru_stime.tv_sec, t->system_time.microseconds = (int)ru.ru_stime.tv_usec;
    return KERN_SUCCESS;
}
static inline kern_return_t vm_remap(mach_port_t a, vm_address_t *b, uintptr_t c, uintptr_t d, int e, mach_port_t f,
                                     vm_address_t g, int h, vm_prot_t *i, vm_prot_t *j, int k) {
    (void)a, (void)b, (void)c, (void)d, (void)e, (void)f, (void)g, (void)h, (void)i, (void)j, (void)k;
    return KERN_FAILURE; /* HV_JIT_SPLIT is macOS-only */
}
