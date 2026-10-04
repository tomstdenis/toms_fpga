/*
	float add/subtract, rounds to zero, does not track GRS

*/

`default_nettype none

module faddsub
#(
	parameter USE_BARREL=1,			// use a barrel shifter (drops from ~30 to ~3 cycles)
	parameter USE_TWO_STAGE_CMP=1,   // use a pipelined compare for higher Fmax
	parameter USE_BIG_STEP=1        // use a 4-bit comparator, adds area but reduces the spread of cycle counts
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
	
	reg isnan_a;
	reg isnan_b;
	reg explt;
	reg expeq;
	reg mantlt;
	reg expaz;
	reg expbz;
	
	// various comparisons to pipeline
	wire isnan_a_next = (in_a[30:23] == 8'hFF && (|in_a[22:0] == 1'b1)) ? 1'b1 : 1'b0;
	wire isnan_b_next = (in_b[30:23] == 8'hFF && (|in_b[22:0] == 1'b1)) ? 1'b1 : 1'b0;
	wire expaz_next   = (in_a[30:23] == 8'h00) ? 1'b1 : 1'b0;
	wire expbz_next   = (in_b[30:23] == 8'h00) ? 1'b1 : 1'b0;
	wire explt_next   = (in_a[30:23] < in_b[30:23]) ? 1'b1 : 1'b0;
	wire expeq_next   = (in_a[30:23] == in_b[30:23]) ? 1'b1 : 1'b0;
	wire mantlt_next  = (in_a[22:0] < in_b[22:0]) ? 1'b1 : 1'b0;
	
	always @(posedge clk) begin
		ready     <= 1'b0;
		case (fsm_state)
			FSM_IDLE: begin
				if (~ready & valid) begin
					issub     <= in_a[31] ^ in_b[31] ^ sub_op;	// is this a subtract?
					if (USE_TWO_STAGE_CMP == 1) begin
						// perform all the compares in parallel here
						isnan_a   <= isnan_a_next;
						isnan_b   <= isnan_b_next;
						expaz     <= expaz_next;
						expbz     <= expbz_next;
						explt     <= explt_next;
						expeq     <= expeq_next;
						mantlt    <= mantlt_next;
						fsm_state <= FSM_SORT;
					end else begin
						// not pipelining comparisons so we use *_next directly here
						if (isnan_a_next || isnan_b_next) begin
							a_sign       <= in_a[31] ^ in_b[31] ^ sub_op;
							a_exp        <= 8'hFF;
							a_mant       <= {1'b1, 22'b0, 4'b0000};
							ready        <= 1;
						end else if (expaz_next && expbz_next) begin
							// both zero
							a_sign       <= in_a[31] ^ in_b[31] ^ sub_op;
							a_exp        <= 0;
							a_mant       <= 0;
							ready        <= 1;
						end else if (expaz_next) begin
							// a is zero
							a_sign       <= in_b[31] ^ sub_op;
							a_exp        <= in_b[30:23];
							a_mant[26:4] <= in_b[22:0];
							ready        <= 1;
						end else if (expbz_next) begin
							// b is zero
							a_sign       <= in_a[31] ^ sub_op;
							a_exp        <= in_a[30:23];
							a_mant[26:4] <= in_a[22:0];
							ready        <= 1;
						end else begin
							// a != 0 && b != 0
							if (explt_next || (expeq_next && mantlt_next)) begin
								fsm_state <= FSM_ALIGN;
								// swap operands (a,b) => (b,a)
								a_sign    <= in_b[31] ^ sub_op;
								a_mant    <= {1'b0, 1'b1, in_b[22:0], 4'b0};
								a_exp     <= in_b[30:23];
								b_mant    <= {1'b0, 1'b1, in_a[22:0], 4'b0};
								b_exp     <= in_a[30:23];
								exp_delta <= in_b[30:23] - in_a[30:23];
							end else begin
								fsm_state <= FSM_ALIGN;
								// normal order
								a_sign    <= in_a[31];
								a_mant    <= {1'b0, 1'b1, in_a[22:0], 4'b0};
								a_exp     <= in_a[30:23];
								b_mant    <= {1'b0, 1'b1, in_b[22:0], 4'b0};
								b_exp     <= in_b[30:23];
								exp_delta <= in_a[30:23] - in_b[30:23];
							end
						end
					end
				end
			end
			// if we're pipelining the compare then this FSM stage does the
			// sort we'd otherwise do in FSM_IDLE
			FSM_SORT: begin
				if (USE_TWO_STAGE_CMP == 1) begin
					// sort the input based on the compares from the previous cycle
					fsm_state <= FSM_ALIGN;
					if (isnan_a || isnan_b) begin
						a_sign       <= in_a[31] ^ in_b[31] ^ sub_op;
						a_exp        <= 8'hFF;
						a_mant       <= {1'b1, 22'b0, 4'b0000};
						ready        <= 1;
					end else if (expaz && expbz) begin
						// both zero
						a_sign       <= in_a[31] ^ in_b[31] ^ sub_op;
						a_exp        <= 0;
						a_mant       <= 0;
						ready        <= 1;
						fsm_state <= FSM_IDLE;
					end else if (expaz) begin
						// a is zero
						a_sign       <= in_b[31] ^ sub_op;
						a_exp        <= in_b[30:23];
						a_mant[26:4] <= in_b[22:0];
						ready        <= 1;
						fsm_state    <= FSM_IDLE;
					end else if (expbz) begin
						// b is zero
						a_sign       <= in_a[31] ^ sub_op;
						a_exp        <= in_a[30:23];
						a_mant[26:4] <= in_a[22:0];
						ready        <= 1;
						fsm_state    <= FSM_IDLE;
					end else begin
						// a != 0 && b != 0
						if (explt || (expeq && mantlt)) begin
							// swap operands (a,b) => (b,a)
							a_sign    <= in_b[31] ^ sub_op;
							a_mant    <= {1'b0, 1'b1, in_b[22:0], 4'b0};
							a_exp     <= in_b[30:23];
							b_mant    <= {1'b0, 1'b1, in_a[22:0], 4'b0};
							b_exp     <= in_a[30:23];
							exp_delta <= in_b[30:23] - in_a[30:23];
						end else begin
							// normal order
							a_sign    <= in_a[31];
							a_mant    <= {1'b0, 1'b1, in_a[22:0], 4'b0};
							a_exp     <= in_a[30:23];
							b_mant    <= {1'b0, 1'b1, in_b[22:0], 4'b0};
							b_exp     <= in_b[30:23];
							exp_delta <= in_a[30:23] - in_b[30:23];
						end
					end
				end
			end
			
			// align b so it has the same exponent as a
			FSM_ALIGN: begin
				fsm_state     <= FSM_CORE;
				if (USE_BARREL == 1) begin
					if (exp_delta < 31) begin
						// barrel shift
						b_mant    <= b_mant >> exp_delta[4:0];
					end else begin
						// it's zero just grab a sticky bit
						b_mant    <= |b_mant;
					end
				end else begin // USE_BARREL == 0
					if (exp_delta < 31) begin
						if (b_mant != 0 && b_exp < a_exp) begin
							// repeatedly shift b by not zero
							b_mant    <= b_mant >> 1;
							b_exp     <= b_exp + 1'b1;
							fsm_state <= fsm_state;			// stay in ALIGN state
						end
					end else begin
						// shift is excess just sticky it
						b_mant <= |b_mant;
					end
				end
			end
			// do the add or sub
			FSM_CORE: begin
				if (issub) begin
					a_mant <= a_mant - b_mant;
				end else begin
					a_mant <= a_mant + b_mant;
				end
				fsm_state  <= FSM_NORM;
			end
			// normalize the sum and implicitly shift right 4
			FSM_NORM: begin
				if (a_mant[28]) begin
					// bit 24 set so shift right and grab sticky bit
					a_mant <= (a_mant >> 1) | a_mant[0];
					a_exp  <= a_exp + 1'b1;
				end else begin
					if (USE_BIG_STEP == 1 && |a_mant[26:0] && a_mant[27:24] == 4'b0000) begin
						a_mant <= a_mant << 4;
						a_exp  <= a_exp - 4;
					end else if (|a_mant[26:0] & ~a_mant[27]) begin
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
