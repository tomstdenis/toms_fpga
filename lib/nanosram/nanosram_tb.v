`timescale 1ns/1ps

module nanosram_tb();
	localparam
		DUMMY = 3,
		SRAM_ADDR_WIDTH = 24;

	reg [4:0] test_phase;
	reg clk;
	reg rst_n;
	
    // Parameters
    localparam CLK_PERIOD = 20;    //  50MHz
	
    // Clock Generation
    always #(CLK_PERIOD/2) clk = ~clk;

    reg [23:0] sram_addr;
    reg [7:0]  sram_din;
    wire [7:0] sram_dout;
    reg        sram_wr_en;
    reg        sram_start_trans;
    reg        sram_shift_data;
    wire       sram_trans_started;
    wire       sram_busy;
    wire       sram_idle;

    wire [3:0] sio_din;
    wire [3:0] sio_dout;
    wire       sio_en;
    wire       cs_pin;
	wire	   sck_pin;

    nanosram dut(
        .clk(clk), .rst_n(rst_n),
        .addr(sram_addr), .data_in(sram_din), .data_out(sram_dout), .wr_en(sram_wr_en),
        .start_trans(sram_start_trans), .trans_started(sram_trans_started), .shift_data(sram_shift_data), .busy(sram_busy), .idle(sram_idle),
        .sio_din(sio_din), .sio_dout(sio_dout), .sio_en(sio_en), .cs_pin(cs_pin), .sck_pin(sck_pin));

    // --- Test Logic ---
    integer i;
    integer j;
    integer k;
	integer X;

	initial begin
        // Waveform setup
        $dumpfile("nanosram.vcd");
        $dumpvars(0, nanosram_tb);

		X = 0;
		i = 0;
		j = 0;
		k = 0;
		rst_n = 0;
		clk   = 0;
		sram_shift_data  = 0;
		sram_start_trans = 0;
		sram_wr_en       = 0;

        // Reset system
        repeat(10) @(posedge clk);
        rst_n = 1;
        wait(sram_idle == 1);
        
        // write one byte
        sram_wr_en = 1;
        sram_addr  = 24'h100;
        sram_din   = 8'hEA;
        sram_start_trans = 1;
        wait (sram_trans_started == 1);
        // toggle shift
        sram_shift_data = 1;
        wait(sram_busy == 1);
        sram_shift_data = 0;
        wait(sram_busy == 0);
        sram_start_trans = 0;
        wait(sram_idle == 1);

        // read one byte
        sram_wr_en = 0;
        sram_addr  = 24'h100;
        sram_start_trans = 1;
        wait (sram_trans_started == 1);
        // toggle shift
        sram_shift_data = 1;
        wait(sram_busy == 1);
        sram_shift_data = 0;
        wait(sram_busy == 0);
        sram_start_trans = 0;
        wait(sram_idle == 1);
		$display("Read %h", sram_dout);
                
		repeat(16) @(posedge clk);
        $finish;
	end

endmodule
