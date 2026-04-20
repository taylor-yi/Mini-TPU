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
    rounding_bias = 0x7FFF + ((int32_val >> 16) & 1)
    int32_val = (int32_val + rounding_bias) & 0xFFFFFFFF # Ensure it stays 32-bit
    
    # 3. Truncate the bottom 16 bits to get our 16-bit BF16 value
    bf16_val = int32_val >> 16
    return bf16_val