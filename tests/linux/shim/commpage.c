/* Linux test build: the two words of Darwin's commpage the translator reads for counter reads
   (timebase offset 0, timebase type 1: ISB then CNTVCT_EL0). */
#include <stdint.h>
#include <sys/mman.h>
__attribute__((constructor)) static void commpage_init(void) {
    uint8_t *p = mmap((void *)0xfffffc000ull, 0x4000, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS | MAP_FIXED, -1, 0);
    if (p == MAP_FAILED) return;
    *(uint64_t *)(p + 0x088) = 0;
    p[0x090] = 1;
}
