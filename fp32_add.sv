module fp32_add (a, b, result);
    input  logic [31:0] a, b;
    output logic [31:0] result;

    // Modified BF16 to add floating points to not round until the end
    logic sign_a, sign_b;
    logic [23:0] mant_a, mant_b;
    logic [7:0] exp_a, exp_b;

    assign sign_a = a[31];
    assign sign_b = b[31];
    assign exp_a = a[30:23];
    assign exp_b = b[30:23];
    assign mant_a = {1'b1, a[22:0]};
    assign mant_b = {1'b1, b[22:0]};

    logic a_is_larger;
    logic [7:0] exp_large, exp_small;
    logic [23:0] mant_large_start, mant_small_start;
    logic sign_large, sign_small;

    always_comb begin
        if ((exp_a > exp_b) || ((exp_a == exp_b) && (mant_a >= mant_b))) begin
            a_is_larger = 1'b1;
            exp_large = exp_a;
            exp_small = exp_b;
            mant_large_start = mant_a;
            mant_small_start = mant_b;
            sign_large = sign_a;
            sign_small = sign_b;
        end else begin
            a_is_larger = 1'b0;
            exp_large = exp_b;
            exp_small = exp_a;
            mant_large_start = mant_b;
            mant_small_start = mant_a;
            sign_large = sign_b;
            sign_small = sign_a;
        end
    end

    logic [7:0]  exp_diff;
    logic [23:0] mant_small_aligned;

    assign exp_diff         = exp_large - exp_small;
    assign mant_small_aligned = (exp_diff > 24) ? 24'd0 : (mant_small_start >> exp_diff);
    // Threshold was 8 — now 24 to match mantissa width

    logic [24:0] mant_sum;  // was [8:0] — one extra bit for carry
    logic final_sign;

    always_comb begin
        if (sign_large == sign_small) begin
            mant_sum   = {1'b0, mant_large_start} + {1'b0, mant_small_aligned};
            final_sign = sign_large;
        end else begin
            mant_sum   = {1'b0, mant_large_start} - {1'b0, mant_small_aligned};
            final_sign = sign_large;
        end
    end

    logic [24:0] norm_mant;
    logic [7:0]  norm_exp;

    always_comb begin
        if (mant_sum[24]) begin          // carry-out from addition
            norm_mant = mant_sum >> 1;
            norm_exp  = exp_large + 1;
        end else if (mant_sum[23]) begin // already normalised
            norm_mant = mant_sum;
            norm_exp  = exp_large;
        end else begin
            norm_mant = mant_sum;
            norm_exp  = exp_large;
            for (int i = 0; i < 23; i++) begin
                if (!norm_mant[23] && norm_exp > 0) begin
                    norm_mant = norm_mant << 1;
                    norm_exp  = norm_exp  - 1;
                end
            end
            if (!norm_mant[23]) begin
                norm_mant = 25'd0;
                norm_exp  = 8'd0;
            end
        end
    end

    assign result = {final_sign, norm_exp, norm_mant[22:0]};

endmodule