/*
	Realllly simple SPI SRAM demo, does a write then read.  Uses debug node to receive commands and report status.
*/
module top(input clk, inout [3:0] sio, output cs, output cs2, output sck, input uart_rx, output uart_tx);

	localparam
		DATA_WIDTH = `BITS,
		SRAM_ADDR_WIDTH = `SRAM_ADDR_WIDTH,
		DEBUG_ENABLE = 1;
    wire sram_done;
    reg [DATA_WIDTH-1:0] sram_data_in;
    reg sram_data_in_valid;
    wire [DATA_WIDTH-1:0] sram_data_out;
    reg [3:0] sram_data_be;

    reg sram_write_cmd;
    reg sram_read_cmd;
    reg [SRAM_ADDR_WIDTH-1:0] sram_address;
    reg [3:0] rstcnt = 4'b0;
    wire rst_n;
    assign rst_n = rstcnt[3];
    wire pll_clk;
	wire pll_locked;

	pll1 pll(.clkin(clk), .clkout0(pll_clk), .locked(pll_locked));
	
	/* Our debug node mostly used to spy on the FSM state and sram_data_out 
	 * Payload is DATA_WIDTH bus data, SRAM_ADDR_WIDTH worth of address, 16-bit cycle counter, 1 reserved bit, 1 bit sram done, 3 bits tag, 3 bits state 
	 */
	wire rx_data;
	wire rx_clk;
	wire tx_data;
	wire tx_clk;

	localparam
		DEBUG_SIZE = DATA_WIDTH + 24 + SRAM_ADDR_WIDTH;

	reg [DEBUG_SIZE-1:0] debug_outgoing_data;								// data to write to the PC
	wire debug_outgoing_tgl;												// toggle for when this is read
	reg prev_debug_outgoing_tgl;											// previous toggle so we can detect edges
	wire [DEBUG_SIZE-1:0] debug_incoming_data;								// data written FROM the PC 
	wire debug_incoming_tgl;												// toggle for when a write happens
	reg prev_debug_incoming_tgl;											// previous toggle to detect edges
	reg [DEBUG_SIZE-1:0] debug_identity;									// identity of this node 
	wire [15:0] debug_identity_bits = `BITS;
	
	serial_debug #(.BITS(DEBUG_SIZE), .ENABLE(DEBUG_ENABLE)) debug_node(
		.clk(pll_clk), .rst_n(rst_n),
		.prescaler(2),
		.rx_data(rx_data), .rx_clk(rx_clk),
		.tx_data(tx_data), .tx_clk(tx_clk),
		.debug_outgoing_data(debug_outgoing_data), .debug_outgoing_tgl(debug_outgoing_tgl),
		.debug_incoming_data(debug_incoming_data), .debug_incoming_tgl(debug_incoming_tgl),
		.identity(debug_identity));

	/* Our debug_uart instance to communicate to the outside world */
	wire [15:0] uart_bauddiv = `FREQ * 1_000_000 / 1_000_000;
	serial_debug_uart #(.BITS(DEBUG_SIZE), .ENABLE(DEBUG_ENABLE)) debug_uart(
		.clk(pll_clk), .rst_n(rst_n),
		.prescaler(2),
		.debug_tx_clk(tx_clk), .debug_tx_data(tx_data),
		.debug_rx_clk(rx_clk), .debug_rx_data(rx_data),
		.uart_bauddiv(uart_bauddiv), .uart_rx_pin(uart_rx), .uart_tx_pin(uart_tx));

    always @(posedge pll_clk) begin
		if (pll_locked) begin
			rstcnt <= {rstcnt[2:0], 1'b1};
		end
    end

// remember to switch cs pin!!!
//`define USE_23AA04M

	// wiring to our pins from the SPI block
	wire [3:0] sio_din;
	reg [3:0] sio_dout;
	reg sio_sck;
	wire [3:0] sio_en;
	
	// either output to sio or set to high impedence state
	assign sio[0] = sio_en[0] ? sio_dout[0] : 1'bz;
	assign sio[1] = sio_en[1] ? sio_dout[1] : 1'bz;
	assign sio[2] = sio_en[2] ? sio_dout[2] : 1'bz;
	assign sio[3] = sio_en[3] ? sio_dout[3] : 1'bz;
	// sio input is always just the sio pins
	assign sio_din = sio;
	assign sck = sio_sck;

    spi_sram
    #(
`ifdef USE_23AA04M
            .DATA_WIDTH(DATA_WIDTH), .CLK_FREQ_MHZ(`FREQ), .SRAM_ADDR_WIDTH(SRAM_ADDR_WIDTH),
            .DUMMY_BYTES(3), .CMD_READ(8'h0B), .CMD_WRITE(8'h02), .CMD_EQIO(8'h38),
            .MIN_CPH_NS(25), .SPI_TIMER_BITS(4), .QPI_TIMER_BITS(1), .MIN_WAKEUP_NS(100_000),
            .PSRAM_RESET(0), .CMD_RESETEN(8'h66), .CMD_RESET(8'h99)
`else
			// PSRAM configuration (Some chips allow 1 Tclk between CS low but ESP-PSRAM requires 50ns)
            .DATA_WIDTH(DATA_WIDTH), .CLK_FREQ_MHZ(`FREQ), .SRAM_ADDR_WIDTH(SRAM_ADDR_WIDTH),
            .DUMMY_BYTES(3), .CMD_READ(8'hEB), .CMD_WRITE(8'h02), .CMD_EQIO(8'h35),
            .MIN_CPH_NS(50), .SPI_TIMER_BITS(4), .QPI_TIMER_BITS(1), .MIN_WAKEUP_NS(150_000),
            .PSRAM_RESET(1), .CMD_RESETEN(8'h66), .CMD_RESET(8'h99)
`endif  
    ) test_sram(
        .clk(pll_clk),
        .rst_n(rst_n),
        .done(sram_done),
        .data_in(sram_data_in),
        .data_in_valid(sram_data_in_valid), 
        .data_be(sram_data_be),
        .data_out(sram_data_out),
        .write_cmd(sram_write_cmd),
        .read_cmd(sram_read_cmd),
        .address(sram_address),
        .sio_din(sio_din), .sio_dout(sio_dout), .sio_en(sio_en),
        .cs_pin(cs2), .sck_pin(sio_sck));

    reg [2:0] state;
    reg [2:0] tag;
    reg [DATA_WIDTH-1:0] test_value;
    reg [15:0] counter;
    reg [15:0] job_start;

    localparam
        STATE_ISSUE_WRITE = 1,
        STATE_ISSUE_READ = 2,
        STATE_COMPARE_READ = 3,
        STATE_SUCCESS = 4,
        STATE_FAILURE = 5,
        STATE_WAIT_DONE = 6,
        STATE_DELAY=7;

    always @(posedge pll_clk) begin
        if (!rst_n) begin
            // these must be initialized in reset
            sram_data_in_valid 		<= 0;
            sram_write_cmd 			<= 0;
            sram_read_cmd 			<= 0;
            sram_data_in 			<= 0;
			sram_address 			<= 'h001234;				// default use address 1234
            sram_data_be 			<= 4'b1111;
            state 					<= STATE_WAIT_DONE;			// we start in WAIT since the SPI SRAM module needs to init first
            tag 					<= STATE_ISSUE_WRITE;		// jump to issuing the write once the SPI is done init
            debug_outgoing_data 	<= 0;
            prev_debug_incoming_tgl <= 0;
            prev_debug_outgoing_tgl <= 0;
            debug_identity 			<= {{{DATA_WIDTH - 24}{1'b0}}, 16'hFFDD, debug_identity_bits};
            test_value 				<= 'h12345678;
            counter					<= 0;
            job_start				<= 0;
        end else begin
			counter <= counter + 1; 												// cycle counter
			// outgoing data contains what the SRAM read/done, and FSM state
			debug_outgoing_data <= { sram_data_out, sram_address, job_start, 1'b0, sram_done, tag, state };
			if (prev_debug_incoming_tgl != debug_incoming_tgl) begin				// if we receive a node write change the test
				test_value 				<= debug_incoming_data[DEBUG_SIZE-1:(24+SRAM_ADDR_WIDTH)];	// store new test value (lower 24 bits is job_start, 1'b0, sram_done, tag, state)
				sram_address			<= debug_incoming_data[24+SRAM_ADDR_WIDTH-1:24];			// store new address	
				tag 					<= STATE_ISSUE_WRITE;						// re-issue the write
				state					<= STATE_WAIT_DONE;							// wait for done (in case we were in the middle of a test)
				prev_debug_incoming_tgl <= debug_incoming_tgl;
				sram_write_cmd 			<= 0;										// ensure sram inputs are off
				sram_read_cmd 			<= 0;
				sram_data_in_valid		<= 0;
			end else begin
				case(state)
					STATE_WAIT_DONE:
						begin
							sram_data_in_valid	<= 0;			// turn off data in
							sram_write_cmd		<= 0;			// turn off read/write commands
							sram_read_cmd		<= 0;
							if (sram_done) begin				// if SRAM is done jump to the tag FSM state
								state 			<= tag;
								job_start 		<= counter - job_start;
							end
						end
					STATE_ISSUE_WRITE:
						begin
							sram_data_be 		<= 4'b1111;			// enable all four bytes (used in 32-bit mode)
							sram_data_in 		<= test_value;		// we write the test value which is 12345678 by default or assigned by the debug
							sram_data_in_valid 	<= 1;				// data in is valid
							sram_write_cmd 		<= 1;				// we want to write it
							tag 				<= STATE_ISSUE_READ;// jump to read when done
							state 				<= STATE_WAIT_DONE;
						end
					STATE_ISSUE_READ:
						begin
							sram_read_cmd 		<= 1;					// issue a read
							sram_data_be 		<= 4'b1111;				// of all four bytes (in 32-bit mode)
							tag 				<= STATE_COMPARE_READ;	// jump to compare when done
							state 				<= STATE_WAIT_DONE;
							job_start 			<= counter;
						end
					STATE_COMPARE_READ:
						begin
							if (sram_data_out == test_value) begin
								state <= STATE_SUCCESS;
							end else begin
								state <= STATE_FAILURE;
							end
						end
					default: begin end
				endcase
			end
        end         
    end
endmodule
