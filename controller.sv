// =============================================================================
// controller.sv
// =============================================================================
// FSM that sequences a single matrix-multiply operation through three phases:
//
//   IDLE    → waiting for start pulse
//   LOAD    → feeding input data into the skew buffers and array for N+N-1
//             cycles (N cycles to fill the skew pipeline + N-1 drain cycles
//             so every PE sees valid data). en=1, clear=0.
//   COMPUTE → extra cycles to let the last data ripple through the array and
//             fully accumulate. en=1, clear=0.
//   DRAIN   → assert drain_en for one cycle so mem_interface latches results,
//             then assert done and return to IDLE.
//
// Timing budget for an NxN array:
//   - Data enters skew buffers on cycle 0.
//   - The last datum (row N-1 / col N-1) exits the skew buffer on cycle N-1.
//   - It then propagates through N columns of pipeline registers inside the
//     array before reaching PE[N-1][N-1], taking another N-1 cycles.
//   - Total cycles from first load_en to last valid accumulation = 2*(N-1)+N
//     = 3N-2. We add one margin cycle → total LOAD+COMPUTE = 3N-1 cycles.
//
// Assumptions:
//   - N = 4 by default, matches README.
//   - start is a single-cycle pulse from the host / testbench.
//   - done is held high until the next start pulse clears it.
// =============================================================================

module controller #(parameter N = 4) (
    input  logic clk,
    input  logic rst,       // active-low

    input  logic start,     // single-cycle pulse: begin a new multiply

    output logic load_en,   // to mem_interface: accept input data this cycle
    output logic array_en,  // to systolic_array: PE accumulators running
    output logic array_clear, // to systolic_array: reset all PE accumulators
    output logic drain_en,  // to mem_interface: latch results
    output logic done       // held high after completion, cleared on next start
);

    // -------------------------------------------------------------------------
    // State encoding
    // -------------------------------------------------------------------------
    typedef enum logic [1:0] {
        IDLE    = 2'b00,
        LOAD    = 2'b01,
        COMPUTE = 2'b10,
        DRAIN   = 2'b11
    } state_t;

    state_t state, next_state;

    // Cycle counter — wide enough for 3N-1 counts
    localparam LOAD_CYCLES = 2 * N - 1;  // cycles to stream all skewed data in
    localparam COMPUTE_CYCLES = N;           // extra cycles for last data to settle
    localparam TOTAL_ACTIVE = LOAD_CYCLES + COMPUTE_CYCLES; // = 3N-1

    localparam CTR_WIDTH = $clog2(TOTAL_ACTIVE + 2);
    logic [CTR_WIDTH-1:0] cycle_cnt;

    logic done_reg; 

    always_ff @(posedge clk or negedge rst) begin
        if (!rst)
            done_reg <= 1'b0;
        else if (start)
            done_reg <= 1'b0;
        else if (state == DRAIN && next_state == IDLE)  //Only trigger done when the 4-cycle drain is actually finishing
            done_reg <= 1'b1;
    end
    assign done = done_reg;

    always_ff @(posedge clk or negedge rst) begin
        if (!rst)
            state <= IDLE;
        else
            state <= next_state;
    end

    always_ff @(posedge clk or negedge rst) begin
        if (!rst)
            cycle_cnt <= '0;
        else if (state != next_state)
            cycle_cnt <= '0;
        else
            cycle_cnt <= cycle_cnt + 1'b1;
    end

    always_comb begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start)
                    next_state = LOAD;
            end

            LOAD: begin
                if (cycle_cnt == CTR_WIDTH'(LOAD_CYCLES - 1))
                    next_state = COMPUTE;
            end

            COMPUTE: begin
                if (cycle_cnt == CTR_WIDTH'(COMPUTE_CYCLES - 1))
                    next_state = DRAIN;
            end

            DRAIN: begin
                if (cycle_cnt == CTR_WIDTH'(N-1)) // drain for N cycles to ensure results are latched before going back to IDLE
                next_state = IDLE;
            end
        endcase
    end

    always_comb begin
        load_en     = 1'b0;
        array_en    = 1'b0;
        array_clear = 1'b0;
        drain_en    = 1'b0;

        case (state)
            IDLE: begin
                array_clear = 1'b1;
            end

            LOAD: begin
                load_en  = 1'b1;
                array_en = 1'b1;
            end

            COMPUTE: begin
                array_en = 1'b1;
            end

            DRAIN: begin
                drain_en = 1'b1;
            end
        endcase
    end

endmodule
