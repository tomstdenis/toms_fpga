// Little Timmy 1000 SOC
`default_nettype none

// SOC revision
`define LT1000SOC_REV 8'h00

module lt1000soc
#(
    // *** SOC parameters ***
    parameter CORE_FREQ_KHZ   = 50_000,         // core clock
    parameter CACHE_SIZE_BITS = 13,             // cache for PSRAM region
    parameter TCM_SIZE_BITS   = 16,             // TCM region
    parameter SRAM_ADDR_WIDTH = 24,

    // *** RV parameters ***
    parameter RV_ENABLE_COUNTERS=1,             // 32/64 bit counters
    parameter RV_TWO_CYCLE_COMPARE=0,
    parameter RV_TWO_CYCLE_ALU=0,
 	parameter RV_TWO_STAGE_SHIFT=0,
	parameter RV_BARREL_SHIFTER=1,
    parameter RV_LATCHED_MEM_RDATA=0,
    parameter RV_COMPRESSED_ISA=0,
    parameter RV_ENABLE_MUL=1,
    parameter RV_ENABLE_FAST_MUL=0,
    parameter RV_ENABLE_DIV=1,
    parameter RV_PROGADDR_RESET=32'h0100_0000,
    parameter RV_STACKADDR=32'h0200_8000,

    // *** UART parameters ***
    parameter UART_BAUD       = 1_000_000,
    parameter UART_FIFO_DEPTH = 64
) 
(
    // *** Clocks ***
    input  wire       core_clk,                  // The clock for the CPU
    input  wire       vga_clk,                   // The clock for the VGA
    input  wire       core_rst_n,
    input  wire       vga_rst_n,

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
    output wire       spi_mosi_pin,              // SPI MOSI pin
    output wire       spi_sck_pin,               // SPI SCK  pin
    output reg  [3:0] spi_cs_pin,                // SPI CS   pin

    // *** GPIO ***
    input wire [31:0] gpio_din,                  // GPIO data output
    output reg [31:0] gpio_dout,                 // GPIO data input
    output reg [31:0] gpio_oe,                   // GPIO output enable

    // *** UART ***
    input wire        uart_rx,                   // UART RX pin
    output wire       uart_tx                    // UART TX pin
);

	// core reset
	reg [15:0] crst;
	wire crst_n;
	assign crst_n = crst[15];
	
	always @(posedge core_clk) begin
		if (!core_rst_n) begin
			crst <= 16'b0;
		end else begin
			crst <= {crst[14:0], 1'b1};
		end
	end
	
	// vga reset
	reg [15:0] vrst;
	wire vrst_n;
	assign vrst_n = vrst[15];
	
	always @(posedge vga_clk) begin
		if (!vga_rst_n) begin
			vrst <= 16'b0;
		end else begin
			vrst <= {vrst[14:0], 1'b1};
		end
	end

// memory addressing 
localparam 
    // regions (one hot selector)
    MEM_16M_BIOS  = 24,
    MEM_16M_TCM   = 25,
    MEM_16M_VGA   = 26,
    MEM_16M_PSRAM = 27,
    MEM_16M_MMIO  = 28;

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
        end
        if (tcm_wren[1]) begin
            tcm_lane1[tcm_addr[TCM_SIZE_BITS-1:2]] <= tcm_din1;
        end
        if (tcm_wren[2]) begin
            tcm_lane2[tcm_addr[TCM_SIZE_BITS-1:2]] <= tcm_din2;
        end
        if (tcm_wren[3]) begin
            tcm_lane3[tcm_addr[TCM_SIZE_BITS-1:2]] <= tcm_din3;
        end
        tcm_dout0_tmp <= tcm_lane0[tcm_addr[TCM_SIZE_BITS-1:2]];
        tcm_dout0     <= tcm_dout0_tmp;
        tcm_dout1_tmp <= tcm_lane1[tcm_addr[TCM_SIZE_BITS-1:2]];
        tcm_dout1     <= tcm_dout1_tmp;
        tcm_dout2_tmp <= tcm_lane2[tcm_addr[TCM_SIZE_BITS-1:2]];
        tcm_dout2     <= tcm_dout2_tmp;
        tcm_dout3_tmp <= tcm_lane3[tcm_addr[TCM_SIZE_BITS-1:2]];
        tcm_dout3     <= tcm_dout3_tmp;
    end

// *** VGA ***
	reg         cvga_video_mode;
	reg         cvga_page_sel;
    reg         vga_h_blank_l;
    reg         vga_v_blank_l;
    wire        vga_h_blank;
    wire        vga_v_blank;
    reg [1:0]   cvga_h_blank;
    reg [1:0]   cvga_v_blank;
    reg [1:0]   vga_video_mode;
    reg [1:0]   vga_page_sel;
    reg [16:0]  vga_host_addr;
    reg [31:0]  vga_data_in;
    reg [3:0]   vga_wren;
    wire [31:0] vga_data_out;
    
    always @(posedge vga_clk) begin
		if (!vrst_n) begin
			vga_video_mode <= 2'b00;
			vga_page_sel   <= 2'b00;
		end else begin
			vga_video_mode <= {vga_video_mode[0], cvga_video_mode};
			vga_page_sel   <= {vga_page_sel[0], cvga_page_sel};
            vga_h_blank_l  <= vga_h_blank;
            vga_v_blank_l  <= vga_v_blank;
		end
	end

    always @(posedge core_clk) begin
        if (!crst_n) begin
            cvga_h_blank <= 2'b00;
            cvga_v_blank <= 2'b00;
        end else begin
            cvga_h_blank <= {cvga_h_blank[0], vga_h_blank_l};
            cvga_v_blank <= {cvga_v_blank[0], vga_v_blank_l};
        end
    end

    vga vga(
        .vga_clk(vga_clk), .host_clk(core_clk), .rst_n(vrst_n),
        .video_mode(vga_video_mode[1]), .page_sel(vga_page_sel[1]),
        .host_addr(vga_host_addr), .host_data_in(vga_data_in),
        .host_write_mask(vga_wren), .host_data_out(vga_data_out),
        .vga_r(vga_r), .vga_g(vga_g), .vga_b(vga_b), .vga_v_pulse(vga_v_pulse),
        .vga_h_pulse(vga_h_pulse), .vga_v_blank(vga_v_blank), .vga_h_blank(vga_h_blank)
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

    uart #(
        .FIFO_DEPTH(UART_FIFO_DEPTH), .RX_ENABLE(1), .TX_ENABLE(1), .BAUD_WIDTH(BAUD_WIDTH)
    ) uart (
        .clk(core_clk), .rst_n(crst_n), .baud_div(uart_baud),
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
        .CACHE_SIZE(CACHE_SIZE_BITS), 
        .FREQ(CORE_FREQ_KHZ/1000)
    ) psram_mem (
        .clk(core_clk), .rst_n(crst_n),
        .data_in(psram_data_in), .write_mask(psram_write_mask),
        .data_addr(psram_data_addr), .data_wr_en(psram_data_wr_en),
        .data_out(psram_data_out), .valid(psram_valid), .ready(psram_ready),
        .idle(psram_idle),
        .sio_din(psram_sio_din), .sio_dout(psram_sio_dout),
        .sio_en(psram_sio_en), .cs_pin(psram_cs_pin), .sck_pin(psram_sck_pin)
    );

// ** SPI **
    reg        spi_valid;
    wire       spi_idle;
    reg [3:0]  spi_div;
    reg        spi_cs_start;
    reg        spi_cs_end;
    reg [7:0]  spi_mosi_byte;
    wire [7:0] spi_miso_byte;
    wire       spi_m_cs;
    reg [1:0]  spi_cs_sel;

    always @(*) begin
        case (spi_cs_sel)
            2'b00: spi_cs_pin = {1'b1, 1'b1, 1'b1, spi_m_cs};
            2'b01: spi_cs_pin = {1'b1, 1'b1, spi_m_cs, 1'b1};
            2'b10: spi_cs_pin = {1'b1, spi_m_cs, 1'b1, 1'b1};
            2'b11: spi_cs_pin = {spi_m_cs, 1'b1, 1'b1, 1'b1};
        endcase
    end

    spi spi_bus(
        .clk(core_clk), .rst_n(crst_n),
        .valid(spi_valid), .idle(spi_idle),
        .div(spi_div), .cs_start(spi_cs_start), .cs_end(spi_cs_end), .mosi_byte(spi_mosi_byte), .miso_byte(spi_miso_byte),
        .cs_pin(spi_m_cs), .sck_pin(spi_sck_pin), .mosi_pin(spi_mosi_pin), .miso_pin(spi_miso_pin));

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
        .ENABLE_COUNTERS(RV_ENABLE_COUNTERS),
        .ENABLE_COUNTERS64(RV_ENABLE_COUNTERS),
        .TWO_CYCLE_COMPARE(RV_TWO_CYCLE_COMPARE),
        .TWO_CYCLE_ALU(RV_TWO_CYCLE_ALU),
 	    .TWO_STAGE_SHIFT(RV_TWO_STAGE_SHIFT),
	    .BARREL_SHIFTER(RV_BARREL_SHIFTER),
        .LATCHED_MEM_RDATA(RV_LATCHED_MEM_RDATA),
        .COMPRESSED_ISA(RV_COMPRESSED_ISA),
        .ENABLE_MUL(RV_ENABLE_MUL),
        .ENABLE_FAST_MUL(RV_ENABLE_FAST_MUL),
        .ENABLE_DIV(RV_ENABLE_DIV),
        .PROGADDR_RESET(RV_PROGADDR_RESET),
        .STACKADDR(RV_STACKADDR)
    ) picorv32 (
        .clk(core_clk), .resetn(crst_n), .trap(picorv_trap),
        .mem_valid(picorv_mem_valid), .mem_instr(picorv_mem_instr),
        .mem_ready(picorv_mem_ready), .mem_addr(picorv_mem_addr),
        .mem_wdata(picorv_mem_wdata), .mem_wstrb(picorv_mem_wstrb),
        .mem_rdata(picorv_mem_rdata)
    );

