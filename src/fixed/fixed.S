
# Fixed-point arithmetic using RV32I.
#
# a0, a1: input operands
# a2: pointer to iteration count (op1 only)
# a0: return value
#
# t0-t6: temporary registers
# No M, F, or compressed instructions.

    .text

# --------------------------------------------------
# op1: Bitwise addition with carry propagation.
# --------------------------------------------------
    .globl op1_asm
    .type op1_asm, @function
    .align 2
op1_asm:
    li t0, 0
    beqz a1, .Lop1_done

.Lop1_loop:
    and t1, a0, a1
    xor a0, a0, a1
    slli a1, t1, 1
    addi t0, t0, 1
    bnez a1, .Lop1_loop

.Lop1_done:
    sw t0, 0(a2)
    ret
    .size op1_asm, .-op1_asm

# --------------------------------------------------
# op2: Subtraction modulo 2^32.
# --------------------------------------------------
    .globl op2_asm
    .type op2_asm, @function
    .align 2
op2_asm:
    sub a0, a0, a1
    ret
    .size op2_asm, .-op2_asm

# --------------------------------------------------
# op3: Overflow-safe unsigned average.
# --------------------------------------------------
    .globl op3_asm
    .type op3_asm, @function
    .align 2
op3_asm:
    and t0, a0, a1
    xor a0, a0, a1
    srli a0, a0, 1
    add a0, a0, t0
    ret
    .size op3_asm, .-op3_asm

# --------------------------------------------------
# q_mul: Signed Q11.20 multiplication.
#
# Unsigned 64-bit shift-and-add multiplication,
# followed by signed correction and rounding.
#
# t0: product low 32 bits
# t1: product high 32 bits
# t2: multiplicand low 32 bits
# t3: multiplicand high 32 bits
# t4: multiplier
# t5: temporary sign
# t6: product sign flag
# a0, a1: working temporaries
# --------------------------------------------------
    .globl q_mul_asm
    .type q_mul_asm, @function
    .align 2
q_mul_asm:
    beqz a0, .Lq_zero
    beqz a1, .Lq_zero

    # Record whether the product is negative.
    slt t6, a0, zero
    slt t5, a1, zero
    xor t6, t6, t5

    # Convert a to unsigned magnitude.
    bgez a0, .Lq_abs_a_done
    sub a0, zero, a0

.Lq_abs_a_done:
    # Convert b to unsigned magnitude.
    bgez a1, .Lq_abs_b_done
    sub a1, zero, a1

.Lq_abs_b_done:
    li t0, 0
    li t1, 0
    mv t2, a0
    li t3, 0
    mv t4, a1

.Lq_mul_loop:
    # Add multiplicand when multiplier bit is 1.
    andi a0, t4, 1
    beqz a0, .Lq_skip_add

    add t0, t0, t2
    sltu a1, t0, t2
    add t1, t1, t3
    add t1, t1, a1

.Lq_skip_add:
    # Shift 64-bit multiplicand left by one bit.
    srli a0, t2, 31
    slli t2, t2, 1
    slli t3, t3, 1
    or t3, t3, a0

    # Shift multiplier right.
    srli t4, t4, 1
    bnez t4, .Lq_mul_loop

    # Negate 64-bit product if necessary.
    beqz t6, .Lq_round

    sltu a0, zero, t0
    sub t0, zero, t0
    sub t1, zero, t1
    sub t1, t1, a0

.Lq_round:
    # Add 2^19 before shifting right by 20.
    li a0, 0x80000
    add a1, t0, a0
    sltu a0, a1, t0
    add t1, t1, a0

    # Extract bits 20..51 of the 64-bit result.
    srli a0, a1, 20
    slli t1, t1, 12
    or a0, a0, t1
    ret

.Lq_zero:
    li a0, 0
    ret
    .size q_mul_asm, .-q_mul_asm
