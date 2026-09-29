/*
	Float sqrt
	
*/
`default_nettype none

module fsqrt
(
	input wire clk,
	input wire rst_n,
	
	input wire [31:0] in_a,			// float
	input wire        valid,		// command valid
	
	output reg [31:0] out,			// sqrt(float)
	output reg        ready			// result is valid
);
	reg [7:0]  a_exp;
	reg [48:0] a_mant;
	reg [48:0] one;
	reg [24:0] res;
	reg [1:0]  fsm_state;

	localparam
		FSM_IDLE   = 0,
		FSM_EXP    = 1,
		FSM_REDUCE = 2,
		FSM_NORM   = 3;

	always @(posedge clk) begin
		ready     <= 1'b0;
		case (fsm_state)
			FSM_IDLE: begin
				if (~ready & valid) begin
					if (in_a[31]) begin
						// only positive
						out   <= 32'hffc00000;
						ready <= 1'b1;
					end else if (in_a[30:23] == 8'h00) begin
						// handle zero
						out   <= 32'b0;
						ready <= 1'b1;
					end else begin
						// prepare for handling 
						fsm_state <= FSM_EXP;
						a_exp     <= in_a[30:23];
						a_mant    <= {1'b1, in_a[22:0], 24'b0};
						one       <= 1 << 48;
						res       <= 0;
					end
				end
			end
			FSM_EXP: begin
				fsm_state <= FSM_REDUCE;
				if (a_exp[0]) begin
					// handle odd exponents
					a_exp  <= (a_exp - 128) >> 1;
					a_mant <= a_mant >> 1;
				end else begin
					// even exponents
					a_exp  <= (a_exp - 127) >> 1;
				end
			end
			FSM_REDUCE: begin
				if (one != 0) begin
					if (a_mant >= (res + one)) begin
						a_mant <= a_mant - (res + one);
						res  <= (res >> 1) + one;
					end else begin
						res  <= res >> 1;
					end
					one <= one >> 2;
				end else begin
					// normalize
					fsm_state <= FSM_NORM;
				end
			end
			FSM_NORM: begin
				if (res[24]) begin
					res   <= res >> 1;
					a_exp <= a_exp + 1;
				end else if (!res[23]) begin
					res   <= res << 1;
					a_exp <= a_exp - 1;
				end else begin
					out       <= {1'b0, a_exp, res[22:0]};
					ready     <= 1;
					fsm_state <= FSM_IDLE;
				end
			end
		endcase	
		if (~rst_n) begin
			fsm_state <= FSM_IDLE;
			out       <= 32'b0;
		end
	end
endmodule
