// =============================================================================
// Module: booth_radix4_selector.v
// Description: Generates a partial product row of specified width from
//              multiplicand X and Radix-4 Booth control signals.
//              Handles bit negation for two's complement (-X or -2X).
// =============================================================================
`timescale 1ns / 1ps

module booth_radix4_selector #(
    parameter WIDTH = 16
)(
    input  wire [WIDTH-1:0] x,
    input  wire             x_sign, // Sign bit of X for sign extension
    input  wire             one,
    input  wire             two,
    input  wire             neg,
    input  wire             zero,
    output wire [WIDTH:0]   pp_out, // Extended by 1 bit to accommodate 2X shift
    output wire             pp_cin  // Carry-in (+1) to LSB position for two's complement negation
);

    genvar j;
    generate
        for (j = 0; j <= WIDTH; j = j + 1) begin : gen_pp_bits
            wire bit_curr;
            wire bit_prev;
            wire bit_selected;

            assign bit_curr = (j < WIDTH) ? x[j] : x_sign;
            assign bit_prev = (j == 0) ? 1'b0 : ((j - 1 < WIDTH) ? x[j-1] : x_sign);

            assign bit_selected = (one & bit_curr) | (two & bit_prev);
            // If zero is active, output is 0 (or 0^neg = neg when inverted)
            assign pp_out[j] = zero ? neg : (bit_selected ^ neg);
        end
    endgenerate

    // If negative, add 1 at the LSB of this partial product row
    assign pp_cin = neg;

endmodule
