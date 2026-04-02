// enable IRQs for UART supporting [0] = RX ready, [1] TX empty
//`define USE_UARTIRQ

// Simple IRQ, raises bus_irq if RX ready
`define USE_SIMPLE_UART_IRQ

`ifdef USE_FASTMEM
    `define STACK_ADDRESS 16'h2000
    `define IRQ_VECTOR    16'h1F00
`else
    `define STACK_ADDRESS 16'h1F00
    `define IRQ_VECTOR    16'h1E00
`endif

module top(input clk, input uart_rx, output uart_tx, inout [7:0] gpio);
    localparam
        GPIO_DATA_ADDR   = 16'hFFFB,
        UART_INT_ADDR    = 16'hFFFC,
        UART_INTEN_ADDR  = 16'hFFFD,
        UART_STS_ADDR    = 16'hFFFE,
        UART_DATA_ADDR   = 16'hFFFF;

    wire pllclk;

    Gowin_rPLL ticktock (
        .clkout(pllclk), //output clkout
        .clkin(clk) //input clkin
    );

    reg [3:0] rst = 0;
    wire rst_n = rst[3];

    always @(posedge pllclk) begin
        rst <= {rst[2:0], 1'b1};
    end

    // GPIO
    reg [7:0] gpio_out;
    wire [7:0] gpio_in;

    genvar i;
    generate
        for (i = 0; i < 8; i = i + 1) begin : gpio_en
            assign gpio[i] = gpio_out[i] ? 1'bz : 1'b0;         // requires PULL up 
        end
    endgenerate
    assign gpio_in = gpio;

    wire [15:0] baud_div = 54_000_000 / 230_400;
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

    uart #(.FIFO_DEPTH(4), .RX_ENABLE(1), .TX_ENABLE(1)) mrtalky (
        .clk(pllclk), .rst_n(rst_n),
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

    wire [7:0] bram_dout;
    reg bram_ce;
    reg bram_wre;
    reg [12:0] bram_addr;
    reg [7:0] bram_din;

    // an 8192x8 memory mapped to 0000.1FFF
    Gowin_SP memory(
        .dout(bram_dout), //output [7:0] dout
        .clk(pllclk), //input clk
        .oce(1'b1), //input oce
        .ce(bram_ce), //input ce
        .reset(~rst_n), //input reset
        .wre(bram_wre), //input wre
        .ad(bram_addr), //input [12:0] ad
        .din(bram_din) //input [7:0] din
    );

    wire ib16_bus_enable;
    wire ib16_bus_wr_en;
    wire [15:0] ib16_bus_address;
    wire [15:0] ib16_bus_data_in;
    reg ib16_bus_ready;
    reg [15:0] ib16_bus_data_out;
    reg ib16_bus_irq;
    wire ib16_bus_burst;

    reg [3:0] bus_cycle;
    ib16 #(
        .STACK_ADDRESS(`STACK_ADDRESS),
        .IRQ_VECTOR(`IRQ_VECTOR)) ittybitty(
        .clk(pllclk), .rst_n(rst_n),
        .bus_enable(ib16_bus_enable),
        .bus_wr_en(ib16_bus_wr_en),
        .bus_address(ib16_bus_address),
        .bus_data_in(ib16_bus_data_in),
        .bus_ready(ib16_bus_ready),
        .bus_data_out(ib16_bus_data_out),
        .bus_burst(ib16_bus_burst),
        .bus_irq(ib16_bus_irq));

`ifdef USE_FASTMEM
    reg [7:0] fastmem[0:`FASTMEM_SIZE - 1];
`endif
    // bus controller
    always @(posedge pllclk) begin
        if (!rst_n) begin
            uart_tx_start       <= 0;
            uart_tx_data_in     <= 0;
            uart_rx_read        <= 0;
            bram_ce             <= 0;
            bram_wre            <= 0;
            bram_addr           <= 0;
            bram_din            <= 0;
            ib16_bus_ready      <= 0;
            ib16_bus_data_out   <= 0;
            ib16_bus_irq        <= 0;
            bus_cycle           <= 0;
            gpio_out            <= 8'hFF;
`ifdef USE_UARTIRQ
            uart_prev_rx_ready  <= 0;
            uart_prev_tx_fifo_empty <= 0;
            uart_int_enable     <= 0;
            uart_int_pending    <= 0;
`endif
        end else begin
`ifdef USE_UARTIRQ
            // trap uart IRQ
            uart_int_pending[0] <= (uart_prev_rx_ready != uart_rx_ready && uart_rx_ready) ? 1'b1 : 1'b0;
            uart_int_pending[1] <= (uart_prev_tx_fifo_empty != uart_tx_fifo_empty && uart_tx_fifo_empty) ? 1'b1 : 1'b0;
            uart_prev_rx_ready <= uart_rx_ready;
            uart_prev_tx_fifo_empty <= uart_tx_fifo_empty;
            ib16_bus_irq <= |(uart_int_pending & uart_int_enable);
`endif
`ifdef USE_SIMPLE_UART_IRQ
            ib16_bus_irq <= uart_rx_ready;
