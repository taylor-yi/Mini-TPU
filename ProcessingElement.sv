module processing_element(a, b, result, clk, rst, en, clear);
    input  logic [15:0] a, b;
    input  logic        clk, rst, en, clear;
    output logic [15:0] result;

    logic [15:0] mul_bf16;
    bf16_mul PE_Mul (.a(a), .b(b), .result(mul_bf16));

    // Widen mul result to FP32 for accumulation
    logic [31:0] mul_fp32;
    bf16_to_fp32 widen_mul (.bf16_in(mul_bf16), .fp32_out(mul_fp32));

    // Accumulator is now 32-bit FP32
    logic [31:0] accumulator;

    // Add in FP32
    // NOTE: you'll need a fp32_add module here (see note below)
    logic [31:0] add_fp32_out;
    fp32_add PE_Add (.a(mul_fp32), .b(accumulator), .result(add_fp32_out));

    always_ff @(posedge clk or negedge rst) begin
        if (!rst)        accumulator <= 32'h0000_0000;
        else if (clear)  accumulator <= 32'h0000_0000;
        else if (en)     accumulator <= add_fp32_out;
    end

    // Narrow back to BF16 only at the output
    fp32_to_bf16 narrow_result (.fp32_in(accumulator), .bf16_out(result));

endmodule