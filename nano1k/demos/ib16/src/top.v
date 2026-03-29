module top(input clk, input uart_rx, output uart_tx, inout [7:0] gpio);
    localparam
        UART_DATA_ADDR = 16'hFFFF;

    reg [3:0] rst = 0;
    wire rst_n = rst[3];

    always @(posedge clk) begin
        rst <= {rst[2:0], 1'b1};
    end

    wire [15:0] baud_div = 27_000_000 / 115_200;
    reg uart_tx_start;
    reg [7:0] uart_tx_data_in;
    wire uart_tx_fifo_full;
    wire uart_tx_fifo_empty;
    reg uart_rx_read;
    wire uart_rx_ready;
    wire [7:0] uart_rx_byte;

    uart #(.FIFO_DEPTH(4), .RX_ENABLE(1), .TX_ENABLE(1)) mrtalky (
        .clk(clk), .rst_n(rst_n),
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
        .clk(clk), //input clk
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

    ib16 ittybitty(
        .clk(clk), .rst_n(rst_n & run_mode),
        .bus_enable(ib16_bus_enable),
        .bus_wr_en(ib16_bus_wr_en),
        .bus_address(ib16_bus_address),
        .bus_data_in(ib16_bus_data_in),
        .bus_ready(ib16_bus_ready),
        .bus_data_out(ib16_bus_data_out),
        .bus_irq(ib16_bus_irq));

    // bus controller
    always @(posedge clk) begin
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
        end else 
            if (!run_mode) begin
                // handle boot loader
                case(bus_cycle)
                    0: //wait for RX
                        begin
                            if (uart_rx_ready) begin
                                uart_rx_read    <= 1;
                                bus_cycle       <= 1;
                            end
                        end
                    1: // delay (waiting for uart to handle request)
                        begin
                            uart_rx_read    <= 0;
                            bus_cycle       <= 2;
                        end
                    2: // store byte
                        begin
                            bram_wre    <= 1;
                            bram_ce     <= 1;
                            bram_addr   <= boot_addr[12:0];
                            bram_din    <= uart_rx_byte;
                            boot_addr   <= boot_addr;
                            bus_cycle   <= 3;
                        end
                    3: // read back?
                        begin
                            bram_wre    <= 0;
                            bus_cycle   <= 4;
                        end
                    4: 
                        begin
                            bus_cycle <= 5;
                        end
                    5: // transmit data read back
                        begin
                            uart_tx_start       <= 1;
                            uart_tx_data_in     <= bram_dout;
                            bus_cycle           <= 6;
                        end
                    6: // turn off TX and next byte
                        begin
                            uart_tx_start       <= 0;
                            boot_addr           <= boot_addr + 1;
                            if (boot_addr == 16'h1FFF) begin
                                run_mode        <= 1;
                            end
                            bus_cycle           <= 0;
                        end
                endcase
            end else begin
                // normal mode
                if (ib16_bus_enable && !ib16_bus_ready) begin
                    // handle new command
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
                                        uart_rx_read <= 0;
                                        bus_cycle    <= 2;
                                    end
                                2: // store byte and go back to idle
                                    begin
                                        ib16_bus_data_out   <= uart_rx_byte;
                                        bus_cycle           <= 0;
                                        ib16_bus_ready      <= 1;
                                    end
                            endcase
                        end
                    end else if (ib16_bus_address < 16'h2000) begin
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
                                        bus_cycle           <= 0;
                                        bram_wre            <= 0;
                                        bram_ce             <= 0;
                                        ib16_bus_ready      <= 1;
                                    end else begin
                                        bus_cycle           <= 2;
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