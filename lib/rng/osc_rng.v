`ifndef EXTERNAL_CONFIG
//`define RNG_ECP5
`define RNG_ICE40
`endif

module ring_oscillator #(
    parameter integer STAGES = 5
)(
    input wire enable,
    output wire clk_out,
);

    wire [STAGES-1:0] chain;

    // First stage: NAND gate combining chain[STAGES-1] and enable
    // ECP5 LUT4 with INIT mask for ~(A & B) -> 4'h7 (or similar depending on input mapping)
    // For simplicity, using a structural primitive or primitive LUT:
    // Alternatively, mark instances with keep/dont_touch.

    generate
        // Stage 0: Gated inverter (NAND-equivalent)
        (* keep = "true" *)
`ifdef RNG_ECP5        
        LUT4 #(
            .INIT(16'h7777) // Function dependent on inputs
        ) lut_stages [STAGES-1:0] (
            .Z(chain),
            .A({chain[STAGES-2:0], chain[STAGES-1]}), // feedback loop wrap-around
            .B(enable),
            .C(1'b1),
            .D(1'b1)
        );
`endif
`ifdef RNG_ICE40
        SB_LUT4 #(
            .LUT_INIT(16'h7777) // Function dependent on inputs
        ) lut_stages [STAGES-1:0] (
            .O(chain),
            .I0({chain[STAGES-2:0], chain[STAGES-1]}), // feedback loop wrap-around
            .I1(enable),
            .I2(1'b1),
            .I3(1'b1)
        );
`endif        
    endgenerate
    assign clk_out = chain[STAGES-1];
endmodule

module osc_rng(
	input wire clk,
	input wire rst_n,

	output reg bit,
	output reg strobe
);

	reg [2:0] enable;
	wire osc1_out, osc1_tap;
	wire osc2_out, osc2_tap;
	wire osc3_out, osc3_tap;

	ring_oscillator #(.STAGES(127)) osc1 (.enable(enable[0]), .clk_out(osc1_out));
	ring_oscillator #(.STAGES(211)) osc2 (.enable(enable[1]), .clk_out(osc2_out));
	ring_oscillator #(.STAGES(263)) osc3 (.enable(enable[2]), .clk_out(osc3_out));

	reg [15:0] counter;
	reg [1:0] osc_outs [0:2];
	reg [1:0] buffer;
	reg [31:0] accumulator;
	reg [1:0] filter;

	always @(posedge clk) begin
		strobe      <= 1'b0;
		counter     <= counter + 1;

		osc_outs[0] <= {osc_outs[0][0], osc1_out};
		osc_outs[1] <= {osc_outs[1][0], osc2_out};
		osc_outs[2] <= {osc_outs[2][0], osc3_out};
		buffer      <= {buffer[1] ^ buffer[0], osc_outs[0][1] ^ osc_outs[1][1] ^ osc_outs[2][1]};
		case (counter[1:0])
			0: accumulator <= accumulator ^ (accumulator << 1) ^ buffer[1];
			1: accumulator <= accumulator ^ (accumulator >> 3);
			2: accumulator <= accumulator ^ (accumulator << 10);
			3: accumulator <= accumulator ^ (accumulator >> 11);
		endcase
		filter  <= {filter[1] ^ filter[0], accumulator[0]};

		if (counter == 65535) begin
			enable  <= {enable[1:0], 1'b1};
			strobe  <= &enable & (filter[0] ^ filter[1]);
			bit     <= filter[1];
		end

		if (!rst_n) begin
			enable  <= 3'b000;
			counter <= 0;
			bit     <= 1'b0;
			filter  <= 2'b00;
		end
	end
endmodule