// *** BUS ***
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
    reg  [31:0] mmio_data_out;

    // combinatorially connect bus to blocks
    always @(*) begin
        // assign mmio wires
        mmio_reg_mcfg        = 0;
        mmio_reg_mcfg[11:0]  = CORE_FREQ_KHZ / 10;
        mmio_reg_mcfg[19:15] = TCM_SIZE_BITS;
        mmio_reg_mcfg[27:20] = `LT1000SOC_REV;

        // addresses 
        bios_mem_addr   = picorv_mem_addr[12:0];
        tcm_addr        = picorv_mem_addr[TCM_SIZE_BITS-1:0];
        vga_host_addr   = picorv_mem_addr[16:0];
        psram_data_addr = picorv_mem_addr[SRAM_ADDR_WIDTH-1:0];

        // data input routing
        tcm_din0         = picorv_mem_wdata[7:0];
        tcm_din1         = picorv_mem_wdata[15:8];
        tcm_din2         = picorv_mem_wdata[23:16];
        tcm_din3         = picorv_mem_wdata[31:24];
        vga_data_in      = picorv_mem_wdata;
        psram_data_in    = { picorv_mem_wdata[7:0], picorv_mem_wdata[15:8], picorv_mem_wdata[23:16], picorv_mem_wdata[31:24] }; // PSRAM is big endian

        // default to all write enables off
        picorv_mem_rdata  = 32'hBEBEBEEF;
        tcm_wren          = 4'b0000;
        psram_write_mask  = 4'b0000;
        psram_data_wr_en  = 1'b0;
        vga_wren          = 4'b0000;

        if (picorv_mem_addr[MEM_16M_BIOS]) begin
            picorv_mem_rdata = { bios_mem_dout3, bios_mem_dout2, bios_mem_dout1, bios_mem_dout0 };
        end else if (picorv_mem_addr[MEM_16M_TCM]) begin
            tcm_wren         = picorv_mem_valid ? picorv_mem_wstrb : 4'b0000;
            picorv_mem_rdata = { tcm_dout3, tcm_dout2, tcm_dout1, tcm_dout0 };
        end else if (picorv_mem_addr[MEM_16M_VGA]) begin
            vga_wren         = picorv_mem_valid ? picorv_mem_wstrb : 4'b0000;
            picorv_mem_rdata = vga_data_out;
        end else if (picorv_mem_addr[MEM_16M_PSRAM]) begin
            psram_write_mask = picorv_mem_valid ? { picorv_mem_wstrb[0], picorv_mem_wstrb[1], picorv_mem_wstrb[2], picorv_mem_wstrb[3] } : 4'b0000;
            psram_data_wr_en = picorv_mem_valid ? |picorv_mem_wstrb : 1'b0;
            picorv_mem_rdata = { psram_data_out[7:0], psram_data_out[15:8], psram_data_out[23:16], psram_data_out[31:24] };
        end else if (picorv_mem_addr[MEM_16M_MMIO]) begin
            picorv_mem_rdata = mmio_data_out;
        end
    end

    // driver of ready signal
    reg [1:0] bus_cycle;

    always @(posedge core_clk) begin
        // always reset various signals
        uart_tx_start        <= 1'b0;
        uart_rx_read         <= 1'b0;
        picorv_mem_ready     <= 1'b0;
        psram_valid          <= 1'b0;
        spi_valid            <= 1'b0;

        // respond to valid only if ready is already low
        if (~picorv_mem_ready & picorv_mem_valid) begin
            if (picorv_mem_addr[MEM_16M_BIOS] | picorv_mem_addr[MEM_16M_TCM] | picorv_mem_addr[MEM_16M_VGA]) begin
// *** BIOS, TCM, VGA ***
            // simple memories with 1 cycle delay on reads
                if (|picorv_mem_wstrb) begin
                    picorv_mem_ready <= 1'b1;
                end else begin
                    // memory address is set, now we wait two cycles
                    bus_cycle[0]     <= ~bus_cycle[0];
                    picorv_mem_ready <= bus_cycle[0];
                end
            end else if (picorv_mem_addr[MEM_16M_PSRAM]) begin
// *** PSRAM ***
                if (psram_idle & ~bus_cycle) begin
                    // start job
                    bus_cycle        <= 1'b1;
                    psram_valid      <= 1'b1;
                end else if (bus_cycle[0]) begin
                    // wait till ready (and picorv drops valid)
                    bus_cycle[0]     <= ~psram_ready;
                    picorv_mem_ready <= psram_ready;
                end
            end else if (picorv_mem_addr[MEM_16M_MMIO]) begin
// *** MMIO ***
                // default to ready
                picorv_mem_ready <= 1'b1;
                case (picorv_mem_addr[7:0])
                    MMIO_MCFG: begin
                        if (!(|picorv_mem_wstrb)) begin
                            mmio_data_out <= mmio_reg_mcfg;
                        end
                    end
                    MMIO_GPIO_DATA: begin
                        if (picorv_mem_wstrb[0]) begin
                            gpio_dout[7:0] <= picorv_mem_wdata[7:0];
                        end else begin
                            mmio_data_out[7:0] <= gpio_din[7:0];
                        end
                        if (picorv_mem_wstrb[1]) begin
                            gpio_dout[15:8] <= picorv_mem_wdata[15:8];
                        end else begin
                            mmio_data_out[15:8] <= gpio_din[15:8];
                        end
                        if (picorv_mem_wstrb[2]) begin
                            gpio_dout[23:16] <= picorv_mem_wdata[23:16];
                        end else begin
                            mmio_data_out[23:16] <= gpio_din[23:16];
                        end
                        if (picorv_mem_wstrb[3]) begin
                            gpio_dout[31:24] <= picorv_mem_wdata[31:24];
                        end else begin
                            mmio_data_out[31:24] <= gpio_din[31:24];
                        end
                    end
                    MMIO_GPIO_OE: begin
                        if (picorv_mem_wstrb[0]) begin
                            gpio_oe[7:0] <= picorv_mem_wdata[7:0];
                        end else begin
                            mmio_data_out[7:0] <= gpio_oe[7:0];
                        end
                        if (picorv_mem_wstrb[1]) begin
                            gpio_oe[15:8] <= picorv_mem_wdata[15:8];
                        end else begin
                            mmio_data_out[15:8] <= gpio_oe[15:8];
                        end
                        if (picorv_mem_wstrb[2]) begin
                            gpio_oe[23:16] <= picorv_mem_wdata[23:16];
                        end else begin
                            mmio_data_out[23:16] <= gpio_oe[23:16];
                        end
                        if (picorv_mem_wstrb[3]) begin
                            gpio_oe[31:24] <= picorv_mem_wdata[31:24];
                        end else begin
                            mmio_data_out[31:24] <= gpio_oe[31:24];
                        end
                    end
                    MMIO_GPIO_W1S: begin // Write one to set bit
                        if (picorv_mem_wstrb[0]) begin
                            gpio_dout[7:0] <= gpio_dout[7:0] | picorv_mem_wdata[7:0];
                        end
                        if (picorv_mem_wstrb[1]) begin
                            gpio_dout[15:8] <= gpio_dout[15:8] | picorv_mem_wdata[15:8];
                        end
                        if (picorv_mem_wstrb[2]) begin
                            gpio_dout[23:16] <= gpio_dout[23:16] | picorv_mem_wdata[23:16];
                        end
                        if (picorv_mem_wstrb[3]) begin
                            gpio_dout[31:24] <= gpio_dout[31:24] | picorv_mem_wdata[31:24];
                        end
                    end
                    MMIO_GPIO_W1C: begin // Write one to clear bit
                        if (picorv_mem_wstrb[0]) begin
                            gpio_dout[7:0] <= gpio_dout[7:0] & ~picorv_mem_wdata[7:0];
                        end
                        if (picorv_mem_wstrb[1]) begin
                            gpio_dout[15:8] <= gpio_dout[15:8] & ~picorv_mem_wdata[15:8];
                        end
                        if (picorv_mem_wstrb[2]) begin
                            gpio_dout[23:16] <= gpio_dout[23:16] & ~picorv_mem_wdata[23:16];
                        end
                        if (picorv_mem_wstrb[3]) begin
                            gpio_dout[31:24] <= gpio_dout[31:24] & ~picorv_mem_wdata[31:24];
                        end
                    end
                    MMIO_GPIO_W1T: begin // Write one to toggle bit
                        if (picorv_mem_wstrb[0]) begin
                            gpio_dout[7:0] <= gpio_dout[7:0] ^ picorv_mem_wdata[7:0];
                        end
                        if (picorv_mem_wstrb[1]) begin
                            gpio_dout[15:8] <= gpio_dout[15:8] ^ picorv_mem_wdata[15:8];
                        end
                        if (picorv_mem_wstrb[2]) begin
                            gpio_dout[23:16] <= gpio_dout[23:16] ^ picorv_mem_wdata[23:16];
                        end
                        if (picorv_mem_wstrb[3]) begin
                            gpio_dout[31:24] <= gpio_dout[31:24] ^ picorv_mem_wdata[31:24];
                        end
                    end
                    MMIO_UART_DATA: begin
                        if (picorv_mem_wstrb[0]) begin // only care about lower byte
                            if (!uart_tx_fifo_full) begin
                                uart_tx_data_in    <= picorv_mem_wdata[7:0];
                                uart_tx_start      <= 1'b1;
                            end 
                        end else begin
                            // default to all FF if no bytes to read
                            mmio_data_out <= 32'hFFFF_FFFF;
                            if ((bus_cycle == 2'b00) && uart_rx_ready) begin
                                uart_rx_read       <= 1'b1;
                                bus_cycle          <= 2'b01;
                                picorv_mem_ready   <= 1'b0;
                            end
                            if (bus_cycle == 2'b01) begin
                                picorv_mem_ready   <= 1'b0;
                                bus_cycle          <= 2'b11;
                            end
                            if (bus_cycle == 2'b11) begin
                                mmio_data_out   <= {24'h0, uart_rx_byte};
                            end
                        end
                    end
                    MMIO_UART_STATUS: begin
                        mmio_data_out <= { 29'b0, uart_rx_ready, uart_tx_fifo_empty, uart_tx_fifo_full };
                    end
                    MMIO_VGA_CTRL: begin
                        if (picorv_mem_wstrb[0]) begin
                            cvga_video_mode <= picorv_mem_wdata[0];
                            cvga_page_sel   <= picorv_mem_wdata[1];
                        end else begin
                            mmio_data_out  <= { 28'b0, cvga_v_blank[1], cvga_h_blank[1], cvga_page_sel, cvga_video_mode };
                        end
                    end
                    MMIO_SPI_TRANSFER: begin
                        if (picorv_mem_wstrb[2:0] == 3'b111) begin
                            spi_mosi_byte <= picorv_mem_wdata[7:0];
                            spi_div       <= picorv_mem_wdata[11:8];
                            spi_cs_start  <= picorv_mem_wdata[12];
                            spi_cs_end    <= picorv_mem_wdata[13];
                            spi_cs_sel    <= picorv_mem_wdata[15:14];
                            spi_valid     <= picorv_mem_wdata[16];
                        end else begin
                            mmio_data_out <= {23'b0, spi_idle, spi_miso_byte};
                        end
                    end
                    default: mmio_data_out <= 32'hBEBEBEEF;
                endcase
            end else begin // default 16M region that isn't mapped to anything
                // unmapped memory just return ready better than hanging I guess 
                picorv_mem_ready <= 1'b1;
                mmio_data_out <= 32'hBEBEBEEF;
            end
        end else begin // ready & valid (reset things before the next bus access)
            bus_cycle <= 0;
        end
        if (!crst_n) begin
            bus_cycle          <= 1'b0;
            uart_tx_start      <= 1'b0;
            uart_rx_read       <= 1'b0;
            psram_valid        <= 1'b0;
            cvga_page_sel      <= 1'b0;
            cvga_video_mode    <= 1'b0;
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
`include "../../spi/spi.v"