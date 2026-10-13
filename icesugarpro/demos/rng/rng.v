`timescale 1ns/1ps
`default_nettype none

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
        LUT4 #(
            .INIT(16'h7777) // Function dependent on inputs
        ) lut_stages [STAGES-1:0] (
            .Z(chain),
            .A({chain[STAGES-2:0], chain[STAGES-1]}), // feedback loop wrap-around
            .B(enable),
            .C(1'b1),
            .D(1'b1)
        );
    endgenerate

    assign clk_out = chain[STAGES-1];
endmodule

module rng(
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

	always @(posedge clk) begin
		strobe      <= 1'b0;
		counter     <= counter + 1;

		osc_outs[0] <= {osc_outs[0][0], osc1_out};
		osc_outs[1] <= {osc_outs[1][0], osc2_out};
		osc_outs[2] <= {osc_outs[2][0], osc3_out};
		buffer      <= {buffer[0], osc_outs[0][1] ^ osc_outs[1][1] ^ osc_outs[2][1]};
		case (counter[1:0])
			0: accumulator <= accumulator ^ buffer[1];
			1: accumulator <= accumulator ^ (accumulator >> 7);
			2: accumulator <= accumulator ^ (accumulator << 13) ^ buffer[1];
			3: accumulator <= accumulator ^ (accumulator >> 9);
		endcase

		if (counter == 65535) begin
			enable  <= {enable[1:0], 1'b1};
			strobe  <= 1'b1;
			bit     <= accumulator[0];
		end

		if (!rst_n) begin
			enable  <= 3'b000;
			counter <= 0;
			bit     <= 1'b0;
		end
	end
endmodule

module top(
	input clk,
	input rx,
	output tx);
	
	reg rst_n;

	localparam
		freq = 100_000_000,
		baud = 1_000_000,
		baudwidth = $clog2(freq / baud);
		
	wire [baudwidth-1:0] bauddiv = freq / baud;
	reg uart_tx_start;
	reg uart_rx_read;
	reg [7:0] uart_tx_data_in;
	wire uart_tx_fifo_full;
	wire uart_rx_ready;
	wire [7:0] uart_rx_byte;
	wire pll_clk;
	wire plllock;
	
	initial begin
		rst_n = 0;
	end
	

	pll mypll(.clkin(clk), .clkout0(pll_clk), .locked(plllock));
		
	uart #(.BAUD_WIDTH(baudwidth), .FIFO_DEPTH(4), .RX_ENABLE(0), .TX_ENABLE(1)) myuart(
		.clk(pll_clk), .rst_n(rst_n),
		.baud_div(bauddiv), 
		.uart_tx_start(uart_tx_start), .uart_tx_data_in(uart_tx_data_in), .uart_tx_pin(tx), .uart_tx_fifo_full(uart_tx_fifo_full),
		.uart_rx_pin(rx), .uart_rx_read(uart_rx_read), .uart_rx_ready(uart_rx_ready), .uart_rx_byte(uart_rx_byte));

	wire bit;
	wire strobe;
	rng myrng (.clk(pll_clk), .rst_n(rst_n), .bit(bit), .strobe(strobe));
	
	reg bit_l;
	reg strobe_l;

	always @(posedge pll_clk) begin
		bit_l         <= strobe ? bit : bit_l;
		strobe_l      <= strobe_l | strobe;
		uart_tx_start <= 1'b0;
		uart_rx_read  <= 1'b0;
		
		if (strobe_l && !uart_tx_fifo_full) begin
			strobe_l        <= 1'b0;
			uart_tx_data_in <= uart_tx_data_in ^ bit_l;
			uart_tx_start   <= 1'b1;
		end

		if (!rst_n) begin
			rst_n           <= 1;
			strobe_l        <= 1'b0;
			bit_l           <= 1'b0;
			uart_tx_data_in <= 8'd64;
		end
	end
endmodule
