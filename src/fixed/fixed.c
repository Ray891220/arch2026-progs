
#include "fixed.h"

/* Add two unsigned integers using bitwise operations. */
uint32_t op1(uint32_t a, uint32_t b, int *n)
{
    int passes = 0;

    while (b != 0u) {
        uint32_t carry = (a & b) << 1;
        a ^= b;
        b = carry;
        passes++;
    }

    *n = passes;
    return a;
}

/* Unsigned subtraction modulo 2^32. */
uint32_t op2(uint32_t a, uint32_t b)
{
    return a - b;
}

/* Average without overflowing the intermediate sum. */
uint32_t op3(uint32_t a, uint32_t b)
{
    return (a & b) + ((a ^ b) >> 1);
}

/* Q11.20 multiplication without a hardware multiplier. */
int32_t q_mul(int32_t a, int32_t b)
{
    uint32_t x = (uint32_t) a;
    uint32_t y = (uint32_t) b;

    if (a < 0)
        x = 0u - x;
    if (b < 0)
        y = 0u - y;

    uint32_t lo = 0;
    uint32_t hi = 0;
    uint32_t multiplicand_lo = x;
    uint32_t multiplicand_hi = 0;

    while (y != 0u) {
        if ((y & 1u) != 0u) {
            uint32_t old_lo = lo;
            lo += multiplicand_lo;
            hi += multiplicand_hi + (lo < old_lo);
        }

        multiplicand_hi = (multiplicand_hi << 1) | (multiplicand_lo >> 31);
        multiplicand_lo <<= 1;
        y >>= 1;
    }

    if ((a < 0) != (b < 0)) {
        uint32_t borrow = (lo != 0u);
        lo = 0u - lo;
        hi = 0u - hi - borrow;
    }

    uint32_t carry = (lo >> 19) == 0x1fffu;
    lo += 1u << 19;
    hi += carry;

    return (int32_t) ((lo >> 20) | (hi << 12));
}
