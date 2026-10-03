/*
 * fpu.c - Hardware-Accelerated Math Library for Little Timmy 1000 SoC
 * Powered by nanofpu (RISC-V PCPI Hardware Co-Processor)
 */

#include "lt1000.h"

// -----------------------------------------------------------------------------
// Core Trigonometric Functions (Taylor Series & Identities)
// -----------------------------------------------------------------------------

TCM_FUNC(fsin) float fsin(float x)
{
    while (fcmp(x, 3.14159265f) == FPU_GT)  x = fsub(x, 6.28318530f);
    while (fcmp(x, -3.14159265f) == FPU_LT) x = fadd(x, 6.28318530f);

    float x2  = fmul(x, x);
    float x3  = fmul(x, x2);
    float x5  = fmul(x3, x2);
    float x7  = fmul(x5, x2);
    float x9  = fmul(x7, x2);
    float x11 = fmul(x9, x2);
    
    // Terms: x - x^3/3! + x^5/5! - x^7/7! + x^9/9! - x^11/11!
    float t1 = fdiv(x3,  6.0f);
    float t2 = fdiv(x5,  120.0f);
    float t3 = fdiv(x7,  5040.0f);
    float t4 = fdiv(x9,  362880.0f);
    float t5 = fdiv(x11, 39916800.0f);

//	printf("x,x2,3,5,7,9,11 == %e, %e, %e, %e, %e, %e, %e\n", x, x2, x3, x5, x7, x9, x11);
//	printf("t1,2,3,4,5 == %e, %e, %e, %e, %e\n", t1, t2, t3, t4, t5);

 
    //printf("res = ");
    float res = fsub(x, t1);
    //printf("%e, ", res);
    res = fadd(res, t2);
    //printf("%e, ", res);
    res = fsub(res, t3);
    //printf("%e, ", res);
    res = fadd(res, t4);
    //printf("%e, ", res);
    res = fsub(res, t5);
    //printf("%e\n", res);
    return res;
}

TCM_FUNC(fcos) float fcos(float x)
{
    // cos(x) = sin(x + PI/2)
    return fsin(fadd(x, 1.57079632f));
}

TCM_FUNC(ftan) float ftan(float x)
{
    // tan(x) = sin(x) / cos(x)
    return fdiv(fsin(x), fcos(x));
}

// -----------------------------------------------------------------------------
// Inverse Trigonometry (Fast Polynomial Arctangent)
// -----------------------------------------------------------------------------

TCM_FUNC(fatan2) float fatan2(float y, float x)
{
    // Handle x == 0 boundary cases
    if (fcmp(x, 0.0f) == FPU_EQ) {
        if (fcmp(y, 0.0f) == FPU_GT) return 1.57079632f;  //  PI/2
        if (fcmp(y, 0.0f) == FPU_LT) return -1.57079632f; // -PI/2
        return 0.0f;
    }

    float abs_y = (fcmp(y, 0.0f) == FPU_LT) ? fsub(0.0f, y) : y;
    float abs_x = (fcmp(x, 0.0f) == FPU_LT) ? fsub(0.0f, x) : x;
    
    // Min/Max ratio setup for 0..PI/4 range
    float min_val = (fcmp(abs_x, abs_y) == FPU_LT) ? abs_x : abs_y;
    float max_val = (fcmp(abs_x, abs_y) == FPU_GT) ? abs_x : abs_y;
    
    float z = fdiv(min_val, max_val);
    float z2 = fmul(z, z);

    // Fast atan(z) polynomial approximation on [0, 1]: z * (0.995354 - 0.288679 * z^2)
    float poly = fsub(0.995354f, fmul(0.288679f, z2));
    float angle = fmul(z, poly);

    // Octant mapping
    if (fcmp(abs_y, abs_x) == FPU_GT) {
        angle = fsub(1.57079632f, angle);
    }
    if (fcmp(x, 0.0f) == FPU_LT) {
        angle = fsub(3.14159265f, angle);
    }
    if (fcmp(y, 0.0f) == FPU_LT) {
        angle = fsub(0.0f, angle);
    }

    return angle;
}

// -----------------------------------------------------------------------------
// Helper Utilities & LUT Generator
// -----------------------------------------------------------------------------

TCM_FUNC(fdeg2rad) float fdeg2rad(float deg)
{
    return fmul(deg, 0.0174532925f); // deg * (PI / 180)
}

TCM_FUNC(frad2deg) float frad2deg(float rad)
{
    return fmul(rad, 57.2957795f);  // rad * (180 / PI)
}

