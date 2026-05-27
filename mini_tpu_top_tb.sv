module mini_tpu_top_tb ();

    localparam N = 4;

    // --------------------------------------------------------
    // 1. Declare signals
    // --------------------------------------------------------
    logic clk;
    logic rst;
    logic start;
    
    logic [N*16-1:0]   a_flat;
    logic [N*16-1:0]   b_flat;
    logic [N*N*16-1:0] result_flat;
    
    logic result_valid;
    logic done;

    // --------------------------------------------------------
    // 2. Instantiate the Top-Level TPU
    // --------------------------------------------------------
    mini_tpu_top #(.N(N)) dut (
        .clk(clk),
        .rst(rst),
        .start(start),
        .a_flat(a_flat),
        .b_flat(b_flat),
        .result_flat(result_flat),
        .result_valid(result_valid),
        .done(done)
    );

    // --------------------------------------------------------
    // 3. Clock Generation
    // --------------------------------------------------------
    always #5 clk = ~clk;

    // --------------------------------------------------------
    // 4. Test Variables & 2D Arrays
    // --------------------------------------------------------
    int file_handle;
    int scan_return;
    int test_count = 0;
    int error_count = 0;
    int local_errors;

    logic [15:0] A [0:N-1][0:N-1];
    logic [15:0] B [0:N-1][0:N-1];
    logic [15:0] C_expected [0:N-1][0:N-1];
    logic [15:0] C_actual   [0:N-1][0:N-1];

    // --------------------------------------------------------
    // 5. Main Test Sequence
    // --------------------------------------------------------
    initial begin
        // Initialize everything
        clk = 0;
        rst = 0;
        start = 0;
        a_flat = '0;
        b_flat = '0;

        // Open the text file
        file_handle = $fopen("matmul_vectors.txt", "r");
        if (file_handle == 0) begin
            $display("FATAL ERROR: Could not open matmul_vectors.txt!");
            $finish;
        end

        // Assert reset to clear the chip
        #20 rst = 1;
        #10;

        $display("==================================================");
        $display("Starting Top-Level 4x4 TPU Array Verification...");
        $display("==================================================");

        // Loop through the file line by line
        while (!$feof(file_handle)) begin
            
            // 1. Read 16 values for Matrix A
            for (int r = 0; r < N; r++) 
                for (int c = 0; c < N; c++) 
                    scan_return = $fscanf(file_handle, "%h", A[r][c]);

            // 2. Read 16 values for Matrix B
            for (int r = 0; r < N; r++) 
                for (int c = 0; c < N; c++) 
                    scan_return = $fscanf(file_handle, "%h", B[r][c]);

            // 3. Read 16 values for the Expected Matrix C
            for (int r = 0; r < N; r++) 
                for (int c = 0; c < N; c++) 
                    scan_return = $fscanf(file_handle, "%h", C_expected[r][c]);

            // If we hit a blank line or EOF, break the loop safely
            if (scan_return != 1) break;

            local_errors = 0;

            // ----------------------------------------------------
            // FIRE THE CHIP!
            // ----------------------------------------------------
            @(posedge clk);
            start = 1;
            @(posedge clk);
            start = 0;

            // Wait until the controller FSM enters the LOAD state
            wait (dut.u_ctrl.state == 2'b01); 

            // Stream the matrices into the flat buses over N clock cycles
            for (int t = 0; t < N; t++) begin
                // Pack Column 't' of Matrix A
                a_flat = {A[3][t], A[2][t], A[1][t], A[0][t]};
                // Pack Row 't' of Matrix B
                b_flat = {B[t][3], B[t][2], B[t][1], B[t][0]};
                
                @(posedge clk); // Advance clock
            end

            // The LOAD phase lasts longer than N cycles to let the skew buffers drain.
            // Feed zeros for the remaining load cycles so we don't corrupt the math.
            a_flat = '0;
            b_flat = '0;

            // ----------------------------------------------------
            // WAIT FOR DRAIN AND VERIFY
            // ----------------------------------------------------
            // The FSM is now in COMPUTE. We pause the testbench until result_valid pulses HIGH
            wait (result_valid == 1'b1);

            // Unpack the massive 256-bit flat bus back into a readable 2D array
            for (int r = 0; r < N; r++) begin
                for (int c = 0; c < N; c++) begin
                    // Extract the specific 16-bit slice from the bus
                    C_actual[r][c] = result_flat[16*(r*N + c) +: 16];
                    
                    // Grade the output
                    if (C_actual[r][c] !== C_expected[r][c]) begin
                        $display("  [MISMATCH] Test %0d, Pos [%0d][%0d]: Expected %h, Got %h", 
                                 test_count, r, c, C_expected[r][c], C_actual[r][c]);
                        local_errors++;
                    end
                end
            end

            if (local_errors > 0) begin
                error_count++;
                $display("ERROR: Matrix Test %0d failed with %0d incorrect cells.", test_count, local_errors);
            end

            // Wait for the FSM to cleanly return to IDLE before starting the next matrix
            wait (done == 1'b1);
            test_count++;
        end

        $fclose(file_handle);

        $display("==================================================");
        if (error_count == 0) begin
            $display("SUCCESS: All %0d full-matrix multiplications passed!", test_count);
            $display("The Controller, Memory Interface, and Array are perfectly synchronized.");
        end else begin
            $display("FAILED: %0d out of %0d matrix tests failed.", error_count, test_count);
        end
        $display("==================================================");

        $finish;
    end

endmodule