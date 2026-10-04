/*
	Float load float into int32_t
	
*/
`default_nettype none

// load a float into an int32_t
module fsti
#(
	parameter USE_BARREL=1			// enable a (large, rooughly 3-5x larger) barrel shifter drops cycle count down quite a bit
)
(
	input wire clk,
	input wire rst_n,
	
	input wire [31:0] in_a,			// int32_t 
	input wire        valid,		// command valid
	
	output wire [31:0] out,			// result(float)
	output reg        ready			// result is valid
);
	reg        a_sign;
	reg [7:0]  a_exp;
	reg [31:0] a_mant;
	reg        fsm_state;
	
	reg [4:0]  a_exp_over;
	reg [4:0]  a_exp_under;
	
	assign out = a_mant;

	localparam
		FSM_IDLE  = 0,
		FSM_NORM  = 1;

	always @(posedge clk) begin
		ready     <= 1'b0;
		case (fsm_state)
			FSM_IDLE: begin
				if (~ready & valid) begin
					a_sign      <= in_a[31];
					a_exp       <= in_a[30:23] - 127;
					a_exp_over  <= (in_a[30:23] - 127) - 23;
					a_exp_under <= 23 - (in_a[30:23] - 127);
					a_mant      <= {1'b1, in_a[22:0]};
					if (in_a[30:23] < 127) begin
						// number is below zero just output zero
						a_mant  <= 0;
						ready   <= 1;
					end else if (in_a[30:23] >= 158) begin
						// number exceeds INT_MAX 
						ready   <= 1;
						a_mant  <= in_a[31] ? 32'h8000_0000 : 32'h7FFF_FFFF;
					end else begin
						// number has bits in range so let's normalize it
						fsm_state  <= FSM_NORM;
					end					
				end
			end

			// normalize to an integer range
			FSM_NORM: begin
				if (a_exp > 23) begin
					if (USE_BARREL == 0) begin
						a_mant    <= a_mant << 1;
						a_exp     <= a_exp - 1;
					end else begin
						a_mant    <= a_mant << a_exp_over;
						a_exp     <= 23;
					end
				end else if (a_exp < 23) begin
					if (USE_BARREL == 0) begin
						a_mant    <= a_mant >> 1;
						a_exp     <= a_exp + 1;
					end else begin
						a_mant    <= a_mant >> a_exp_under;
						a_exp     <= 23;
					end
				end else begin
					// no more bits to shift
					a_mant        <= a_sign ? -a_mant : a_mant;
					ready         <= 1;
					fsm_state     <= FSM_IDLE;
				end
			end
		endcase	
		if (~rst_n) begin
			fsm_state <= FSM_IDLE;
			a_mant    <= 32'b0;    // ensure output is reset
		end
	end
endmodule
