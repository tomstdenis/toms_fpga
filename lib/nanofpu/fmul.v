/*
	float multiply, rounds to zero, tracks overflow/underflow does not track subnorm
	
*/

`default_nettype none
module fmul
#(
	parameter USE_TWO_STAGE_CMP=1,
	parameter USE_MULT=1
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
	
	localparam
		FSM_IDLE  = 0,
		FSM_CMP   = 1,
		FSM_CORE  = 2,
		FSM_REG   = 3,
		FSM_REG2  = 4,
		FSM_NORM  = 5;
	
	reg [47:0] da_prod;
	reg [47:0] da_opa;
	reg [4:0]  da_cnt;
	
	reg [35:0] p00_prod;
	reg [35:0] p01_prod;
	reg [35:0] p10_prod;
	reg [35:0] p11_prod;

	reg isnan_a;
    reg isnan_b;
    reg isaz;
    reg isbz;
	wire isnan_a_next = (in_a[30:23] == 8'hFF && (|in_a[22:0] == 1'b1)) ? 1'b1 : 1'b0;
	wire isnan_b_next = (in_b[30:23] == 8'hFF && (|in_b[22:0] == 1'b1)) ? 1'b1 : 1'b0;
	wire isaz_next    = (in_a[30:23] == 0) ? 1'b1 : 1'b0;
	wire isbz_next    = (in_b[30:23] == 0) ? 1'b1 : 1'b0;

	assign out = {a_sign, a_exp[7:0], a_mant[22:0]};

	always @(posedge clk) begin
		ready     <= 1'b0;
		case (fsm_state)
			FSM_IDLE: begin
				if (~ready & valid) begin
					a_sign    <= in_a[31] ^ in_b[31];  // sign of product
					if (USE_TWO_STAGE_CMP == 1) begin
                        isnan_a   <= isnan_a_next;
                        isnan_b   <= isnan_b_next;
                        isaz      <= isaz_next;
                        isbz      <= isbz_next;
                        fsm_state <= FSM_CMP;
					end else begin
						if (isnan_a_next || isnan_b_next) begin
							a_exp  <= 8'hFF;
							a_mant <= {1'b1, 22'b0};
							ready  <= 1'b1;
						end else if (isaz_next || isbz_next) begin
							// multiplying by zero, short cut to zero result
							a_exp  <= 0;
							a_mant <= 0;
							ready  <= 1'b1;
						end else begin
							a_mant    <= {1'b1, in_a[22:0]};
							a_exp     <= {2'b0, in_a[30:23]} + {2'b0, in_b[30:23]} - 10'd127;
							b_mant    <= {1'b1, in_b[22:0]};
							if (USE_MULT == 0 || USE_MULT == 3) begin
								da_opa  <= {24'b0, 1'b1, in_a[22:0]};
								da_prod <= 0;
								da_cnt  <= 24;
							end
							fsm_state <= FSM_CORE;
						end
					end
				end
			end

			FSM_CMP: begin
				if (USE_TWO_STAGE_CMP == 1) begin
					if (isnan_a || isnan_b) begin
						a_exp     <= 8'hFF;
						a_mant    <= {1'b1, 22'b0};
						ready     <= 1'b1;
						fsm_state <= FSM_IDLE;
					end else if (isaz || isbz) begin
						// multiplying by zero, short cut to zero result
						a_exp     <= 0;
						a_mant    <= 0;
						ready     <= 1'b1;
						fsm_state <= FSM_IDLE;
					end else begin
						a_mant    <= {1'b1, in_a[22:0]};
						a_exp     <= {2'b0, in_a[30:23]} + {2'b0, in_b[30:23]} - 10'd127;
						b_mant    <= {1'b1, in_b[22:0]};
						if (USE_MULT == 0 || USE_MULT == 3) begin
							da_opa  <= {24'b0, 1'b1, in_a[22:0]};
							da_prod <= 0;
							da_cnt  <= 24;
						end
						fsm_state <= FSM_CORE;
					end
				end
			end

			FSM_CORE: begin
				if (USE_MULT == 2) begin
					// using 18x18 multipliers we break the 24x24 mult into
					// four pieces
					p00_prod <= a_mant[17:0] * b_mant[17:0];
					p01_prod <= a_mant[17:0] * b_mant[23:18];
					p10_prod <= a_mant[23:18] * b_mant[17:0];
					p11_prod <= a_mant[23:18] * b_mant[23:18];
					fsm_state <= FSM_REG2;
				end else if (USE_MULT == 1) begin
					// using 36x36 multipliers 
					da_prod     <= a_mant[23:0] * b_mant[23:0];
					fsm_state   <= FSM_REG;
				end else if (USE_MULT == 3) begin
					// 2-bit double and add
					b_mant <= b_mant >> 2;
					da_opa <= da_opa << 2;
					// in theory we could precompute 2x and 3x but this
					// path seems to be fine on my ECP5/GW5A-60B
					case (b_mant[1:0])
						2'b00: da_prod <= da_prod;
						2'b01: da_prod <= da_prod + da_opa;
						2'b10: da_prod <= da_prod + (da_opa << 1);
						2'b11: da_prod <= da_prod + (da_opa + (da_opa << 1));
					endcase;
					da_cnt <= da_cnt - 2;
					if (da_cnt == 0) begin
						a_mant <= da_prod[47:23];
						fsm_state <= FSM_NORM;
					end
				end else begin // (USE_MULT == 0)
					// 1-bit double and add
					b_mant <= b_mant >> 1;
					da_opa <= da_opa << 1;
					case (b_mant[0])
						1'b0: da_prod <= da_prod;
						1'b1: da_prod <= da_prod + da_opa;
					endcase;
					da_cnt <= da_cnt - 1;
					if (da_cnt == 0) begin
						a_mant <= da_prod[47:23];
						fsm_state <= FSM_NORM;
					end
				end
			end
			// register the product when in 18x18 mode by summing the smaller products
			FSM_REG2: begin
				if (USE_MULT == 2) begin
					da_prod   <= p00_prod + ((p01_prod + p10_prod) << 18) + (p11_prod << 36);
					fsm_state <= FSM_REG;
				end
			end
			// register the 48-bit product into the mantissa
			FSM_REG: begin
				if (USE_MULT == 1 || USE_MULT == 2) begin
					a_mant    <= da_prod[47:23];
					fsm_state <= FSM_NORM;
				end
			end
			// normalize the product and return
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
			fsm_state                          <= FSM_IDLE;
			{a_sign, a_exp[7:0], a_mant[22:0]} <= 32'b0; // reset output
		end
	end
endmodule
