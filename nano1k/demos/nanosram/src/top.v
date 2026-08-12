module top(
    input wire clk,
    output reg rgb_r,
    output reg rgb_g,
    output reg rgb_b,

    output wire sck_pin,
    output wire cs_pin,
    inout wire [3:0] sio
);

    localparam
        PSRAM  = 1,   // 1 == use PSRAM, 0 == SRAM
        FREQ   = 81,  // clock rate in MHz
        RUNLEN = 16;  // how many bytes to transfer

    wire pllclk;

    Gowin_rPLL MrGoFast(
        .clkout(pllclk), //output clkout
        .clkin(clk) //input clkin
    );

    reg rst_n = 1'b0;

    reg [15:0] sram_addr;
    reg [7:0]  sram_din;
    wire [7:0] sram_dout;
    reg        sram_wr_en;
    reg        sram_start_trans;
    wire       sram_ready;
    wire       sram_busy;
    wire       sram_idle;
    wire       sram_read_strobe;
    wire       sram_write_strobe;

    wire [3:0] sio_din;
    wire [3:0] sio_dout;
    wire       sio_en;

    assign sio     = sio_en ? sio_dout : 4'bzzzz;
    assign sio_din = sio;

    nanosram #(.PSRAM(PSRAM), .FREQ(FREQ)) emm386 (
        .clk(pllclk), .rst_n(rst_n),
        .addr({8'b0, sram_addr}), .data_in(sram_din), .data_out(sram_dout), .wr_en(sram_wr_en),
        .start_trans(sram_start_trans), .ready(sram_ready), .busy(sram_busy), .idle(sram_idle),
        .read_strobe(sram_read_strobe), .write_strobe(sram_write_strobe),
        .sio_din(sio_din), .sio_dout(sio_dout), .sio_en(sio_en), .cs_pin(cs_pin), .sck_pin(sck_pin));

    // simple test go to address 16'h1234 and write 16 bytes starting at value 8'h55 increasing by 1 per bytes
    reg [1:0] test_state;
    reg [1:0] test_tag;
    reg [1:0] test_cycle;

    localparam
        STATE_START_WRITE = 0,
        STATE_LOOP_WRITE  = 1,
        STATE_START_READ  = 2,
        STATE_LOOP_READ   = 3;

    always @(posedge pllclk) begin
        if (!rst_n) begin
            rst_n            <= 1'b1;
            sram_start_trans <= 1'b0;
            sram_wr_en       <= 1'b0;
            rgb_r            <= 1'b1;
            rgb_g            <= 1'b1;
            rgb_b            <= 1'b1;
            test_state       <= STATE_START_WRITE;
            test_cycle       <= 0;
        end else begin
            case (test_state)
                STATE_START_WRITE:
                    begin
                        if (sram_idle) begin
                            sram_addr             <= 16'h1234;
                            sram_din              <= 8'h2A;
                            sram_start_trans      <= 1'b1;
                            sram_wr_en            <= 1'b1;
                            {rgb_r, rgb_g, rgb_b} <= 3'b101; // green == writing
                            test_state            <= STATE_LOOP_WRITE;
                        end
                    end
                STATE_LOOP_WRITE:                                               // by this point we're in SHIFT_QUAD
                    begin
                        if (sram_ready & sram_write_strobe) begin
                            // the write strobe occurs BEFORE the current byte is finished so if we lower
                            // start_trans the FSM will stop writing with the current byte being shifted out
                            if (sram_addr == (16'h1234 + RUNLEN - 1)) begin
                                sram_start_trans <= 0;
                                test_state       <= STATE_START_READ;
                            end else begin
                                sram_addr        <= sram_addr + 1'b1;
                                sram_din         <= sram_din + 1'b1;
                            end
                        end
                    end
                STATE_START_READ:
                    begin
                        if (sram_idle) begin
                            sram_addr             <= 16'h1234;
                            sram_wr_en            <= 1'b0;
                            sram_start_trans      <= 1'b1;
                            {rgb_r, rgb_g, rgb_b} <= 3'b110; // blue == read
                            test_state            <= STATE_LOOP_READ;
                        end
                    end
                STATE_LOOP_READ:                                               // by this point we're in SHIFT_QUAD
                    begin
                        if (sram_ready & sram_read_strobe) begin
                            if (sram_addr == (16'h1234 + RUNLEN)) begin
                                {rgb_r, rgb_g, rgb_b} <= 3'b000; // white == good
                            end else begin
								// we're at the 2nd last byte turn off the transaction so it stops reading once it reads
								// byte 1024.  Unlike write_strobe the read_strobe occurs on the cycle the latest byte is
                                // valid so we need to lower the start_trans reg on the count-1 byte.
                                if (sram_addr == (16'h1234 + RUNLEN - 1)) begin
                                    sram_start_trans      <= 1'b0;
                                end
                                if (sram_dout == ((8'h2A + sram_addr[7:0] - 8'h34) & 8'hFF)) begin
                                    sram_addr         <= sram_addr + 1'b1;
                                end else begin 
                                    {rgb_r, rgb_b, rgb_b} <= 3'b011;        // compare error == RED
                                    sram_start_trans      <= 1'b0;
                                end
                            end
                        end
                    end
            endcase
        end
    end
endmodule