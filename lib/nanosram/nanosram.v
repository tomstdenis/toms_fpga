/*
nano sram (QPI) driver for SPI SRAM ICs.

To write:

   1. wait for idle to go high
   2. set start_trans and wr_en high, data_in, addr
   3. if you are done writing set start_trans low go back to idle
   4. if you are writing wait for ready & write_strobe, then set data_in and goto 3

To read:

   1. wait for idle to go high
   2. set start_trans high, wr_en low, addr
   3. If you are done reading set start_trans low and go back to idle
   4. If you are reading more wait for ready & read_strobe, then capture data_out and goto 3

*/
`timescale 1ns/1ps
`default_nettype none

module nanosram #(
    parameter SRAM_ADDR_WIDTH=24,           // Address width
    parameter DUMMY_BYTES=3,                // number of dummy cycles on a fast read
    parameter QPI_TIMER=0,                  // how many cycles every half cycle of SCK is (minus 1)
    parameter PSRAM=0,                      // switch between PSRAM and SRAM
    parameter FREQ=81                       // frequency of core in MHz used for PSRAM timing
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

    localparam
        WAKEUP_CYCLES = FREQ * 50,                      // 50 uSec wakeup timer (smaller value == better timing and seems to work)
        HANGUP_CYCLES = (50 * FREQ + 999) / 1000;       // 50ns hangup timer

    reg [$clog2(WAKEUP_CYCLES)-1:0] delay_timer;
    reg [$clog2(QPI_TIMER):0] qpi_timer;    // timer to divide clk into SCK
    reg [7:0] temp_wire_bits;               // latch the data_in/out
    reg       temp_cnt;                     // which nibble are we on
    reg [2:0] init_cnt;
    reg [31:0] init_sr;
    reg       init_en;
    reg [1:0] fsm_state;                    // FSM state control
    reg       ready_sr;
    
    wire [31:0] sram_eqio_bits;                  // Enter QIO mode framed as QPI transactions (0x38)
    assign sram_eqio_bits = { // 0011_1000
        4'b1110, // 0
        4'b1110, // 0
        4'b1111, // 1
        4'b1111, // 1
        4'b1111, // 1
        4'b1110, // 0
        4'b1110, // 0
        4'b1110  // 0
    };
    
    wire [31:0] psram_eqio_bits;                  // Enter QIO mode framed as QPI transactions (0x35)
    assign psram_eqio_bits = { // 0011_0101
        4'b1110, // 0
        4'b1110, // 0
        4'b1111, // 1
        4'b1111, // 1
        4'b1110, // 0
        4'b1111, // 1
        4'b1110, // 0
        4'b1111  // 1
    };

    localparam
        FSM_STATE_EQIO  = 0,
        FSM_STATE_IDLE  = 1,
        FSM_SHIFT_QUAD  = 2,
        FSM_DELAY       = 3;
    
    assign idle = (fsm_state == FSM_STATE_IDLE) ? 1'b1 : 1'b0;
    assign busy = (fsm_state == FSM_SHIFT_QUAD) ? 1'b1 : 1'b0;
       
    always @(posedge clk) begin
		write_strobe <= 1'b0;
		read_strobe  <= 1'b0;
        if (!rst_n) begin
            if (PSRAM == 1) begin
                fsm_state      <= FSM_DELAY;
                delay_timer    <= WAKEUP_CYCLES;
            end else begin
                fsm_state      <= FSM_STATE_EQIO;
            end
            sio_en        <= 1'b1;
            sck_pin       <= 1'b0;
            ready_sr      <= 1'b0;
			temp_cnt      <= 1;
            qpi_timer     <= QPI_TIMER;
            init_en       <= 1'b1;
