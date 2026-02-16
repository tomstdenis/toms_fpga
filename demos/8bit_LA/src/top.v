module top(
    input clk,
    output uart_tx,
    input uart_rx,
    input [7:0] io,
    output [3:0] led);

    // RESET
    reg [3:0] rstcnt = 4'b0;
    assign rst_n = rstcnt[3];

    // LEDs
    reg [3:0] ledv;
    assign led = ~ledv;                                         // LEDs are active low

    // UART
    wire [15:0] uart_bauddiv = 27_000_000 / 115_200;            // bauddiv counter
    reg uart_tx_start;                                          // start a transmit of what is in uart_tx_data_in (this is edge triggered so you just toggle it to send)
    reg [7:0] uart_tx_data_in;                                  // data to send
    reg uart_rx_read;                                           // ack a read (toggle, edge triggered like uart_tx_start)
    wire uart_rx_ready;                                         // there's a byte to read
    wire [7:0] uart_rx_byte;                                    // the byte that is available to read

    uart #(.FIFO_DEPTH(8), .RX_ENABLE(1), .TX_ENABLE(1)) la_uart(
        .clk(clk), .rst_n(rst_n),
        .baud_div(uart_bauddiv),
        .uart_tx_start(uart_tx_start),
        .uart_tx_data_in(uart_tx_data_in),
        .uart_tx_pin(uart_tx),
        .uart_tx_fifo_full(uart_tx_fifo_full),
        .uart_tx_fifo_empty(uart_tx_fifo_empty),
        .uart_rx_pin(uart_rx),
        .uart_rx_read(uart_rx_read),
        .uart_rx_ready(uart_rx_ready),
        .uart_rx_byte(uart_rx_byte));
        
        
    // TIMER (and acquire)
    reg [7:0] timer_prescale_cnt;               // current prescale value
    reg [7:0] timer_prescale;                   // target prescale value
    reg [15:0] timer_post_cnt;                  // how many samples post trigger left to store
    reg [15:0] timer_mem_ptr;                   // the WPTR of the ring buffer (incremented each time timer_prescale_cnt == timer_prescale)
    reg [15:0] timer_mem_wptr;                  // saved WPTR when done sampling
    reg timer_triggered;                        // have we triggered yet
    reg [1:0] timer_state;                      // timer FSM state id
    reg [7:0] timer_io_latch;                   // latched io
    wire [7:0] timer_mem_data_out;              // memory output
    reg timer_mem_wren;                         // write enable
    reg [7:0] timer_trigger_mask;               // which pins do we care about
    reg [7:0] timer_trigger_pol;                // what is the required value of the pin that changed
    reg timer_start;                            // 1 == switch from IDLE to RUNNING

    wire [7:0] timer_trig_delta = ((io ^ timer_io_latch) & timer_trigger_mask);         // did a pin change that we care about
    wire [7:0] timer_trig_value = (~(io ^ timer_trigger_pol) & timer_trigger_mask);     // is the current bit equal to the value we wanted
    wire timer_trigger_event = (|timer_trig_delta & |timer_trig_value);                 // goes true if a trigger event occurred

    Gowin_SP timer_mem(
        .dout(timer_mem_data_out), //output [7:0] dout
        .clk(clk), //input clk
        .oce(1'b1), //input oce
        .ce(1'b1), //input ce
        .reset(~rst_n), //input reset
        .wre(timer_mem_wren), //input wre
        .ad(timer_mem_ptr), //input [15:0] ad
        .din(timer_io_latch) //input [7:0] din
    );

    // MAIN app
    reg [7:0] main_rx_frame[3:0];           // each command is 4 bytes
    reg [2:0] main_rx_frame_i;              // how many bytes have we read so far
    reg [7:0] main_tx_byte_buf;             // buffer holding byte to send for MAIN_TRANSMIT_WAIT
    reg [4:0] main_state;                   // which state is the FSM in
    reg [4:0] main_state_tag;               // tag system allows generic wait and what not
    reg [16:0] main_buf_i;                  // index into buffer to send

    localparam
        TIMER_IDLE = 0,
        TIMER_RUNNING = 1;

    localparam
        MAIN_INIT = 0,
        MAIN_READ4_BYTES = 1,               // loop on reading 4 bytes
        MAIN_READ_BYTE_DELAY = 2,           // delay cycle after reading a byte
        MAIN_PROGRAM_TIMER = 3,             // program the timer based on what we read
        MAIN_TRANSMIT_DATA_START = 4,       // init sending the buffer
        MAIN_TRANSMIT_WPTR_0 = 5,           // transmit wptr[7:0]
        MAIN_TRANSMIT_WPTR_1 = 6,           // transmit wptr[15:8]
        MAIN_TRANSMIT_BUF = 7,              // transmit buffer 0..65535
        MAIN_TRANSMIT_WAIT = 8,             // wait for ability to send byte
        MAIN_TRANSMIT_READ_MEM1 = 9,        // wait cycle for mem to respond to address
        MAIN_TRANSMIT_READ_MEM2 = 10;       // cycle to read memory output

    always @(posedge clk) begin
        rstcnt <= {rstcnt[2:0], 1'b1};
        if (!rst_n) begin
            // LEDs
            ledv <= 0;                      // all LEDs off

            // reset UART controller
            uart_tx_start <= 0;
            uart_tx_data_in <= 0;
            uart_rx_read <= 0;

            // reset timer
            timer_prescale <= 0;
            timer_prescale_cnt <= 0;
            timer_post_cnt <= 0;
            timer_mem_ptr <= 0;
            timer_triggered <= 0;
            timer_state <= TIMER_IDLE;
            timer_io_latch <= 8'hFF;
            timer_mem_wren <= 0;
            timer_trigger_mask <= 0;
            timer_trigger_pol <= 0;
            timer_start <= 0;

            // reset main
            main_rx_frame_i <= 0;
            main_state <= MAIN_INIT;
            main_state_tag <= 0;
        end else begin
            // main code
            timer_io_latch <= io;               // latch the IO pins

            case(timer_state)
                TIMER_IDLE:
                    begin
                        if (timer_start) begin
                            timer_prescale_cnt <= 0;                                    // zero out prescale count
                            timer_mem_ptr <= 0;                                         // start at address 0
                            timer_triggered <= 0;                                       // reset triggered stats
                            timer_mem_wren <= 1'b1;                                     // enable memory write
                            timer_state <= TIMER_RUNNING;
                        end else begin
                            // MAIN application goes here
                            case (main_state)
                                MAIN_INIT:
                                    begin
                                        main_rx_frame_i <= 0;                           // reset frame counter
                                        main_state <= MAIN_READ4_BYTES;
                                    end
                                MAIN_READ4_BYTES:
                                    begin
                                        if (main_rx_frame_i == 4) begin
                                            main_state <= MAIN_PROGRAM_TIMER;
                                        end else begin
                                            if (uart_rx_ready) begin
                                                main_rx_frame[main_rx_frame_i] <= uart_rx_byte;     // latch byte
                                                main_rx_frame_i <= main_rx_frame_i + 1'b1;
                                                uart_rx_read <= uart_rx_read ^ 1'b1;                // toggle line
                                                main_state <= MAIN_READ_BYTE_DELAY;
                                            end
                                        end
                                    end
                                MAIN_READ_BYTE_DELAY: // delay cycle
                                    begin
                                        main_state <= MAIN_READ4_BYTES;
                                    end
                                MAIN_PROGRAM_TIMER:
                                    begin
                                        main_state <= MAIN_TRANSMIT_WPTR_0;             // get ready for next main task which is sending the lower 8 bits
                                        timer_start <= 1;                               // start the timer
                                        timer_trigger_mask <= main_rx_frame[0];         // load mask
                                        timer_trigger_pol  <= main_rx_frame[1];         // load pol
                                        timer_prescale     <= main_rx_frame[2];         // prescale
                                        timer_post_cnt     <= {main_rx_frame[3], 8'b0}; // post_cnt * 256 samples
                                    end
                                MAIN_TRANSMIT_WAIT:
                                    begin
                                        if (!uart_tx_fifo_full) begin
                                            uart_tx_data_in <= main_tx_byte_buf;
                                            uart_tx_start <= uart_tx_start ^ 1'b1;
                                            main_state <= main_state_tag;               // jump back to next state
                                        end
                                    end
                                MAIN_TRANSMIT_WPTR_0:
                                    begin
                                        main_tx_byte_buf <= timer_mem_wptr[7:0];
                                        main_state_tag   <= MAIN_TRANSMIT_WPTR_1;
                                        main_state       <= MAIN_TRANSMIT_WAIT;
                                    end
                                MAIN_TRANSMIT_WPTR_1:
                                    begin
                                        main_tx_byte_buf <= timer_mem_wptr[15:8];
                                        main_state_tag   <= MAIN_TRANSMIT_BUF;
                                        main_state       <= MAIN_TRANSMIT_WAIT;
                                        main_buf_i       <= 0;                          // clear index into memory to transmit
                                    end
                                MAIN_TRANSMIT_BUF:
                                    begin
                                        if (main_buf_i == 17'h10000) begin
                                            main_state <= MAIN_INIT;
                                        end else begin
                                            timer_mem_ptr    <= main_buf_i[15:0];
                                            main_state       <= MAIN_TRANSMIT_READ_MEM1;
                                        end
                                    end
                                MAIN_TRANSMIT_READ_MEM1:
                                    begin
                                        main_state <= MAIN_TRANSMIT_READ_MEM2;
                                    end
                                MAIN_TRANSMIT_READ_MEM2:
                                    begin
                                        main_tx_byte_buf <= timer_mem_data_out;
                                        main_state_tag   <= MAIN_TRANSMIT_BUF;
                                        main_state       <= MAIN_TRANSMIT_WAIT;
                                        main_buf_i       <= main_buf_i + 1'b1;;
                                    end
                                default: begin end
                            endcase
                        end
                    end
                TIMER_RUNNING:
                    begin
                        if (timer_trigger_event) begin
                            // detect and latch a trigger event
                            timer_triggered <= 1'b1;
                        end
                        if (timer_post_cnt > 0) begin
                            // we haven't yet reached the post count limit
                            if (timer_prescale_cnt >= timer_prescale) begin
                                timer_prescale_cnt <= 0;                                // reset prescale count
                                timer_mem_ptr <= timer_mem_ptr + 1'b1;                  // advance memory pointer
                                timer_post_cnt <= timer_post_cnt - timer_triggered;     // only decrement post count after trigger
                            end else begin
                                timer_prescale_cnt <= timer_prescale_cnt + 1'b1;
                            end
                        end else begin
                            // we're done sampling
                            timer_mem_wren <= 0;                                        // turn off memory write
                            timer_start    <= 0;                                        // disable timer
                            timer_state    <= TIMER_IDLE;                               // return to IDLE state
                            timer_mem_wptr <= timer_mem_ptr;                            // save the current WPTR since we reuse timer_mem_ptr to read mem
                        end                            
                    end
                default:
                    begin
                    end
            endcase
        end
    end


/*
    Gowin_rPLL rPLL(
        .clkout(pll_clk), //output clkout
        .clkin(clk) //input clkin
    );
*/


endmodule