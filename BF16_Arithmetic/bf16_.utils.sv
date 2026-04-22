module bf16_utils(num_input, infinity, NaN, zero);
    input logic [15:0] num_input;
    output logic pos_infinity, neg_infinity, NaN, zero;

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