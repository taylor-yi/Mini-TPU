module systolic_array #(parameter N = 3) (
    input  logic        clk,
    input  logic        rst,
    input  logic        en,
    input  logic        clear,

    input  logic [15:0] a_in [N-1:0],
    input  logic [15:0] b_in [N-1:0],

    output logic [15:0] result_out [N-1:0]
);

    // ----------------------------------------------------------------
    // Claude Comment:
    // Internal wire mesh
    // a_wire[row][col]: activation flowing left → right
    // b_wire[row][col]: weight flowing top → bottom
    //
    // Fixed indexing vs. original:
    //   a_wire needs N rows and N+1 columns (col 0 = input, col N = unused sink)
    //   b_wire needs N+1 rows (row 0 = input, row N = unused sink) and N columns
    // ----------------------------------------------------------------

    logic [15:0] a_wire [N-1:0][N:0];   // [row][col]
    logic [15:0] b_wire [N:0][N-1:0];   // [row][col]

    // Hook up the boundary inputs

    genvar r, c;
    generate
        for (r = 0; r < N; r++) begin
            assign a_wire[r][0] = a_in[r];   // activations enter from the left
        end
        for (c = 0; c < N; c++) begin
            assign b_wire[0][c] = b_in[c];   // weights enter from the top
        end
    endgenerate

    // Instantiate the NxN grid of processing elements

    generate
        for (r = 0; r < N; r++) begin : row
            for (c = 0; c < N; c++) begin : col

                processing_element PE (
                    .clk    (clk),
                    .rst    (rst),
                    .en     (en),
                    .clear  (clear),
                    .a      (a_wire[r][c]),
                    .b      (b_wire[r][c]),
                    .result ()
                );

                always_ff @(posedge clk or negedge rst) begin
                    if (!rst)
                        a_wire[r][c+1] <= 16'h0000;
                    else
                        a_wire[r][c+1] <= a_wire[r][c];
                end

                always_ff @(posedge clk or negedge rst) begin
                    if (!rst)
                        b_wire[r+1][c] <= 16'h0000;
                    else
                        b_wire[r+1][c] <= b_wire[r][c];
                end

            end
        end
    endgenerate

    // Drain results from the bottom row
    generate
        for (c = 0; c < N; c++) begin
            assign result_out[c] = row[N-1].col[c].PE.result;
        end
    endgenerate

endmodule