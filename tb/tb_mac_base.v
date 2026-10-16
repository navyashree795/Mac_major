// =============================================================================
// Testbench: tb_mac_base.v
// Description: Automated self-checking testbench for the Base MAC top module.
//              Verifies both Unsigned and Signed operations, multi-cycle
//              sequences, and overflow carry counter handling.
// =============================================================================
`timescale 1ns / 1ps

module tb_mac_base;

    parameter N     = 16;
    parameter ALPHA = 8;
    parameter K     = 16;

    reg                 clk;
    reg                 rst_n;
    reg                 clr;
    reg                 en;
    reg                 last_cycle;
    reg                 is_signed;
    reg  [N-1:0]         in_x;
    reg  [N-1:0]         in_y;
    wire [2*N+ALPHA-1:0] mac_out;
    wire                 valid_out;

    integer errors = 0;
    integer tests_passed = 0;

    // Instantiate Base MAC Unit
    mac_base_top #(
        .N(N),
        .ALPHA(ALPHA),
        .K(K)
    ) uut (
        .clk(clk),
        .rst_n(rst_n),
        .clr(clr),
        .en(en),
        .last_cycle(last_cycle),
        .is_signed(is_signed),
        .in_x(in_x),
        .in_y(in_y),
        .mac_out(mac_out),
        .valid_out(valid_out)
    );

    // 1 GHz Clock generation (period = 1.0 ns)
    always #0.5 clk = ~clk;

    // Golden software accumulator
    reg [2*N+ALPHA-1:0] expected_acc;

    task reset_dut;
        begin
            rst_n      = 0;
            clr        = 1;
            en         = 0;
            last_cycle = 0;
            is_signed  = 0;
            in_x       = 0;
            in_y       = 0;
            expected_acc = 0;
            #2;
            rst_n      = 1;
            clr        = 0;
            #1;
        end
    endtask

    // Perform a multi-cycle MAC test sequence
    task run_mac_sequence(input integer count, input bit signed_mode);
        integer i;
        reg [N-1:0] rand_x, rand_y;
        reg [2*N-1:0] prod;
        begin
            clr = 1;
            expected_acc = 0;
            @(posedge clk);
            clr = 0;

            for (i = 0; i < count; i = i + 1) begin
                rand_x = $random;
                rand_y = $random;

                in_x       = rand_x;
                in_y       = rand_y;
                is_signed  = signed_mode;
                en         = 1;
                last_cycle = (i == count - 1) ? 1'b1 : 1'b0;

                // Compute expected software result
                if (signed_mode) begin
                    prod = $signed({{N{rand_x[N-1]}}, rand_x}) * $signed({{N{rand_y[N-1]}}, rand_y});
                    expected_acc = expected_acc + {{ALPHA{prod[2*N-1]}}, prod};
                end else begin
                    prod = rand_x * rand_y;
                    expected_acc = expected_acc + {{ALPHA{1'b0}}, prod};
                end

                @(posedge clk);
            end

            en = 0;
            last_cycle = 0;

            // Wait for Stage 2 pipeline latency (valid_out)
            while (!valid_out) @(posedge clk);

            // Compare result
            if (mac_out !== expected_acc) begin
                $display("[ERROR] Mismatch! Count=%0d, Signed=%0b | Expected: 0x%010h, Got: 0x%010h",
                         count, signed_mode, expected_acc, mac_out);
                errors = errors + 1;
            end else begin
                $display("[PASS] Count=%0d, Signed=%0b | Result: 0x%010h Matches Expected!",
                         count, signed_mode, mac_out);
                tests_passed = tests_passed + 1;
            end
        end
    endtask

    initial begin
        $dumpfile("mac_base_tb.vcd");
        $dumpvars(0, tb_mac_base);

        clk = 0;
        reset_dut();

        $display("==========================================================");
        $display("   STARTING AUTOMATED VERIFICATION FOR BASE 16-BIT MAC    ");
        $display("==========================================================");

        // Test 1: Single cycle unsigned
        run_mac_sequence(1, 0);

        // Test 2: Single cycle signed
        run_mac_sequence(1, 1);

        // Test 3: 4-cycle sequence unsigned
        run_mac_sequence(4, 0);

        // Test 4: 4-cycle sequence signed
        run_mac_sequence(4, 1);

        // Test 5: 16-cycle sequence unsigned
        run_mac_sequence(16, 0);

        // Test 6: 16-cycle sequence signed
        run_mac_sequence(16, 1);

        // Test 7: 64-cycle sequence stress test
        run_mac_sequence(64, 0);

        $display("==========================================================");
        if (errors == 0) begin
            $display("   ALL %0d BASE MAC TESTS PASSED SUCCESSFULLY!            ", tests_passed);
        end else begin
            $display("   VERIFICATION FAILED WITH %0d ERRORS!                   ", errors);
        end
        $display("==========================================================");

        #10;
        $finish;
    end

endmodule
