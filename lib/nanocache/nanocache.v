/* byte wide nanocache

Gist (doc tbd): 

Cycle 0: when idle then set data_in/data_addr/data_wr_en/valid
Cycle 1: set valid = 0 if not reading/writing more than 1 byte, if writing you can load the 2nd byte into data_in
Cycle 2..N: while ready==0
Cycle N+1: if reading store data_out, if writing (more than 2 bytes) store the 3rd byte in data_in
Cycle N+2...: set valid=0 after the last byte is read/written otherwise keep looping like Cycle N+1

Basically once ready==1 every cycle valid==1 means another byte is read/written from the cache line.  Keep in mind if you
are writing you must preload byte #2 before ready==1 (you can do it after cycle 0).  After you load byte #2, you then
load byte 3,4,5,... every cycle after ready==1.

*/

`timescale 1ns/1ps
`default_nettype none

module nanocache #(
    parameter CACHE_SIZE=11,                // log2(cache_bytes)
    parameter CACHE_LINE=5,                    // log2(cache_line_bytes)

    parameter SRAM_ADDR_WIDTH=24,           // Address width
    parameter DUMMY_BYTES=3,                // number of dummy cycles on a fast read
    parameter FREQ=81                       // frequency of core in MHz used for PSRAM timing
)(
    input wire                       clk,
    input wire                       rst_n,
    
    input wire [7:0]                 data_in,               // byte to write to cache line when data_wr_en==1
    input wire [SRAM_ADDR_WIDTH-1:0] data_addr,             // address in memory to read from
    input wire                       data_wr_en,            // write enable 
    output reg [7:0]                 data_out,              // byte to read
    
    input wire                       valid,                 // request is valid
    output reg                       ready,                 // command is done (must be low before sending next command)
    output wire                      idle,                  // waiting in IDLE state

    // I/O
    input wire [3:0]                 sio_din,               // QPI data in
    output wire [3:0]                sio_dout,              // QPI data out
    output wire                      sio_en,                // QPI output enable (1 == output, 0 == input
    output wire                      cs_pin,                // active low CS pin
    output wire                      sck_pin                // SPI clock
    
);
    // configuration data
    localparam
        CACHE_LINES = CACHE_SIZE - CACHE_LINE,                           // log2(# of cache lines)
        TAG_BITS    = 2 + SRAM_ADDR_WIDTH - CACHE_LINE - CACHE_LINES,    // # of bits in TAG (plus D and V bits)
        TAG_SIZE    = TAG_BITS - 2,                                      // # of bits just in the tag
        VALID_BIT   = TAG_BITS-2,                                        // which bit of the tag array is valid
        DIRTY_BIT   = TAG_BITS-1;                                        // which bit of the tag array is dirty
        
    // input address mapping mapping
    wire [TAG_SIZE-1:0]    data_tag;
    wire [CACHE_LINE-1:0]  data_line_offset;
    wire [CACHE_LINES-1:0] data_line_index;
    
    assign data_line_offset = data_addr[CACHE_LINE-1:0];                            // offset into line
    assign data_line_index  = data_addr[CACHE_LINES+CACHE_LINE-1:CACHE_LINE];        // which line
    assign data_tag         = data_addr[SRAM_ADDR_WIDTH-1:CACHE_LINE+CACHE_LINES];    // tag 

    // tag memory
    reg [TAG_BITS-1:0]      tag_mem_out;
    reg [TAG_BITS-1:0]      tag_mem_in;
    reg [CACHE_LINES-1:0]   tag_mem_addr;
    reg                     tag_mem_wren;
    reg [TAG_BITS-1:0]      tag_mem[0:(1<<CACHE_LINES)-1];
    
    always @(posedge clk) begin
        if (tag_mem_wren) begin
            tag_mem[tag_mem_addr] <= tag_mem_in;
        end else begin
            tag_mem_out <= tag_mem[tag_mem_addr];
        end
    end
    
    // cache memory
    reg [7:0]                cache_mem_out;
    reg [7:0]                cache_mem_in;
    reg [CACHE_SIZE-1:0]     cache_mem_addr;
    reg                      cache_mem_wren;
    reg [7:0]                cache_mem[0:(1<<CACHE_SIZE)-1];
    wire [CACHE_SIZE-1:0]    cache_mem_next;
    assign cache_mem_next =  cache_mem_addr[CACHE_SIZE-1:0] + 1'b1;
    
    always @(posedge clk) begin
        if (cache_mem_wren) begin
            cache_mem[cache_mem_addr] <= cache_mem_in;
        end else begin
            cache_mem_out <= cache_mem[cache_mem_addr];
        end
    end
    
    // psram interface
    reg [7:0]                 psram_data_in;
    reg                       psram_wr_en;
    wire [7:0]                psram_data_out;
    reg                       psram_start_trans;
    reg [SRAM_ADDR_WIDTH-1:0] psram_addr;
    wire                      psram_busy;
    wire                      psram_idle;
    wire                      psram_ready;
    wire                      psram_read_strobe;
    wire                      psram_write_strobe;
    wire [CACHE_LINE-1:0]     psram_zero;
    assign psram_zero = 0;
    
    nanosram #(
        .SRAM_ADDR_WIDTH(SRAM_ADDR_WIDTH),
        .DUMMY_BYTES(DUMMY_BYTES),
        .PSRAM(1),
        .FREQ(FREQ)) memory(
            .clk(clk), .rst_n(rst_n),
            .addr(psram_addr), .data_in(psram_data_in), .wr_en(psram_wr_en), .data_out(psram_data_out),
            .start_trans(psram_start_trans), .busy(psram_busy), .idle(psram_idle),
            .ready(psram_ready), .read_strobe(psram_read_strobe), .write_strobe(psram_write_strobe),
            .sio_din(sio_din), .sio_dout(sio_dout), .sio_en(sio_en), .cs_pin(cs_pin), .sck_pin(sck_pin)
        );
    
    // controller logic
    reg [2:0]               ctrl_fsm;                // what FSM state are we in
    reg [CACHE_LINE-1:0]    ctrl_idx;
    reg                     ctrl_spin;
    reg [7:0]               ctrl_data_in;
    
    localparam
        FSM_CLEAR_TAGS   = 3'd0,
        FSM_IDLE         = 3'd1,
        FSM_COMPARE_TAG  = 3'd2,
        FSM_EVICT        = 3'd3,
        FSM_FILL         = 3'd4,
        FSM_RETIRE       = 3'd5;

    // idle signal
    assign idle = (ctrl_fsm == FSM_IDLE ? 1'b1 : 1'b0);

    always @(posedge clk) begin
        ctrl_spin       <= 1'b0;
        tag_mem_wren    <= 1'b0;
        cache_mem_wren  <= 1'b0;
        case ({ctrl_spin, ctrl_fsm})
            // zero out all of the tags
            {1'b0, FSM_CLEAR_TAGS}:
                begin
                    tag_mem_wren     <= 1'b1;
                    if (tag_mem_addr == ((1<<CACHE_LINES) - 1)) begin
                        ctrl_fsm     <= FSM_IDLE;
                    end else begin
                        tag_mem_addr <= tag_mem_addr + 1'b1;
                    end
                end

            // idle state waiting for a command
            {1'b0, FSM_IDLE}:
                begin
                    if (valid) begin
                        // start reading tag and reading from cache
                        tag_mem_addr   <= data_line_index;
                        cache_mem_addr <= {data_line_index, data_line_offset};
                        ctrl_fsm       <= FSM_COMPARE_TAG;
                        ctrl_spin      <= 1'b1;
                        ctrl_data_in   <= data_in;
                    end
                end

            // tag compare state
            {1'b1, FSM_COMPARE_TAG}:
                begin
                    // since we want to pipeline reads if we hit we need to keep incrementing the cache addr
                    if (~data_wr_en) begin
                        cache_mem_addr[CACHE_LINE-1:0] <= cache_mem_next;        // only advance if we're reading
                    end
                end
            {1'b0, FSM_COMPARE_TAG}:
                begin
                    // at this point cache_mem_out is the initial data_line_offset and by the next cycle
                    // it'll be data_line_offset+1 which allows nice read streaming from the cache
                    if (tag_mem_out[VALID_BIT] && data_tag == tag_mem_out[TAG_SIZE-1:0]) begin
                        // cache line is valid and matches rest of tag
                        // we jump to retire skipping the spin cycle because we incremented the address
                        // in the spin+COMPARE_TAG cycle.  We must make sure we increment the cache addr
                        // below in our ~data_wr_en state
                        ctrl_fsm                     <= FSM_RETIRE;
                        ready                        <= 1; // ready first goes high for first cycle of RETIRE+~spin
                        if (data_wr_en) begin
                            // write the tag as dirty since we wrote to it
                            tag_mem_in               <= tag_mem_out; // tag bits
                            tag_mem_in[DIRTY_BIT]    <= 1'b1;
                            tag_mem_wren             <= 1'b1;
                            // write to cache memory
                            cache_mem_in             <= ctrl_data_in;
                            cache_mem_wren           <= 1'b1;
                        end else begin
                            // we already have cache_mem_addr pointing at the 2nd byte so by time we hit RETIRE+spin we're consistent with FSM_FILL
                            data_out                 <= cache_mem_out;
                            // since we want to pipeline reads if we hit we need to keep incrementing the cache addr
                            cache_mem_addr[CACHE_LINE-1:0] <= cache_mem_next; // only advance if we're reading
                        end
                    end else begin
                        // miss is it a valid line we need to evict?
                        ctrl_idx                           <= (1 << CACHE_LINE) - 1;
                        if (tag_mem_out[DIRTY_BIT]) begin
                            // line is dirty we need to evict it first
                            ctrl_fsm                       <= FSM_EVICT;
                            ctrl_spin                      <= 1;   // add delay to wait for cache data
                            cache_mem_addr[CACHE_LINE-1:0] <= 0;   // read 0th byte of line we are evicting
                        end else begin
                            // line is clean so we can fill first
                            ctrl_fsm                       <= FSM_FILL;
                        end
                    end
                end

            // Evict a line to PSRAM then jump to fill it
            {1'b0, FSM_EVICT}:
                begin
                    if (psram_idle) begin
                        // start at byte zero of the cache line and write it out to PSRAM
                        psram_start_trans                  <= 1'b1;
                        psram_wr_en                        <= 1'b1;
                        psram_addr                         <= {tag_mem_out[TAG_SIZE-1:0], data_line_index, psram_zero};
                        psram_data_in                      <= cache_mem_out;                            // we previously ready this: during EVICT+spin
                        // note we have at least 4 cycles between write strobes so we don't need to
                        // per cycle pipeline reads from the cache mem
                        cache_mem_addr[CACHE_LINE-1:0]     <= cache_mem_next;    // advance cache addr for write strobe
                    end
                    if (psram_write_strobe) begin
                        ctrl_idx                           <= ctrl_idx - 1'b1;
                        if (ctrl_idx == 0) begin
                            // evict is done
                            ctrl_idx                       <= (1 << CACHE_LINE) - 1;
                            ctrl_fsm                       <= FSM_FILL;
                            psram_start_trans              <= 1'b0;
                            psram_wr_en                    <= 1'b0;
                        end else begin
                            psram_data_in                  <= cache_mem_out;
                            cache_mem_addr[CACHE_LINE-1:0] <= cache_mem_next;
                        end
                    end
                end

            // fill a line and write out the new tag then jump to retire (remember to honour data_in/data_out mid fill)
            {1'b0, FSM_FILL}:
                begin
                    // only write data once (there will be multiple cycles per data)        
                    if (psram_idle) begin
                        // configure cache
                        cache_mem_addr           <= {data_line_index, ~psram_zero};    // start at -1 in the cache line since we preincrement during the strobe

                        // start PSRAM read
                        psram_start_trans        <= 1'b1;
                        psram_addr               <= {data_tag, data_line_index, psram_zero};

                        // start write of tag mem
                        tag_mem_in[TAG_SIZE-1:0] <= data_tag;
                        tag_mem_in[DIRTY_BIT]    <= data_wr_en;
                        tag_mem_in[VALID_BIT]    <= 1'b1;
                        tag_mem_wren             <= 1'b1;
                    end
                    if (psram_read_strobe) begin
                        ctrl_idx                 <= ctrl_idx - 1'b1;

                        // write to to cache (if we're writing to memory check against address)
                        cache_mem_wren                 <= 1'b1;
                        cache_mem_addr[CACHE_LINE-1:0] <= cache_mem_next;
                        
                        // store data_out matching the corresponding line byte read from PSRAM
                        if (cache_mem_next == data_line_offset) begin
                            if (~data_wr_en) begin
                                // host is reading this byte so relay to data_out
                                data_out         <= psram_data_out;
                                cache_mem_in     <= psram_data_out;
                            end else begin
                                cache_mem_in     <= ctrl_data_in;
                            end
                        end else begin
                            // we're not aligned with the host read/write cache line offset
                            // so just store what we read from psram
                            cache_mem_in         <= psram_data_out;
                        end

                        // we hit the last byte
                        if (ctrl_idx == 0) begin
                            // last byte
                            ctrl_fsm             <= FSM_RETIRE;   // retire
                            ctrl_spin            <= 1;            // give cycle for host to respond to ready only if they're still waiting
                            psram_start_trans    <= 1'b0;
                            cache_mem_addr[CACHE_SIZE-1:CACHE_LINE] <= data_line_index;
                            cache_mem_addr[CACHE_LINE-1:0]          <= data_line_offset + ~data_wr_en;
                        end                    
                    end
                end

            // host sees 'ready' after this cycle so that by time we get to RETIRE+~spin data_in is valid
            {1'b1, FSM_RETIRE}:
                begin
                    ready <= 1; // ready first goes high for first cycle of RETIRE+~spin
                    if (~data_wr_en) begin
                        cache_mem_addr[CACHE_LINE-1:0] <= cache_mem_next;        // only advance if we're reading
                    end
                end
            // we're done waiting for valid to lower
            {1'b0, FSM_RETIRE}:
                begin
                    if (~valid) begin 
                        ready     <= 1'b0;
                        ctrl_fsm  <= FSM_IDLE;
                    end else begin
                        // stream bytes 2,3,4,...,N-1
                        cache_mem_addr[CACHE_LINE-1:0] <= cache_mem_next;        // advance cache (reads are already ahead, writes start at addr-1)
                        if (data_wr_en) begin
                            cache_mem_in    <= data_in;
                            cache_mem_wren  <= 1;                                // turn on cache write enable
                        end else begin
                            data_out        <= cache_mem_out;
                        end
                    end
                end
			default: begin
				ctrl_fsm     <= FSM_CLEAR_TAGS;
				tag_mem_addr <= 0;
				tag_mem_out  <= 0;
			end
        endcase
        if (~rst_n) begin
            ctrl_fsm          <= FSM_CLEAR_TAGS;
            psram_data_in     <= 0;
            psram_wr_en       <= 1'b0;
            psram_start_trans <= 1'b0;
            cache_mem_addr    <= 0;
            cache_mem_in      <= 0;
            tag_mem_in        <= 0;
            tag_mem_addr      <= 0;
            tag_mem_wren      <= 1'b1;
        end
    end
endmodule
