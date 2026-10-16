import random

def test():
    for _ in range(1000):
        count = random.randint(1, 64)
        signed_mode = random.choice([True, False])
        
        reg1_lower = 0
        reg1_upper = 0
        reg4 = 0
        expected = 0
        
        for _ in range(count):
            if signed_mode:
                x = random.randint(-32768, 32767)
                y = random.randint(-32768, 32767)
                p = x * y
            else:
                x = random.randint(0, 65535)
                y = random.randint(0, 65535)
                p = x * y
            expected += p
            
            # Step in Stage 1
            sum_step = p + reg1_lower + (reg1_upper << 15)
            reg1_lower = sum_step & 0x7FFF
            upper_part = sum_step >> 15
            reg1_upper = upper_part & 0xFFFF
            carry = upper_part >> 16
            reg4 += carry
            
        stage2_sum = (reg4 << 16) + reg1_upper
        hw_res = (stage2_sum << 15) + reg1_lower
        
        assert (hw_res & 0xFFFFFFFFFF) == (expected & 0xFFFFFFFFFF), f"Mismatch: exp={hex(expected & 0xFFFFFFFFFF)}, got={hex(hw_res & 0xFFFFFFFFFF)}"
    print("SUCCESS: 1000/1000 RANDOM TESTS PASSED!")

test()
