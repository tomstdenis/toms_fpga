// Yo dawg, I heard you like programmable logic so I put programmable logic inside your programmable logic.
`timescale 1ns/1ps
module pla #(
    parameter PINS = 8,								// how many in/out signals
    parameter TERMS = 16,							// the # of AND blocks
    localparam W_WIDTH = 2 * (PINS + 2) 			// width of the AND block input (determines how many fuses are needed per AND)
)(
    input clk,										// this is the PLA clock which should be attached to a GBPIN
    input rst_n,									// active low global reset for the DFFs
    inout [PINS-1:0] gpio,							// the GPIO pins which are tri-state
    input [(TERMS * W_WIDTH)-1:0] and_fuses,		// the AND fuses, each AND gate uses W_WIDTH bits from here
    input [(PINS * TERMS)-1:0]    or_fuses,			// the OR fuses, each OR gate uses TERMS bits from here
    input [PINS-1:0]              tri_fuses,		// tri-state fuses (1 == output, 0 == input) (1 per OR gate)
    input [PINS-1:0]              poly_fuses		// inverted output fuse (1 per OR gate)
);

    wire [TERMS-1:0] and_comb;
    reg  [TERMS-1:0] and_reg;

    // --- The Programmable AND Plane ---
    genvar i;
    generate
        for (i = 0; i < TERMS; i = i + 1) begin : and_block
            wire [W_WIDTH-1:0] local_matrix;
            
            // Wires 0-15: The 8 GPIOs (Dual-Rail)
            assign local_matrix[15:0] = {~gpio[7], gpio[7], ~gpio[6], gpio[6], 
                                         ~gpio[5], gpio[5], ~gpio[4], gpio[4],
                                         ~gpio[3], gpio[3], ~gpio[2], gpio[2],
                                         ~gpio[1], gpio[1], ~gpio[0], gpio[0]};
            
            // Wires 16-17: Local Combinatorial Feedback
            assign local_matrix[17:16] = {~and_comb[i], and_comb[i]};
            
            // Wires 18-19: Local Registered Feedback
            assign local_matrix[19:18] = {~and_reg[i], and_reg[i]};

            // The AND Gate
            assign and_comb[i] = &(local_matrix | and_fuses[i*W_WIDTH +: W_WIDTH]);
            
            // The DFF
            always @(posedge clk or negedge rst_n) begin
				if (!rst_n) begin
					and_reg[i] <= 1'b0;
				end else begin
					and_reg[i] <= and_comb[i];
				end
        end
    endgenerate

    // --- The Programmable OR Plane ---
    generate
        for (i = 0; i < PINS; i = i + 1) begin : or_plane
            // Each pin can OR-sum any of the 16 REGISTERED outputs
            wire or_sum = |(and_reg & ~or_fuses[i*TERMS +: TERMS]);
            
            // Tri-state and Polarity
            assign gpio[i] = tri_fuses[i] ? (or_sum ^ poly_fuses[i]) : 1'bz;
        end
    endgenerate
endmodule
