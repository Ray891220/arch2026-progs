# Integer-only BFloat16 operations (RV32I).
    .text

    .globl bf16_from_f32_asm
    .type bf16_from_f32_asm, @function
    .align 2
bf16_from_f32_asm:
    srli t0, a0, 23
    andi t0, t0, 255
    li t1, 255
    beq t0, t1, .Lf32_special
    srli t0, a0, 16
    andi t0, t0, 1
    li t1, 0x7fff
    add a0, a0, t1
    add a0, a0, t0
.Lf32_special:
    srli a0, a0, 16
    ret
    .size bf16_from_f32_asm, .-bf16_from_f32_asm

    .globl bf16_mul_asm
    .type bf16_mul_asm, @function
    .align 2
bf16_mul_asm:
    xor t6, a0, a1
    li t4, 0x8000
    and t6, t6, t4
    srli t0, a0, 7
    andi t0, t0, 255
    srli t1, a1, 7
    andi t1, t1, 255
    andi t2, a0, 127
    andi t3, a1, 127
    li t4, 255
    beq t0, t4, .Lmul_a_special
    beq t1, t4, .Lmul_b_special
    or t4, t0, t2
    beqz t4, .Lmul_zero
    or t4, t1, t3
    beqz t4, .Lmul_zero

    li t4, 0
    bnez t0, .Lmul_a_normal
.Lmul_a_denormal:
    andi t5, t2, 128
    bnez t5, .Lmul_a_ready
    slli t2, t2, 1
    addi t4, t4, -1
    j .Lmul_a_denormal
.Lmul_a_ready:
    li t0, 1
    j .Lmul_b_check
.Lmul_a_normal:
    ori t2, t2, 128
.Lmul_b_check:
    bnez t1, .Lmul_b_normal
.Lmul_b_denormal:
    andi t5, t3, 128
    bnez t5, .Lmul_b_ready
    slli t3, t3, 1
    addi t4, t4, -1
    j .Lmul_b_denormal
.Lmul_b_ready:
    li t1, 1
    j .Lmul_compute
.Lmul_b_normal:
    ori t3, t3, 128

.Lmul_compute:
    add t0, t0, t1
    addi t0, t0, -127
    add t0, t0, t4
    li t5, 0
    mv a0, t2
    mv a1, t3
.Lmul_loop:
    andi t2, a1, 1
    beqz t2, .Lmul_skip_add
    add t5, t5, a0
.Lmul_skip_add:
    slli a0, a0, 1
    srli a1, a1, 1
    bnez a1, .Lmul_loop

    li t2, 0x8000
    and t2, t2, t5
    beqz t2, .Lmul_shift7
    srli t5, t5, 8
    addi t0, t0, 1
    j .Lmul_scaled
.Lmul_shift7:
    srli t5, t5, 7
.Lmul_scaled:
    andi t5, t5, 127
    li t2, 255
    bge t0, t2, .Lmul_inf
    blt zero, t0, .Lmul_pack
    li t2, -6
    blt t0, t2, .Lmul_zero
    li t2, 1
    sub t2, t2, t0
    srl t5, t5, t2
    li t0, 0
.Lmul_pack:
    slli t0, t0, 7
    or a0, t0, t5
    or a0, a0, t6
    ret

.Lmul_a_special:
    bnez t2, .Lmul_return
    or t4, t1, t3
    beqz t4, .Lmul_nan
    j .Lmul_inf
.Lmul_b_special:
    bnez t3, .Lmul_return_b
    or t4, t0, t2
    beqz t4, .Lmul_nan
    j .Lmul_inf
.Lmul_return_b:
    mv a0, a1
.Lmul_return:
    ret
.Lmul_nan:
    li a0, 0x7fc0
    ret
.Lmul_inf:
    li a0, 0x7f80
    or a0, a0, t6
    ret
.Lmul_zero:
    mv a0, t6
    ret
    .size bf16_mul_asm, .-bf16_mul_asm

    .globl bf16_sqrt_asm
    .type bf16_sqrt_asm, @function
    .align 2
bf16_sqrt_asm:
    srli t0, a0, 7
    andi t0, t0, 255
    andi t1, a0, 127
    li t2, 255
    beq t0, t2, .Lsqrt_special
    li t2, 0x7fff
    and t2, a0, t2
    beqz t2, .Lsqrt_zero
    srli t2, a0, 15
    bnez t2, .Lsqrt_nan
    beqz t0, .Lsqrt_zero
    addi t2, t0, -127
    ori a1, t1, 128
    andi t3, t2, 1
    beqz t3, .Lsqrt_even
    slli a1, a1, 1
    addi t2, t2, -1
.Lsqrt_even:
    srai t2, t2, 1
    addi t2, t2, 127
    li t0, 90
    li t1, 256
    li t5, 128
    la t6, .Lsqrt_squares
.Lsqrt_search:
    bltu t1, t0, .Lsqrt_found
    add t3, t0, t1
    srli t3, t3, 1
    addi t4, t3, -90
    slli t4, t4, 1
    add t4, t4, t6
    lhu t4, 0(t4)
    bltu a1, t4, .Lsqrt_smaller
    mv t5, t3
    addi t0, t3, 1
    j .Lsqrt_search
.Lsqrt_smaller:
    addi t1, t3, -1
    j .Lsqrt_search
.Lsqrt_found:
    andi t5, t5, 127
    slli t2, t2, 7
    or a0, t2, t5
    ret
.Lsqrt_special:
    bnez t1, .Lsqrt_return
    srli t2, a0, 15
    bnez t2, .Lsqrt_nan
.Lsqrt_return:
    ret
.Lsqrt_nan:
    li a0, 0x7fc0
    ret
.Lsqrt_zero:
    li a0, 0
    ret
    .size bf16_sqrt_asm, .-bf16_sqrt_asm

    .section .rodata
    .align 1
.Lsqrt_squares:
    .half 63, 64, 66, 67, 69, 70, 72, 73
    .half 75, 76, 78, 79, 81, 82, 84, 86
    .half 87, 89, 91, 92, 94, 96, 98, 99
    .half 101, 103, 105, 106, 108, 110, 112, 114
    .half 116, 118, 120, 122, 124, 126, 128, 130
    .half 132, 134, 136, 138, 140, 142, 144, 146
    .half 148, 150, 153, 155, 157, 159, 162, 164
    .half 166, 168, 171, 173, 175, 178, 180, 182
    .half 185, 187, 190, 192, 195, 197, 200, 202
    .half 205, 207, 210, 212, 215, 217, 220, 223
    .half 225, 228, 231, 233, 236, 239, 242, 244
    .half 247, 250, 253, 255, 258, 261, 264, 267
    .half 270, 273, 276, 279, 282, 285, 288, 291
    .half 294, 297, 300, 303, 306, 309, 312, 315
    .half 318, 321, 325, 328, 331, 334, 338, 341
    .half 344, 347, 351, 354, 357, 361, 364, 367
    .half 371, 374, 378, 381, 385, 388, 392, 395
    .half 399, 402, 406, 409, 413, 416, 420, 424
    .half 427, 431, 435, 438, 442, 446, 450, 453
    .half 457, 461, 465, 468, 472, 476, 480, 484
    .half 488, 492, 496, 500, 504, 508, 512
