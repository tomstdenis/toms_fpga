// enable IRQs for UART supporting [0] = RX ready, [1] TX empty
//`define USE_UARTIRQ

// Simple IRQ, raises bus_irq if RX ready
`define USE_SIMPLE_UART_IRQ
`default_nettype none

`define STACK_ADDRESS 16'hF00
`define IRQ_VECTOR    16'hE00

module top(input clk, input uart_rx, output uart_tx, output [7:0] gpio);
    localparam
        GPIO_DATA_ADDR   = 16'hFFFB,
        UART_INT_ADDR    = 16'hFFFC,
        UART_INTEN_ADDR  = 16'hFFFD,
        UART_STS_ADDR    = 16'hFFFE,
        UART_DATA_ADDR   = 16'hFFFF;

	wire pll_clk = clk;
	wire pll_lock;
	
    reg [3:0] rst = 0;
    wire rst_n = rst[3];

    always @(posedge pll_clk) begin
		rst <= {rst[2:0], 1'b1};
    end

    // GPIO
    reg [7:0] gpio_out;
    wire [7:0] gpio_in;

// TODO use primitive for this ...
	assign gpio = gpio_out;
    assign gpio_in = gpio_out;

    wire [15:0] baud_div = 12_000_000 / 115_200;
    reg uart_tx_start;
    reg [7:0] uart_tx_data_in;
    wire uart_tx_fifo_full;
    wire uart_tx_fifo_empty;
    reg uart_rx_read;
    wire uart_rx_ready;
    wire [7:0] uart_rx_byte;
`ifdef USE_UARTIRQ
    reg uart_prev_tx_fifo_empty;
    reg uart_prev_rx_ready;
    reg [1:0] uart_int_enable;
    reg [1:0] uart_int_pending;
`endif

    uart #(.FIFO_DEPTH(2), .RX_ENABLE(1), .TX_ENABLE(1)) mrtalky (
        .clk(pll_clk), .rst_n(rst_n),
        .baud_div(baud_div),
        .uart_tx_start(uart_tx_start),
        .uart_tx_data_in(uart_tx_data_in),
        .uart_tx_pin(uart_tx),
        .uart_tx_fifo_empty(uart_tx_fifo_empty),
        .uart_tx_fifo_full(uart_tx_fifo_full),
        .uart_rx_pin(uart_rx),
        .uart_rx_read(uart_rx_read),
        .uart_rx_ready(uart_rx_ready),
        .uart_rx_byte(uart_rx_byte));

	// main memory
	//access to spram
	reg [7:0]  main_mem[0:4095];
	reg [11:0] main_mem_next_addr;

    wire ib16_bus_enable;
    wire ib16_bus_wr_en;
    wire [15:0] ib16_bus_address;
    wire [15:0] ib16_bus_data_in;
    reg ib16_bus_ready;
    reg [15:0] ib16_bus_data_out;
    reg [7:0] ib16_bus_irq;
    wire ib16_bus_burst;
    
    reg [3:0] bus_cycle;

    ib16 #(
        .STACK_ADDRESS(`STACK_ADDRESS),
        .IRQ_VECTOR(`IRQ_VECTOR),
        .TWO_CYCLE(1)) ittybitty(
        .clk(pll_clk), .rst_n(rst_n),
        .bus_enable(ib16_bus_enable),
        .bus_wr_en(ib16_bus_wr_en),
        .bus_address(ib16_bus_address),
        .bus_data_in(ib16_bus_data_in),
        .bus_ready(ib16_bus_ready),
		.bus_burst(ib16_bus_burst),
        .bus_data_out(ib16_bus_data_out),
        .bus_irq(ib16_bus_irq));

    // bus controller
    always @(posedge pll_clk) begin
        if (!rst_n) begin
            uart_tx_start       <= 0;
            uart_tx_data_in     <= 0;
            uart_rx_read        <= 0;
            ib16_bus_ready      <= 0;
            ib16_bus_data_out   <= 0;
            ib16_bus_irq        <= 0;
            bus_cycle           <= 0;
            gpio_out            <= 8'hFF;
        end else begin
			ib16_bus_irq <= uart_rx_ready;

			// normal mode
			if (ib16_bus_enable && !ib16_bus_ready) begin
				// handle new command
				// GPIO port
				if (ib16_bus_address == GPIO_DATA_ADDR) begin
					if (ib16_bus_wr_en) begin
						gpio_out <= ib16_bus_data_in;
					end else begin
						ib16_bus_data_out <= gpio_in;
					end
					ib16_bus_ready <= 1;
				end

				// UART Status register
				if (ib16_bus_address == UART_STS_ADDR) begin
					if (ib16_bus_wr_en) begin
					end else begin
						ib16_bus_data_out <= {5'b0, uart_tx_fifo_empty, uart_tx_fifo_full, uart_rx_ready};
					end
					ib16_bus_ready <= 1;
				end 
				// UART data register
				if (ib16_bus_address == UART_DATA_ADDR) begin
					if (ib16_bus_wr_en) begin
						case(bus_cycle)
							0: // wait for a FIFO slot
								begin
									if (!uart_tx_fifo_full) begin
										uart_tx_data_in <= ib16_bus_data_in;
										uart_tx_start   <= 1;
										bus_cycle       <= 1;
									end
								end
							1: // deassert and go to ready
								begin
									uart_tx_start   <= 0;
									bus_cycle       <= 0;
									ib16_bus_ready  <= 1;
								end
						endcase
					end else begin
						case(bus_cycle)
							0: // wait for incoming byte
								begin
									if (uart_rx_ready) begin
										uart_rx_read    <= 1;
										bus_cycle       <= 1;
									end
								end
							1: // deassert read and delay for byte
								begin
									uart_rx_read        <= 0;
									bus_cycle           <= 2;
								end
							2: // store byte and go back to idle
								begin
									ib16_bus_data_out   <= uart_rx_byte;
									bus_cycle           <= 0;
									ib16_bus_ready      <= 1;
								end
						endcase
					end
				end 
				if (ib16_bus_address < 16'h1000) begin
					case(bus_cycle)
						0: begin
								main_mem_next_addr <= ib16_bus_address + 1;
								bus_cycle <= 1;
						   end
						1: begin
							if (ib16_bus_wr_en) begin
								main_mem[main_mem_next_addr] <= ib16_bus_data_in[7:0];
							end else begin
								ib16_bus_data_out[7:0] <= main_mem[main_mem_next_addr];
							end
							if (!ib16_bus_burst) begin
								ib16_bus_ready <= 1;
							end else begin
								bus_cycle <= 1;
							end
							main_mem_next_addr <= main_mem_next_addr + 1;
						   end
						2: begin
							if (ib16_bus_wr_en) begin
								main_mem[main_mem_next_addr] <= ib16_bus_data_in[15:8];
							end else begin
								ib16_bus_data_out[15:8] <= main_mem[main_mem_next_addr];
							end
							ib16_bus_ready <= 1;
							bus_cycle <= 0;
							end
					endcase
				end
                // 2000..20FF is the boot ROM
                if (ib16_bus_address[15:8] == 8'h20) begin
                    case(ib16_bus_address[5:0])
                        8'h00: ib16_bus_data_out <= 16'h0eff;
                        8'h02: ib16_bus_data_out <= 16'h0fff;
                        8'h04: ib16_bus_data_out <= 16'h0000;
                        8'h06: ib16_bus_data_out <= 16'h0100;
                        8'h08: ib16_bus_data_out <= 16'h045a;
                        8'h0a: ib16_bus_data_out <= 16'h93fe;
                        8'h0c: ib16_bus_data_out <= 16'h7134;
                        8'h0e: ib16_bus_data_out <= 16'hd5fd;
                        8'h10: ib16_bus_data_out <= 16'h92fe;
                        8'h12: ib16_bus_data_out <= 16'h93fe;
                        8'h14: ib16_bus_data_out <= 16'ha3fe;
                        8'h16: ib16_bus_data_out <= 16'ha310;
                        8'h18: ib16_bus_data_out <= 16'h8050;
                        8'h1a: ib16_bus_data_out <= 16'hd5fb;
                        8'h1c: ib16_bus_data_out <= 16'h8151;
                        8'h1e: ib16_bus_data_out <= 16'h7112;
                        8'h20: ib16_bus_data_out <= 16'hd402;
                        8'h22: ib16_bus_data_out <= 16'h4000;
                        8'h24: ib16_bus_data_out <= 16'he008;
                        8'h26: ib16_bus_data_out <= 16'h93fe;
                        8'h28: ib16_bus_data_out <= 16'ha310;
                        8'h2a: ib16_bus_data_out <= 16'h8050;
                        8'h2c: ib16_bus_data_out <= 16'hd5fc;
                        8'h2e: ib16_bus_data_out <= 16'hd1f6;
                        default: ib16_bus_data_out <= 16'h0000;
                    endcase
                    ib16_bus_ready <= 1;
                end
                end if (ib16_bus_ready && !ib16_bus_enable) begin
                    ib16_bus_ready <= 0;
                end
            end
        end
endmodule 
