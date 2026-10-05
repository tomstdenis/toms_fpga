#ifndef LT1000_FPU_H
#define LT1000_FPU_H

#define FPU_LT 1
#define FPU_GT 2
#define FPU_EQ 4

#if 0
#define DEBUGI1 printf("%s: %d %f\n", __func__, a, res);
#define DEBUGF1 printf("%s: %f %d\n", __func__, a, res);
#define DEBUG1 printf("%s: %f %f\n", __func__, a, res);
#define DEBUG2 printf("%s: %f %f %f\n", __func__, a, b, res);
#define DEBUGI2 printf("%s: %f %f %d\n", __func__, a, b, res);
#else
#define DEBUGI1
#define DEBUGF1
#define DEBUG1
#define DEBUG2
#define DEBUGI2
#endif

static inline float fadd(float a, float b) {
    float res;
    asm volatile (
        ".insn r 0x0B, 0, 0, %0, %1, %2\n\t"
        : "=r" (res)
        : "r" (a), "r" (b)
    );
    DEBUG2
    return res;
}

static inline float fsub(float a, float b) {
    float res;
    asm volatile (
        ".insn r 0x0B, 0, 0x01, %0, %1, %2\n\t"
        : "=r" (res)
        : "r" (a), "r" (b)
    );
    DEBUG2
    return res;
}

static inline float fmul(float a, float b) {
    float res;
    asm volatile (
        ".insn r 0x0B, 0, 0x02, %0, %1, %2\n\t"
        : "=r" (res)
        : "r" (a), "r" (b)
    );
    DEBUG2
    return res;
}

static inline float fdiv(float a, float b) {
    float res;
    asm volatile (
        ".insn r 0x0B, 0, 0x03, %0, %1, %2\n\t"
        : "=r" (res)
        : "r" (a), "r" (b)
    );
    DEBUG2
    return res;
}

static inline float fldi(int32_t a) {
    float res;
    asm volatile (
        ".insn r 0x0B, 0, 0x04, %0, %1, %1\n\t"
        : "=r" (res)
        : "r" (a)
    );
	DEBUGI1
    return res;
}

static inline int32_t fsti(float a) {
    int32_t res;
    asm volatile (
        ".insn r 0x0B, 0, 0x05, %0, %1, %1\n\t"
        : "=r" (res)
        : "r" (a)
    );
	DEBUGF1
    return res;
}

static inline float fsqrt(float a) {
    float res;
    asm volatile (
        ".insn r 0x0B, 0, 0x06, %0, %1, %1\n\t"
        : "=r" (res)
        : "r" (a)
    );
    DEBUG1
    return res;
}

static inline uint32_t fcmp(float a, float b) {
    uint32_t res;
    asm volatile (
        ".insn r 0x0B, 0, 0x07, %0, %1, %2\n\t"
        : "=r" (res)
        : "r" (a), "r" (b)
    );
    DEBUGI2
    return res;
}

static inline uint32_t iadd8(uint32_t a, uint32_t b) {
    uint32_t res;
    asm volatile (
        ".insn r 0x0B, 0, 0x08, %0, %1, %2\n\t"
        : "=r" (res)
        : "r" (a), "r" (b)
    );
    DEBUGI2
    return res;
}

static inline uint32_t isub8(uint32_t a, uint32_t b) {
    uint32_t res;
    asm volatile (
        ".insn r 0x0B, 0, 0x09, %0, %1, %2\n\t"
        : "=r" (res)
        : "r" (a), "r" (b)
    );
    DEBUGI2
    return res;
}

static inline uint32_t iadd16(uint32_t a, uint32_t b) {
    uint32_t res;
    asm volatile (
        ".insn r 0x0B, 0, 0x0A, %0, %1, %2\n\t"
        : "=r" (res)
        : "r" (a), "r" (b)
    );
    DEBUGI2
    return res;
}

static inline uint32_t isub16(uint32_t a, uint32_t b) {
    uint32_t res;
    asm volatile (
        ".insn r 0x0B, 0, 0x0B, %0, %1, %2\n\t"
        : "=r" (res)
        : "r" (a), "r" (b)
    );
    DEBUGI2
    return res;
}

static inline uint32_t fpmul16(uint32_t a, uint32_t b) {
    uint32_t res;
    asm volatile (
        ".insn r 0x0B, 0, 0x0C, %0, %1, %2\n\t"
        : "=r" (res)
        : "r" (a), "r" (b)
    );
    DEBUGI2
    return res;
}




float fsin(float x);
float fcos(float x);
float ftan(float x);
float fatan2(float y, float x);
float fdeg2rad(float deg);
float frad2deg(float rad);
void fpu_init_sin_lut(float *lut, int entries);
float flog2(float x);
float flog(float x);
float fexp2(float x);
float fpow(float x, float y);

#endif

