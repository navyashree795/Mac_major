// =============================================================================
// Module: booth_radix4_encoder.v
// Description: Radix-4 Modified Booth Encoder.
//              Recodes overlapping 3-bit slices of multiplier: {y_msb, y_mid, y_lsb}
//              Generates control signals:
//              - one  : magnitude is 1 (|d| = 1)
//              - two  : magnitude is 2 (|d| = 2)
//              - neg  : negative sign (d < 0)
//              - zero : magnitude is 0 (d = 0)
// =============================================================================
`timescale 1ns / 1ps

module booth_radix4_encoder (
    input  wire y_msb,
    input  wire y_mid,
    input  wire y_lsb,
    output wire one,
    output wire two,
    output wire neg,
    output wire zero
);

    assign one  = y_mid ^ y_lsb;
    assign two  = (~y_msb & y_mid & y_lsb) | (y_msb & ~y_mid & ~y_lsb);
    assign neg  = y_msb & ~(y_mid & y_lsb);
    assign zero = (y_msb == y_mid) && (y_mid == y_lsb);

endmodule
