# gcd_u32_asm: Binary GCD using RV32I.
#
# Inputs:
#   a0 = a
#   a1 = b
# Output:
#   a0 = gcd(a, b)
#
# Registers:
#   t0 = common power-of-two count
#   t1 = temporary value
#   t2 = constant one
#
# No hardware multiplication or division.

    .text
    .globl gcd_u32_asm
    .type gcd_u32_asm, @function
    .align 2
    .text
    .globl gcd_u32_asm
    .type gcd_u32_asm, @function
    .align 2

gcd_u32_asm:
    # a0 = a, a1 = b
    beqz a0, .Lreturn_b
    beqz a1, .Lreturn

    # Fast path: gcd(x, 1) = 1
    li t2, 1
    beq a0, t2, .Lreturn_one
    beq a1, t2, .Lreturn_one

    # t0 counts common factors of two.
    li t0, 0

.Lcommon:
    or t1, a0, a1
    andi t1, t1, 1
    bnez t1, .Lmake_a_odd

    srli a0, a0, 1
    srli a1, a1, 1
    addi t0, t0, 1
    j .Lcommon

.Lmake_a_odd:
    andi t1, a0, 1
    bnez t1, .Lmake_b_odd
    srli a0, a0, 1
    j .Lmake_a_odd

.Lmake_b_odd:
    andi t1, a1, 1
    bnez t1, .Lcompare
    srli a1, a1, 1
    j .Lmake_b_odd

.Lcompare:
    # Both operands are odd.
    # Reduce the larger operand directly.
    bltu a1, a0, .Lreduce_a

    sub a1, a1, a0
    beqz a1, .Lrestore

.Lreduce_b:
    srli a1, a1, 1
    andi t1, a1, 1
    beqz t1, .Lreduce_b
    j .Lcompare

.Lreduce_a:
    sub a0, a0, a1

.Lstrip_a:
    srli a0, a0, 1
    andi t1, a0, 1
    beqz t1, .Lstrip_a
    j .Lcompare

.Lrestore:
    sll a0, a0, t0

.Lreturn:
    ret

.Lreturn_b:
    mv a0, a1
    ret

.Lreturn_one:
    li a0, 1
    ret

    .size gcd_u32_asm, .-gcd_u32_asm