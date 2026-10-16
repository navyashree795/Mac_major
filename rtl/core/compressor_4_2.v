// =============================================================================
// Module: compressor_4_2.v
// Description: Symmetrical 4:2 Compressor with independent horizontal carry (cout).
//              Compresses 4 bits of weight 2^i and cin (weight 2^i) into:
//              - sum   (weight 2^i)
//              - carry (weight 2^(i+1))
//              - cout  (weight 2^(i+1), sent horizontally to column i+1)
//
// Delay: 3 XOR gate delays, completely independent of word length.
// =============================================================================
`timescale 1ns / 1ps

module compressor_4_2 (
    input  wire x1,
    input  wire x2,
    input  wire x3,
    input  wire x4,
    input  wire cin,
    output wire sum,
    output wire carry,
    output wire cout
);

    wire xor12;
    wire xor34;
    wire xor_all;

    assign xor12   = x1 ^ x2;
    assign xor34   = x3 ^ x4;
    assign xor_all = xor12 ^ xor34;

    // cout does not depend on cin (eliminates horizontal ripple delay)
    assign cout    = xor12 ? x3 : x1;

    assign sum     = xor_all ^ cin;
    assign carry   = xor_all ? cin : x4;

endmodule
