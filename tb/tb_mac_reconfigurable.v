// =============================================================================
// Testbench: tb_mac_reconfigurable.v
// Description: Automated self-checking testbench for the Reconfigurable Dual-Mode
//              MAC unit. Verifies both 16-bit Mode and Dual 8-bit SIMD Mode.
// =============================================================================
`timescale 1ns / 1ps

module tb_mac_reconfigurable;

    parameter N     = 16;
    parameter ALPHA = 8;
    parameter K     = 16;

    reg                 clk;
    reg                 rst_n;
    reg                 clr;
    reg                 en;
    reg                 mode_16b;
    reg                 last_cycle;
    reg                 is_signed;
    reg  [N-1:0]         in_x;
    reg  [N-1:0]         in_y;
    wire [2*N+ALPHA-1:0] mac_out_16b;
    wire [19:0]          mac_out_8b_hi;
    wire [19:0]          mac_out_8b_lo;
    wire                 valid_out;

    integer errors = 0;
    integer tests_passed = 0;

    // Instantiate Reconfigurable MAC Unit
    mac_reconfigurable_top #(
        .N(N),
        .ALPHA(ALPHA),
        .K(K)
    ) uut (
        .clk(clk),
        .rst_n(rst_n),
        .clr(clr),
        .en(en),
        .mode_16b(mode_16b),
        .last_cycle(last_cycle),
        .is_signed(is_signed),
        .in_x(in_x),
        .in_y(in_y),
        .mac_out_16b(mac_out_16b),
        .mac_out_8b_hi(mac_out_8b_hi),
        .mac_out_8b_lo(mac_out_8b_lo),
        .valid_out(valid_out)
    );

    // 1 GHz Clock generation (period = 1.0 ns)
    always #0.5 clk = ~clk;

    // Golden models
    reg [2*N+ALPHA-1:0] expected_16b;
    reg [19:0]          expected_8b_hi;
    reg [19:0]          expected_8b_lo;

    task reset_dut;
        begin
            rst_n          = 0;
            clr            = 1;
            en             = 0;
            mode_16b       = 1;
            last_cycle     = 0;
            is_signed      = 0;
            in_x           = 0;
            in_y           = 0;
            expected_16b   = 0;
            expected_8b_hi = 0;
            expected_8b_lo = 0;
            #2;
            rst_n          = 1;
            clr            = 0;
            #1;
        end
    endtask

    // Task to test 16-bit MAC mode
    task test_16b_sequence(input integer count, input bit signed_mode);
        integer i;
        reg [N-1:0] rand_x, rand_y;
        reg [2*N-1:0] prod;
        begin
            clr = 1;
            expected_16b = 0;
            @(posedge clk);
            clr = 0;

            for (i = 0; i < count; i = i + 1) begin
                rand_x = $random;
                rand_y = $random;

                in_x       = rand_x;
                in_y       = rand_y;
                mode_16b   = 1;
                is_signed  = signed_mode;
                en         = 1;
                last_cycle = (i == count - 1) ? 1'b1 : 1'b0;

                if (signed_mode) begin
                    prod = $signed({{N{rand_x[N-1]}}, rand_x}) * $signed({{N{rand_y[N-1]}}, rand_y});
                    expected_16b = expected_16b + {{ALPHA{prod[2*N-1]}}, prod};
                end else begin
                    prod = rand_x * rand_y;
                    expected_16b = expected_16b + {{ALPHA{1'b0}}, prod};
                end

                @(posedge clk);
            end

            en = 0;
            last_cycle = 0;
            while (!valid_out) @(posedge clk);

            if (mac_out_16b !== expected_16b) begin
                $display("[ERROR 16B] Mismatch! Count=%0d, Signed=%0b | Exp: 0x%010h, Got: 0x%010h",
                         count, signed_mode, expected_16b, mac_out_16b);
                errors = errors + 1;
            end else begin
                $display("[PASS 16B] Count=%0d, Signed=%0b | 16-bit Result: 0x%010h Matches Expected!",
                         count, signed_mode, mac_out_16b);
                tests_passed = tests_passed + 1;
            end
        end
    endtask

    // Task to test Dual 8-bit SIMD MAC mode (2x throughput)
    task test_dual_8b_sequence(input integer count, input bit signed_mode);
        integer i;
        reg [7:0] rx_hi, ry_hi, rx_lo, ry_lo;
        reg [15:0] prod_hi, prod_lo;
        begin
            clr = 1;
            expected_8b_hi = 0;
            expected_8b_lo = 0;
            @(posedge clk);
            clr = 0;

            for (i = 0; i < count; i = i + 1) begin
                rx_hi = $random;
                ry_hi = $random;
                rx_lo = $random;
                ry_lo = $random;

                in_x       = {rx_hi, rx_lo};
                in_y       = {ry_hi, ry_lo};
                mode_16b   = 0; // Dual 8-bit SIMD mode
                is_signed  = signed_mode;
                en         = 1;
                last_cycle = (i == count - 1) ? 1'b1 : 1'b0;

                if (signed_mode) begin
                    prod_hi = $signed({{8{rx_hi[7]}}, rx_hi}) * $signed({{8{ry_hi[7]}}, ry_hi});
                    prod_lo = $signed({{8{rx_lo[7]}}, rx_lo}) * $signed({{8{ry_lo[7]}}, ry_lo});
                    expected_8b_hi = expected_8b_hi + {{4{prod_hi[15]}}, prod_hi};
                    expected_8b_lo = expected_8b_lo + {{4{prod_lo[15]}}, prod_lo};
                end else begin
                    prod_hi = rx_hi * ry_hi;
                    prod_lo = rx_lo * ry_lo;
                    expected_8b_hi = expected_8b_hi + {{4{1'b0}}, prod_hi};
                    expected_8b_lo = expected_8b_lo + {{4{1'b0}}, prod_lo};
                end

                @(posedge clk);
            end

            en = 0;
            last_cycle = 0;
            while (!valid_out) @(posedge clk);

            if ((mac_out_8b_hi !== expected_8b_hi) || (mac_out_8b_lo !== expected_8b_lo)) begin
                $display("[ERROR Dual-8B] Mismatch! Count=%0d | HiExp: 0x%05h, HiGot: 0x%05h | LoExp: 0x%05h, LoGot: 0x%05h",
                         count, expected_8b_hi, mac_out_8b_hi, expected_8b_lo, mac_out_8b_lo);
                errors = errors + 1;
            end else begin
                $display("[PASS Dual-8B] Count=%0d | Hi: 0x%05h, Lo: 0x%05h (2 Operations per Cycle Verified!)",
                         count, mac_out_8b_hi, mac_out_8b_lo);
                tests_passed = tests_passed + 1;
            end
        end
    endtask

    initial begin
        $dumpfile("mac_reconfigurable_tb.vcd");
        $dumpvars(0, tb_mac_reconfigurable);

        clk = 0;
        reset_dut();

        $display("==========================================================");
        $display("   STARTING VERIFICATION FOR RECONFIGURABLE DUAL-MODE MAC ");
        $display("==========================================================");

        // Section A: 16-bit High-Precision Mode Tests
        $display("\n--- Testing 16-bit Standard Mode ---");
        test_16b_sequence(1, 0);
        test_16b_sequence(1, 1);
        test_16b_sequence(4, 0);
        test_16b_sequence(4, 1);
        test_16b_sequence(16, 0);
        test_16b_sequence(16, 1);

        // Section B: Dual 8-bit SIMD Mode Tests (2x Throughput)
        $display("\n--- Testing Dual 8-bit SIMD Mode (2x Throughput) ---");
        test_dual_8b_sequence(1, 0);
        test_dual_8b_sequence(1, 1);
        test_dual_8b_sequence(4, 0);
        test_dual_8b_sequence(4, 1);
        test_dual_8b_sequence(16, 0);
        test_dual_8b_sequence(16, 1);
        test_dual_8b_sequence(32, 0);

        $display("\n==========================================================");
        if (errors == 0) begin
            $display("   ALL %0d RECONFIGURABLE DUAL-MODE TESTS PASSED!        ", tests_passed);
            $display("   2x THROUGHPUT ACCELERATION FULLY VERIFIED!             ");
        end else begin
            $display("   VERIFICATION FAILED WITH %0d ERRORS!                   ", errors);
        end
        $display("==========================================================");

        #10;
        $finish;
    end

endmodule
