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
    input wire [SRAM_ADDR_WIDTH-1:0] addr,  // address to access in SRAM
    input wire [7:0]            data_in,    // byte to write to SRAM
    input wire                  wr_en,      // write enable control (cannot be swapped during a transaction)
    output wire [7:0]           data_out,   // byte read from SRAM
    
    // control
    input wire start_trans,                 // start a transaction (hold high during the entire transmission)
    output wire trans_started,              // we're ready to start clocking data
    input wire shift_data,                  // start shifting a new byte (takes 2*(QPI_TIMER+1) cycles)

    // I/O
    input wire [3:0] sio_din,               // QPI data in
    output reg [3:0] sio_dout,              // QPI data out
    output reg       sio_en,                // QPI output enable (1 == output, 0 == input
    output reg cs_pin,                      // active low CS pin
    output reg sck_pin                      // SPI clock
);

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
    
    assign trans_started = (fsm_state == FSM_WORK_MODE) ? 1'b1 : 1'b0;
    assign data_out      = temp_wire_bits;
    
    reg [31:0]                init_sr;
    
    always @(posedge clk) begin
        if (!rst_n) begin
            fsm_state     <= FSM_STATE_INIT;
            sio_dout      <= 4'b1111;
            sio_en        <= 1'b1;
            cs_pin        <= 1'b1;
            sck_pin       <= 1'b0;
            init_cnt      <= 3;
            init_sr       <= eqio_bits;
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
                        
                        if (start_trans) begin
                            // start by writing command byte
                            temp_wire_bits <= wr_en ? 8'h02 : 8'h0B;
                            cs_pin         <= 1'b0;
                            sio_dout       <= 0;                        // note: the upper quad is 0 for both read and write
                            sio_en         <= 1'b1;
                            fsm_state      <= FSM_SHIFT_QUAD;
                            fsm_tag        <= FSM_WRITE_ADDR;
                            init_cnt       <= (SRAM_ADDR_WIDTH/8)-1'b1;    // how many address bytes to write - 1
                            if (SRAM_ADDR_WIDTH == 24) begin
								init_sr <= {addr[23:0], 8'b0};
							end else begin
								init_sr <= {addr[15:0], 16'b0};
							end
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
                            fsm_tag    <= wr_en ? FSM_WAIT_DUMMY : FSM_WORK_MODE;
                            init_cnt   <= DUMMY_BYTES - 1;
                        end
                    end
                FSM_WAIT_DUMMY:
                    begin
                        temp_wire_bits <= 8'hFF;
                        sio_dout       <= 4'hF;
                        fsm_state      <= FSM_SHIFT_QUAD;
                        fsm_tag        <= (init_cnt == 0) ? fsm_state : FSM_WORK_MODE;
                        init_cnt       <= init_cnt - 1'b1;
                    end
                FSM_WORK_MODE:
                    begin
						sio_en <= wr_en;
                        if (start_trans) begin
                            if (shift_data) begin
								if (wr_en) begin
									temp_wire_bits <= data_in;
									sio_dout       <= data_in[7:4];
								end
                                fsm_state      <= FSM_SHIFT_QUAD;
                                fsm_tag        <= fsm_state;
                            end
                        end else begin
                            // go back to idle
                            cs_pin             <= 1'b0;
                            fsm_state          <= FSM_STATE_IDLE;
                        end
                    end
                FSM_SHIFT_QUAD:
                    begin
                        // drive SCK via qpi_timer
                        if (qpi_timer == 0) begin
                            qpi_timer <= QPI_TIMER;
                            sck_pin   <= ~sck_pin;

							if (sck_pin) begin
								temp_cnt       <= temp_cnt - 1'b1;                    // note this resets temp_cnt to 1 after each byte
								temp_wire_bits <= {temp_wire_bits[3:0], sio_din};
								sio_dout       <= temp_wire_bits[3:0];
								if (!temp_cnt) begin
									if (!shift_data | !start_trans) begin
										fsm_state      <= fsm_tag;					  // transaction cancelled or not shifting more data
									end else if (wr_en) begin                         // avoid 1 cycle delay if we're doing back to back
										temp_wire_bits <= data_in;
										sio_dout       <= data_in[7:4];
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
