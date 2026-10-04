/*

	Float compare, outputs 1 for LT, 2 for GT, and 4 for EQ
	
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

	reg iszero;
	reg explt;
	reg expgt;
	reg mantlt;
	reg mantgt;
	reg fsm_state;
	
	localparam
		FSM_IDLE = 0,
		FSM_CMP  = 1;

	reg isnan_a;
    reg isnan_b;
	wire isnan_a_next = (in_a[30:23] == 8'hFF && (|in_a[22:0] == 1'b1)) ? 1'b1 : 1'b0;
	wire isnan_b_next = (in_b[30:23] == 8'hFF && (|in_b[22:0] == 1'b1)) ? 1'b1 : 1'b0;
	wire isaz_next    = (in_a[30:23] == 0) ? 1'b1 : 1'b0;
	wire isbz_next    = (in_b[30:23] == 0) ? 1'b1 : 1'b0;

	always @(posedge clk) begin
		ready <= 1'b0;
		case (fsm_state)
			FSM_IDLE: begin
				if (~ready & valid) begin
					// do all the compares in parallel here
					isnan_a   <= isnan_a_next;
					isnan_b   <= isnan_b_next;
					iszero    <= isaz_next && isbz_next;
					explt     <= (a_exp < b_exp) ? 1'b1 : 1'b0;
					expgt     <= (a_exp > b_exp) ? 1'b1 : 1'b0;
					mantlt    <= (a_sig < b_sig) ? 1'b1 : 1'b0;
					mantgt    <= (a_sig > b_sig) ? 1'b1 : 1'b0;
					fsm_state <= FSM_CMP;
				end
			end
			FSM_CMP: begin
				// use all the compares we computed in the previous cycle
				ready <= 1'b1;
				cmp   <= 3'b000;
				if (isnan_a || isnan_b) begin
					cmp <= 3'b000; // comparing anything to NaN should leave all three clear
				end else if (iszero) begin
					// Special handling for IEEE +0.0 == -0.0
					cmp <= 3'b100; // EQ (4)
				end else if (~a_sign & b_sign) begin
					cmp <= 3'b010; // A > 0, B < 0 -> GT (2)
				end else if (a_sign & ~b_sign) begin
					cmp <= 3'b001; // A < 0, B > 0 -> LT (1)
				end else if (a_sign == b_sign) begin
					if (explt) begin
						cmp <= a_sign ? 3'b010 : 3'b001; // If neg: GT (2), else: LT (1)
					end else if (expgt) begin
						cmp <= a_sign ? 3'b001 : 3'b010; // If neg: LT (1), else: GT (2)
					end else begin
						if (mantlt) begin
							cmp <= a_sign ? 3'b010 : 3'b001; // If neg: GT (2), else: LT (1)
						end else if (mantgt) begin
							cmp <= a_sign ? 3'b001 : 3'b010; // If neg: LT (1), else: GT (2)
						end else begin
							cmp <= 3'b100; // EQ (4)
						end
					end
				end
				fsm_state <= FSM_IDLE;
			end
		endcase
		if (~rst_n) begin
			fsm_state <= FSM_IDLE;
		end
	end
endmodule
