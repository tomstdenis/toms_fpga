`timescale 1ns/1ps
`default_nettype none

module sqrt_bin
	#(parameter
		BIT_WIDTH=16
	)(

	input wire clk,
	input wire rst_n,
	
	input wire [BIT_WIDTH-1:0] num,
	input wire valid,
	
	output reg ready,
	output reg [(BIT_WIDTH/2)-1:0] sqrt);
	
	reg [BIT_WIDTH-1:0] num_l;
	reg [(BIT_WIDTH/2)-1:0] tmp;
	reg [1:0] fsm_state;
		
	localparam
		FSM_IDLE      = 0,				// Idle waiting for valid
		FSM_DONE      = 1,				// Done waiting for !valid
		FSM_SOLVE     = 2;				// solve
	
	wire [7:0] guess = tmp | sqrt;
	
	always @(posedge clk) begin
		if (!rst_n) begin
			tmp       <= 0;
			sqrt 	  <= 0;
			ready     <= 0;
			fsm_state <= FSM_IDLE;
		end else begin
			case(fsm_state)
				FSM_IDLE:
					begin
						if (valid) begin
							sqrt      <= 0;
							num_l     <= num;
							tmp	      <= { 1'b1, {((BIT_WIDTH/2)-1){1'b0}} };
							fsm_state <= FSM_SOLVE;
						end	
					end
				FSM_SOLVE:
					begin
						if (num_l >= (guess * guess)) begin
							sqrt <= sqrt | tmp;
						end
						if (!tmp[0]) begin
							tmp <= {1'b0, tmp[((BIT_WIDTH/2)-1):1] };
						end else begin
							ready 	  <= 1'b1;
							fsm_state <= FSM_DONE;
						end
					end
				FSM_DONE:
					begin
						// wait for other side to drop valid
						if (!valid) begin
							ready     <= 0;
							fsm_state <= FSM_IDLE;
						end
					end
				default: fsm_state <= FSM_IDLE;
			endcase
		end
	end
endmodule