`ifdef MODEL_SIM
			sim_active    <= 1'b0;
`endif			
        end else begin
            ready       <= ready_sr;
            delay_timer <= delay_timer - 1'b1;
            case (fsm_state)
                FSM_STATE_EQIO:  // Send init commands
                    begin
                        cs_pin         <= 1'b0;
                        init_cnt       <= 3;

                        // advance state
                        fsm_state      <= FSM_SHIFT_QUAD;
                        if (PSRAM == 0) begin
                            init_sr        <= {sram_eqio_bits[23:0], 8'b0};
                            temp_wire_bits <= sram_eqio_bits[31:24];
                            sio_dout       <= sram_eqio_bits[31:28];
                        end else begin
                            init_sr        <= {psram_eqio_bits[23:0], 8'b0};
                            temp_wire_bits <= psram_eqio_bits[31:24];
                            sio_dout       <= psram_eqio_bits[31:28];
                        end
                    end
                FSM_STATE_IDLE:
                    begin
                        cs_pin         <= 1'b1;                         // ensure CS defaults to high (inactive)
						ready          <= 1'b0;
                        ready_sr       <= 1'b0;
`ifdef MODEL_SIM
						sim_active 	   <= 1'b0;
`endif                        
                        if (cs_pin & start_trans) begin
                            // start by writing command byte
                            cs_pin         <= 1'b0;
                            sio_en         <= 1'b1;
                            fsm_state      <= FSM_SHIFT_QUAD;
							/* verilator lint_off WIDTHTRUNC */
                            init_cnt       <= wr_en ? (SRAM_ADDR_WIDTH/8) : (SRAM_ADDR_WIDTH/8) + DUMMY_BYTES;    // how many address bytes to write - 1
                            /* verilator lint_on WIDTHTRUNC */
                            temp_wire_bits <= wr_en ? 8'h02 : ((PSRAM == 0) ? 8'h0B : 8'hEB);
                            sio_dout       <= wr_en ? 4'h0  : ((PSRAM == 0) ? 4'h0 : 4'hE);
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
								temp_cnt       <= ~temp_cnt; // this resets temp_cnt at the end of each byte
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
                                    if (init_cnt != 0) begin
                                        // shift in data from the shift register
                                        temp_wire_bits <= init_sr[31:24];
                                        sio_dout       <= init_sr[31:28];
                                        init_sr        <= {init_sr[23:0], 8'b0};
                                        init_cnt       <= init_cnt - 1'b1;
                                    end else begin
                                        if (init_en) begin 
                                            init_en    <= 1'b0;
                                            // we're done sending eqio jump to idle
                                            if (PSRAM == 1) begin
                                                // if we're ending a transmission we need to do the hangup cycles first
                                                fsm_state     <= FSM_DELAY;
                                            end else begin
                                                fsm_state     <= FSM_STATE_IDLE;	// transaction cancelled or not shifting more data
                                            end
                                        end else begin
                                            // we're done sending the command now moving to data
                                            sio_en     <= wr_en;
                                            ready_sr   <= 1;   // we use a shift register since we don't want to trigger a read strobe
                                                               // on this cycle.  
`ifdef MODEL_SIM
                                            sim_active <= 1'b1;
`endif

                                            if (start_trans) begin
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
                                                if (PSRAM == 1) begin
                                                    // if we're ending a transmission we need to do the hangup cycles first
                                                    fsm_state     <= FSM_DELAY;
                                                end else begin
                                                    fsm_state     <= FSM_STATE_IDLE;	// transaction cancelled or not shifting more data
                                                end
                                            end
                                        end
                                    end
                                end
							end
                        end else begin
                            if (QPI_TIMER > 0) begin
                                qpi_timer <= qpi_timer - 1'b1;
                            end
                        end
                   end
                FSM_DELAY:
                    begin
                        if (PSRAM == 1) begin
                            cs_pin      <= 1'b1;
                            if (delay_timer == 0) begin
                                delay_timer   <= HANGUP_CYCLES;
                                if (init_en) begin
                                    fsm_state <= FSM_STATE_EQIO;
                                end else begin
                                    fsm_state <= FSM_STATE_IDLE;
                                end
                            end
                        end
                    end
            endcase
        end
    end
endmodule
