// mini_tpu_top.sv
// Top-level integration for the 4×4 BF16 systolic array TPU.
//
// Block diagram:
//
//   a_flat ──┐
//            ├─► mem_interface ──► systolic_array ──► mem_interface ──► result_flat
//   b_flat ──┘        ▲                  ▲                  │
//                     │                  │                  └──► result_valid
//                  controller ───────────┘
//                     ▲
//                   start
//
// Port summary:
//   clk, rst       — clock and active-low reset
//   start          — single-cycle pulse to begin a multiply
//   a_flat         — N×16-bit packed activation matrix rows (streamed in)
//   b_flat         — N×16-bit packed weight matrix columns (streamed in)
//   result_flat    — N×16-bit packed result (held until next start)
//   result_valid   — pulses high for one cycle when result_flat is ready
//   done           — held high after completion, cleared on next start

module mini_tpu_top #(parameter N = 4) (
    input  logic clk,
    input  logic rst,               // active-low

    input  logic start,             // begin a new matrix multiply

    input  logic [N*16-1:0] a_flat, // activation rows, packed BF16
    input  logic [N*16-1:0] b_flat, // weight columns, packed BF16

    output logic [N*N*16-1:0] result_flat,
    output logic            result_valid,
    output logic            done
);

    // Internal signals between blocks

    // Controller → mem_interface / array
    logic load_en;
    logic array_en;
    logic array_clear;
    logic drain_en;

    // mem_interface → systolic_array
    logic [15:0] a_skewed [N-1:0];
    logic [15:0] b_skewed [N-1:0];

    // systolic_array → mem_interface
    logic [15:0] result_raw [N-1:0];

    // Controller
    controller #(.N(N)) u_ctrl (
        .clk         (clk),
        .rst         (rst),
        .start       (start),
        .load_en     (load_en),
        .array_en    (array_en),
        .array_clear (array_clear),
        .drain_en    (drain_en),
        .done        (done)
    );

    // Memory interface (skew buffers + result latch)
    mem_interface #(.N(N)) u_mem (
        .clk          (clk),
        .rst          (rst),
        .load_en      (load_en),
        .drain_en     (drain_en),
        .a_flat       (a_flat),
        .b_flat       (b_flat),
        .a_skewed     (a_skewed),
        .b_skewed     (b_skewed),
        .result_in    (result_raw),
        .result_flat  (result_flat),
        .result_valid (result_valid)
    );

    // Systolic array
    systolic_array #(.N(N)) u_array (
        .clk        (clk),
        .rst        (rst),
        .en         (array_en),
        .drain_en   (drain_en),
        .clear      (array_clear),
        .a_in       (a_skewed),
        .b_in       (b_skewed),
        .result_out (result_raw)
    );

endmodule
