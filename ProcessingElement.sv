module processing_element(a, b, data_from_above, result, clk, rst, en, clear, drain_en);
    input  logic [15:0] a, b, data_from_above;
    input  logic        clk, rst, en, clear, drain_en;
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

    // We must cast the data coming from above into FP32 so it fits in the accumulator
    logic [31:0] drain_data_fp32;
    bf16_to_fp32 widen_drain (.bf16_in(data_from_above), .fp32_out(drain_data_fp32));

    always_ff @(posedge clk or negedge rst) begin
        if (!rst) begin
            accumulator <= 32'h0000_0000;
        end else if (clear) begin
            accumulator <= 32'h0000_0000;
        end else if (drain_en) begin        // if draining to next PE, load new data from above instead of adding
            accumulator <= drain_data_fp32;  // Load new data from above when draining
        end else if (en) begin
            accumulator <= add_fp32_out;
        end
    end

    // Narrow back to BF16 only at the output
    fp32_to_bf16 narrow_result (.fp32_in(accumulator), .bf16_out(result));

endmodule