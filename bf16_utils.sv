module bf16_special_detection(num_input, infinity, NaN, zero);
    input logic [15:0] num_input;
    output logic infinity, infinity, NaN, zero;

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

module fp32_to_bf16 (fp32_in, bf16_out);
    input  logic [31:0] fp32_in,
    output logic [15:0] bf16_out

    logic [31:0] rounding_bias;
    logic [31:0] rounded_val;

    // Add 0x7FFF plus the 16th bit (which will become our new LSB)
    assign rounding_bias = 32'h0000_7FFF + {31'b0, fp32_in[16]};
    
    // Add the bias to force the round up or round down
    assign rounded_val = fp32_in + rounding_bias;

    // Truncate the bottom 16 bits to get the final BF16 value
    assign bf16_out = rounded_val[31:16];
    
endmodule

module bf16_to_fp32 (bf16_in, fp32_out);
    input  logic [15:0] bf16_in,
    output logic [31:0] fp32_out
    assign fp32_out = {bf16_in, 16'h0000};

endmodule