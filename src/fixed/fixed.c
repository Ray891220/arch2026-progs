
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
    uint64_t x = a < 0 ? (uint64_t) (-(int64_t) a) : (uint64_t) a;

    uint32_t y = b < 0 ? (uint32_t) (-(int64_t) b) : (uint32_t) b;

    uint64_t product = 0;

    /* Shift-and-add multiplication. */
    while (y != 0u) {
        if ((y & 1u) != 0u)
            product += x;

        x <<= 1;
        y >>= 1;
    }

    /* Restore the sign of the product. */
    int64_t signed_product =
        ((a < 0) != (b < 0)) ? -(int64_t) product : (int64_t) product;

    /* Round ties toward positive infinity. */
    int64_t rounded = (signed_product + (INT64_C(1) << (Q - 1))) >> Q;

    /* Keep only the low 32 bits. */
    return (int32_t) (uint32_t) rounded;
}
