// Little Timmy 1000 SOC
`default_nettype none

// SOC revision
`define LT1000SOC_REV 8'h00

// GW5AT-LV60PG484AC1/I0

module lt1000soc
#(
    // *** SOC parameters ***
    parameter CORE_FREQ_KHZ   = 50_000,         // 50MHz default core clock
    parameter CACHE_SIZE_BITS = 12,             // 8KB cache for PSRAM region
    parameter TCM_SIZE_BITS   = 15,             // 32KB TCM region
    parameter SRAM_ADDR_WIDTH = 24,

    // *** RV parameters ***
    parameter RV_TWO_CYCLE_COMPARE=1,
    parameter RV_TWO_CYCLE_ALU=1,
 	parameter RV_TWO_STAGE_SHIFT = 1,
	parameter RV_BARREL_SHIFTER = 0,
    parameter RV_COMPRESSED_ISA=1,
    parameter RV_ENABLE_MUL=1,
    parameter RV_ENABLE_DIV=1,
    parameter RV_PROGADDR_RESET=32'h0100_0000,
    parameter RV_STACKADDR=32'h0200_7FFF,

    // *** UART parameters ***
    parameter UART_BAUD       = 230_400,
    parameter UART_FIFO_DEPTH = 64
) 
(
    // *** Clocks ***
    input  wire       core_clk,                  // The clock for the CPU
    input  wire       vga_clk,                   // The clock for the VGA
    input  wire       rst_n,

    // *** VGA output ***
    output wire [3:0] vga_r,                     // VGA red channel
    output wire [3:0] vga_g,                     // VGA green channel
    output wire [3:0] vga_b,                     // VGA blue channel
    output wire       vga_v_pulse,               // VGA vertical blank pulse
    output wire       vga_h_pulse,               // VGA horizontal blank pulse

    // *** PSRAM ***
    input wire [3:0]  psram_sio_din,             // PSRAM QPI output
    output wire [3:0] psram_sio_dout,            // PSRAM QPI input
    output wire       psram_sio_en,              // PSRAM output enable for QPI
    output wire       psram_cs_pin,              // PSRAM CS pin
    output wire       psram_sck_pin,             // PSRAM SCK pin

    // *** SPI ***
    input wire        spi_miso_pin,              // SPI MISO pin
    output reg        spi_mosi_pin,              // SPI MOSI pin
    output reg        spi_sck_pin,               // SPI SCK  pin
    output reg [3:0]  spi_cs_pin,                // SPI CS   pin

    // *** GPIO ***
    input wire [31:0] gpio_din,                  // GPIO data output
    output reg [31:0] gpio_dout,                 // GPIO data input
    output reg [31:0] gpio_oe,                   // GPIO output enable

    // *** UART ***
    input wire        uart_rx,                   // UART RX pin
    output wire       uart_tx                    // UART TX pin
);

// memory addressing 
localparam 
    // regions (one hot selector)
    MEM_16M_BIOS  = 24,
    MEM_16M_TCM   = 25,
    MEM_16M_VGA   = 26,
    MEM_16M_PSRAM = 27,
    MEM_16M_MMIO  = 28,

    // MMIO address (lower 8 bits)
    MEM_MMIO_MCFG         = 8'h00,
    MEM_MMIO_GPIO_DOUT    = 8'h04,
    MEM_MMIO_GPIO_DIN     = 8'h08,
    MEM_MMIO_GPIO_OE      = 8'h0C,
    MEM_MMIO_GPIO_SET     = 8'h10,
    MEM_MMIO_GPIO_CLEAR   = 8'h14,
    MEM_MMIO_GPIO_TOGGLE  = 8'h18,
    MEM_MMIO_UART_DATA    = 8'h1C,
    MEM_MMIO_UART_STATUS  = 8'h20,
    MEM_MMIO_VGA_CTRL     = 8'h24,
    MEM_MMIO_SPI_TRANSFER = 8'h28;

