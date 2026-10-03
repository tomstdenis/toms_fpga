/*
	Float load int32_t into float
	
	Takes 3+ cycles.
	
	ICE40: 158 LUT4, 43 DFF, 36 CARRY
	ECP5:  125 LUT4, 43 DFF, 20 CARRY

*/
`default_nettype none

// load an int32_t into a float
module fldi
#(
	parameter USE_BIG_SHIFT=1
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
	reg [1:0]  fsm_state;
	
	assign out = { a_sign, a_exp, a_mant[30:8] };

	localparam
		FSM_IDLE      = 0,
		FSM_BIG_SHIFT = 1,
		FSM_NORM      = 2;

	always @(posedge clk) begin
		ready     <= 1'b0;
		case (fsm_state)
			FSM_IDLE: begin
				if (~ready & valid) begin
					if (in_a == 0) begin
						a_sign       <= 0;
						a_exp        <= 0;
						a_mant[30:8] <= 0;
						ready        <= 1;
					end else begin
						fsm_state  <= (USE_BIG_SHIFT == 1) ? FSM_BIG_SHIFT : FSM_NORM;
						a_sign     <= in_a[31];
						a_exp      <= 127 + 31;
						a_mant     <= in_a[31] ? -in_a : in_a;
					end
				end
			end
			FSM_BIG_SHIFT: begin
				if (USE_BIG_SHIFT == 1) begin
					if (a_mant[31:28] == 4'b0000) begin
						a_mant <= a_mant << 4;
						a_exp  <= a_exp - 4;
					end else begin
						fsm_state <= FSM_NORM;
					end
				end
			end
			FSM_NORM: begin
				if (~a_mant[31]) begin
					a_mant    <= a_mant << 1;
					a_exp     <= a_exp - 1;
				end else begin
					ready     <= 1'b1;
					fsm_state <= FSM_IDLE;
				end
			end
		endcase	
		if (~rst_n) begin
			fsm_state                       <= FSM_IDLE;
			{ a_sign, a_exp, a_mant[30:8] } <= 32'b0;  // reset modules output
		end
	end
endmodule
