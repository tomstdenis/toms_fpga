// Yo dawg, I heard you like programmable logic so I put programmable logic inside your programmable logic.

/* Total bits is 3 * PINS + PINS * TERMS + 2 * (PINS + 2) * TERMS 

PINS		TERMS		Fuse bits		DFFs
8			16			464				16
8			24			696				32
8			32			920				40
8			48			1368			56
8			64			1816			72
12			24			996				36
12			48			1956			60
12			96			3876			108
16			32			1712			48
16			48			2544			64
16			64			3376			80
16			80			4208			96
16			96			5040			112
16			128			6704			144
*/

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
    input [PINS-1:0]			  or_reg_fuses,		// whether the output is (1) registered or (0) combinatorial
    input [PINS-1:0]              or_invert_fuses,	// inverted output fuse (1 per OR gate)
    input [PINS-1:0]              tri_fuses			// tri-state fuses (1 == output, 0 == input) (1 per OR gate)
);
	// we're intentionally feeding back on ourselves...
	/* verilator lint_off UNOPTFLAT */
    wire [TERMS-1:0] and_comb;
    reg  [TERMS-1:0] and_reg;
    reg  [PINS-1:0] or_reg;

    // --- The Programmable AND Plane ---
    genvar i, j;
    generate
        for (i = 0; i < TERMS; i = i + 1) begin : and_block
            wire [W_WIDTH-1:0] local_matrix;
            
			for (j = 0; j < PINS; j++) begin
				assign local_matrix[j+j+0] = gpio[j];
				assign local_matrix[j+j+1] = ~gpio[j];
			end
            
            // Wires 16-17: Local Combinatorial Feedback
            assign local_matrix[PINS * 2 +: 2] = {~and_comb[i], and_comb[i]};
            
            // Wires 18-19: Local Registered Feedback
            assign local_matrix[PINS * 2 + 2 +: 2] = {~and_reg[i], and_reg[i]};

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
        end
    endgenerate

    // --- The Programmable OR Plane ---
    generate
        for (i = 0; i < PINS; i = i + 1) begin : or_plane
            // Each pin can OR-sum any of the 16 REGISTERED outputs
            wire or_sum = |(and_reg & ~or_fuses[i*TERMS +: TERMS]) ^ or_invert_fuses[i];
            
            // The DFF
            always @(posedge clk or negedge rst_n) begin
				if (!rst_n) begin
					or_reg[i] <= 1'b0;
				end else begin
					or_reg[i] <= or_sum;
				end
			end

            // Tri-state and Polarity
            assign gpio[i] = tri_fuses[i] ? (or_reg_fuses[i] ? or_reg[i] : or_sum) : 1'bz;
        end
    endgenerate
endmodule