// *** BIOS ***
    reg [7:0] bios_lane_0[0:2047];
    reg [7:0] bios_lane_1[0:2047];
    reg [7:0] bios_lane_2[0:2047];
    reg [7:0] bios_lane_3[0:2047];
    reg [12:0] bios_mem_addr;
    reg [7:0] bios_mem_dout0;
    reg [7:0] bios_mem_dout1;
    reg [7:0] bios_mem_dout2;
    reg [7:0] bios_mem_dout3;
    reg [7:0] bios_mem_dout0_tmp;
    reg [7:0] bios_mem_dout1_tmp;
    reg [7:0] bios_mem_dout2_tmp;
    reg [7:0] bios_mem_dout3_tmp;
    always @(posedge core_clk) begin
        bios_mem_dout0_tmp <= bios_lane_0[bios_mem_addr[12:2]];
        bios_mem_dout1_tmp <= bios_lane_1[bios_mem_addr[12:2]];
        bios_mem_dout2_tmp <= bios_lane_2[bios_mem_addr[12:2]];
        bios_mem_dout3_tmp <= bios_lane_3[bios_mem_addr[12:2]];
        bios_mem_dout0     <= bios_mem_dout0_tmp;
        bios_mem_dout1     <= bios_mem_dout1_tmp;
        bios_mem_dout2     <= bios_mem_dout2_tmp;
        bios_mem_dout3     <= bios_mem_dout3_tmp;
    end
    initial begin
`include "../bios/bios_lane0.vh"
`include "../bios/bios_lane1.vh"
`include "../bios/bios_lane2.vh"
`include "../bios/bios_lane3.vh"
    end

// *** TCM ***
    reg [7:0] tcm_lane0[0:(1<<(TCM_SIZE_BITS-2))-1];
    reg [7:0] tcm_lane1[0:(1<<(TCM_SIZE_BITS-2))-1];
    reg [7:0] tcm_lane2[0:(1<<(TCM_SIZE_BITS-2))-1];
    reg [7:0] tcm_lane3[0:(1<<(TCM_SIZE_BITS-2))-1];
    reg [7:0] tcm_dout0;
    reg [7:0] tcm_dout1;
    reg [7:0] tcm_dout2;
    reg [7:0] tcm_dout3;
    reg [7:0] tcm_dout0_tmp;
    reg [7:0] tcm_dout1_tmp;
    reg [7:0] tcm_dout2_tmp;
    reg [7:0] tcm_dout3_tmp;
    reg [7:0] tcm_din0;
    reg [7:0] tcm_din1;
    reg [7:0] tcm_din2;
    reg [7:0] tcm_din3;
    reg [3:0] tcm_wren;
    reg [TCM_SIZE_BITS-1:0] tcm_addr;
    always @(posedge core_clk) begin
        if (tcm_wren[0]) begin
            tcm_lane0[tcm_addr[TCM_SIZE_BITS-1:2]] <= tcm_din0;
        end else begin
            tcm_dout0_tmp <= tcm_lane0[tcm_addr[TCM_SIZE_BITS-1:2]];
            tcm_dout0     <= tcm_dout0_tmp;
        end
        if (tcm_wren[1]) begin
            tcm_lane1[tcm_addr[TCM_SIZE_BITS-1:2]] <= tcm_din1;
        end else begin
            tcm_dout1_tmp <= tcm_lane1[tcm_addr[TCM_SIZE_BITS-1:2]];
            tcm_dout1     <= tcm_dout1_tmp;
        end
        if (tcm_wren[2]) begin
            tcm_lane2[tcm_addr[TCM_SIZE_BITS-1:2]] <= tcm_din2;
        end else begin
            tcm_dout2_tmp <= tcm_lane2[tcm_addr[TCM_SIZE_BITS-1:2]];
            tcm_dout2     <= tcm_dout2_tmp;
        end
        if (tcm_wren[3]) begin
            tcm_lane3[tcm_addr[TCM_SIZE_BITS-1:2]] <= tcm_din3;
        end else begin
            tcm_dout3_tmp <= tcm_lane3[tcm_addr[TCM_SIZE_BITS-1:2]];
            tcm_dout3     <= tcm_dout3_tmp;
        end
    end

// *** VGA ***
    reg vga_video_mode;
    reg vga_page_sel;
    reg [16:0] vga_host_addr;
    reg  [31:0] vga_data_in;
    reg [3:0]  vga_wren;
    wire [31:0] vga_data_out;

    vga vga(
        .vga_clk(vga_clk), .host_clk(core_clk), .rst_n(rst_n),
        .video_mode(vga_video_mode), .page_sel(vga_page_sel),
        .host_addr(vga_host_addr), .host_data_in(vga_data_in),
        .host_write_mask(vga_wren), .host_data_out(vga_data_out),
        .vga_r(vga_r), .vga_g(vga_g), .vga_b(vga_b), .vga_v_blank(vga_v_pulse),
        .vga_h_blank(vga_h_pulse)
    );

