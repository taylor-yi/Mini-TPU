module bf16_mul (a, b, result);

    input  logic [15:0] a;
    input  logic [15:0] b;
    output logic [15:0] result;

    // 1. Unpack: Extract sign, exponent, and mantissa for A and B
    logic sign_a, sign_b; // 0 is positive
    logic [6:0] mantissa_a, mantissa_b;
    logic [7:0] exponent_a, exponent_b;

    assign sign_a = a[15];
    assign sign_b = b[15];
    
    assign exponent_a = a[14:7];
    assign exponent_b = b[14:7];

    assign mantissa_a = a[6:0];
    assign mantissa_b = b[6:0]
    


    // 2. Sign: XOR the sign bits
    logic sign_output;
    assign sign_output = sign_a ^ sign_b;

    
    // 3. Exponent: Add exponents and subtract the 127 bias
    logic [8:0] out_exponent;
    assign out_exponent = exponent_a + exponent_b - 127;
    
    // 4. Mantissa: Append the hidden '1' and multiply
    logic [7:0] temp_mantissa_a, temp_mantissa_b;
    
    assign temp_mantissa_a = {1'b1, mantissa_a};
    assign temp_mantissa_b = {1'b1, mantissa_b};

    logic [15:0] output_mant;
    assign output_mant = temp_mantissa_a * temp_mantissa_b;
    
    // 5. Normalize: Shift if there's a carry-out and adjust exponent
    logic [8:0] exp_result
    logic [6:0] mant_result
   
    always_comb begin
        if (mant_product[15]) begin
            mant_result = mant_product[14:8]
            exp_result = out_exponent + 1'b1
        end

        else begin
            mant_result = mant_product[13:7];
            exp_result = out_exponent;
        end
   end

    // 6. Pack: Assemble final sign, exponent, and mantissa into 'result'
   assign result = {sign_output, exp_result[7:0], mant_result};
endmodule