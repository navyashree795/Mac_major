import random

def test_pipeline():
    ALPHA = 8
    K = 16
    LOWER_W = 15
    
    # Run 1000 random tests
    for test in range(100):
        count = random.randint(1, 32)
        signed_mode = random.choice([False, True])
        
        reg1_lower = 0
        reg1_upper = 0
        reg4 = 0
        
        expected = 0
        
        for i in range(count):
            if signed_mode:
                x = random.randint(-32768, 32767)
                y = random.randint(-32768, 32767)
                p = x * y
            else:
                x = random.randint(0, 65535)
                y = random.randint(0, 65535)
                p = x * y
            expected += p
            
            # Hardware accumulation in Stage 1
            # Current accumulated value before this step:
            # lower 15 bits: reg1_lower
            # upper bits: reg1_upper << 15
            # reg4 << 31
            # Total sum:
            if signed_mode:
                sum_step = p + reg1_lower + (reg1_upper << 15)
                # Next lower 15 bits:
                reg1_lower = sum_step & 0x7FFF
                # Upper part shifted by 15:
                upper_part = sum_step >> 15
                reg1_upper = upper_part & 0xFFFF
                # Carry into column 31:
                carry = upper_part >> 16
                reg4 += carry
            else:
                sum_step = p + reg1_lower + (reg1_upper << 15)
                reg1_lower = sum_step & 0x7FFF
                upper_part = sum_step >> 15
                reg1_upper = upper_part & 0xFFFF
                carry = upper_part >> 16
                reg4 += carry
                
        # Stage 2 final addition
        stage2_sum = (reg4 << 16) + reg1_upper
        hw_result = (stage2_sum << 15) + reg1_lower
        
        # Mask to 40-bit representation
        if signed_mode:
            expected_masked = expected & 0xFFFFFFFFFF
            hw_masked = hw_result & 0xFFFFFFFFFF
        else:
            expected_masked = expected & 0xFFFFFFFFFF
            hw_masked = hw_result & 0xFFFFFFFFFF
            
        assert hw_masked == expected_masked, f"Mismatch: count={count}, exp={hex(expected_masked)}, got={hex(hw_masked)}"
    print("ALL 100 TESTS PASSED IN PYTHON!")

if __name__ == '__main__':
    test_pipeline()
