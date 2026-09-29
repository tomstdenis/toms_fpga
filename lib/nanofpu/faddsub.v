/*
	float add/subtract, rounds to zero, does not track GRS
	
	On ICE40, Takes ~28 cycles (353 LUT4, 73 DFF, 105 CARRY) with USE_BARREL=0, or ~4 cycles (442 LUT4, 73 DFF, 102 CARRY) with USE_BARREL=1
	
	On ECP5, Takes ~28 cycles (530 LUT4, 72 DFF, 57 CARRY) with USE_BARREL=0, or ~4 cycles (399 LUT4, 73 DFF, 55 CARRY) with USE_BARREL=1

*/

`default_nettype none

module faddsub
#(
	parameter USE_BARREL=1			// use a barrel shifter (drops from ~30 to ~3 cycles)
)
(
	input wire clk,
	input wire rst_n,
	
	input wire [31:0] in_a,
	input wire [31:0] in_b,
	input wire        sub_op,		// 0 == addition, 1 == sub
	input wire        valid,		// command valid
	
	output wire [31:0] out,			// result
	output reg        ready			// result is valid
);

	reg        issub;
	reg        a_sign;
	reg [7:0]  a_exp;
	reg [24:0] a_mant;
	reg [7:0]  b_exp;
	reg [24:0] b_mant;
	reg [1:0]  fsm_state;
	
	reg [7:0]  exp_delta;
	
	assign out = {a_sign, a_exp, a_mant[22:0]};

	localparam
		FSM_IDLE  = 0,
		FSM_ALIGN = 1,
		FSM_CORE  = 2,
		FSM_NORM  = 3;
	
	always @(posedge clk) begin
		ready     <= 1'b0;
		case (fsm_state)
			FSM_IDLE: begin
				if (valid) begin
					// sort and latch input 
					issub <= in_a[31] ^ in_b[31] ^ sub_op;		// is this a subtract?
					if ((in_a[30:23] < in_b[30:23]) || ((in_a[30:23] == in_b[30:23]) && (in_a[22:0] < in_b[22:0]))) begin
						// swap operands (a,b) => (b,a)
						a_sign <= in_b[31] ^ sub_op;
						a_mant <= {1'b0, 1'b1, in_b[22:0]};
						a_exp  <= in_b[30:23];
						b_mant <= {1'b0, 1'b1, in_a[22:0]};
						b_exp  <= in_a[30:23];
						exp_delta <= in_b[30:23] - in_a[30:23];
					end else begin
						// normal order
						a_sign <= in_a[31];
						a_mant <= {1'b0, 1'b1, in_a[22:0]};
						a_exp  <= in_a[30:23];
						b_mant <= {1'b0, 1'b1, in_b[22:0]};
						b_exp  <= in_b[30:23];
						exp_delta <= in_a[30:23] - in_b[30:23];
					end
					fsm_state <= FSM_ALIGN;
				end
			end
			FSM_ALIGN: begin
				fsm_state     <= FSM_CORE;
				if (USE_BARREL == 1) begin
					if (exp_delta < 24) begin
						b_mant    <= b_mant >> exp_delta[4:0];
					end else begin
						b_mant    <= 0;
					end
				end else begin
					if (b_mant != 0 && b_exp < a_exp) begin
						b_mant    <= b_mant >> 1;
						b_exp     <= b_exp + 1'b1;
						fsm_state <= fsm_state;			// stay in ALIGN state
					end
				end
			end
			FSM_CORE: begin
				if (issub) begin
					a_mant <= a_mant - b_mant;
				end else begin
					a_mant <= a_mant + b_mant;
				end
				fsm_state  <= FSM_NORM;
			end
			FSM_NORM: begin
				if (a_mant[24]) begin
					a_mant <= a_mant >> 1;
					a_exp  <= a_exp + 1'b1;
				end else begin
					if (a_mant != 0 && ~a_mant[23]) begin
						a_mant <= a_mant << 1;
						a_exp  <= a_exp - 1'b1;
					end else begin
						ready     <= 1'b1;
						fsm_state <= FSM_IDLE;
					end
				end
			end
		endcase	
		if (~rst_n) begin
			fsm_state <= FSM_IDLE;
			issub     <= 1'b0;
		end
	end
endmodule
