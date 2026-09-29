/*
	float multiply, rounds to zero, tracks overflow/underflow does not track subnorm
	
	On ICE40, takes ~28 cycles (243 LUT4, ~200 DFF, 74 CARRY) with USE_MULT=0, (you can enable USE_MULT but your
Fmax and logic count will suffer).

	On ECP5, takes ~28 cycles (178 LUT4, 197 DFF, 41 carry) with USE_MULT=0, or 
~5 cycles (125 LUT4, 121 FF, 4 MULT) with USE_MULT=1.

*/

`default_nettype none
module fmul
#(
	parameter USE_MULT=0
)
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
	reg [9:0]  a_exp;
	reg [24:0] a_mant;
	reg [23:0] b_mant;
	reg [1:0]  fsm_state;
	
	wire [47:0] product;
	assign product = a_mant * b_mant;

	localparam
		FSM_IDLE  = 0,
		FSM_CORE  = 1,
		FSM_REG   = 2,
		FSM_NORM  = 3;
	
	reg [47:0] da_prod;
	reg [47:0] da_opa;
	reg [4:0]  da_cnt;
	
	always @(posedge clk) begin
		ready     <= 1'b0;
		case (fsm_state)
			FSM_IDLE: begin
				if (valid) begin
					a_sign    <= in_a[31] ^ in_b[31];  // sign of product
					a_mant    <= {1'b1, in_a[22:0]};
					a_exp     <= {2'b0, in_a[30:23]} + {2'b0, in_b[30:23]} - 10'd127;
					b_mant    <= {1'b1, in_b[22:0]};
					if (USE_MULT == 0) begin
						da_opa  <= {24'b0, 1'b1, in_a[22:0]};
						da_prod <= 0;
						da_cnt  <= 24;
					end
					fsm_state <= FSM_CORE;
				end
			end
			FSM_CORE: begin
				if (USE_MULT == 1) begin
					da_prod     <= product[47:23];
					fsm_state   <= FSM_REG;
				end else begin
					b_mant <= b_mant >> 1;
					da_opa <= da_opa << 1;
					if (b_mant[0]) begin
						da_prod <= da_prod + da_opa;
					end
					da_cnt <= da_cnt - 1;
					if (da_cnt == 0) begin
						a_mant <= da_prod[47:23];
						fsm_state <= FSM_NORM;
					end
				end
			end
			FSM_REG: begin
				a_mant    <= da_prod;
				fsm_state <= FSM_NORM;
			end
			FSM_NORM: begin
				if (a_mant[24]) begin
					a_mant    <= a_mant >> 1;
					a_exp     <= a_exp + 1'b1;
				end else begin
					if ($signed(a_exp) >= $signed(10'd255)) begin
						// handle overflow
						out       <= {a_sign, 8'hFE, 23'h7FFFFF};
					end else if ($signed(a_exp) <= $signed(10'd0)) begin
						// handle underflow
						out       <= {a_sign, 31'b0};
					end else begin
						out       <= {a_sign, a_exp[7:0], a_mant[22:0]};
					end
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
