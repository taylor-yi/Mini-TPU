import struct
import numpy as np

def float_to_bf16_int(f_val):
    """
    Converts a standard Python float into a 16-bit integer representing a BF16 number.
    """
    # convert to a 32-bit float in big-endian format
    packed32 = struct.pack('>f', f_val)
    # unpack the 32-bit float as an unsigned integer
    int32_val = struct.unpack('>I', packed32)[0]

    # Round-to-nearest-even logic for the mantissa 
    # (Add 0x7FFF + the 16th bit to handle the tie-breaking) 
    # if the 16th bit is 1, we need to round up, otherwise we round down (stay at the same value)
    rounding_bias = 0x7FFF + ((int32_val >> 16) & 1)
    int32_val = (int32_val + rounding_bias) & 0xFFFFFFFF # Ensure it stays 32-bit
    
    # Truncate the bottom 16 bits to get our 16-bit BF16 value
    bf16_val = int32_val >> 16
    return bf16_val

def bf16_int_to_float(bf16_val):
    """
    Converts a 16-bit BF16 integer back into a Python float for NumPy to use.
    """
    # Pad the bottom 16 bits with zeros to rebuild a 32-bit FP32 number
    int32_val = bf16_val << 16
    
    # Unpack the raw binary back into a standard Python float
    packed32 = struct.pack('>I', int32_val)
    return struct.unpack('>f', packed32)[0]

# --- Quick Sanity Check ---
# if __name__ == "__main__":
#     test_num = 3.14159
#     bf16_hex = float_to_bf16_int(test_num)
#     restored = bf16_int_to_float(bf16_hex)
    
#     print(f"Original: {test_num}")
#     print(f"BF16 Hex: 0x{bf16_hex:04X}") 
#     print(f"Restored: {restored} (Notice the lost precision!)")

def hardware_mac(bf16_input_a, bf16_input_b, current_fp32_accumulator):
    """
    Simulates a single clock cycle inside one PE.
    """
    
    # 1. Hardware casts the BF16 inputs up to FP32 to do the math
    float_a = bf16_int_to_float(bf16_input_a)
    float_b = bf16_int_to_float(bf16_input_b)
    
    # 2. Hardware multiplies them
    product = float_a * float_b
    
    # 3. Hardware adds the product to the FP32 accumulator register
    new_accumulator = current_fp32_accumulator + product
    
    return new_accumulator