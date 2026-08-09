module top(
    input wire clk,
    output reg rgb_r,
    output reg rgb_g,
    output reg rgb_b,

    output wire sck_pin,
    output wire cs_pin,
    inout wire [3:0] sio
);

    reg rst_n = 1'b0;

    reg [23:0] sram_addr;
    reg [7:0]  sram_din;
    wire [7:0] sram_dout;
    reg        sram_wr_en;
    reg        sram_start_trans;
    reg        sram_shift_data;
    wire       sram_ready;
    wire       sram_busy;
    wire       sram_idle;

    wire [3:0] sio_din;
    wire [3:0] sio_dout;
    wire       sio_en;

    assign sio     = sio_en ? sio_dout : 4'bzzzz;
    assign sio_din = sio;

    nanosram(
        .clk(clk), .rst_n(rst_n),
        .addr(sram_addr), .data_in(sram_din), .data_out(sram_dout), .wr_en(sram_wr_en),
        .start_trans(sram_start_trans), .ready(sram_ready), .shift_data(sram_shift_data), .busy(sram_busy), .idle(sram_idle),
        .sio_din(sio_din), .sio_dout(sio_dout), .sio_en(sio_en), .cs_pin(cs_pin), .sck_pin(sck_pin));

    // simple test go to address 16'h1234 and write 16 bytes starting at value 8'h55 increasing by 1 per bytes
    reg [7:0] test_byte;
    reg [3:0] test_state;
    reg [3:0] test_tag;
    reg [1:0] test_cycle;

    localparam
        STATE_START_WRITE = 0,
        STATE_LOOP_WRITE  = 1,
        STATE_START_READ  = 2,
        STATE_LOOP_READ   = 3;

    always @(posedge clk) begin
        if (!rst_n) begin
            rst_n <= 1'b1;
            sram_start_trans <= 1'b0;
            sram_shift_data  <= 1'b0;
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
                            sram_addr        <= 16'h1234;
                            sram_din         <= 8'h2A;
                            sram_start_trans <= 1'b1;
                            sram_wr_en       <= 1'b1;
                        end
                        if (sram_start_trans & sram_ready) begin
                            {rgb_r, rgb_g, rgb_b} <= 3'b101; // green == writing
                            test_state            <= STATE_LOOP_WRITE;
                            sram_shift_data       <= 1'b1;                      // NS is in WORK_MODE state
                        end
                    end
                STATE_LOOP_WRITE:                                               // by this point we're in SHIFT_QUAD
                    begin
                        sram_shift_data <= 1'b0;
                        if (sram_ready & !sram_shift_data) begin
                            if (sram_addr == (16'h1234 + 16'd256)) begin
                                sram_shift_data  <= 0;
                                sram_start_trans <= 0;
                                test_state       <= STATE_START_READ;
                            end else begin
                                sram_addr        <= sram_addr + 1'b1;
                                sram_din         <= sram_din + 1'b1;
                                sram_shift_data  <= 1'b1;
                            end
                        end
                    end
                STATE_START_READ:
                    begin
                        if (sram_idle) begin
                            sram_addr        <= 16'h1234;
                            sram_wr_en       <= 1'b0;
                            sram_start_trans <= 1'b1;
                        end
                        if (sram_start_trans & sram_ready) begin
                            {rgb_r, rgb_g, rgb_b} <= 3'b110; // blue == read
                            test_state      <= STATE_LOOP_READ;
                            sram_shift_data <= 1'b1;
                        end
                    end
                STATE_LOOP_READ:                                               // by this point we're in SHIFT_QUAD
                    begin
                        sram_shift_data <= 1'b0;
                        if (sram_ready & !sram_shift_data) begin
                            if (sram_addr == (16'h1234 + 16'd256)) begin
                                {rgb_r, rgb_g, rgb_b} <= 3'b000; // white == good
                            end else begin
                                if (sram_dout == ((8'h2A + sram_addr - 16'h1234) & 8'hFF)) begin
                                    sram_addr        <= sram_addr + 1'b1;
                                    sram_shift_data  <= 1'b1;
                                end else begin 
                                    sram_shift_data  <= 1'b0;
                                    {rgb_r, rgb_b, rgb_b} <= 3'b011;
                                end
                            end
                        end
                    end
            endcase
        end
    end
endmodule