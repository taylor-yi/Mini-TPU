module systolic_array(paraneter N = 3)(clk, rst, en, clear, a_in, b_in, result_out); //Paramterize the size for future scaling
    input  logic        clk,
    input  logic        rst,
    input  logic        en,
    input  logic        clear,
    
    // Input activations: one per row, fed in from the left
    input  logic [15:0] a_in [N-1:0],

    // Input weights: one per column, fed in from the top
    input  logic [15:0] b_in [N-1:0],

    // Output results: one per column, drained from the bottom
    output logic [15:0] result_out [N-1:0];
    
    // TODO
    // Internal wire mesh
    // a_wire[row][col] carries the activation value flowing left → right
    // b_wire[row][col] carries the weight value flowing top → bottom
    // Each PE passes its input straight through to the next PE
    // ----------------------------------------------------------------

    logic [15:0] a_wire [N:0][N-1:0];   // [row][col], extra row for inputs
    logic [15:0] b_wire [N-1:0][N:0];   // [row][col], extra col for inputs

    // ----------------------------------------------------------------
    // Hook up the boundary inputs
    // ----------------------------------------------------------------

    genvar r, c;
    generate
        for (r = 0; r < N; r++) begin
            assign a_wire[r][0] = a_in[r];   // activations enter from the left
        end
        for (c = 0; c < N; c++) begin
            assign b_wire[0][c] = b_in[c];   // weights enter from the top
        end
    endgenerate

    // ----------------------------------------------------------------
    // Instantiate the NxN grid of processing elements
    // ----------------------------------------------------------------

    generate
        for (r = 0; r < N; r++) begin : row
            for (c = 0; c < N; c++) begin : col

                processing_element PE (
                    .clk    (clk),
                    .rst_n  (rst_n),
                    .en     (en),
                    .clear  (clear),
                    .a      (a_wire[r][c]),       // activation in from left
                    .b      (b_wire[r][c]),       // weight in from top
                    .result ()                    // TODO: wire up accumulator output
                );

                // Pass activation rightward
                // TODO: register this for proper systolic timing
                assign a_wire[r][c+1] = a_wire[r][c];

                // Pass weight downward
                // TODO: register this for proper systolic timing
                assign b_wire[r+1][c] = b_wire[r][c];

            end
        end
    endgenerate

    // ----------------------------------------------------------------
    // Drain results from the bottom row
    // ----------------------------------------------------------------

    generate
        for (c = 0; c < N; c++) begin
            // TODO: connect row[N-1].col[c] PE result to result_out[c]
            assign result_out[c] = 16'h0000; // placeholder
        end
    endgenerate

endmodule