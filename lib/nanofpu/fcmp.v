/*

	Float compare, outputs 1 for LT, 2 for GT, and 4 for EQ
	
	Takes 1 cycle.
	
	ICE40: 100 LUT4, 4 DFF, 31 CARRY
	ECP5:   80 LUT4, 4 DFF, 15 CARRY, 7 L6MUX, 17 PFUMX

*/
`default_nettype none

module fcmp
(
	input wire clk,
	input wire rst_n,
	
	input wire [31:0] in_a,			// left side
	input wire [31:0] in_b,			// right side
	input wire        valid,		// command valid
	
	output wire [31:0] out,			// cmp ([2] = EQ, [1] = GT, [0] = LT)
	output reg        ready			// result is valid
);
	reg fsm_state;
	reg [2:0] cmp;
	
	assign out = {29'b0, cmp};

	wire        a_sign;
	wire [7:0]  a_exp;
	wire [22:0] a_sig;
	wire        b_sign;
	wire [7:0]  b_exp;
	wire [22:0] b_sig;
	
	assign a_sign = in_a[31];
	assign a_exp  = in_a[30:23];
	assign a_sig  = in_a[22:0];
	
	assign b_sign = in_b[31];
	assign b_exp  = in_b[30:23];
	assign b_sig  = in_b[22:0];

	always @(posedge clk) begin
		ready <= 1'b0;
		if (~ready & valid) begin
			ready <= 1'b1;
			cmp   <= 3'b000;
			
			// Special handling for IEEE +0.0 == -0.0
			if ((in_a[30:0] == 31'b0) && (in_b[30:0] == 31'b0)) begin
				cmp <= 3'b100; // EQ (4)
			end else if (~a_sign & b_sign) begin
				cmp <= 3'b010; // A > 0, B < 0 -> GT (2)
			end else if (a_sign & ~b_sign) begin
				cmp <= 3'b001; // A < 0, B > 0 -> LT (1)
			end else if (a_sign == b_sign) begin
				if (a_exp < b_exp) begin
					cmp <= a_sign ? 3'b010 : 3'b001; // If neg: GT (2), else: LT (1)
				end else if (a_exp > b_exp) begin
					cmp <= a_sign ? 3'b001 : 3'b010; // If neg: LT (1), else: GT (2)
				end else begin
					if (a_sig < b_sig) begin
						cmp <= a_sign ? 3'b010 : 3'b001; // If neg: GT (2), else: LT (1)
					end else if (a_sig > b_sig) begin
						cmp <= a_sign ? 3'b001 : 3'b010; // If neg: LT (1), else: GT (2)
					end else begin
						cmp <= 3'b100; // EQ (4)
					end
				end
			end
		end
	end
endmodule
