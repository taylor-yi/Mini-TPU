module bf16_add (a, b, result);
    input [15:0] a, b;
    output [15:0] result;

    logic sign_a, sign_b;
    logic [7:0] mantissa_a, mantissa_b;
    logic [7:0] exp_a, exp_b;

    assign sign_a = a[15];
    assign sign_b = b[15];

    assign exp_a = a[14:7];
    assign exp_b = b[14:7];

    assign mantissa_a = {1'b1, a[6:0]};
    assign mantissa_b = {1'b1, b[6:0]};

    // --------------------------------------------------------
    // 2. FIND THE LARGER NUMBER (To know who shifts)
    // --------------------------------------------------------
    logic a_is_larger;
    logic [7:0] exp_large, exp_small;
    logic [7:0] mant_large_start, mant_small_start;
    logic sign_large, sign_small;

    always_comb begin
        // Compare exponents first. If equal, compare mantissas.
        if ((exp_a > exp_b) || ((exp_a == exp_b) && (mant_a >= mant_b))) begin
            a_is_larger      = 1'b1;
            exp_large        = exp_a;
            exp_small        = exp_b;
            mant_large_start = mant_a;
            mant_small_start = mant_b;
            sign_large       = sign_a;
            sign_small       = sign_b;
        end else begin
            a_is_larger      = 1'b0;
            exp_large        = exp_b;
            exp_small        = exp_a;
            mant_large_start = mant_b;
            mant_small_start = mant_a;
            sign_large       = sign_b;
            sign_small       = sign_a;
        end
    end

    logic [7:0] exp_diff;
    logic [7:0] small_mant_moved;

    assign exp_diff = exp_large - exp_small;

    assign small_mant_moved = (exp_diff > 8) ? 8'd0 : (mant_small_start >> exp_diff);

    

endmodule