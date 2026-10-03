/*
	float add/subtract, rounds to zero, does not track GRS

*/

`default_nettype none

module faddsub
#(
	parameter USE_BARREL=1,			// use a barrel shifter (drops from ~30 to ~3 cycles)
	parameter USE_TWO_STAGE_CMP=1   // use a pipelined compare for higher Fmax
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
	reg [28:0] a_mant;
	reg [7:0]  b_exp;
	reg [28:0] b_mant;
	reg [2:0]  fsm_state;
	
	reg [7:0]  exp_delta;
	reg        sticky;
	
	assign out = {a_sign, a_exp, a_mant[26:4]};

	localparam
		FSM_IDLE  = 0,
		FSM_SORT  = 1,
		FSM_ALIGN = 2,
		FSM_CORE  = 3,
		FSM_NORM  = 4;
	
	reg explt;
	reg expeq;
	reg mantlt;
	
	wire explt_next  = (in_a[30:23] < in_b[30:23]) ? 1'b1 : 1'b0;
	wire expeq_next  = (in_a[30:23] == in_b[30:23]) ? 1'b1 : 1'b0;
	wire mantlt_next = (in_a[22:0] < in_b[22:0]) ? 1'b1 : 1'b0;
	
	always @(posedge clk) begin
		ready     <= 1'b0;
		case (fsm_state)
			FSM_IDLE: begin
				if (valid) begin
					// perform all the compares in parallel here
					issub     <= in_a[31] ^ in_b[31] ^ sub_op;	// is this a subtract?
					if (USE_TWO_STAGE_CMP == 1) begin
						explt     <= explt_next;
						expeq     <= expeq_next;
						mantlt    <= mantlt_next;
						fsm_state <= FSM_SORT;
					end else begin
						fsm_state <= FSM_ALIGN;
						if (explt_next || (expeq_next && mantlt_next)) begin
							// swap operands (a,b) => (b,a)
							a_sign <= in_b[31] ^ sub_op;
							a_mant <= {1'b0, 1'b1, in_b[22:0], 4'b0};
							a_exp  <= in_b[30:23];
							b_mant <= {1'b0, 1'b1, in_a[22:0], 4'b0};
							b_exp  <= in_a[30:23];
							exp_delta <= in_b[30:23] - in_a[30:23];
						end else begin
							// normal order
							a_sign <= in_a[31];
							a_mant <= {1'b0, 1'b1, in_a[22:0], 4'b0};
							a_exp  <= in_a[30:23];
							b_mant <= {1'b0, 1'b1, in_b[22:0], 4'b0};
							b_exp  <= in_b[30:23];
							exp_delta <= in_a[30:23] - in_b[30:23];
						end
					end
				end
			end
			FSM_SORT: begin
				if (USE_TWO_STAGE_CMP == 1) begin
					// sort the input based on the compares from the previous cycle
					fsm_state <= FSM_ALIGN;
					if (explt || (expeq && mantlt)) begin
						// swap operands (a,b) => (b,a)
						a_sign <= in_b[31] ^ sub_op;
						a_mant <= {1'b0, 1'b1, in_b[22:0], 4'b0};
						a_exp  <= in_b[30:23];
						b_mant <= {1'b0, 1'b1, in_a[22:0], 4'b0};
						b_exp  <= in_a[30:23];
						exp_delta <= in_b[30:23] - in_a[30:23];
					end else begin
						// normal order
						a_sign <= in_a[31];
						a_mant <= {1'b0, 1'b1, in_a[22:0], 4'b0};
						a_exp  <= in_a[30:23];
						b_mant <= {1'b0, 1'b1, in_b[22:0], 4'b0};
						b_exp  <= in_b[30:23];
						exp_delta <= in_a[30:23] - in_b[30:23];
					end
				end
			end
			
			FSM_ALIGN: begin
				fsm_state     <= FSM_CORE;
				if (USE_BARREL == 1) begin
					if (exp_delta < 31) begin
						b_mant    <= b_mant >> exp_delta[4:0];
					end else begin
						b_mant    <= |b_mant;
					end
				end else begin
					if (exp_delta < 31) begin
						if (b_mant != 0 && b_exp < a_exp) begin
							b_mant    <= b_mant >> 1;
							b_exp     <= b_exp + 1'b1;
							fsm_state <= fsm_state;			// stay in ALIGN state
						end
					end else begin
						b_mant <= |b_mant;
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
				if (a_mant[28]) begin
					a_mant <= (a_mant >> 1) | a_mant[0];
					a_exp  <= a_exp + 1'b1;
				end else begin
					if (|a_mant[26:0] & ~a_mant[27]) begin
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
			fsm_state               <= FSM_IDLE;
			issub                   <= 1'b0;
			{a_sign, a_exp, a_mant} <= 0; // reset output
		end
	end
endmodule
