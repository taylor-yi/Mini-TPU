module bf16_add (a, b, result);
    input [15:0] a, b;
    output [15:0] result;

    logic sign_a, sign_b;
    logic [6:0] mantissa_a, mantissa_b;
    logic [7:0] exp_a, exp_b;

    assign sign_a = a[15];
    assign sign_b = b[15];

    assign exp_a = a[14:7];
    assign exp_b = b[14:7];

    assign mantissa_a = {1'b1, a[6:0]};
    assign mantissa_b = {1'b1, b[6:0]};

    

endmodule