// *** UART ***
    localparam
        BAUD_DIV   = (CORE_FREQ_KHZ * 1000) / UART_BAUD,
        BAUD_WIDTH = $clog2(BAUD_DIV);

    wire [BAUD_WIDTH-1:0] uart_baud = BAUD_DIV;
    reg        uart_tx_start;
    reg [7:0]  uart_tx_data_in;
    wire       uart_tx_fifo_full;
    wire       uart_tx_fifo_empty;
    reg        uart_rx_read;
    wire       uart_rx_ready;
    wire [7:0] uart_rx_byte;
    reg [31:0] uart_data_out; // for the bus

    uart #(
        .FIFO_DEPTH(UART_FIFO_DEPTH), .RX_ENABLE(1), .TX_ENABLE(1), .BAUD_WIDTH(BAUD_WIDTH)
    ) uart (
        .clk(core_clk), .rst_n(rst_n), .baud_div(uart_baud),
        .uart_tx_start(uart_tx_start), .uart_tx_data_in(uart_tx_data_in),
        .uart_tx_pin(uart_tx), .uart_tx_fifo_full(uart_tx_fifo_full),
        .uart_tx_fifo_empty(uart_tx_fifo_empty), .uart_rx_pin(uart_rx),
        .uart_rx_read(uart_rx_read), .uart_rx_ready(uart_rx_ready),
        .uart_rx_byte(uart_rx_byte)
    );

// *** PSRAM ***
    reg  [31:0] psram_data_in;  // Note bus is LE and this needs BE
    reg [3:0]   psram_write_mask;
    reg [SRAM_ADDR_WIDTH-1:0] psram_data_addr;
    reg         psram_data_wr_en;
    wire [31:0] psram_data_out; // note this is BE and bus needs LE
    reg         psram_valid;
    wire        psram_ready;
    wire        psram_idle;

    nanocache #(
        .CACHE_SIZE(CACHE_SIZE_BITS), .FREQ(CORE_FREQ_KHZ/1000)
    ) psram_mem (
        .clk(core_clk), .rst_n(rst_n),
        .data_in(psram_data_in), .write_mask(psram_write_mask),
        .data_addr(psram_data_addr), .data_wr_en(psram_data_wr_en),
        .data_out(psram_data_out), .valid(psram_valid), .ready(psram_ready),
        .idle(psram_idle),
        .sio_din(psram_sio_din), .sio_dout(psram_sio_dout),
        .sio_en(psram_sio_en), .cs_pin(psram_cs_pin), .sck_pin(psram_sck_pin)
    );

// ** SPI **
   // IOU One SPI module.

// *** RISCV core ***   
    wire picorv_trap;

    wire picorv_mem_valid;
    wire picorv_mem_instr;
    reg  picorv_mem_ready;
    wire [31:0] picorv_mem_addr;
    wire [31:0] picorv_mem_wdata;
    wire [3:0]  picorv_mem_wstrb;
    reg  [31:0] picorv_mem_rdata;

    picorv32 #(
        .TWO_CYCLE_COMPARE(RV_TWO_CYCLE_COMPARE),
        .TWO_CYCLE_ALU(RV_TWO_CYCLE_ALU),
 	    .TWO_STAGE_SHIFT(RV_TWO_STAGE_SHIFT),
	    .BARREL_SHIFTER(RV_BARREL_SHIFTER),
        .COMPRESSED_ISA(RV_COMPRESSED_ISA),
        .ENABLE_MUL(RV_ENABLE_MUL),
        .ENABLE_DIV(RV_ENABLE_DIV),
        .PROGADDR_RESET(RV_PROGADDR_RESET),
        .STACKADDR(RV_STACKADDR)
    ) picorv32 (
        .clk(core_clk), .resetn(rst_n), .trap(picorv_trap),
        .mem_valid(picorv_mem_valid), .mem_instr(picorv_mem_instr),
        .mem_ready(picorv_mem_ready), .mem_addr(picorv_mem_addr),
        .mem_wdata(picorv_mem_wdata), .mem_wstrb(picorv_mem_wstrb),
        .mem_rdata(picorv_mem_rdata)
    );

