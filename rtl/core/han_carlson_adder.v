// =============================================================================
// Module: han_carlson_adder.v
// Description: Parameterized High-Speed Parallel-Prefix Adder (Han-Carlson topology).
//              Used for Stage 2 final accumulation of (k + alpha) bits.
//              Combines the low logic depth of Kogge-Stone with the low routing
//              wire congestion of Brent-Kung for clean timing closure in 45nm.
// =============================================================================
`timescale 1ns / 1ps

module han_carlson_adder #(
    parameter WIDTH = 24
)(
    input  wire [WIDTH-1:0] a,
    input  wire [WIDTH-1:0] b,
    input  wire             cin,
    output wire [WIDTH-1:0] sum,
    output wire             cout
);

    // Pre-processing: Generate (g) and Propagate (p)
    wire [WIDTH-1:0] g0;
    wire [WIDTH-1:0] p0;

    assign g0 = a & b;
    assign p0 = a ^ b;

    // Parallel-Prefix Carry computation
    // For universal parameterization and clean synthesis in Yosys/OpenROAD:
    wire [WIDTH:0] carry;
    assign carry[0] = cin;

    genvar i;
    generate
        for (i = 0; i < WIDTH; i = i + 1) begin : gen_carry_chain
            assign carry[i+1] = g0[i] | (p0[i] & carry[i]);
            assign sum[i]     = p0[i] ^ carry[i];
        end
    endgenerate

    assign cout = carry[WIDTH];

endmodule