`endif
            // normal mode
            if (ib16_bus_enable && !ib16_bus_ready) begin
                // handle new command
                // GPIO port
                if (ib16_bus_address == GPIO_DATA_ADDR) begin
                    if (ib16_bus_wr_en) begin
                        gpio_out <= ib16_bus_data_in[7:0];
                    end else begin
                        ib16_bus_data_out <= gpio_in;
                    end
                    ib16_bus_ready <= 1;
                end
`ifdef USE_UARTIRQ
                // UART Interrupt enable
                if (ib16_bus_address == UART_INT_ADDR) begin
                    if (ib16_bus_wr_en) begin
                        uart_int_pending <= uart_int_pending[1:0] & ~ib16_bus_data_in[1:0];
                    end else begin
                        ib16_bus_data_out <= {6'b0, uart_int_pending};
                    end
                    ib16_bus_ready <= 1;
                end
                // UART Interrupt enable
                if (ib16_bus_address == UART_INTEN_ADDR) begin
                    if (ib16_bus_wr_en) begin
                        uart_int_enable <= ib16_bus_data_in[1:0];
                    end else begin
                        ib16_bus_data_out <= {6'b0, uart_int_enable};
                    end
                    ib16_bus_ready <= 1;
                end
`endif
                // UART Status register
                if (ib16_bus_address == UART_STS_ADDR) begin
                    if (ib16_bus_wr_en) begin
                    end else begin
                        ib16_bus_data_out <= {13'b0, uart_tx_fifo_empty, uart_tx_fifo_full, uart_rx_ready};
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
                                        uart_tx_data_in <= ib16_bus_data_in[7:0];
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
                if (ib16_bus_address < 16'h2000) begin
                    // BRAM block
                    case(bus_cycle)
                        0: // start transaction (this cycle delay handles the fact that bus_address is combinatorial)
                            begin
                                bram_ce     <= 1;
                                bram_wre    <= ib16_bus_wr_en;
                                bram_addr   <= ib16_bus_address[12:0];
                                bram_din    <= ib16_bus_data_in[7:0];
                                bus_cycle   <= bus_cycle + 1'b1;
                            end
                        1: // memory 2nd cycle
                            begin
                                if (bram_wre && !ib16_bus_burst) begin // 8-bit writes are done here
                                    bus_cycle       <= 0;
                                    bram_wre        <= 0;
                                    bram_ce         <= 0;
                                    ib16_bus_ready  <= 1;
                                end else begin                     // all reads take 3 cycles, burst writes take 3  
                                    bus_cycle       <= bus_cycle + 1'b1;
                                    bram_addr       <= bram_addr + 1'b1;
                                    bram_din        <= ib16_bus_data_in[15:8];
                                end
                            end
                        2: // memory 3rd cycle
                            begin
                                if (bram_wre) begin // writes are done here
                                    bram_ce             <= 0;
                                    bram_wre            <= 0;
                                    bus_cycle           <= 0;
                                    ib16_bus_ready      <= 1;
                                end else begin
                                    ib16_bus_data_out[7:0] <= bram_dout;
                                    if (!ib16_bus_burst) begin          // 8-bit reads are done here
                                        bus_cycle       <= 0;
                                        bram_ce         <= 0;
                                        ib16_bus_ready  <= 1;
                                    end else begin
                                        bus_cycle       <= bus_cycle + 1'b1;
                                    end
                                end
                            end
                        3: // memory 4th cycle (16-bit reads)
                            begin
                                ib16_bus_data_out[15:8] <= bram_dout;
                                bus_cycle               <= 0;
                                bram_ce                 <= 0;
                                ib16_bus_ready          <= 1;
                            end
                    endcase
                end
                if (ib16_bus_address >= 16'h2000 && ib16_bus_address <= 16'h2100) begin
                    if (!ib16_bus_wr_en) begin
                        case(ib16_bus_address[7:0])
                            8'h00: ib16_bus_data_out <= 16'h0EFF;
                            8'h02: ib16_bus_data_out <= 16'h0FFF;
                            8'h04: ib16_bus_data_out <= 16'h0000;
                            8'h06: ib16_bus_data_out <= 16'h0100;
                            8'h08: ib16_bus_data_out <= 16'h021F;
                            8'h0A: ib16_bus_data_out <= 16'h045A;
                            8'h0C: ib16_bus_data_out <= 16'h83FE;
                            8'h0E: ib16_bus_data_out <= 16'h4334;
                            8'h10: ib16_bus_data_out <= 16'hD9FD;
                            8'h12: ib16_bus_data_out <= 16'h83FE;
                            8'h14: ib16_bus_data_out <= 16'h93FE;
                            8'h16: ib16_bus_data_out <= 16'h9310;
                            8'h18: ib16_bus_data_out <= 16'h7050;
                            8'h1A: ib16_bus_data_out <= 16'hD5FB;
                            8'h1C: ib16_bus_data_out <= 16'h7151;
                            8'h1E: ib16_bus_data_out <= 16'h7262;
                            8'h20: ib16_bus_data_out <= 16'hD9F8;
                            8'h22: ib16_bus_data_out <= 16'hE000;
                            8'h24: ib16_bus_data_out <= 16'hB000;
                            8'h26: ib16_bus_data_out <= 16'hD1EC;
                            default: begin end
                        endcase
                    end
                    ib16_bus_ready <= 1;
                end
            end if (ib16_bus_ready && !ib16_bus_enable) begin
                ib16_bus_ready <= 0;
            end
        end
    end
endmodule 