// *** BUS ***
    reg [31:0]  mmio_data_out;
    reg [31:0]  mmio_data_in;
    reg [3:0]   mmio_wren;
    reg [7:0]   mmio_addr;

    localparam
        MMIO_MCFG         = 8'h00,
        MMIO_GPIO_DATA    = 8'h04,
        MMIO_GPIO_OE      = 8'h08,
        MMIO_GPIO_W1S     = 8'h0C,
        MMIO_GPIO_W1C     = 8'h10,
        MMIO_GPIO_W1T     = 8'h14,
        MMIO_UART_DATA    = 8'h18,
        MMIO_UART_STATUS  = 8'h1C,
        MMIO_VGA_CTRL     = 8'h20,
        MMIO_SPI_TRANSFER = 8'h24;

    reg  [31:0] mmio_reg_mcfg;
    reg  [31:0] mmio_reg_gpio_din;
    reg  [31:0] mmio_reg_uart_status;
    reg  [31:0] mmio_reg_spi_transfer_in;
    wire [31:0] mmio_reg_spi_transfer_out;
    reg         mmio_uart_rx_delay;

    // combinatorially connect bus to blocks
    always @(*) begin
        // assign mmio wires
        mmio_reg_mcfg        = 0;
        mmio_reg_mcfg[11:0]  = CORE_FREQ_KHZ / 10;
        mmio_reg_mcfg[19:15] = TCM_SIZE_BITS;
        mmio_reg_mcfg[27:20] = `LT1000SOC_REV;
        mmio_reg_gpio_din    = gpio_din;
        mmio_reg_uart_status = { 29'b0, uart_rx_ready, uart_tx_fifo_empty, uart_tx_fifo_full };

        // assign inputs
        bios_mem_addr = picorv_mem_addr[12:0];
        tcm_addr = picorv_mem_addr[TCM_SIZE_BITS-1:0];
        tcm_din0 = picorv_mem_wdata[7:0];
        tcm_din1 = picorv_mem_wdata[15:8];
        tcm_din2 = picorv_mem_wdata[23:16];
        tcm_din3 = picorv_mem_wdata[31:24];
        psram_data_addr = picorv_mem_addr[SRAM_ADDR_WIDTH-1:0];
        psram_data_in = // byte swap since PSRAM is BE
            { picorv_mem_wdata[7:0], picorv_mem_wdata[15:8], 
              picorv_mem_wdata[23:16], picorv_mem_wdata[31:24] };
        vga_host_addr = picorv_mem_addr[16:0];
        vga_data_in   = picorv_mem_wdata;
        mmio_addr     = picorv_mem_addr[7:0];
        mmio_data_in  = picorv_mem_wdata;

        // ensure wren's are zeroed out 
        tcm_wren         = 4'b0000;
        psram_write_mask = 4'b0000;
        psram_data_wr_en = 1'b0;
        vga_wren         = 4'b0000;
        mmio_wren        = 1'b0;

        // assign outputs
        picorv_mem_rdata = 32'hBEBEBEEF;

        if (picorv_mem_addr[MEM_16M_BIOS]) begin
            picorv_mem_rdata = { bios_mem_dout3, bios_mem_dout2, bios_mem_dout1, bios_mem_dout0 };
        end else if (picorv_mem_addr[MEM_16M_TCM]) begin
            picorv_mem_rdata = { tcm_dout3, tcm_dout2, tcm_dout1, tcm_dout0 };
            tcm_wren         = picorv_mem_valid ? picorv_mem_wstrb : 4'b0000;
        end else if (picorv_mem_addr[MEM_16M_VGA]) begin
            picorv_mem_rdata = vga_data_out;
            vga_wren         = picorv_mem_valid ? picorv_mem_wstrb : 4'b0000;
        end else if (picorv_mem_addr[MEM_16M_PSRAM]) begin
            picorv_mem_rdata = 
                { psram_data_out[7:0], psram_data_out[15:8],
                  psram_data_out[23:16], psram_data_out[31:24] };
            psram_write_mask = picorv_mem_wstrb;
            psram_data_wr_en = picorv_mem_valid ? |picorv_mem_wstrb : 1'b0;
        end else if (picorv_mem_addr[MEM_16M_MMIO]) begin
            mmio_wren        = picorv_mem_valid ? |picorv_mem_wstrb : 1'b0;
            picorv_mem_rdata = mmio_data_out;
        end
    end

    // driver of ready signal
    reg bus_cycle;

    always @(posedge core_clk) begin
        // always reset various signals
        bus_cycle          <= 1'b0;
        uart_tx_start      <= 1'b0;
        uart_rx_read       <= 1'b0;
        psram_valid        <= 1'b0;
        mmio_uart_rx_delay <= 1'b0;
        picorv_mem_ready   <= 1'b0;

        // respond to valid only if ready is already low
        if (~picorv_mem_ready & picorv_mem_valid) begin
            if (picorv_mem_addr[MEM_16M_BIOS] || 
                picorv_mem_addr[MEM_16M_TCM]  ||
                picorv_mem_addr[MEM_16M_VGA]) begin
// *** BIOS, TCM, VGA ***
            // simple memories with 1 cycle delay on reads
                if (|picorv_mem_wstrb) begin
                    picorv_mem_ready <= 1'b1;
                end else begin
                    bus_cycle        <= 1'b1;
                    picorv_mem_ready <= bus_cycle;
                end
            end else if (picorv_mem_addr[MEM_16M_PSRAM]) begin
// *** PSRAM ***
                if (psram_idle & ~bus_cycle) begin
                    // start job
                    bus_cycle        <= 1'b1;
                    psram_valid      <= 1'b1;
                end else if (bus_cycle) begin
                    // wait till ready (and picorv drops valid)
                    bus_cycle        <= ~psram_ready;
                    picorv_mem_ready <= psram_ready;
                end
            end else if (picorv_mem_addr[MEM_16M_MMIO]) begin
// *** MMIO ***
                // default to ready
                picorv_mem_ready <= 1'b1;
                case (mmio_addr)
                    MMIO_MCFG: begin
                        if (!(|picorv_mem_wstrb)) begin
                            mmio_data_out <= mmio_reg_mcfg;
                        end
                    end
                    MMIO_GPIO_DATA: begin
                        if (picorv_mem_wstrb[0]) begin
                            gpio_dout[7:0] <= mmio_data_in[7:0];
                        end else begin
                            mmio_data_out[7:0] <= gpio_din[7:0];
                        end
                        if (picorv_mem_wstrb[1]) begin
                            gpio_dout[15:8] <= mmio_data_in[15:8];
                        end else begin
                            mmio_data_out[15:8] <= gpio_din[15:8];
                        end
                        if (picorv_mem_wstrb[2]) begin
                            gpio_dout[23:16] <= mmio_data_in[23:16];
                        end else begin
                            mmio_data_out[23:16] <= gpio_din[23:16];
                        end
                        if (picorv_mem_wstrb[3]) begin
                            gpio_dout[31:24] <= mmio_data_in[31:24];
                        end else begin
                            mmio_data_out[31:24] <= gpio_din[31:24];
                        end
                    end
                    MMIO_GPIO_OE: begin
                        if (picorv_mem_wstrb[0]) begin
                            gpio_oe[7:0] <= mmio_data_in[7:0];
                        end else begin
                            mmio_data_out[7:0] <= gpio_oe[7:0];
                        end
                        if (picorv_mem_wstrb[1]) begin
                            gpio_oe[15:8] <= mmio_data_in[15:8];
                        end else begin
                            mmio_data_out[15:8] <= gpio_oe[15:8];
                        end
                        if (picorv_mem_wstrb[2]) begin
                            gpio_oe[23:16] <= mmio_data_in[23:16];
                        end else begin
                            mmio_data_out[23:16] <= gpio_oe[23:16];
                        end
                        if (picorv_mem_wstrb[3]) begin
                            gpio_oe[31:24] <= mmio_data_in[31:24];
                        end else begin
                            mmio_data_out[31:24] <= gpio_oe[31:24];
                        end
                    end
                MMIO_GPIO_W1S: begin // Write one to set bit
                    if (picorv_mem_wstrb[0]) begin
                        gpio_dout[7:0] <= gpio_dout[7:0] | mmio_data_in[7:0];
                    end
                    if (picorv_mem_wstrb[1]) begin
                        gpio_dout[15:8] <= gpio_dout[15:8] | mmio_data_in[15:8];
                    end
                    if (picorv_mem_wstrb[2]) begin
                        gpio_dout[23:16] <= gpio_dout[23:16] | mmio_data_in[23:16];
                    end
                    if (picorv_mem_wstrb[3]) begin
                        gpio_dout[31:24] <= gpio_dout[31:24] | mmio_data_in[31:24];
                    end
                end
                MMIO_GPIO_W1C: begin // Write one to clear bit
                    if (picorv_mem_wstrb[0]) begin
                        gpio_dout[7:0] <= gpio_dout[7:0] & ~mmio_data_in[7:0];
                    end
                    if (picorv_mem_wstrb[1]) begin
                        gpio_dout[15:8] <= gpio_dout[15:8] & ~mmio_data_in[15:8];
                    end
                    if (picorv_mem_wstrb[2]) begin
                        gpio_dout[23:16] <= gpio_dout[23:16] & ~mmio_data_in[23:16];
                    end
                    if (picorv_mem_wstrb[3]) begin
                        gpio_dout[31:24] <= gpio_dout[31:24] & ~mmio_data_in[31:24];
                    end
                end
                MMIO_GPIO_W1T: begin // Write one to toggle bit
                    if (picorv_mem_wstrb[0]) begin
                        gpio_dout[7:0] <= gpio_dout[7:0] ^ mmio_data_in[7:0];
                    end
                    if (picorv_mem_wstrb[1]) begin
                        gpio_dout[15:8] <= gpio_dout[15:8] ^ mmio_data_in[15:8];
                    end
                    if (picorv_mem_wstrb[2]) begin
                        gpio_dout[23:16] <= gpio_dout[23:16] ^ mmio_data_in[23:16];
                    end
                    if (picorv_mem_wstrb[3]) begin
                        gpio_dout[31:24] <= gpio_dout[31:24] ^ mmio_data_in[31:24];
                    end
                end
                MMIO_UART_DATA: begin
                    if (picorv_mem_wstrb[0]) begin // only care about lower byte
                        uart_tx_data_in        <= mmio_data_in[7:0];
                        if (!uart_tx_fifo_full) begin
                            uart_tx_start      <= 1'b1;
                        end 
                    end else begin
                        // default to all FF if no bytes to read
                        mmio_data_out <= 32'hFFFF_FFFF;
                        if (~mmio_uart_rx_delay & ~bus_cycle & uart_rx_ready) begin
                            uart_rx_read       <= 1;
                            bus_cycle          <= 1'b1;
                            picorv_mem_ready   <= ~uart_rx_ready;
                        end
                        if (~mmio_uart_rx_delay & bus_cycle) begin
                            picorv_mem_ready   <= 1'b0;
                            mmio_uart_rx_delay <= 1'b1;
                        end
                        if (mmio_uart_rx_delay) begin
                            mmio_data_out      <= {24'h0, uart_rx_byte};
                        end
                    end
                end
                MMIO_UART_STATUS: begin
                    if (~picorv_mem_wstrb[0]) begin
                        mmio_data_out <= mmio_reg_uart_status;
                    end
                end
                MMIO_VGA_CTRL: begin
                    if (picorv_mem_wstrb[0]) begin
                        vga_video_mode <= mmio_data_in[0];
                        vga_page_sel   <= mmio_data_in[1];
                    end else begin
                        mmio_data_out  <= { 30'b0, vga_page_sel, vga_video_mode };
                    end
                end
                MMIO_SPI_TRANSFER: begin
                    if (picorv_mem_wstrb[0]) begin
                        mmio_reg_spi_transfer_in <= mmio_data_in;
                        // TODO: actually call out to SPI module and block
                        //     : ready until SPI is done
                    end else begin
                        mmio_data_out <= mmio_reg_spi_transfer_out;
                    end
                end
                endcase
            end
        end
        if (!rst_n) begin
            bus_cycle          <= 1'b0;
            uart_tx_start      <= 1'b0;
            uart_rx_read       <= 1'b0;
            psram_valid        <= 1'b0;
            mmio_uart_rx_delay <= 1'b0;
            vga_page_sel       <= 1'b0;
            vga_video_mode     <= 1'b0;
            picorv_mem_ready   <= 1'b0;
            gpio_dout          <= 32'b0;
            gpio_oe            <= 32'b0;
        end
    end
endmodule

`include "picorv32/picorv32.v"
`include "../../uart/blocks/uart.v"
`include "../../uart/blocks/tx_uart.v"
`include "../../uart/blocks/rx_uart.v"
`include "../../nanocache/nanocache.v"
`include "../../nanocache/refmem.v"
`include "../../nanosram/nanosram.v"
`include "../../vga/blocks/vga.v"
`include "../../timer/blocks/timer.v"