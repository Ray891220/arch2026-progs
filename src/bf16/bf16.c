#include "bf16.h"

#define BF16_INF 0x7F80u
#define BF16_NAN 0x7FC0u

uint16_t bf16_from_f32(uint32_t f32bits)
{
    uint32_t exponent = (f32bits >> 23) & 0xFFu;
    if (exponent == 0xFFu)
        return (uint16_t) (f32bits >> 16);

    uint32_t lsb = (f32bits >> 16) & 1u;
    return (uint16_t) ((f32bits + 0x7FFFu + lsb) >> 16);
}

uint16_t bf16_mul(uint16_t a, uint16_t b)
{
    uint32_t sign = (a ^ b) & 0x8000u;
    int32_t ea = (a >> 7) & 0xFFu;
    int32_t eb = (b >> 7) & 0xFFu;
    uint32_t ma = a & 0x7Fu;
    uint32_t mb = b & 0x7Fu;

    /* The order of special-value handling is part of the contract. */
    if (ea == 0xFF) {
        if (ma != 0u)
            return a;
        if ((b & 0x7FFFu) == 0u)
            return BF16_NAN;
        return (uint16_t) (sign | BF16_INF);
    }
    if (eb == 0xFF) {
        if (mb != 0u)
            return b;
        if ((a & 0x7FFFu) == 0u)
            return BF16_NAN;
        return (uint16_t) (sign | BF16_INF);
    }
    if ((a & 0x7FFFu) == 0u || (b & 0x7FFFu) == 0u)
        return (uint16_t) sign;

    int32_t adjustment = 0;
    if (ea == 0) {
        while ((ma & 0x80u) == 0u) {
            ma <<= 1;
            adjustment--;
        }
        ea = 1;
    } else {
        ma |= 0x80u;
    }
    if (eb == 0) {
        while ((mb & 0x80u) == 0u) {
            mb <<= 1;
            adjustment--;
        }
        eb = 1;
    } else {
        mb |= 0x80u;
    }

    uint32_t product = ma * mb;
    int32_t exponent = ea + eb - 127 + adjustment;
    uint32_t fraction;
    if ((product & 0x8000u) != 0u) {
        fraction = (product >> 8) & 0x7Fu;
        exponent++;
    } else {
        fraction = (product >> 7) & 0x7Fu;
    }

    if (exponent >= 0xFF)
        return (uint16_t) (sign | BF16_INF);
    if (exponent <= 0) {
        if (exponent < -6)
            return (uint16_t) sign;
        /* Preserve the quiz's truncation-before-underflow behavior. */
        fraction >>= (unsigned) (1 - exponent);
        exponent = 0;
    }
    return (uint16_t) (sign | ((uint32_t) exponent << 7) | fraction);
}

uint16_t bf16_sqrt(uint16_t a)
{
    uint32_t exponent = (a >> 7) & 0xFFu;
    uint32_t fraction = a & 0x7Fu;

    if (exponent == 0xFFu) {
        if (fraction != 0u)
            return a;
        return (a & 0x8000u) != 0u ? BF16_NAN : a;
    }
    if ((a & 0x7FFFu) == 0u)
        return 0;
    if ((a & 0x8000u) != 0u)
        return BF16_NAN;
    if (exponent == 0u)
        return 0;

    int32_t e = (int32_t) exponent - 127;
    uint32_t m = 0x80u | fraction;
    if ((e & 1) != 0) {
        m <<= 1;
        e--;
    }
    uint32_t result_exponent = (uint32_t) (e / 2 + 127);

    uint32_t low = 90;
    uint32_t high = 256;
    uint32_t best = 128;
    while (low <= high) {
        uint32_t mid = (low + high) >> 1;
        uint32_t square_scaled = (mid * mid) >> 7;
        if (square_scaled <= m) {
            best = mid;
            low = mid + 1;
        } else {
            high = mid - 1;
        }
    }

    if (best >= 256) {
        best >>= 1;
        result_exponent++;
    }
    if (result_exponent >= 0xFFu)
        return BF16_INF;
    if (result_exponent == 0u)
        return 0;
    return (uint16_t) ((result_exponent << 7) | (best & 0x7Fu));
}