// Populates a 256-entry float LUT in PSRAM using nanofpu hardware ops
void fpu_init_sin_lut(float *lut, int entries)
{
    float step = fdiv(6.28318530f, (float)entries);
    for (int i = 0; i < entries; i++) {
        float angle = fmul((float)i, step);
        lut[i] = fsin(angle);
    }
}

// -----------------------------------------------------------------------------
// Base-2 Logarithm: log2(x) = k + log2(m), where x = m * 2^k and m in [1.0, 2.0)
// -----------------------------------------------------------------------------

TCM_FUNC(flog2) float flog2(float x)
{
    if (fcmp(x, 0.0f) != FPU_GT) return 0.0f;

    uint32_t u = *(uint32_t *)&x;
    int32_t exp = (int32_t)((u >> 23) & 0xFF) - 127;

    // Extract mantissa into [1.0, 2.0)
    u = (u & 0x007FFFFF) | 0x3F800000;
    float m = *(float *)&u;

    // Range reduction: If m > SQRT2 (1.41421356f), scale m down by 0.5 and bump exponent k
    if (fcmp(m, 1.41421356f) == FPU_GT) {
        m = fmul(m, 0.5f);
        exp++;
    }

    float k = fldi(exp);

    // Transform to s = (m - 1) / (m + 1)
    // For m in [1/SQRT2, SQRT2], s is in [-0.17157, +0.17157]
    float num = fsub(m, 1.0f);
    float den = fadd(m, 1.0f);
    float s   = fdiv(num, den);
    float s2  = fmul(s, s);

    // log2(m) = (2 / ln(2)) * s * (1 + s^2/3 + s^4/5 + s^6/7)
    // 2 / ln(2) ≈ 2.885390081777927
    // Horner's method for (1 + s2 * (1/3 + s2 * (1/5 + s2 * 1/7)))
    float poly = fadd(0.14285714f, fmul(s2, 0.20f));         // 1/7 + s2 * 1/5
    poly       = fadd(0.33333333f, fmul(s2, poly));         // 1/3 + s2 * poly
    poly       = fadd(1.0f,         fmul(s2, poly));         // 1.0 + s2 * poly

    float log2_m = fmul(fmul(s, 2.88539008f), poly);

    return fadd(k, log2_m);
}

// -----------------------------------------------------------------------------
// Natural Logarithm: ln(x) = log2(x) * ln(2)
// -----------------------------------------------------------------------------

TCM_FUNC(flog) float flog(float x)
{
    // ln(2) ≈ 0.69314718f
    return fmul(flog2(x), 0.69314718f);
}

// -----------------------------------------------------------------------------
// Base-2 Exponential: 2^x = 2^i * 2^f, where i = floor(x) and f in [0.0, 1.0)
// -----------------------------------------------------------------------------

TCM_FUNC(fexp2) float fexp2(float x)
{
    int32_t i = fsti(x);
    float f = fsub(x, fldi(i)); // Remainder in [0.0, 1.0)

    float f2 = fmul(f, f);
    float f3 = fmul(f2, f);
    float f4 = fmul(f2, f2);
    float f5 = fmul(f3, f2);

    // 2^f ≈ 1 + c1*f + c2*f^2 + c3*f^3 + c4*f^4 + c5*f^5
    float t1 = fmul(f,  0.69314718f);
    float t2 = fmul(f2, 0.24022650f);
    float t3 = fmul(f3, 0.05550411f);
    float t4 = fmul(f4, 0.00961812f);
    float t5 = fmul(f5, 0.00133336f);

    float res = fadd(1.0f, t1);
    res = fadd(res, t2);
    res = fadd(res, t3);
    res = fadd(res, t4);
    res = fadd(res, t5);

    uint32_t u = *(uint32_t *)&res;
    int32_t exp = (int32_t)((u >> 23) & 0xFF) + i;

    if (exp <= 0) return 0.0f;
    if (exp >= 255) exp = 254;

    u = (u & 0x807FFFFF) | ((uint32_t)exp << 23);
    return *(float *)&u;
}
// -----------------------------------------------------------------------------
// Power Function: x^y = 2^(y * log2(x))
// -----------------------------------------------------------------------------

TCM_FUNC(fpow) float fpow(float x, float y)
{
    if (fcmp(x, 0.0f) == FPU_EQ) return 0.0f;
    if (fcmp(y, 0.0f) == FPU_EQ) return 1.0f;

    // x^y = 2^(y * log2(x))
    float log2_x = flog2(x);
    float exponent = fmul(y, log2_x);
    return fexp2(exponent);
}
