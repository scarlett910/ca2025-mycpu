# UF8 Encode/Decode - Optimized for Pipelined RISC-V CPU
# Eliminates unnecessary load-use hazards through instruction reordering

.data
    # Test messages
    test_header: .string "\n=== UF8 Pipeline Test ===\n"
    test_msg: .string "\nTest "
    colon: .string ": "
    arrow: .string " -> 0x"
    arrow2: .string " -> "
    pass_msg: .string " [PASS]"
    fail_msg: .string " [FAIL]"
    summary: .string "\n\nTests: "
    passed: .string " Passed: "
    failed: .string " Failed: "
    newline: .string "\n"
    
    # test data - smaller set for pipeline testing
    test_values: .word 0, 15, 16, 48, 100, 240, 1000, 16368
    test_count: .word 8
    
    # Result counters
    total: .word 0
    pass_count: .word 0
    fail_count: .word 0

.text
.globl main

main:
    # initialize stack pointer
    lui sp, 0x10010
    addi sp, sp, -32
    
    # Print header
    la a0, test_header
    li a7, 4
    ecall
    
    # initialize counters: reorder to avoid load-use hazard
    la t0, total
    la t1, pass_count      # load all addresses first
    la t2, fail_count
    sw zero, 0(t0)         # then store (no hazard)
    sw zero, 0(t1)
    sw zero, 0(t2)
    
    # setup test loop: load with gap
    la s0, test_values
    lw s1, test_count      # load test_count
    li s2, 0               # NOP equivalent - provides 1-cycle gap
    # s1 ready for use
    
test_loop:
    # check completion
    bge s2, s1, test_done
    
    # print test number
    la a0, test_msg
    li a7, 4
    ecall
    
    addi a0, s2, 1
    li a7, 1
    ecall
    
    la a0, colon
    li a7, 4
    ecall
    
    # calculate address and load with gap
    slli t0, s2, 2         # calculate offset
    add t0, s0, t0         # get address
    lw s3, 0(t0)           # load test value
    nop                    # explicit NOP for clarity (can be removed if next inst independent)
    
    # print original value (s3 ready after NOP)
    mv a0, s3
    li a7, 1
    ecall
    
    # Encode: prepare argument then call
    mv a0, s3              # a0 = value to encode
    jal ra, uf8_encode
    mv s4, a0              # s4 = encoded result
    
    # print encoded hex
    la a0, arrow
    li a7, 4
    ecall
    
    mv a0, s4
    jal ra, print_hex
    
    # Decode: prepare argument then call
    mv a0, s4
    jal ra, uf8_decode
    mv s5, a0              # s5 = decoded result
    
    # print decoded value
    la a0, arrow2
    li a7, 4
    ecall
    
    mv a0, s5
    li a7, 1
    ecall
    
    # validation logic: constants loaded early
    li t0, 16              # load constant early
    blt s3, t0, check_exact
    
    # large value tolerance check
    sub t0, s5, s3         # diff = decoded - original
    bgez t0, diff_positive
    neg t0, t0             # abs(diff)
    
diff_positive:
    slli t0, t0, 4         # diff * 16
    ble t0, s3, test_pass  # if diff*16 <= original, pass
    j test_fail
    
check_exact:
    beq s5, s3, test_pass
    j test_fail

test_fail:
    la a0, fail_msg
    li a7, 4
    ecall
    
    # load address once, reuse
    la t0, fail_count
    lw t1, 0(t0)
    addi t1, t1, 1
    sw t1, 0(t0)
    j test_next

test_pass:
    la a0, pass_msg
    li a7, 4
    ecall
    
    # load address once, reuse
    la t0, pass_count
    lw t1, 0(t0)
    addi t1, t1, 1
    sw t1, 0(t0)

test_next:
    # update total counter
    la t0, total
    lw t1, 0(t0)
    addi t1, t1, 1
    sw t1, 0(t0)
    
    addi s2, s2, 1
    j test_loop

test_done:
    # print summary
    la a0, summary
    li a7, 4
    ecall
    
    la t0, total
    lw a0, 0(t0)
    li a7, 1
    ecall
    
    la a0, passed
    li a7, 4
    ecall
    
    la t0, pass_count
    lw a0, 0(t0)
    li a7, 1
    ecall
    
    la a0, failed
    li a7, 4
    ecall
    
    la t0, fail_count
    lw a0, 0(t0)
    li a7, 1
    ecall
    
    la a0, newline
    li a7, 4
    ecall
    
    # store final result in memory for test verification
    la t0, pass_count
    lw t1, 0(t0)
    lui t2, 0x10000
    sw t1, 4(t2)           # store pass_count at 0x10000004 for CPUTest
    
    # Exit
    li a7, 10
    ecall

# helper: Print hexadecimal byte
print_hex:
    addi sp, sp, -4
    sw s0, 0(sp)
    mv s0, a0
    
    # high nibble
    srli a0, s0, 4
    li t0, 10
    blt a0, t0, ph1
    addi a0, a0, 87        # 'a'-'f'
    j ph2
ph1:
    addi a0, a0, 48        # '0'-'9'
ph2:
    li a7, 11
    ecall
    
    # Low nibble
    andi a0, s0, 0x0F
    li t0, 10
    blt a0, t0, ph3
    addi a0, a0, 87
    j ph4
ph3:
    addi a0, a0, 48
ph4:
    li a7, 11
    ecall
    
    lw s0, 0(sp)
    addi sp, sp, 4
    ret

# UF8 Decode: byte -> value
uf8_decode:
    # all independent operations, no hazards
    andi t0, a0, 0x0F      # mantissa = lower 4 bits
    srli t1, a0, 4         # exponent = upper 4 bits
    li t2, 1
    sll t2, t2, t1         # 2^exponent
    addi t2, t2, -1        # 2^exponent - 1
    slli t2, t2, 4         # offset = (2^exp - 1) * 16
    sll t0, t0, t1         # mantissa << exponent
    add a0, t0, t2         # result = (mantissa << exp) + offset
    ret

# UF8 Encode: value -> byte
uf8_encode:
    # handle small values
    li t0, 16
    blt a0, t0, small
    
    # initialize all loop variables early
    li t1, 0               # exponent
    li t2, 0               # base_offset
    li t4, 15              # max_exponent
    
loop_exp:
    # calculate next threshold
    add t3, t2, t0
    bgt t3, a0, done_exp
    
    mv t2, t3              # update base_offset
    slli t0, t0, 1         # double threshold
    addi t1, t1, 1         # increment exponent
    blt t1, t4, loop_exp
    
done_exp:
    # calculate mantissa with no dependencies
    sub t3, a0, t2         # remaining = value - base_offset
    srl t3, t3, t1         # mantissa = remaining >> exponent
    andi t3, t3, 0x0F      # mask to 4 bits
    slli t1, t1, 4         # shift exponent to upper nibble
    or a0, t1, t3          # combine exponent | mantissa
    ret

small:
    # Value < 16, return as-is
    ret
