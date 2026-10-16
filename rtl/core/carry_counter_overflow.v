// =============================================================================
// Module: carry_counter_overflow.v
// Description: Accumulates overflow carry bits from the highest column (2N-1).
//              Includes the translation circuit for both Unsigned and Signed
//              (Baugh-Wooley compensated) arithmetic as specified in the base paper.
// =============================================================================
`timescale 1ns / 1ps

module carry_counter_overflow #(
    parameter ALPHA = 8
)(
    input  wire             clk,
    input  wire             rst_n,
    input  wire             clr,        // Synchronous clear between MAC sequences
    input  wire             en,         // Accumulation enable for current cycle
    input  wire             is_signed,  // 0: Unsigned mode, 1: Signed mode
    input  wire             car0,       // Overflow bit 0 from column 2N-1
    input  wire             car1,       // Overflow bit 1 from column 2N-1
    output reg  [ALPHA-1:0] reg4        // Accumulated carry count
);

    wire [ALPHA-1:0] trans_val;

    // Translation Circuit:
    // Unsigned: val = car0 + car1
    // Signed  : val = car0 + car1 - 1
    assign trans_val = (~is_signed) ? (
        (car0 & car1) ? {{ALPHA-2{1'b0}}, 2'b10} :
        (car0 ^ car1) ? {{ALPHA-1{1'b0}}, 1'b1}  :
                        {ALPHA{1'b0}}
    ) : (
        (car0 & car1) ? {{ALPHA-1{1'b0}}, 1'b1}  : // (1 + 1 - 1) = +1
        (car0 ^ car1) ? {ALPHA{1'b0}}             : // (1 + 0 - 1) =  0
                        {ALPHA{1'b1}}               // (0 + 0 - 1) = -1 (all 1s in two's complement)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            reg4 <= {ALPHA{1'b0}};
        end else if (clr) begin
            reg4 <= {ALPHA{1'b0}};
        end else if (en) begin
            reg4 <= reg4 + trans_val;
        end
    end

endmodule
