`default_nettype none

// load a float into an int32_t
module fsti
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
	reg        fsm_state;

	localparam
		FSM_IDLE  = 0,
		FSM_NORM  = 1;

	always @(posedge clk) begin
		ready     <= 1'b0;
		case (fsm_state)
			FSM_IDLE: begin
				if (~ready & valid) begin
					a_sign <= in_a[31];
					a_exp  <= in_a[30:23] - 127;
					a_mant <= {1'b1, in_a[22:0]};
					if (in_a[30:23] < 127) begin
						out    <= 0;
						ready  <= 1;
					end else if (in_a[30:23] >= 158) begin
						ready  <= 1;
						out    <= in_a[31] ? 32'h8000_0000 : 32'h7FFF_FFFF;
					end else begin
						fsm_state  <= FSM_NORM;
					end					
				end
			end
			FSM_NORM: begin
				if (a_exp > 23) begin
					a_mant    <= a_mant << 1;
					a_exp     <= a_exp - 1;
				end else if (a_exp < 23) begin
					a_mant    <= a_mant >> 1;
					a_exp     <= a_exp + 1;
				end else begin
					out       <= a_sign ? -a_mant : a_mant;
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
