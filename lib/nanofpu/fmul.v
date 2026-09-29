/*
	float multiply, rounds to zero, tracks overflow/underflow does not track subnorm
	
	On ICE40, 
		USE_MULT=0: takes ~28 cycles (221 LUT4, 165 DFF, 74 CARRY)

	On ECP5, takes 
		USE_MULT=0: ~28 cycles (178 LUT4, 197 DFF, 41 carry)
		USE_MULT=1: ~5 cycles (123 LUT4, 89 FF, 4 MULT)
		USE_MULT=2: ~6 cycles (125 LUT4, 186 FF, 4 MULT)

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
	
	output wire [31:0] out,			// result
	output reg        ready			// result is valid
);
	reg        a_sign;
	reg [9:0]  a_exp;
	reg [24:0] a_mant;
	reg [23:0] b_mant;
	reg [2:0]  fsm_state;
	
	wire [47:0] product;
	assign product = a_mant[23:0] * b_mant[23:0];
	
	assign out = {a_sign, a_exp[7:0], a_mant[22:0]};

	localparam
		FSM_IDLE  = 0,
		FSM_CORE  = 1,
		FSM_REG   = 2,
		FSM_REG2  = 3,
		FSM_NORM  = 4;
	
	reg [47:0] da_prod;
	reg [47:0] da_opa;
	reg [4:0]  da_cnt;
	
	reg [35:0] p00_prod;
	reg [35:0] p01_prod;
	reg [35:0] p10_prod;
	reg [35:0] p11_prod;
	
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
				if (USE_MULT == 2) begin
					p00_prod <= a_mant[17:0] * b_mant[17:0];
					p01_prod <= a_mant[17:0] * b_mant[23:18];
					p10_prod <= a_mant[23:18] * b_mant[17:0];
					p11_prod <= a_mant[23:18] * b_mant[23:18];
					fsm_state <= FSM_REG2;
				end else if (USE_MULT == 1) begin
					da_prod     <= a_mant[23:0] * b_mant[23:0];
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
			FSM_REG2: begin
				if (USE_MULT == 2) begin
					da_prod   <= p00_prod + ((p01_prod + p10_prod) << 18) + (p11_prod << 36);
					fsm_state <= FSM_REG;
				end
			end
			FSM_REG: begin
				if (USE_MULT != 0) begin
					a_mant    <= da_prod[47:23];
					fsm_state <= FSM_NORM;
				end
			end
			FSM_NORM: begin
				if (a_mant[24]) begin
					a_mant    <= a_mant >> 1;
					a_exp     <= a_exp + 1'b1;
				end else begin
					if ($signed(a_exp) >= $signed(10'd255)) begin
						// handle overflow
						a_exp     <= 8'hFE;
						a_mant    <= 23'h7FFFFF;
					end else if ($signed(a_exp) <= $signed(10'd0)) begin
						// handle underflow
						a_exp     <= 0;
						a_mant    <= 0;
					end
					ready     <= 1'b1;
					fsm_state <= FSM_IDLE;
				end
			end
		endcase	
		if (~rst_n) begin
			fsm_state <= FSM_IDLE;
		end
	end
endmodule
