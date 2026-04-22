module bf16_utils(num_input, infinity, NaN, zero);
    input logic [15:0] num_input;
    output logic pos_infinity, neg_infinity, NaN, zero;

// Check for NaN, Infinity and Zero, based on the special cases
    always_comb begin
        if(num_input[14:7] == 8'hFF) begin
            if(a[6:0] == 0) begin
                assign infinity = 1'b1;
            end
            else begin
                assign NaN = 1'b1;
            end
        end

        elsif(num_input[14:0] == 0) begin
            assign zero = 1'b1;
        end
    end

endmodule

// --------------------------------------------------------
// Utility 1: FP32 to BF16 Caster (with Round-to-Nearest-Even)
// --------------------------------------------------------
module fp32_to_bf16 (
    input  logic [31:0] fp32_in,
    output logic [15:0] bf16_out
);
    logic [31:0] rounding_bias;
    logic [31:0] rounded_val;

    // This is the exact hardware equivalent of the Python hack we wrote earlier.
    // We add 0x7FFF plus the 16th bit (which will become our new Least Significant Bit)
    assign rounding_bias = 32'h0000_7FFF + {31'b0, fp32_in[16]};
    
    // Add the bias to force the round up or round down
    assign rounded_val = fp32_in + rounding_bias;

    // Truncate the bottom 16 bits to get the final BF16 value
    assign bf16_out = rounded_val[31:16];
    
endmodule

// --------------------------------------------------------
// Utility 2: BF16 to FP32 Caster
// --------------------------------------------------------
module bf16_to_fp32 (
    input  logic [15:0] bf16_in,
    output logic [31:0] fp32_out
);
    // This is the easiest logic in the entire project. 
    // We just take the 16 bits and concatenate 16 zeros onto the bottom.
    assign fp32_out = {bf16_in, 16'h0000};
    
endmodule