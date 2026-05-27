// =============================================================================
// mem_interface.sv
// =============================================================================
// Assumptions:
//   - N = 4 (4x4 array), matching README
//   - Dataflow: output-stationary. Both A (activations) and B (weights) stream
//     in from the top-level ports every cycle the controller asserts load_en.
//   - Input skewing: a_in row r must arrive r cycles late relative to row 0
//     so that data from the same matrix row meets data from the same matrix
//     column inside the correct PE. This module inserts those pipeline delays.
//     B columns are skewed symmetrically (col c delayed by c cycles).
//   - The flat input bus (a_flat, b_flat) carries one full row/column worth
//     of BF16 values packed together: a_flat[16*(r+1)-1 : 16*r] = row r.
//   - result_flat packs the bottom-row PE outputs the same way.
// =============================================================================

module mem_interface #(parameter N = 4) (
    input  logic        clk,
    input  logic        rst,        // active-low, matches PE convention
    input  logic        load_en,    // controller: accept new input data this cycle
    input  logic        drain_en,   // controller: latch result outputs this cycle

    // Flat packed input buses from top level / testbench
    input  logic [N*16-1:0] a_flat,     // N activations packed, row 0 at LSBs
    input  logic [N*16-1:0] b_flat,     // N weights packed, col 0 at LSBs

    // Skewed outputs to systolic array
    output logic [15:0] a_skewed [N-1:0],
    output logic [15:0] b_skewed [N-1:0],

    // Results from systolic array bottom row
    input  logic [15:0] result_in [N-1:0],

    // Latched result output to top level
    output logic [N*N*16-1:0] result_flat,  // N * N spots of 16-bit results, packed into a flat array
    output logic            result_valid    // high for one cycle when results are latched
);

    // -------------------------------------------------------------------------
    // Unpack flat buses into arrays for easier indexing
    // -------------------------------------------------------------------------
    logic [15:0] a_in [N-1:0];
    logic [15:0] b_in [N-1:0];

    genvar i;
    generate
        for (i = 0; i < N; i++) begin : unpack
            assign a_in[i] = a_flat[16*(i+1)-1 : 16*i];
            assign b_in[i] = b_flat[16*(i+1)-1 : 16*i];
        end
    endgenerate

    // -------------------------------------------------------------------------
    // Input skew buffers
    //
    // Row r of A needs to be delayed r cycles so it arrives at PE[r][r] on the
    // same cycle that col r of B arrives at PE[r][r].
    //
    // skew_a[r][d] = the value of a_in[r] delayed by d cycles.
    // We build a shift-register of depth N-1 for each row/col.
    // Row/col 0 needs no delay (passes straight through).
    // -------------------------------------------------------------------------
    logic [15:0] skew_a [N-1:0][N-1:0];   // [row][delay stage 0..N-1]
    logic [15:0] skew_b [N-1:0][N-1:0];   // [col][delay stage 0..N-1]

    genvar r, c, d;
    generate
        for (r = 0; r < N; r++) begin : skew_row
            // Stage 0 always holds the raw input
            always_ff @(posedge clk or negedge rst) begin
                if (!rst)
                    skew_a[r][0] <= 16'h0000;
                else if (load_en)
                    skew_a[r][0] <= a_in[r];
            end

            // Stages 1..N-1 are chained pipeline registers
            for (d = 1; d < N; d++) begin : delay_a
                always_ff @(posedge clk or negedge rst) begin
                    if (!rst)
                        skew_a[r][d] <= 16'h0000;
                    else if (load_en)
                        skew_a[r][d] <= skew_a[r][d-1];
                end
            end

            // Row r taps delay stage r (0 delay for row 0, r cycles for row r)
            assign a_skewed[r] = skew_a[r][r];
        end

        for (c = 0; c < N; c++) begin : skew_col
            always_ff @(posedge clk or negedge rst) begin
                if (!rst)
                    skew_b[c][0] <= 16'h0000;
                else if (load_en)
                    skew_b[c][0] <= b_in[c];
            end

            for (d = 1; d < N; d++) begin : delay_b
                always_ff @(posedge clk or negedge rst) begin
                    if (!rst)
                        skew_b[c][d] <= 16'h0000;
                    else if (load_en)
                        skew_b[c][d] <= skew_b[c][d-1];
                end
            end

            assign b_skewed[c] = skew_b[c][c];
        end
    endgenerate

    // -------------------------------------------------------------------------
    // Output drain: latch results when controller asserts drain_en
    // -------------------------------------------------------------------------
    logic [15:0] result_matrix [N-1:0][N-1:0]; // [row][col], matches PE output layout

    always_ff @(posedge clk or negedge rst) begin
        if (!rst) begin
            for(int r=0; r<N; r++) for(int c=0; c<N; c++) result_matrix[r][c] <= 16'h0000;
        end else if (drain_en) begin
            for (int c = 0; c < N; c++) begin
                // Shift the saved data DOWN to make room at the top of our basket
                for (int r = N-1; r > 0; r--) begin
                    result_matrix[r][c] <= result_matrix[r-1][c];
                end
                // Catch the newest row falling out of the array
                result_matrix[0][c] <= result_in[c];
            end
        end
    end

    // Pack the 2D array into the massive flat output bus
    genvar r_out, c_out;
    generate
        for (r_out = 0; r_out < N; r_out++) begin : pack_row
            for (c_out = 0; c_out < N; c_out++) begin : pack_col
                // This maps the 2D grid into a single 256-bit wide line of wires
                assign result_flat[16*(r_out*N + c_out + 1) - 1 : 16*(r_out*N + c_out)] = result_matrix[r_out][c_out];
            end
        end
    endgenerate

    // genvar j;
    // generate
    //     for (j = 0; j < N; j++) begin : drain
    //         always_ff @(posedge clk or negedge rst) begin
    //             if (!rst)
    //                 result_reg[j] <= 16'h0000;
    //             else if (drain_en)
    //                 result_reg[j] <= result_in[j];
    //         end
    //     end
    // endgenerate

    // // Pack result array into flat output bus
    // generate
    //     for (i = 0; i < N; i++) begin : pack_result
    //         assign result_flat[16*(i+1)-1 : 16*i] = result_reg[i];
    //     end
    // endgenerate

    // // result_valid pulses for exactly one cycle after drain_en
    // always_ff @(posedge clk or negedge rst) begin
    //     if (!rst)
    //         result_valid <= 1'b0;
    //     else
    //         result_valid <= drain_en;
    // end

    // -------------------------------------------------------------------------
    // Falling Edge Detector for result_valid
    // -------------------------------------------------------------------------
    logic drain_en_delay;

    always_ff @(posedge clk or negedge rst) begin
        if (!rst) begin
            drain_en_delay <= 1'b0;
            result_valid   <= 1'b0;
        end else begin
            // Save the state of drain_en from the previous clock cycle
            drain_en_delay <= drain_en;
            
            // Pulse HIGH for exactly one cycle when drain_en turns OFF
            result_valid   <= (drain_en_delay && !drain_en); 
        end
    end

endmodule
