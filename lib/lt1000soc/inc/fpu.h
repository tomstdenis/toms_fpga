#ifndef LT1000_FPU_H
#define LT1000_FPU_H

#define FPU_LT 1
#define FPU_GT 2
#define FPU_EQ 4

static inline float fadd(float a, float b) {
    float res;
    asm volatile (
        ".insn r 0x0B, 0, 0, %0, %1, %2\n\t"
        : "=r" (res)
        : "r" (a), "r" (b)
    );
    return res;
}

static inline float fsub(float a, float b) {
    float res;
    asm volatile (
        ".insn r 0x0B, 0, 0x01, %0, %1, %2\n\t"
        : "=r" (res)
        : "r" (a), "r" (b)
    );
    return res;
}

static inline float fmul(float a, float b) {
    float res;
    asm volatile (
        ".insn r 0x0B, 0, 0x02, %0, %1, %2\n\t"
        : "=r" (res)
        : "r" (a), "r" (b)
    );
    return res;
}

static inline float fdiv(float a, float b) {
    float res;
    asm volatile (
        ".insn r 0x0B, 0, 0x03, %0, %1, %2\n\t"
        : "=r" (res)
        : "r" (a), "r" (b)
    );
    return res;
}

static inline float fldi(int32_t a) {
    float res;
    asm volatile (
        ".insn r 0x0B, 0, 0x04, %0, %1, %1\n\t"
        : "=r" (res)
        : "r" (a)
    );
    return res;
}

static inline int32_t fsti(float a) {
    int32_t res;
    asm volatile (
        ".insn r 0x0B, 0, 0x05, %0, %1, %1\n\t"
        : "=r" (res)
        : "r" (a)
    );
    return res;
}

static inline float fsqrt(float a) {
    float res;
    asm volatile (
        ".insn r 0x0B, 0, 0x06, %0, %1, %1\n\t"
        : "=r" (res)
        : "r" (a)
    );
    return res;
}

static inline uint32_t fcmp(float a, float b) {
    uint32_t res;
    asm volatile (
        ".insn r 0x0B, 0, 0x07, %0, %1, %2\n\t"
        : "=r" (res)
        : "r" (a), "r" (b)
    );
    return res;
}

float fsin(float x);

#endif

