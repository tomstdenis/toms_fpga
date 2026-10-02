#include "lt1000.h"

float fsin(float x)
{
    while (fcmp(x, 3.14159265f) == FPU_GT)  x = fsub(x, 6.28318530f);
    while (fcmp(x, -3.14159265f) == FPU_LT) x = fadd(x, 6.28318530f);

    float x2 = fmul(x, x);
    float x3 = fmul(x, x2);
    float x5 = fmul(x3, x2);
    float x7 = fmul(x5, x2);

    float t1 = fdiv(x3, 6.0f);
    float t2 = fdiv(x5, 120.0f);
    float t3 = fdiv(x7, 5040.0f);

    float res = fsub(x, t1);
    res = fadd(res, t2);
    res = fsub(res, t3);
    return res;
}
