/*
	Float sqrt
	
	Takes 24, 48, 72 cycles plus overhead depending on STAGES=0,1,2
	
	Higher stage counts increases Fmax at a cost in cycle count.  Handy if you don't do a lot of FSQRT
but want to have it around.  
	
	STAGES=0 synth:
	ICE40: 364 LUT4, 136 DFF, 157 CARRY
	ECP5 : 294 LUT4, 136 DFF, 83 CARRY, 34 L6MUX21

*/
`default_nettype none

module fsqrt
#(
	parameter STAGES=2
)
(
	input wire clk,
	input wire rst_n,
	
	input wire [31:0] in_a,			// float
	input wire        valid,		// command valid
	
	output wire [31:0] out,			// sqrt(float)
	output reg        ready			// result is valid
);
	reg [7:0]  a_exp;
	reg [48:0] a_mant;
	reg [48:0] one;
	reg [48:0] res;
	reg [48:0] tmp;
	reg [2:0]  fsm_state;

	localparam
		FSM_IDLE        = 0,
		FSM_EXP         = 1,
		FSM_REDUCE_PREP = 2,
		FSM_REDUCE_CMP  = 3,
		FSM_REDUCE      = 4,
		FSM_NORM        = 5;

	assign out = res[31:0];
	
	reg [49:0] reduce_cmp;

	always @(posedge clk) begin
		ready     <= 1'b0;
		case (fsm_state)
			FSM_IDLE: begin
				if (~ready & valid) begin
					if (in_a[31]) begin
						// only positive
						res[31:0] <= 32'hffc00000;
						ready     <= 1'b1;
					end else if (in_a[30:23] == 8'h00) begin
						// handle zero
						res[31:0] <= 32'b0;
						ready     <= 1'b1;
					end else begin
						// prepare for handling 
						fsm_state <= FSM_EXP;
						a_exp     <= in_a[30:23];
						a_mant    <= {1'b0, 1'b1, in_a[22:0], 24'b0};
						one       <= 1 << 48;
						res       <= 0;
					end
				end
			end
			// fix up the exponent and if needed the mantissa
			FSM_EXP: begin
				if (STAGES != 0) begin
					fsm_state <= FSM_REDUCE_PREP;
				end else begin
					fsm_state <= FSM_REDUCE;
				end
				if (a_exp[0]) begin
					// handle odd exponents
					a_exp         <= (a_exp - 128) >> 1;
					a_mant[48:24] <= a_mant[48:24] << 1;
				end else begin
					// even exponents
					a_exp         <= (a_exp - 127) >> 1;
				end
			end
			FSM_REDUCE_PREP: begin
				// Pipelining the 48-bit add can help timing...
				if (STAGES != 0) begin
					tmp       <= res + one;
					if (STAGES == 1) begin
						fsm_state <= FSM_REDUCE;
					end else begin
						fsm_state <= FSM_REDUCE_CMP;
					end
				end
			end
			FSM_REDUCE_CMP: begin
				if (STAGES == 2) begin
					reduce_cmp <= a_mant - tmp;
					fsm_state  <= FSM_REDUCE;
				end
			end
			// reduction loop
			FSM_REDUCE: begin
				if (one != 0) begin
					if (STAGES != 0) begin
						fsm_state <= FSM_REDUCE_PREP;
						// the next guess fits or not
						if (STAGES == 1) begin
							// two stage
							if (a_mant >= tmp) begin
								a_mant <= a_mant - tmp;
								res    <= (res >> 1) + one;
							end else begin
								res    <= res >> 1;
							end
						end else begin
							// three stage
							if (~reduce_cmp[49]) begin
								a_mant <= a_mant - tmp;
								res    <= (res >> 1) + one;
							end else begin
								res    <= res >> 1;
							end
						end
					end else begin
						if (a_mant >= res + one) begin
							a_mant <= a_mant - (res + one);
							res    <= (res >> 1) + one;
						end else begin
							res    <= res >> 1;
						end
					end
					one        <= one >> 2;
				end else begin
					// jump to normalize, also re-bias the exponent here
					a_exp      <= a_exp + 127;
					fsm_state  <= FSM_NORM;
				end
			end
			// normalize the output
			FSM_NORM: begin
				if (res[24]) begin
					// overflow
					res[24:0]  <= res[25:1];
					a_exp      <= a_exp + 1;
				end else if (~res[23]) begin
					// underflow
					res[23:0]  <= {res[22:0], 1'b0};
					a_exp      <= a_exp - 1;
				end else begin
					// done
					res[31:0]  <= {1'b0, a_exp, res[22:0]};
					ready      <= 1;
					fsm_state  <= FSM_IDLE;
				end
			end
		endcase	
		if (~rst_n) begin
			fsm_state <= FSM_IDLE;
			res[31:0] <= 32'b0;
		end
	end
endmodule
