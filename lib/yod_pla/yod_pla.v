// Yo dawg, I heard you like programmable logic so I put programmable logic inside your programmable logic.

/* 

This is a DIY Programmable Logic Array (PLA) module.  The design uses
the traditional AND array matrix fed into a OR array matrix.

There are 'TERMS' AND blocks which each take as input

	- the PINS many GPIO as input (and their inverse) (this means outputs can be used as inputs)
	- the combinatorial output of this AND block (and it's inverse)
	- the registered output of this AND block (and it's inverse).

The 2*(PINS+2) terms are selectively AND'ed together (based on the and_fuses[])
to form one of the TERMS outputs.  The output of each AND block that is fed into
the OR matrix is selectable from the AND combinatorial or registered output.

There are 'PINS' OR blocks which each take as input

	- The 'TERMS' many AND output
	- A polarity 'invert' fuse

The output is then the selective OR of the AND outputs, inverted optionally
by the invert fuse, and then registered.  The output is then selectable
from the combinatorial or registered OR output.

Total bits is 2 * PINS + PINS * TERMS + (1 + 2 * (PINS + 3)) * TERMS

PINS	TERMS	Fuse bits	DFFs
8	16	480	24
8	24	712	32
8	32	944	40
8	48	1408	56
8	64	1872	72
12	24	1008	36
12	48	1992	60
12	96	3960	108
16	32	1728	48
16	48	2576	64
16	64	3424	80
16	80	4272	96
16	96	5120	112
16	128	6816	144
32	256	25920	288

*/

`timescale 1ns/1ps
module pla #(
    parameter PINS = 8,								// how many in/out signals
    parameter TERMS = 16							// the # of AND blocks
)(
    input clk,										// this is the PLA clock which should be attached to a GB/GCLK pin
    input rst_n,									// active low global reset for the DFFs

	// input/output signals
    input [PINS-1:0] 			  in_sig,			// The input signals to this tile
    output [PINS-1:0]			  out_sig,			// The output signals from this tile

	// fuses
	input [(2*PINS + PINS*TERMS + (1 + (2 * (PINS + PINS + 3))) * TERMS)-1:0]		  fuses				// the fuses controlling this PLA block
);

	// breakout of the fuses
    localparam W_WIDTH 			   = 2 * (PINS + PINS + 3); 							// width of the AND block input (determines how many fuses are needed per AND)
	localparam TOTAL_FUSES		   = 2 * PINS + PINS * TERMS + (1 + W_WIDTH) * TERMS;
    localparam OFFSET_AND_FUSES    = 0;											// there are TERMS * W_WIDTH [aka (2 * (PINS+2))] fuse bits for AND_FUSES
    localparam OFFSET_AND_OUTSEL   = OFFSET_AND_FUSES    + (TERMS * W_WIDTH);	// there are TERMS fuse bits for AND_OUTSEL
    localparam OFFSET_OR_FUSES     = OFFSET_AND_OUTSEL   + TERMS;				// there are PINS * TERMS fuse bits for OR_FUSES
    localparam OFFSET_OR_OUTSEL    = OFFSET_OR_FUSES     + (PINS * TERMS);		// there are PINS fuse bits for OR_OUTSEL
    localparam OFFSET_OR_INVERT    = OFFSET_OR_OUTSEL    + PINS;				// there are PINS fuse bits for OR_INVERT

// BITS = TERMS * (4 * PINS + 2*3) + TERMS + PINS*TERMS + 2*PINS
// BITS = TERMS * (4 * PINS + 6 + 1 + PINS) + 2*PINS
// BITS = TERMS * (5 * PINS + 7) + 2*PINS
    
    // --- Internal Fuse Mapping ---
    wire [(TERMS * W_WIDTH)-1:0] and_fuses        = fuses[OFFSET_AND_FUSES  +: (TERMS * W_WIDTH)];
    wire [TERMS-1:0]             and_outsel_fuses = fuses[OFFSET_AND_OUTSEL +: TERMS];
    wire [(PINS * TERMS)-1:0]    or_fuses         = fuses[OFFSET_OR_FUSES   +: (PINS * TERMS)];
    wire [PINS-1:0]              or_outsel_fuses  = fuses[OFFSET_OR_OUTSEL  +: PINS];
    wire [PINS-1:0]              or_invert_fuses  = fuses[OFFSET_OR_INVERT  +: PINS];	

	// we're intentionally feeding back on ourselves...
	/* verilator lint_off UNOPTFLAT */
    wire [TERMS-1:0] and_comb;
    reg  [TERMS-1:0] and_reg;
    wire [TERMS-1:0] and_output;
    wire [PINS-1:0]  or_sum;
    reg  [PINS-1:0]  or_reg;

    // --- The Programmable AND Plane ---
    genvar i, j;
    generate
        for (i = 0; i < TERMS; i = i + 1) begin : and_block
            wire [W_WIDTH-1:0] local_matrix;
            
			for (j = 0; j < PINS; j = j + 1) begin
				assign local_matrix[j+j+0] = in_sig[j];
				assign local_matrix[j+j+1] = ~in_sig[j];
			end
            
			for (j = 0; j < PINS; j = j + 1) begin
				assign local_matrix[2*PINS+j+j+0] = or_reg[j];
				assign local_matrix[2*PINS+j+j+1] = ~or_reg[j];
			end

            // Next wires: Local Combinatorial Feedback
            assign local_matrix[4*PINS +: 2] = {and_comb[i], ~and_comb[i]};
            
            // Next wires: Local Registered Feedback
            assign local_matrix[4*PINS + 2 +: 2] = {and_reg[i], ~and_reg[i]};

            // Next wires: carry bit 
            if (i > 0)
				assign local_matrix[4*PINS + 4 +: 2] = {and_reg[i-1], ~and_reg[i-1]};
			else if (i == 0)
				assign local_matrix[4*PINS + 4 +: 2] = {and_reg[TERMS-1], ~and_reg[TERMS-1]};
			
            // The AND Gate
            assign and_comb[i] = &(local_matrix | and_fuses[i*W_WIDTH +: W_WIDTH]);
            
            // the output
            assign and_output[i] = (and_outsel_fuses[i] ? and_reg[i] : and_comb[i]);

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
            // Each pin can OR-sum any of the and_output[] outputs
            assign or_sum[i] = |(and_output & or_fuses[i*TERMS +: TERMS]) ^ or_invert_fuses[i];
            
            // The DFF
            always @(posedge clk or negedge rst_n) begin
				if (!rst_n) begin
					or_reg[i] <= 1'b0;
				end else begin
					or_reg[i] <= or_sum[i];
				end
			end

            // output selector between combinatorial and registered
            assign out_sig[i] = or_outsel_fuses[i] ? or_reg[i] : or_sum[i];
        end
    endgenerate
endmodule
