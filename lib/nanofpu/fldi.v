`default_nettype none

// load an int32_t into a float
module fldi
(
	input wire clk,
	input wire rst_n,
	
	input wire [31:0] in_a,			// int32_t 
	input wire        valid,		// command valid
	
	output reg [31:0] out,			// result(float)
	output reg        ready			// result is valid
);
	reg        a_sign;
	reg [7:0]  a_exp;
	reg [31:0] a_mant;
	reg [1:0]  fsm_state;

	localparam
		FSM_IDLE  = 0,
		FSM_NORM  = 1;

	always @(posedge clk) begin
		ready     <= 1'b0;
		case (fsm_state)
			FSM_IDLE: begin
				if (~ready & valid) begin
					fsm_state  <= FSM_NORM;
					if (in_a == 0) begin
						out    <= 0;
						ready  <= 1;
					end else begin
						a_sign <= in_a[31];
						a_exp  <= 127 + 31;
						a_mant <= in_a[31] ? -in_a : in_a;
					end
				end
			end
			FSM_NORM: begin
				fsm_state <= fsm_state;				// default to staying in this state
				if (~a_mant[31]) begin
					a_mant <= a_mant << 1;
					a_exp  <= a_exp - 1;
				end else begin
					out       <= { a_sign, a_exp, a_mant[30:8] };
					ready     <= 1'b1;
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
