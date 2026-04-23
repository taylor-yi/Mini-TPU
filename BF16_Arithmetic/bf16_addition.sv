module bf16_adder (a, b, result);
    input [15:0] a, b;
    output [15:0] result;

    logic sign_a, sign_b;
    logic [7:0] mantissa_a, mantissa_b;
    logci [7:0] exp_a, exp_b;

    assign sign_a = a[15];
    assign
endmodule