module processing_element(a, b, result, clk, rst, en, clear);
    input logic [15:0] a, b;
    input  logic clk, rst_n, en, clear;
    output logic [15:0] result;

    // First multiply a and b together
    logic [15:0] mul_output;
    logic [15:0] add_out;
    logic [15:0] accumulator;

    bf16_mul PE_Mul(.a(a), .b(b), .result(mul_output));

    logic [15:0] result_next;

    bf16_add PE_Add(.a(mult_output), .b(accumulator), .result(add_out));

    // Add to a global sum and then push the result once the completion is completed
        always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            accumulator <= 16'h0000;
        end else if (clear) begin
            accumulator <= 16'h0000;
        end else if (en) begin
            accumulator <= add_out;
        end
    end

    assign result = accumulator;

endmodule