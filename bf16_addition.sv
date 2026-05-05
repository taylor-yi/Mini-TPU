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

    logic [8:0] mant_sum;
    logic final_sign;

    always_comb begin
        if(sign_large == sign_small) begin
            mant_sum = {1'b0, mant_large_start} + {1'b0, mant_small_aligned};
            final_sign = sign_large;
        end
        else begin
            mant_sum = {1'b0, mant_large_start} - {1'b0, mant_small_aligned};
            final_sign = sign_large;
        end
    end

    logic [8:0] norm_mant;
    logic [7:0] norm_exp;

    always_comb begin
        // Case A: Addition caused a carry-out (e.g. 1.xx + 1.xx = 10.xx)
        if (mant_sum[8] == 1'b1) begin
            norm_mant = mant_sum >> 1; // Shift right to fix
            norm_exp  = exp_large + 1; // Increase exponent
        end
        // Case B: Subtraction caused leading zeros (e.g. 1.5 - 1.25 = 0.25)
        // We must shift left until the leading bit is a 1 again.
        else if (mant_sum[7] == 1'b1) begin
            norm_mant = mant_sum;
            norm_exp  = exp_large;
        end else if (mant_sum[6] == 1'b1) begin
            norm_mant = mant_sum << 1;
            norm_exp  = exp_large - 1;
        end else if (mant_sum[5] == 1'b1) begin
            norm_mant = mant_sum << 2;
            norm_exp  = exp_large - 2;
        end else if (mant_sum[4] == 1'b1) begin
            norm_mant = mant_sum << 3;
            norm_exp  = exp_large - 3;
        end else if (mant_sum[3] == 1'b1) begin
            norm_mant = mant_sum << 4;
            norm_exp  = exp_large - 4;
        end else if (mant_sum[2] == 1'b1) begin
            norm_mant = mant_sum << 5;
            norm_exp  = exp_large - 5;
        end else if (mant_sum[1] == 1'b1) begin
            norm_mant = mant_sum << 6;
            norm_exp  = exp_large - 6;
        end else if (mant_sum[0] == 1'b1) begin
            norm_mant = mant_sum << 7;
            norm_exp  = exp_large - 7;
        end else begin
            // The result is exactly zero
            norm_mant = 9'd0;
            norm_exp  = 8'd0;
        end
    end

    assign result = {final_sign, norm_exp, norm_mant[6:0]};
endmodule

module bf16_add_testbench ();
    logic [15:0] a, b;
	logic [15:0] result;
    logic match;
	
	bf16_add dut (.a, .b, .result);
	
	// assign fullVal = {mult_high, mult_low};
	
	integer i;
	// BF16 helper function: pack a real value into 16-bit bfloat16 format
    function automatic logic [15:0] to_bf16(input real val);
        logic [31:0] fp32;
        fp32 = $realtobits(real'(val));  // Get IEEE 754 single precision bits
        return fp32[31:16];              // BF16 = top 16 bits of FP32
    endfunction

    // BF16 helper: convert bf16 back to real for comparison
    function automatic real from_bf16(input logic [15:0] bf16);
        logic [31:0] fp32;
        fp32 = {bf16, 16'h0000};        // Zero-extend mantissa bits
        return $bitstoreal(fp32);
    endfunction

    initial begin
        // BF16 has ~3 decimal digits of precision; use epsilon-based comparison
        real epsilon;
        epsilon = 0.01;

        // No signed/unsigned loop needed for FP — BF16 handles sign via sign bit
        // Run once (sign is encoded in the BF16 value itself)

        // 0.0 + 0.0 = 0.0
        A <= to_bf16(0.0);  B <= to_bf16(0.0);  #10;
        assert (from_bf16(result) == 0.0)
            else $error("FAIL: 0.0 + 0.0 = %f (expected 0.0)", from_bf16(result));

        // 1.0 + 2.0 = 3.0
        A <= to_bf16(1.0);  B <= to_bf16(2.0);  #10;
        assert ($abs(from_bf16(result) - 3.0) < epsilon)
            else $error("FAIL: 1.0 + 2.0 = %f (expected 3.0)", from_bf16(result));

        // -1.0 + 1.0 = 0.0
        A <= to_bf16(-1.0); B <= to_bf16(1.0);  #10;
        assert ($abs(from_bf16(result) - 0.0) < epsilon)
            else $error("FAIL: -1.0 + 1.0 = %f (expected 0.0)", from_bf16(result));

        // -1.0 + -1.0 = -2.0
        A <= to_bf16(-1.0); B <= to_bf16(-1.0); #10;
        assert ($abs(from_bf16(result) - (-2.0)) < epsilon)
            else $error("FAIL: -1.0 + -1.0 = %f (expected -2.0)", from_bf16(result));

        // Large values: replacing 5<<35 / 6<<35 with large FP equivalents
        // 5.0 * 2^35 = 171798691840.0
        A <= to_bf16(1.718e11); B <= to_bf16(2.061e11); #10;
        assert ($abs(from_bf16(result) - 3.779e11) < (3.779e11 * epsilon))
            else $error("FAIL: large + large = %e (expected ~3.779e11)", from_bf16(result));

        $display("BF16 addition testbench complete.");
        $finish;
    end
endmodule