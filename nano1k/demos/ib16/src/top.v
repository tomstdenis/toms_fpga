
// Enable a 128-byte fast scratch memory for a smaller stack that is 1 cycle
//`define USE_FASTMEM
`ifdef USE_FASTMEM
    `define STACK_ADDRESS 16'h2000
    `define IRQ_VECTOR    16'h1F00
`else
    `define STACK_ADDRESS 16'h1F00
    `define IRQ_VECTOR    16'h1E00
`endif

// enable IRQs for UART supporting [0] = RX ready, [1] TX empty
//`define USE_UARTIRQ

module top(input clk, input uart_rx, output uart_tx, inout [7:0] gpio);
    localparam
        GPIO_DATA_ADDR   = 16'hFFFB,
        UART_INT_ADDR    = 16'hFFFC,
        UART_INTEN_ADDR  = 16'hFFFD,
        UART_STS_ADDR    = 16'hFFFE,
        UART_DATA_ADDR   = 16'hFFFF;

    wire pllclk;

    Gowin_rPLL your_instance_name(
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

    wire [15:0] baud_div = 54_000_000 / 115_200;
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
    reg [7:0] uart_int_enable;
    reg [7:0] uart_int_pending;
`endif

    uart #(.FIFO_DEPTH(2), .RX_ENABLE(1), .TX_ENABLE(1)) mrtalky (
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
    wire [7:0] ib16_bus_data_in;
    reg ib16_bus_ready;
    reg [7:0] ib16_bus_data_out;
    reg ib16_bus_irq;

    reg [3:0] bus_cycle;
    reg run_mode;
    reg [14:0] boot_addr;
    ib16 #(
        .STACK_ADDRESS(`STACK_ADDRESS),
        .IRQ_VECTOR(`IRQ_VECTOR)) ittybitty(
        .clk(pllclk), .rst_n(rst_n & run_mode),
        .bus_enable(ib16_bus_enable),
        .bus_wr_en(ib16_bus_wr_en),
        .bus_address(ib16_bus_address),
        .bus_data_in(ib16_bus_data_in),
        .bus_ready(ib16_bus_ready),
        .bus_data_out(ib16_bus_data_out),
        .bus_irq(ib16_bus_irq));

`ifdef USE_FASTMEM
    reg [7:0] fastmem[0:127];
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
            run_mode            <= 0;
            boot_addr           <= 0;
            gpio_out            <= 8'hFF;
`ifdef USE_UARTIRQ
            uart_prev_rx_ready  <= 0;
            uart_prev_tx_fifo_empty <= 0;
            uart_int_enable     <= 0;
            uart_int_pending    <= 0;
`endif
        end else 
            if (!run_mode) begin
                // handle boot loader
                case(bus_cycle)
                    0: // flush
                        begin
                            if (uart_rx_ready) begin
                                uart_rx_read    <= 1;
                                bus_cycle       <= 1;
                            end else begin
                                bus_cycle       <= 2;
                            end
                        end
                    1: // flush delay
                        begin
                            uart_rx_read        <= 0;
                            bus_cycle           <= 0;
                        end
                    2: //wait for RX
                        begin
                            if (uart_rx_ready) begin
                                uart_rx_read    <= 1;
                                bus_cycle       <= 3;
                            end
                        end
                    3: // delay (waiting for uart to handle request)
                        begin
                            uart_rx_read        <= 0;
                            bus_cycle           <= 4;
                        end
                    4: // store byte
                        begin
                            bram_wre            <= 1;
                            bram_ce             <= 1;
                            bram_addr           <= boot_addr[12:0];
                            bram_din            <= uart_rx_byte;
                            boot_addr           <= boot_addr;
                            bus_cycle           <= 5;
                        end
                    5: // read back?
                        begin
                            bram_wre            <= 0;
                            bus_cycle           <= 6;
                        end
                    6: // delay for BRAM
                        begin
                            bus_cycle           <= 7;
                        end
                    7: // transmit data read back
                        begin
                            uart_tx_start       <= 1;
                            uart_tx_data_in     <= bram_dout;
                            bus_cycle           <= 8;
                        end
                    8: // turn off TX and next byte
                        begin
                            uart_tx_start       <= 0;
                            boot_addr           <= boot_addr + 1'b1;
                            if (boot_addr == 16'h1FFF) begin
                                run_mode        <= 1;
                                bus_cycle       <= 0;
                            end else begin
                                bus_cycle       <= 2;
                            end
                        end
                endcase
            end else begin
`ifdef USE_UARTIRQ
                // trap uart IRQ
                uart_int_pending[0] <= (uart_prev_rx_ready != uart_rx_ready && uart_rx_ready) ? 1'b1 : 1'b0;
                uart_int_pending[1] <= (uart_prev_tx_fifo_empty != uart_tx_fifo_empty && uart_tx_fifo_empty) ? 1'b1 : 1'b0;
                uart_prev_rx_ready <= uart_rx_ready;
                uart_prev_tx_fifo_empty <= uart_tx_fifo_empty;
                ib16_bus_irq <= |(uart_int_pending & uart_int_enable);
`endif
                // normal mode
                if (ib16_bus_enable && !ib16_bus_ready) begin
                    // handle new command
`ifdef USE_FASTMEM
                    // Fast memory (2000..207F)
                    if (ib16_bus_address[15:8] == 8'h20) begin
                        if (ib16_bus_wr_en) begin
                            fastmem[ib16_bus_address[7:0]] <= ib16_bus_data_in;
                        end else begin
                            ib16_bus_data_out <= fastmem[ib16_bus_address[7:0]];
                        end
                        ib16_bus_ready <= 1;
                    end 
`endif
                    // GPIO port
                    if (ib16_bus_address == GPIO_DATA_ADDR) begin
                        if (ib16_bus_wr_en) begin
                            gpio_out <= ib16_bus_data_in;
                        end else begin
                            ib16_bus_data_out <= gpio_in;
                        end
                        ib16_bus_ready <= 1;
                    end
`ifdef USE_UARTIRQ
                    // UART Interrupt enable
                    if (ib16_bus_address == UART_INT_ADDR) begin
                        if (ib16_bus_wr_en) begin
                            uart_int_pending <= uart_int_pending & ~ib16_bus_data_in;
                        end else begin
                            ib16_bus_data_out <= uart_int_pending;
                        end
                        ib16_bus_ready <= 1;
                    end
                    // UART Interrupt enable
                    if (ib16_bus_address == UART_INTEN_ADDR) begin
                        if (ib16_bus_wr_en) begin
                            uart_int_enable <= ib16_bus_data_in;
                        end else begin
                            ib16_bus_data_out <= uart_int_enable;
                        end
                        ib16_bus_ready <= 1;
                    end
`endif
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
                    if (ib16_bus_address < 16'h2000) begin
                        // BRAM block
                        case(bus_cycle)
                            0: // start transaction
                                begin
                                    bram_ce     <= 1;
                                    bram_wre    <= ib16_bus_wr_en;
                                    bram_addr   <= ib16_bus_address[12:0];
                                    bram_din    <= ib16_bus_data_in;
                                    bus_cycle   <= 1;
                                end
                            1: // memory 2nd cycle
                                begin
                                    if (bram_wre) begin
                                        bus_cycle       <= 0;
                                        bram_wre        <= 0;
                                        bram_ce         <= 0;
                                        ib16_bus_ready  <= 1;
                                    end else begin
                                        bus_cycle       <= 2;
                                    end
                                end
                            2: // memory 3rd cycle
                                begin
                                    bus_cycle           <= 0;
                                    bram_ce             <= 0;
                                    ib16_bus_ready      <= 1;
                                    ib16_bus_data_out   <= bram_dout;
                                end
                        endcase
                    end
                end if (ib16_bus_ready && !ib16_bus_enable) begin
                    ib16_bus_ready <= 0;
                end
            end
        end
endmodule 