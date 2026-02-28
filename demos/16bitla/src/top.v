module top(
    input clk,
    output uart_tx,
    input uart_rx,
    input [15:0] io,
    output [3:0] led);
    wire pll_clk;

    Gowin_rPLL la_pll(
        .clkout(pll_clk), //output clkout
        .clkin(clk) //input clkin
    );

    // RESET
    reg [3:0] rstcnt = 4'b0;
    assign rst_n = rstcnt[3];

    // LEDs
    reg [3:0] ledv;
    assign led = ~ledv;                                         // LEDs are active low

    // UART
    wire [15:0] uart_bauddiv = 148_500_000 / 115_200;           // bauddiv counter
    reg uart_tx_start;                                          // start a transmit of what is in uart_tx_data_in (this is edge triggered so you just toggle it to send)
    reg [7:0] uart_tx_data_in;                                  // data to send
    reg uart_rx_read;                                           // ack a read (toggle, edge triggered like uart_tx_start)
    wire uart_rx_ready;                                         // there's a byte to read
    wire [7:0] uart_rx_byte;                                    // the byte that is available to read

    uart #(.FIFO_DEPTH(16), .RX_ENABLE(1), .TX_ENABLE(1)) la_uart(
        .clk(pll_clk), .rst_n(rst_n),
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
    reg timer_mem_ce;                           // Clock enable for memory (wren(1), ce(0): turn clock off for both ports)
    reg timer_triggered;                        // have we triggered yet
    reg timer_state;                            // timer FSM state id
    reg [15:0] timer_io_latch;                  // latched io
    reg [15:0] timer_io_latch2;
    wire [7:0] timer_mem_data_out;              // memory output
    reg [15:0] timer_mem_data_in;               // memory input
    reg timer_8ch_mode;                         // are we in 8ch mode if so we can use 64K samples instead of 32K
    reg timer_8ch_phase;                        // are we on an even or odd 8ch sampling?
    reg timer_mem_wren;                         // write enable
    reg [15:0] timer_trigger_mask;              // which pins do we care about
    reg [15:0] timer_trigger_pol;               // what is the required value of the pin that changed
    reg timer_start;                            // 1 == switch from IDLE to RUNNING
    reg [3:0] timer_trigger_mode;
    reg timer_trigger_latch;                    // latched trigger reduces critical path but delays triggering by 1 cycle

    // Address Mux for the LUT
    reg [3:0] lut_addr;
    always @(*) begin
        case(timer_trigger_mode)
            3'd1: lut_addr = io[3:0];                               // 4-ch static
            3'd2: lut_addr = {io[1:0], timer_io_latch[1:0]};        // 2-ch over 2 cycles
            3'd3: lut_addr = {io[6:4], timer_trigger_mask[io[3:0]]};
            default: lut_addr = 4'b0;
        endcase
    end

    // if you have trouble hitting timing try turning this off.
    localparam ENABLE_LUT_TRIGGER = 1;

    wire lut_trigger = timer_trigger_pol[lut_addr];                 // in LUT4 mode we use the polarity field as a 4-bit LUT
    wire [15:0] timer_trig_delta = ((io ^ timer_io_latch));         // did a pin change that we care about
    wire [15:0] timer_trig_value = (~(io ^ timer_trigger_pol));     // is the current bit equal to the value we wanted
    wire timer_trigger_event = (ENABLE_LUT_TRIGGER == 1 && timer_trigger_mode != 0) ?          // are we using a LUT trigger or standard edge trigger?
                                    lut_trigger : 
                                        (|(timer_trig_delta & timer_trig_value & timer_trigger_mask));

    // dual ported memory 8x65536, let's me write 16-bits at a go,and read it back without mixing port widths
    Gowin_DPB timer_mem(
        .douta(timer_mem_data_out),     //output [7:0] douta
        .doutb(),                       //output [7:0] doutb (unused as we only read from PORT A)
        .clka(pll_clk),                 //input clka
        .ocea(1'b1),                    //input ocea (not used in bypass mode)
        .cea(timer_mem_ce),             //input cea (along with only enabling wren when we have a sample, we also disable the memory clocks when it's not reading or writing)
        .reseta(~rst_n),                //input reseta
        .wrea(timer_mem_wren),          //input wrea
        .clkb(pll_clk),                 //input clkb
        .oceb(1'b1),                    //input oceb
        .ceb(timer_mem_ce),             //input ceb
        .resetb(~rst_n),                //input resetb
        .wreb(timer_mem_wren),          //input wreb
        .ada(timer_mem_ptr),            //input [15:0] ada (we stagger writes so addr goes to PORT A and addr+1 goes to PORT B, as lone as we addr += 2 in our loop we're good
        .dina(timer_mem_data_in[7:0]),  //input [7:0] dina 
        .adb(timer_mem_ptr + 16'd1),    //input [15:0] adb
        .dinb(timer_mem_data_in[15:8])  //input [7:0] dinb
    );

    // MAIN app
    reg [7:0] main_rx_frame[7:0];           // each command is 8 bytes
    reg [3:0] main_rx_frame_i;              // how many bytes have we read so far
    reg [7:0] main_tx_byte_buf;             // buffer holding byte to send for MAIN_TRANSMIT_WAIT
    reg [3:0] main_state;                   // which state is the FSM in
    reg [3:0] main_state_tag;               // tag system allows generic wait and what not
    reg [16:0] main_buf_i;                  // index into buffer to send

    localparam
        TIMER_IDLE = 0,
        TIMER_RUNNING = 1;

    localparam
        MAIN_INIT = 0,
        MAIN_FLUSH_RX = 1,                  // flush any incoming bytes
        MAIN_FLUSH_RX_DELAY = 2,            // delay after issuing read during flush
        MAIN_CMD_BYTES = 3,               // loop on reading 4 bytes
        MAIN_READ_BYTE_DELAY1 = 4,           // delay cycle after reading a byte
        MAIN_READ_BYTE_DELAY2 = 5,           // delay cycle after reading a byte
        MAIN_PROGRAM_TIMER = 6,             // program the timer based on what we read
        MAIN_TRANSMIT_DATA_START = 7,       // init sending the buffer
        MAIN_TRANSMIT_WPTR_0 = 8,           // transmit wptr[7:0]
        MAIN_TRANSMIT_WPTR_1 = 9,           // transmit wptr[15:8]
        MAIN_TRANSMIT_BUF = 10,              // transmit buffer 0..65535
        MAIN_TRANSMIT_WAIT = 11,            // wait for ability to send byte
        MAIN_TRANSMIT_READ_MEM1 = 12,       // wait cycle for mem to respond to address
        MAIN_TRANSMIT_READ_MEM2 = 13;       // cycle to read memory output

    localparam
        LED_WAITING_ON_RX = 0,
        LED_WAITING_ON_SAMPLES = 1,
        LED_WAITING_ON_TX = 2;

    always @(posedge pll_clk) begin
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
            timer_mem_ce  <= 0;
            timer_triggered <= 0;
            timer_state <= TIMER_IDLE;
            timer_io_latch <= 8'hFF;
            timer_io_latch2 <= 8'hFF;
            timer_mem_wren <= 0;
            timer_trigger_mask <= 0;
            timer_trigger_pol <= 0;
            timer_start <= 0;
            timer_8ch_mode <= 0;
            timer_8ch_phase <= 0;
            timer_trigger_mode <= 0;
            timer_trigger_latch <= 0;

            // reset main
            main_rx_frame_i <= 0;
            main_state <= MAIN_INIT;
            main_state_tag <= 0;
        end else begin
            // main code
            timer_io_latch <= io;               // latch the IO pins
            timer_trigger_latch <= timer_trigger_event;
/* This application uses two nested FSMs.  The outer FSM is the timer which when IDLE and timer_start hasn't been asserted
allows the innter "main" FSM to run.  The main FSM is what actually coordinates the device.  It flushes the RX buffer,
waits for a frame (4 bytes) to program the timer, then asserts timer_start.

Once the timer FSM sees timer_start in it's TIMER_IDLE phase it initializes some values and jumps to TIMER_RUNNING.

In TIMER_RUNNING we detect and latch trigger events, then if we haven't exhausted the post trigger countdown we 
every prescale cycles we sample the next data and write it to memory.  

This means once TIMER_RUNNING is going it's constantly sampling to memory (every prescale cycles).  Once the trigger
happens it runs for another post count.  This way you can change how much before/after the trigger you record.  It always
returns 65536 samples.
*/
            case(timer_state)
                TIMER_IDLE:
                    begin
                        if (timer_start) begin
                            timer_prescale_cnt <= 0;                                    // zero out prescale count
                            timer_mem_ptr <= 0;                                         // start at address 0
                            timer_triggered <= 0;                                       // reset triggered stats
                            timer_state <= TIMER_RUNNING;
                        end else begin
                            // MAIN application goes here
                            case (main_state)
                                MAIN_INIT:
                                    begin
                                        timer_mem_ce                 <= 0;  // turn memory off
                                        main_rx_frame_i <= 0;               // reset frame counter
                                        ledv[LED_WAITING_ON_RX]      <= 1;  // waiting for serial RX
                                        ledv[LED_WAITING_ON_SAMPLES] <= 0;  // not waiting for sampling
                                        ledv[LED_WAITING_ON_TX]      <= 0;  // not waiting for transmitting
                                        main_state      <= MAIN_FLUSH_RX;
                                    end
                                MAIN_FLUSH_RX:
                                    begin
                                        if (uart_rx_ready) begin
                                            uart_rx_read <= 1'b1;
                                            main_state <= MAIN_FLUSH_RX_DELAY;
                                        end else begin
                                            main_state <= MAIN_CMD_BYTES;
                                        end
                                    end
                                MAIN_FLUSH_RX_DELAY:
                                    begin
                                        uart_rx_read <= 1'b0;
                                        main_state <= MAIN_FLUSH_RX;
                                    end
                                MAIN_CMD_BYTES:
                                    begin
                                        if (main_rx_frame_i == 'd8) begin
                                            ledv[LED_WAITING_ON_RX]      <= 0;               // not waiting for serial RX
                                            ledv[LED_WAITING_ON_SAMPLES] <= 1;               // waiting for sampling
                                            main_state <= MAIN_PROGRAM_TIMER;
                                        end else begin
                                            if (uart_rx_ready) begin
                                                uart_rx_read <= 1'b1;                // toggle line
                                                main_state <= MAIN_READ_BYTE_DELAY1;
                                            end
                                        end
                                    end
                                MAIN_READ_BYTE_DELAY1:                                       // this is the cycle the UART responds to toggling uart_rx_read
                                    begin
                                        uart_rx_read <= 1'b0;
                                        main_state <= MAIN_READ_BYTE_DELAY2;
                                    end
                                MAIN_READ_BYTE_DELAY2:                                      // Now we can read the data from the UART RX
                                    begin
                                        main_rx_frame[main_rx_frame_i] <= uart_rx_byte;     // latch byte from UART RX
                                        main_rx_frame_i <= main_rx_frame_i + 1'b1;          // increment the frame offset
                                        main_state <= MAIN_CMD_BYTES;
                                    end
                                MAIN_PROGRAM_TIMER:
                                    begin
                                        main_state <= MAIN_TRANSMIT_WPTR_0;                         // get ready for next main task which is sending the lower 8 bits
                                        timer_start <= 1;                                           // start the timer
                                        timer_mem_ce <= 1'b1;                                       // turn memory on
                                        timer_8ch_phase <= 0;                                       // reset phase to 0 so wptr math will always work
                                        timer_trigger_mask <= {main_rx_frame[1], main_rx_frame[0]}; // load mask
                                        timer_trigger_pol  <= {main_rx_frame[3], main_rx_frame[2]}; // load pol
                                        timer_prescale     <= main_rx_frame[4];                     // prescale
                                        timer_8ch_mode     <= ~main_rx_frame[6][7];                 // 8ch mode enabled if msb is zero
                                        if (main_rx_frame[5] == 0) begin                            // if the post_count is zero then force it to 1.
                                            timer_post_cnt <= 'd1;
                                        end else begin
                                            if (main_rx_frame[6][7] == 0) begin                     // if the upper bit is zero
                                                timer_post_cnt     <= {main_rx_frame[5], 8'b0};             // post_cnt * 256 samples (0..65280)
                                            end else begin
                                                timer_post_cnt     <= {1'b0, main_rx_frame[5], 7'b0};       // post_cnt * 128 samples (0..32640)
                                            end
                                        end
                                        timer_trigger_mode <= main_rx_frame[6][3:0];                // trigger mode (0=edge, 1+ == LUT)
                                    end
                                MAIN_TRANSMIT_WAIT:
                                    begin
                                        if (!uart_tx_fifo_full) begin
                                            uart_tx_data_in <= main_tx_byte_buf;
                                            uart_tx_start <= 1'b1;
                                            main_state <= main_state_tag;               // jump back to next state
                                        end
                                    end
                                MAIN_TRANSMIT_WPTR_0:
                                    begin
                                        main_tx_byte_buf <= timer_mem_wptr[7:0];
                                        main_state_tag   <= MAIN_TRANSMIT_WPTR_1;
                                        main_state       <= MAIN_TRANSMIT_WAIT;
                                        ledv[LED_WAITING_ON_SAMPLES]     <= 0;          // not waiting on samples anymore
                                        ledv[LED_WAITING_ON_TX]          <= 1;          // waiting for transmitting
                                    end
                                MAIN_TRANSMIT_WPTR_1:
                                    begin
                                        main_tx_byte_buf <= timer_mem_wptr[15:8];
                                        main_state_tag   <= MAIN_TRANSMIT_BUF;
                                        main_state       <= MAIN_TRANSMIT_WAIT;
                                        main_buf_i       <= 0;                          // clear index into memory to transmit
                                        uart_tx_start    <= 1'b0;
                                    end
                                MAIN_TRANSMIT_BUF:
                                    begin
                                        uart_tx_start    <= 1'b0;
                                        if (main_buf_i == 17'h10000) begin
                                            main_state <= MAIN_INIT;
                                            ledv[LED_WAITING_ON_TX]          <= 0;      // not waiting for transmitting
                                        end else begin
                                            timer_mem_ptr <= main_buf_i[15:0];
                                            main_state    <= MAIN_TRANSMIT_READ_MEM1;
                                        end
                                    end
                                MAIN_TRANSMIT_READ_MEM1:                                // this cycle allows the BRAM to respond to the address
                                    begin
                                        main_state <= MAIN_TRANSMIT_READ_MEM2;
                                    end
                                MAIN_TRANSMIT_READ_MEM2:                                // now we transmit what the memory read
                                    begin
                                        main_tx_byte_buf <= timer_mem_data_out;
                                        main_state_tag   <= MAIN_TRANSMIT_BUF;
                                        main_state       <= MAIN_TRANSMIT_WAIT;
                                        main_buf_i       <= main_buf_i + 1'b1;
                                    end
                                default: begin end
                            endcase
                        end
                    end
                TIMER_RUNNING:                                                          // This state records a new sample every timer_prescale cycles
                    begin
                        if (timer_trigger_latch) begin                                  // did a trigger event happen?
                            // detect and latch a trigger event
                            timer_triggered <= 1'b1;
                            if (timer_triggered == 0) begin
                                timer_mem_wptr <= timer_mem_ptr + timer_8ch_phase;      // save the current WPTR since we reuse timer_mem_ptr to read mem
                            end
                        end
                        if (timer_post_cnt > 0) begin                                   // if we haven't exhausted post trigger bytes keep going
                            // we haven't yet reached the post count limit
                            if (timer_prescale_cnt >= timer_prescale) begin
                                timer_prescale_cnt <= 0;                               // reset prescale count
                                if (timer_8ch_mode == 0) begin                         // 16ch mode we store one word per sample
                                    timer_mem_ptr <= timer_mem_ptr + 16'd2;            // advance memory pointer
                                    timer_mem_data_in <= timer_io_latch;               // latch memory to write
                                    timer_mem_wren <= 1;
                                end else begin
                                    // in 8ch mode we form 2 samples per word of memory
                                    if (timer_8ch_phase == 0) begin
                                        // even phase we just capture data but don't advance the pointer
                                        timer_8ch_phase <= 1;                                              // switch phase
                                        timer_io_latch2 <= timer_io_latch;                                 // latch sample
                                    end else begin
                                        // odd phase so we're done with this word
                                        timer_mem_data_in <= {timer_io_latch[7:0], timer_io_latch2[7:0] }; // store new sample in top half of word (because we write the bottom half to even addresses in memory)
                                        timer_8ch_phase <= 0;                                              // switch phase
                                        timer_mem_ptr   <= timer_mem_ptr + 16'd2;                          // advance to next memory address
                                        timer_mem_wren  <= 1;
                                    end
                                end
                                timer_post_cnt <= timer_post_cnt - timer_triggered;     // only decrement post count after trigger
                            end else begin
                                timer_mem_wren <= 0;                                    // outside of prescale we turn off writes
                                timer_prescale_cnt <= timer_prescale_cnt + 1'b1;
                            end
                        end else begin
                            // we're done sampling
                            timer_mem_wren <= 0;                                        // turn off memory write
                            timer_start    <= 0;                                        // disable timer
                            timer_state    <= TIMER_IDLE;                               // return to IDLE state
                        end                            
                    end
                default:
                    begin
                    end
            endcase
        end
    end
endmodule