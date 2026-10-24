`timescale 1ns/1ps
`default_nettype none

module serial_divide
#(
	parameter BIT_WIDTH=16
)
(
	input wire                 clk,
	input wire                 rst_n,
	
	input wire [BIT_WIDTH-1:0] num,			// numerator
	input wire [BIT_WIDTH-1:0] denom,		// denominator
	input wire                 valid,		// pair valid
	
	output reg                 ready,		// result valid
	output reg [BIT_WIDTH-1:0] quotient,
	output reg [BIT_WIDTH-1:0] remainder
);
	
	reg [BIT_WIDTH-1:0] num_l;
	reg [BIT_WIDTH-1:0] denom_l;
	reg [BIT_WIDTH-1:0] tmp;
	reg [1:0]           fsm_state;
		
	localparam
		FSM_IDLE      = 0,				// Idle waiting for valid
		FSM_NORMALIZE = 1,				// normalize denominator
		FSM_REDUCE    = 2;				// reduce numerator
	
	always @(posedge clk) begin
		ready <= 0;

		case(fsm_state)
			FSM_IDLE: begin
				if (~ready & valid) begin
					quotient  <= 0;
					remainder <= 0;
					num_l     <= num;
					denom_l   <= denom;
					tmp	      <= 1;
					if (num < denom || denom == 0) begin
						remainder <= denom > 0 ? num : 0;
						ready     <= 1;
					end else begin
						fsm_state <= FSM_NORMALIZE;
					end
				end
			end
			FSM_NORMALIZE: begin
				// how many times can we left shift denom_l until it's bigger than num_l
				if ({denom_l, 1'b0} <= {1'b0, num_l}) begin
					denom_l   <= {denom_l[BIT_WIDTH-2:0], 1'b0};
					tmp       <= {tmp[BIT_WIDTH-2:0], 1'b0};
				end else begin
					fsm_state <= FSM_REDUCE;
				end
			end
			FSM_REDUCE:	begin
				if (denom_l <= num_l) begin
					// update quotient and subtract shifted copy of denominator
					quotient <= quotient + tmp;
					num_l    <= num_l - denom_l;
				end else begin
					// can't subtract anymore so shift both right and stop once we hit denormalized state
					denom_l  <= {1'b0, denom_l[BIT_WIDTH-1:1]};
					tmp		 <= {1'b0, tmp[BIT_WIDTH-1:1]};
					if (tmp == 1) begin
						remainder <= num_l;
						ready     <= 1;
						fsm_state <= FSM_IDLE;
					end
				end
			end
		endcase

		if (!rst_n) begin
			ready     <= 0;
			fsm_state <= FSM_IDLE;
		end
	end
endmodule
