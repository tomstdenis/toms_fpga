/*
nano sram (QPI) driver for SPI SRAM ICs.

To write:

   1. wait for idle to go high
   2. set start_trans and wr_en high, data_in
   3. if you are done writing set start_trans low go back to idle
   4. if you are writing wait for ready & write_strobe, then set data_in and goto 3
   
To read:

   1. wait for idle to go high
   2. set start_trans high, wr_en low
   3. If you are done reading set start_trans low and go back to idle
   4. If you are reading more wait for ready & read_strobe, then capture data_out and goto 3

*/
`timescale 1ns/1ps
`default_nettype none

module nanosram #(
    parameter SRAM_ADDR_WIDTH=24,           // Address width
    parameter DUMMY_BYTES=3,                // number of dummy cycles on a fast read
    parameter QPI_TIMER=0                   // how many cycles every half cycle of SCK is (minus 1)
)(
    input wire clk,
    input wire rst_n,
    
    // command 
    input wire [SRAM_ADDR_WIDTH-1:0] addr,     // address to access in SRAM
    input wire [7:0]                 data_in,  // byte to write to SRAM
    input wire                       wr_en,    // write enable control (cannot be swapped during a transaction)
    output reg [7:0]                 data_out, // byte read from SRAM
    
    // control
    input wire  start_trans,                // start a transaction (hold high during the entire transmission)
    output wire busy,						// busy sending/receiving 
    output wire idle,						// we're in the idle state waiting to start_trans
    output reg  ready,						// we're done sending the command you should respond to strobes now
    output reg  read_strobe,				// high when you can read data_out (lasts one cycle)
    output reg  write_strobe,				// high when you should either send a new data_in or take start_trans low to stop further writes

    // I/O
    input wire [3:0] sio_din,               // QPI data in
    output reg [3:0] sio_dout,              // QPI data out
    output reg       sio_en,                // QPI output enable (1 == output, 0 == input
    output reg       cs_pin,                // active low CS pin
    output reg       sck_pin                // SPI clock
);

`ifdef MODEL_SIM
	reg [3:0] sim_mem[65535:0];				// 32K of memory
	reg [SRAM_ADDR_WIDTH-1:0] sim_addr;
	reg                       sim_active;
`endif	

    reg [$clog2(QPI_TIMER):0] qpi_timer;    // timer to divide clk into SCK
    reg [7:0] temp_wire_bits;               // latch the data_in/out
    reg       temp_cnt;                     // which nibble are we on
    reg [1:0] init_cnt;
    reg [2:0] fsm_state;                    // FSM state control
    reg [2:0] fsm_tag;
    
    wire [31:0] eqio_bits;                  // Enter QIO mode framed as QPI transactions (0x38)
    assign eqio_bits = { // 0011_1000
        4'b1110, // 0
        4'b1110, // 0
        4'b1111, // 1
        4'b1111, // 1
        4'b1111, // 1
        4'b1110, // 0
        4'b1110, // 0
        4'b1110  // 0
    };
    
    localparam
        FSM_STATE_INIT  = 0,
        FSM_STATE_IDLE  = 1,
        FSM_WRITE_ADDR  = 2,
        FSM_WAIT_DUMMY  = 3,
        FSM_WORK_MODE   = 4,
        FSM_SHIFT_QUAD  = 5;
    
    assign idle          = (fsm_state == FSM_STATE_IDLE) ? 1'b1 : 1'b0;
    assign busy          = (fsm_state == FSM_SHIFT_QUAD) ? 1'b1 : 1'b0;
    
    reg [31:0]                init_sr;
    
    always @(posedge clk) begin
		write_strobe <= 1'b0;
		read_strobe  <= 1'b0;
        if (!rst_n) begin
            fsm_state     <= FSM_STATE_INIT;
            sio_dout      <= 4'b1111;
            sio_en        <= 1'b1;
            cs_pin        <= 1'b1;
            sck_pin       <= 1'b0;
            init_cnt      <= 3;
            init_sr       <= eqio_bits;
            data_out      <= 8'h00;
			ready         <= 1'b0;
