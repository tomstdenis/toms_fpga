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
    // Normalize x to [-PI, PI]
    while (fcmp(x, 3.14159265f) == FPU_GT)  x = fsub(x, 6.28318530f);
    while (fcmp(x, -3.14159265f) == FPU_LT) x = fadd(x, 6.28318530f);

    float x2 = fmul(x, x);
    float x3 = fmul(x, x2);
    float x5 = fmul(x3, x2);
    float x7 = fmul(x5, x2);

    // sin(x) approx = x - x^3/6 + x^5/120 - x^7/5040
    float t1 = fdiv(x3, 6.0f);
    float t2 = fdiv(x5, 120.0f);
    float t3 = fdiv(x7, 5040.0f);

    float res = fsub(x, t1);
    res = fadd(res, t2);
    res = fsub(res, t3);
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
    // Return 0 for invalid/negative/zero inputs
    if (fcmp(x, 0.0f) != FPU_GT) return 0.0f;

    // Bit-cast float to raw uint32_t to inspect IEEE-754 representation
    uint32_t u = *(uint32_t *)&x;

    // Extract raw 8-bit biased exponent (bits 30:23) and compute k = exp - 127
    int32_t exp = (int32_t)((u >> 23) & 0xFF) - 127;
    float k = fldi(exp); // Integer to float conversion via flti

    // Force exponent to 127 (0x3F800000) to clamp mantissa m into [1.0, 2.0)
    u = (u & 0x007FFFFF) | 0x3F800000;
    float m = *(float *)&u;

    // Shift mantissa to [0.0, 1.0) by subtracting 1.0
    float z = fsub(m, 1.0f);
    float z2 = fmul(z, z);
    float z3 = fmul(z2, z);
    float z4 = fmul(z2, z2);

    // Minimax polynomial approximation for log2(1 + z) on z in [0.0, 1.0):
    // log2(1+z) ≈ 1.442695*z - 0.721166*z^2 + 0.478685*z^3 - 0.228127*z^4
    float p1 = fmul(z, 1.44269504f);
    float p2 = fmul(z2, 0.72116580f);
    float p3 = fmul(z3, 0.47868480f);
    float p4 = fmul(z4, 0.22812700f);

    float log2_m = fsub(p1, p2);
    log2_m = fadd(log2_m, p3);
    log2_m = fsub(log2_m, p4);

    // log2(x) = k + log2(m)
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
    // Convert integer part to float then back to compute integer component i
    int32_t i = (int32_t)fsti(x);
    float f = fsub(x, (float)i); // Fractional remainder in [0.0, 1.0)

    // Polynomial approximation for 2^f on [0.0, 1.0):
    // 2^f ≈ 1.0 + 0.693147*f + 0.240226*f^2 + 0.055504*f^3
    float f2 = fmul(f, f);
    float f3 = fmul(f2, f);

    float t1 = fmul(f, 0.69314718f);
    float t2 = fmul(f2, 0.24022650f);
    float t3 = fmul(f3, 0.05550411f);

    float res = fadd(1.0f, t1);
    res = fadd(res, t2);
    res = fadd(res, t3);

    // Scale by 2^i directly via IEEE exponent bit manipulation
    uint32_t u = *(uint32_t *)&res;
    int32_t exp = (int32_t)((u >> 23) & 0xFF) + i;

    // Check underflow / overflow bounds
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
