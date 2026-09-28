`default_nettype none
module fdiv
(
	input wire clk,
	input wire rst_n,
	
	input wire [31:0] in_a,
	input wire [31:0] in_b,
	input wire        valid,		// command valid
	
	output reg [31:0] out,			// result
	output reg        ready			// result is valid
);
	reg        a_sign;
	reg [7:0]  a_exp;
	reg [23:0] a_mant;
	reg [23:0] b_mant;
	wire [24:0] quot;
	reg [1:0]  fsm_state;
	reg        divider_valid;
	wire       divider_ready;
	
	fdiv_serial fdiv_serial(
		.clk(clk), .rst_n(rst_n), 
		.valid(divider_valid), .sig_a(a_mant), .sig_b(b_mant), .quot(quot), .ready(divider_ready));

	localparam
		FSM_IDLE  = 0,
		FSM_CORE  = 1,
		FSM_NORM  = 2;
	
	always @(posedge clk) begin
		ready         <= 1'b0;
		divider_valid <= 1'b0;
		case (fsm_state)
			FSM_IDLE: begin
				if (valid) begin
					a_sign        <= in_a[31] ^ in_b[31];  // sign of product
					a_mant        <= {1'b1, in_a[22:0]};
					a_exp         <= in_a[30:23] + in_b[30:23] + 127;
					b_mant        <= {1'b1, in_b[22:0]};
					divider_valid <= 1'b1;
					fsm_state     <= fsm_state + 1'b1;
				end
			end
			FSM_CORE: begin
				if (divider_ready) begin
					fsm_state  <= fsm_state + 1'b1;
					if (quot[24]) begin
						a_mant <= quot[24:2];
					end else begin
						a_mant <= quot[22:0];
						a_exp  <= a_exp - 1'b1;
					end
				end
			end
			FSM_NORM: begin
				out       <= {a_sign, a_exp, a_mant[22:0]};
				ready     <= 1'b1;
				fsm_state <= FSM_IDLE;
			end
		endcase	
		if (~rst_n) begin
			ready         <= 1'b0;
			divider_valid <= 1'b0;
			fsm_state     <= FSM_IDLE;
			out           <= 32'b0;
		end
	end
endmodule

`include "fdiv_serial.v"
