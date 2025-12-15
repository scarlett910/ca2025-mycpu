# UF8 Encode/Decode Test - Modified for Pipeline Testing
# Stores final result in memory address 4 for verification

.globl _start
_start:
    # initialize test
    li s0, 0              # test counter
    li s1, 3              # number of tests (reduced for pipeline testing)
    
test_loop:
    beq s0, s1, test_done
    
    # load test value based on counter
    beq s0, x0, test_0
    li t0, 1
    beq s0, t0, test_1
    li t0, 2
    beq s0, t0, test_2
    
test_0:
    li a0, 15             # test value 1: small value
    j do_test
    
test_1:
    li a0, 48             # test value 2: medium value
    j do_test
    
test_2:
    li a0, 240            # test value 3: large value
    j do_test
    
do_test:
    # save original value
    mv s2, a0
    
    # encode
    jal ra, uf8_encode
    mv s3, a0             # s3 = encoded byte
    
    # decode
    mv a0, s3
    jal ra, uf8_decode
    mv s4, a0             # s4 = decoded value
    
    # simple validation: check if decoded ≈ original
    # for small values (<16): must be exact
    li t0, 16
    blt s2, t0, check_exact
    
    # for larger values: allow some error
    sub t0, s4, s2        # diff = decoded - original
    bgez t0, diff_pos
    neg t0, t0            # abs(diff)
diff_pos:
    slli t0, t0, 4        # diff * 16
    bgt t0, s2, test_fail # if diff*16 > original, fail
    j test_pass
    
check_exact:
    bne s4, s2, test_fail
    
test_pass:
    addi s0, s0, 1        # Next test
    j test_loop
    
test_fail:
    # store failure indicator
    li t0, 0xDEAD
    sw t0, 4(x0)          # Memory[4] = 0xDEAD (failure)
    j end_program
    
test_done:
    # all tests passed, store success value
    li t0, 0x55           # 0x55 = success indicator
    sw t0, 4(x0)          # Memory[4] = 0x55
    
end_program:
    # Infinite loop to end
    j end_program

# UF8 Encode: value -> byte
# input: a0 = value to encode
# output: a0 = encoded byte (exponent in upper 4 bits, mantissa in lower 4 bits)
uf8_encode:
    # Handle small values (0-15)
    li t0, 16
    blt a0, t0, encode_small
    
    # Initialize for loop
    li t1, 0              # exponent = 0
    li t2, 0              # base_offset = 0
    li t4, 15             # max_exponent = 15
    
encode_loop:
    # calculate next threshold: base_offset + (16 << exponent)
    add t3, t2, t0
    bgt t3, a0, encode_done
    
    # update for next iteration
    mv t2, t3             # base_offset = threshold
    slli t0, t0, 1        # threshold *= 2
    addi t1, t1, 1        # exponent++
    blt t1, t4, encode_loop
    
encode_done:
    # calculate mantissa: (value - base_offset) >> exponent
    sub t3, a0, t2
    srl t3, t3, t1
    andi t3, t3, 0x0F     # mantissa (4 bits)
    
    # combine: (exponent << 4) | mantissa
    slli t1, t1, 4
    or a0, t1, t3
    ret
    
encode_small:
    # value < 16, no encoding needed
    ret

# UF8 Decode: byte -> value
# input: a0 = encoded byte
# output: a0 = decoded value
uf8_decode:
    # extract exponent and mantissa
    andi t0, a0, 0x0F     # mantissa (lower 4 bits)
    srli t1, a0, 4        # exponent (upper 4 bits)
    
    # calculate offset: (2^exponent - 1) * 16
    li t2, 1
    sll t2, t2, t1        # 2^exponent
    addi t2, t2, -1       # 2^exponent - 1
    slli t2, t2, 4        # * 16
    
    # calculate value: (mantissa << exponent) + offset
    sll t0, t0, t1
    add a0, t0, t2
    ret