`ifdef MODEL_SIM
			sim_active    <= 1'b0;
`endif			
        end else begin
            case (fsm_state)
                FSM_STATE_INIT:    // send EQIO command
                    begin
                        // data to shift out
                        temp_wire_bits <= init_sr[31:24];
                        temp_cnt       <= 1;
                        qpi_timer      <= QPI_TIMER;
                        
                        // setup pins
                        sio_dout       <= init_sr[31:28];
                        sio_en         <= 1'b1;
                        cs_pin         <= 1'b0;

                        // advance state
                        fsm_state      <= FSM_SHIFT_QUAD;
                        fsm_tag        <= (init_cnt == 0) ? FSM_STATE_IDLE : fsm_state;
                        init_cnt       <= init_cnt - 1'b1;
                        init_sr		   <= {init_sr[23:0], 8'b0};
                    end
                FSM_STATE_IDLE:
                    begin
                        cs_pin         <= 1'b1;                         // ensure CS defaults to high (inactive)
						ready          <= 1'b0;
`ifdef MODEL_SIM
						sim_active 	   <= 1'b0;
`endif                        
                        if (cs_pin & start_trans) begin
                            // start by writing command byte
                            temp_wire_bits <= wr_en ? 8'h02 : 8'h0B;
                            cs_pin         <= 1'b0;
                            sio_dout       <= 0;                        // note: the upper quad is 0 for both read and write
                            sio_en         <= 1'b1;
                            fsm_state      <= FSM_SHIFT_QUAD;
                            fsm_tag        <= FSM_WRITE_ADDR;
							/* verilator lint_off WIDTHTRUNC */
                            init_cnt       <= (SRAM_ADDR_WIDTH/8)-1'b1;    // how many address bytes to write - 1
                            /* verilator lint_on WIDTHTRUNC */
                            if (SRAM_ADDR_WIDTH == 24) begin
								init_sr <= {addr[23:0], 8'b0};
							end else begin
								init_sr <= {addr[15:0], 16'b0};
							end
`ifdef MODEL_SIM
							sim_addr <= addr * 2;
`endif							
                        end
                    end
                FSM_WRITE_ADDR:
                    begin
                        temp_wire_bits <= init_sr[31:24];
                        sio_dout       <= init_sr[31:28];
                        init_sr        <= {init_sr[23:0], 8'b0};
                        
                        init_cnt       <= init_cnt - 1'b1;
                        fsm_state      <= FSM_SHIFT_QUAD;
                        if (init_cnt != 0) begin
                            fsm_tag    <= fsm_state;
                        end else begin
                            fsm_tag    <= wr_en ? FSM_WORK_MODE : FSM_WAIT_DUMMY;
                            init_cnt   <= DUMMY_BYTES - 1;
                        end
                    end
                FSM_WAIT_DUMMY:
                    begin
                        temp_wire_bits <= 8'hFF;
                        sio_dout       <= 4'hF;
                        fsm_state      <= FSM_SHIFT_QUAD;
                        fsm_tag        <= (init_cnt != 0) ? fsm_state : FSM_WORK_MODE;
                        init_cnt       <= init_cnt - 1'b1;
                    end
                FSM_WORK_MODE:
                    begin
`ifdef MODEL_SIM
						sim_active <= 1'b1;
`endif
						ready  <= 1'b1;
						sio_en <= wr_en;
						if (wr_en) begin
							temp_wire_bits <= data_in;
							sio_dout       <= data_in[7:4];
						end
						fsm_state      <= FSM_SHIFT_QUAD;
						fsm_tag        <= FSM_STATE_IDLE;
                    end
                FSM_SHIFT_QUAD:
                    begin
                        // drive SCK via qpi_timer
                        if (qpi_timer == 0) begin
                            qpi_timer <= QPI_TIMER;
                            sck_pin   <= ~sck_pin;
                            
                            // we're about to go low SCK phase so good time send write strobe
                            // to get a fresh data_in
							write_strobe <= temp_cnt & sck_pin & wr_en;

							// Time to read data_out
							read_strobe  <= ~temp_cnt & sck_pin & ~wr_en;
							
							if (sck_pin) begin
								temp_cnt       <= temp_cnt - 1'b1;                    // note this resets temp_cnt to 1 after each byte
`ifdef MODEL_SIM
								if (sim_active) begin
									sim_addr <= sim_addr + 1;
									if (wr_en) begin
										sim_mem[sim_addr] <= temp_wire_bits[7:4];
										$display("Storing %h at address %h", temp_wire_bits[7:4], sim_addr);
										temp_wire_bits <= {temp_wire_bits[3:0], 4'b0 };
									end else begin
										temp_wire_bits <= {temp_wire_bits[3:0], sim_mem[sim_addr]};
									end
								end
`else
								temp_wire_bits <= {temp_wire_bits[3:0], sio_din};
`endif
								sio_dout       <= temp_wire_bits[3:0];

								if (!temp_cnt) begin
									if (start_trans && fsm_tag == FSM_STATE_IDLE) begin
										if (wr_en) begin
											temp_wire_bits <= data_in;
											sio_dout       <= data_in[7:4];
										end else begin
`ifdef MODEL_SIM
											data_out <= {temp_wire_bits[3:0], sim_mem[sim_addr]};
`else
											data_out <= {temp_wire_bits[3:0], sio_din};
`endif
										end
									end else begin
										fsm_state          <= fsm_tag;					  // transaction cancelled or not shifting more data
									end
								end
							end
                        end else begin
                            qpi_timer <= qpi_timer - 1'b1;
                        end
                   end
            endcase
        end
    end
endmodule
