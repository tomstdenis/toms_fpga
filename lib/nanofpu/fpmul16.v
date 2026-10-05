/*
	Fixed point 16.16 multiplication
*/
`default_nettype none

module fpmul16
#(
	parameter DSP_MULT=0			// 0 = use 16x16 multiplier, 1 = use 32x32 multiplier
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
	reg [1:0]  fsm_state;
	reg [63:0] product;
	assign out = product[47:16];

	reg [31:0] p00_prod;
	reg [31:0] p01_prod;
	reg [31:0] p10_prod;
	reg [31:0] p11_prod;

	localparam
		FSM_IDLE = 0,
		FSM_REG  = 1;

	always @(posedge clk) begin
		ready     <= 1'b0;
		case (fsm_state)
			FSM_IDLE: begin
				if (~ready & valid) begin
					if (DSP_MULT == 0) begin
						p00_prod  <= in_a[15:0] * in_b[15:0];
						p01_prod  <= in_a[15:0] * in_b[31:16];
						p10_prod  <= in_a[31:16] * in_b[15:0];
						p11_prod  <= in_a[31:16] * in_b[31:16];
						fsm_state <= FSM_REG;
					end else begin
						product   <= in_a * in_b;
						ready     <= 1;
					end
				end
			end
			FSM_REG: begin
				if (DSP_MULT == 0) begin
					product   <= (p11_prod << 32) + ((p10_prod + p01_prod) << 16) + p00_prod;
					ready     <= 1;
					fsm_state <= FSM_IDLE;
				end
			end
		endcase

		if (~rst_n) begin
			fsm_state <= FSM_IDLE;
		end
	end
endmodule
