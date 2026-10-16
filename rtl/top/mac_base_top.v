// =============================================================================
// Module: mac_base_top.v
// Reference: "A High-Performance Multiply-Accumulate Unit by Integrating
//            Additions and Accumulations Into Partial Product Reduction Process"
//            Che-Wei Tung and Shih-Hsu Huang (IEEE Access, 2020)
//
// Parameters:
//   N     = 16 (Input operand bit width)
//   ALPHA = 8  (Number of guard bits, supports 256 consecutive MAC ops)
//   K     = 16 (Higher significance bits deferred to next PPR cycle)
//
// Pipeline Architecture:
//   Stage 1: PPG, PPR reduction with deferred accumulation feedback,
//            (2N-k-1)-bit partial final addition, and alpha-bit carry count.
//   Stage 2: Gated (k + alpha)-bit final addition in terminal cycle.
// =============================================================================
`timescale 1ns / 1ps

module mac_base_top #(
    parameter N     = 16,
    parameter ALPHA = 8,
    parameter K     = 16
)(
    input  wire                 clk,
    input  wire                 rst_n,
    input  wire                 clr,        // Reset accumulation registers to start new sequence
    input  wire                 en,         // Enable compute in current cycle
    input  wire                 last_cycle, // High in the final cycle of the accumulation sequence
    input  wire                 is_signed,  // 0: Unsigned, 1: Signed (2's complement)
    input  wire [N-1:0]         in_x,
    input  wire [N-1:0]         in_y,
    output reg  [2*N+ALPHA-1:0] mac_out,
    output reg                  valid_out
);

    localparam LOWER_W  = 2 * N - K - 1;     // 15 bits
    localparam UPPER_W  = K;                 // 16 bits
    localparam STAGE2_W = 2 * N + ALPHA - LOWER_W; // 40 - 15 = 25 bits

    // -------------------------------------------------------------------------
    // Stage 1 Input Pipeline Registers
    // -------------------------------------------------------------------------
    reg [N-1:0] reg_x;
    reg [N-1:0] reg_y;
    reg         reg_is_signed;
    reg         reg_last_cycle;
    reg         reg_en;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            reg_x          <= {N{1'b0}};
            reg_y          <= {N{1'b0}};
            reg_is_signed  <= 1'b0;
            reg_last_cycle <= 1'b0;
            reg_en         <= 1'b0;
        end else if (clr) begin
            reg_x          <= {N{1'b0}};
            reg_y          <= {N{1'b0}};
            reg_is_signed  <= 1'b0;
            reg_last_cycle <= 1'b0;
            reg_en         <= 1'b0;
        end else if (en) begin
            reg_x          <= in_x;
            reg_y          <= in_y;
            reg_is_signed  <= is_signed;
            reg_last_cycle <= last_cycle;
            reg_en         <= 1'b1;
        end else begin
            reg_en         <= 1'b0;
            reg_last_cycle <= 1'b0;
        end
    end

    // -------------------------------------------------------------------------
    // Stage 1 Accumulation Feedback Registers
    // REG1_LOWER: LOWER_W bits (15 bits, resolved in Stage 1)
    // REG1_UPPER: UPPER_W bits (16 bits, deferred to Stage 2)
    // REG4:       ALPHA bits   (8 bits, overflow carry count)
    // -------------------------------------------------------------------------
    reg [LOWER_W-1:0] reg1_lower;
    reg [UPPER_W-1:0] reg1_upper;
    reg [ALPHA-1:0]   reg4;

    // Multiplier partial product for registered inputs
    wire signed [2*N-1:0] mult_product_signed;
    wire [2*N-1:0]        mult_product_unsigned;

    assign mult_product_signed   = $signed(reg_x) * $signed(reg_y);
    assign mult_product_unsigned = reg_x * reg_y;

    // Stage 1 Reduction & Accumulation
    // sum_step = mult_product + reg1_lower + (reg1_upper << 15)
    wire signed [47:0] sum_step_signed;
    wire [47:0]        sum_step_unsigned;

    assign sum_step_signed = $signed({{16{mult_product_signed[31]}}, mult_product_signed}) +
                             $signed({{33{1'b0}}, reg1_lower}) +
                             $signed({{17{1'b0}}, reg1_upper, 15'b0});

    assign sum_step_unsigned = {{16{1'b0}}, mult_product_unsigned} +
                               {{33{1'b0}}, reg1_lower} +
                               {{17{1'b0}}, reg1_upper, 15'b0};

    wire [47:0] sum_step;
    assign sum_step = reg_is_signed ? sum_step_signed : sum_step_unsigned;

    // Next feedback values
    wire [LOWER_W-1:0]      next_reg1_lower;
    wire [UPPER_W-1:0]      next_reg1_upper;
    wire signed [ALPHA-1:0] next_carry_signed;
    wire [ALPHA-1:0]        next_carry;

    assign next_reg1_lower   = sum_step[LOWER_W-1:0];
    assign next_reg1_upper   = sum_step[LOWER_W + UPPER_W - 1 : LOWER_W];
    assign next_carry_signed = sum_step_signed >>> 31;
    assign next_carry        = reg_is_signed ? next_carry_signed : sum_step[31 + ALPHA - 1 : 31];

    // Pipeline register connecting Stage 1 to Stage 2
    reg stage2_last_cycle;
    reg stage2_signed;
    reg [LOWER_W-1:0] reg1_lower_pipe;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            reg1_lower        <= {LOWER_W{1'b0}};
            reg1_upper        <= {UPPER_W{1'b0}};
            reg4              <= {ALPHA{1'b0}};
            stage2_last_cycle <= 1'b0;
            stage2_signed     <= 1'b0;
            reg1_lower_pipe   <= {LOWER_W{1'b0}};
        end else if (clr) begin
            reg1_lower        <= {LOWER_W{1'b0}};
            reg1_upper        <= {UPPER_W{1'b0}};
            reg4              <= {ALPHA{1'b0}};
            stage2_last_cycle <= 1'b0;
            stage2_signed     <= 1'b0;
            reg1_lower_pipe   <= {LOWER_W{1'b0}};
        end else if (reg_en) begin
            reg1_lower        <= next_reg1_lower;
            reg1_upper        <= next_reg1_upper;
            reg4              <= reg4 + next_carry;
            stage2_last_cycle <= reg_last_cycle;
            stage2_signed     <= reg_is_signed;
            reg1_lower_pipe   <= next_reg1_lower;
        end else begin
            stage2_last_cycle <= 1'b0;
        end
    end

    // -------------------------------------------------------------------------
    // Stage 2: Final Addition (Enabled only on the last cycle of MAC sequence)
    // -------------------------------------------------------------------------
    wire [STAGE2_W-1:0] stage2_op_a;
    wire [STAGE2_W-1:0] stage2_op_b;
    wire [STAGE2_W-1:0] stage2_sum;
    wire                stage2_cout;

    assign stage2_op_a = { {(STAGE2_W - UPPER_W){1'b0}}, reg1_upper };
    assign stage2_op_b = { {(STAGE2_W - UPPER_W - ALPHA){stage2_signed & reg4[ALPHA-1]}}, reg4, {UPPER_W{1'b0}} };

    han_carlson_adder #(
        .WIDTH(STAGE2_W)
    ) u_stage2_adder (
        .a(stage2_op_a),
        .b(stage2_op_b),
        .cin(1'b0),
        .sum(stage2_sum),
        .cout(stage2_cout)
    );

    // Final result output register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mac_out   <= {(2*N+ALPHA){1'b0}};
            valid_out <= 1'b0;
        end else if (clr) begin
            mac_out   <= {(2*N+ALPHA){1'b0}};
            valid_out <= 1'b0;
        end else if (stage2_last_cycle) begin
            mac_out   <= {stage2_sum, reg1_lower_pipe};
            valid_out <= 1'b1;
        end else begin
            valid_out <= 1'b0;
        end
    end

endmodule
