// =============================================================================
// Module: full_adder.v
// Description: Standard 1-bit Full Adder with low-power gate-level implementation.
// =============================================================================
`timescale 1ns / 1ps

module full_adder (
    input  wire a,
    input  wire b,
    input  wire cin,
    output wire sum,
    output wire cout
);

    wire axorb;

    assign axorb = a ^ b;
    assign sum   = axorb ^ cin;
    assign cout  = (axorb & cin) | (a & b);

endmodule
