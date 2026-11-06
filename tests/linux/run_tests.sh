#!/bin/bash
# The engine's tests on Linux, without a Mac: built for aarch64 Linux with clang and run under
# qemu-aarch64 (an x86-64 host is fine). shim/ stands in for the few Darwin interfaces the engine
# uses, and Apple's assembler syntax is rewritten for ELF. The device and graphics tests need
# Metal, so they stay Mac-only.
#
#   sudo apt-get install clang llvm binutils-aarch64-linux-gnu gcc-aarch64-linux-gnu libc6-dev-arm64-cross qemu-user
#   tests/linux/run_tests.sh [build dir]     (default build/linux)
#
# On an aarch64 Linux host the tests run directly; QEMU=qemu-aarch64 forces the emulator.
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/../.." && pwd)
OUT=$(mkdir -p "${1:-$ROOT/build/linux}" && cd "${1:-$ROOT/build/linux}" && pwd)
SHIM=$HERE/shim
cd "$ROOT"

# Apple's assembler assumes an M1, and so does the macOS build of the C code.
CC="clang --target=aarch64-linux-gnu -mcpu=apple-m1"
CFLAGS="-std=c11 -D_GNU_SOURCE -Wall -Wextra -O2 -g -I$SHIM -include $SHIM/darwin_compat.h -Icore -Ihost -Idevices"
OBJCOPY=$(command -v aarch64-linux-gnu-objcopy || command -v llvm-objcopy)

# Apple assembler syntax to ELF: sym@PAGE / sym@PAGEOFF become sym / :lo12:sym, and the C symbols
# lose Mach-O's leading underscore (both the ones defined here and the ones called from here).
asm() {
    local src=$1 obj=$2
    $CC -E -x assembler-with-cpp -Icore -Ihost -Itests "$src" |
        sed -E 's/([A-Za-z0-9_.$]+)@PAGEOFF/:lo12:\1/g; s/@PAGE\b//g; s/\.private_extern/.hidden/g' > "$obj.s"
    $CC -c "$obj.s" -o "$obj.tmp.o"
    llvm-nm "$obj.tmp.o" | awk '{s = $NF} s ~ /^_[A-Za-z]/ {print s " " substr(s, 2)}' | sort -u > "$obj.syms"
    if [ -s "$obj.syms" ]; then $OBJCOPY --redefine-syms="$obj.syms" "$obj.tmp.o" "$obj"; else cp "$obj.tmp.o" "$obj"; fi
}

ENGINE=""
for f in core/classify.c core/operands.c core/translate.c core/dispatch.c core/memop.c core/exception.c \
         core/sysreg.c core/machine.c host/jit_region.c host/disk.c; do
    o=$OUT/$(basename "${f%.c}").o
    $CC $CFLAGS -c "$f" -o "$o"
    ENGINE="$ENGINE $o"
done
$CC $CFLAGS -mgeneral-regs-only -c core/mmu.c -o "$OUT/mmu.o" # as the Makefile: no SIMD in mmu.c
asm host/enter.S "$OUT/enter.o"
$CC $CFLAGS -c "$SHIM/commpage.c" -o "$OUT/commpage.o"
ENGINE="$ENGINE $OUT/mmu.o $OUT/enter.o $OUT/commpage.o"
asm tests/harness.S "$OUT/harness.o"

L="-static -lpthread -ldl"
asm tests/classify_cases.s "$OUT/classify_cases.o"
$CC $CFLAGS tests/test_classify.c "$OUT/classify.o" "$OUT/classify_cases.o" -o "$OUT/test_classify" $L
asm tests/operand_cases.s "$OUT/operand_cases.o"
$CC $CFLAGS tests/test_operands.c "$OUT/operands.o" "$OUT/operand_cases.o" -o "$OUT/test_operands" $L
$CC $CFLAGS tests/test_mmu.c $ENGINE -o "$OUT/test_mmu" $L
for t in jit mem exc bench; do
    asm "tests/${t}_programs.S" "$OUT/${t}_programs.o"
    $CC $CFLAGS -Itests "tests/test_$t.c" "$OUT/${t}_programs.o" "$OUT/harness.o" $ENGINE -o "$OUT/test_$t" $L
done

# neoverse-v1: Armv8.4 with pointer authentication, and a 64-byte DC ZVA block as on Apple's
# chips (QEMU's "max" CPU has a bigger one, so the native half of the DC ZVA test differs).
# The stack: test_jit's main keeps two HvCpus there.
if [ -z "$QEMU" ] && [ "$(uname -m)" != aarch64 ]; then QEMU=qemu-aarch64; fi
RUN=${QEMU:+$QEMU -cpu neoverse-v1 -s 256M}
[ -z "$QEMU" ] && ulimit -s 262144 2>/dev/null || true
failed=0
for t in test_classify test_operands test_mmu test_jit test_mem test_exc; do
    if $RUN "$OUT/$t" > "$OUT/$t.log" 2>&1; then r=ok; else r=FAIL; failed=1; fi
    printf "%-14s %-4s %s\n" "$t" "$r" "$(tail -1 "$OUT/$t.log")"
done
# test_jit_region checks macOS's MAP_JIT and vm_remap shapes, and test_devices needs Metal: Mac only.
# test_bench is timing, so not a pass/fail test; "$OUT/test_bench" runs it.
exit $failed
