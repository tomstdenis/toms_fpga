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
by the invert fuse, and then registered.  The GPIO output is then selectable
from the combinatorial or registered OR output (if the output enable is enabled).

Total bits is 3 * PINS + PINS * TERMS + (1 + 2 * (PINS + 2)) * TERMS

PINS TERMS Fuse bits DFFs
8	16	488	24
8	24	720	32
8	32	952	40
8	48	1416	56
8	64	1880	72
12	24	1020	36
12	48	2004	60
12	96	3972	108
16	32	1744	48
16	48	2592	64
16	64	3440	80
16	80	4288	96
16	96	5136	112
16	128	6832	144

*/

`timescale 1ns/1ps
module pla #(
    parameter PINS = 8,								// how many in/out signals
    parameter TERMS = 16,							// the # of AND blocks
    localparam W_WIDTH = 2 * (PINS + 2) 			// width of the AND block input (determines how many fuses are needed per AND)
)(
    input clk,										// this is the PLA clock which should be attached to a GBPIN
    input rst_n,									// active low global reset for the DFFs

	// GPIO pins and tri-state control (determines if a pin is output or input)
    inout [PINS-1:0] 			  gpio,				// the GPIO pins which are tri-state
    input [PINS-1:0]              gpio_oe,			// tri-state fuses (1 == output, 0 == input) (1 per OR gate)

	// AND TERMS these selectably AND together inputs/feedback (and their inverted senses) to form an output
    input [(TERMS * W_WIDTH)-1:0] and_fuses,		// the AND fuses, each AND gate uses W_WIDTH bits from here
    input [TERMS-1:0]			  and_outsel_fuses,	// select (1) use and_reg or (0) use and_comb as the AND output to the OR fabric

	// OR PINS these selectably OR the AND outputs together to form GPIO outputs
    input [(PINS * TERMS)-1:0]    or_fuses,			// the OR fuses, each OR gate uses TERMS bits from here
    input [PINS-1:0]			  or_outsel_fuses,	// whether the output is (1) registered or (0) combinatorial
    input [PINS-1:0]              or_invert_fuses	// inverted output fuse (1 per OR gate)
);
	// we're intentionally feeding back on ourselves...
	/* verilator lint_off UNOPTFLAT */
    wire [TERMS-1:0] and_comb;
    reg  [TERMS-1:0] and_reg;
    wire [TERMS-1:0] and_output;
    reg  [PINS-1:0] or_reg;

    // --- The Programmable AND Plane ---
    genvar i, j;
    generate
        for (i = 0; i < TERMS; i = i + 1) begin : and_block
            wire [W_WIDTH-1:0] local_matrix;
            
			for (j = 0; j < PINS; j = j + 1) begin
				assign local_matrix[j+j+0] = gpio[j];
				assign local_matrix[j+j+1] = ~gpio[j];
			end
            
            // Wires 16-17: Local Combinatorial Feedback
            assign local_matrix[PINS * 2 +: 2] = {~and_comb[i], and_comb[i]};
            
            // Wires 18-19: Local Registered Feedback
            assign local_matrix[PINS * 2 + 2 +: 2] = {~and_reg[i], and_reg[i]};

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
            wire or_sum = |(and_output & ~or_fuses[i*TERMS +: TERMS]) ^ or_invert_fuses[i];
            
            // The DFF
            always @(posedge clk or negedge rst_n) begin
				if (!rst_n) begin
					or_reg[i] <= 1'b0;
				end else begin
					or_reg[i] <= or_sum;
				end
			end

            // Tri-state and Polarity
            assign gpio[i] = gpio_oe[i] ? (or_outsel_fuses[i] ? or_reg[i] : or_sum) : 1'bz;
        end
    endgenerate
endmodule
