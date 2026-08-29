// nanocache(nanosram) 
`timescale 1ns/1ps
`default_nettype none

module nanocache #(
    parameter CACHE_SIZE=11,                // log2(cache_bytes)
    parameter CACHE_LINE=5,                 // log2(cache_line_bytes)
    parameter CACHE_DP=1,                   // use dual ported cache memory
    parameter CACHE_REGISTERED=1,			// use registered cache memory

    parameter SRAM_ADDR_WIDTH=24,           // Address width
    parameter DUMMY_BYTES=3,                // number of dummy cycles on a fast read
    parameter FREQ=81,                      // frequency of core in MHz used for PSRAM timing
    parameter WAKEUP_DELAY_US=50,           // wakeup delay in uSec
    parameter HANGUP_DELAY_NS=50            // hangup time between commands in nSec
)(
    input wire                       clk,
    input wire                       rst_n,
    
    input wire [31:0]                data_in,        // data to write (from MSB down to LSB)
    input wire [3:0]                 write_mask,     // per byte write mask 
    input wire [SRAM_ADDR_WIDTH-1:0] data_addr,      // address in memory to read from
    input wire                       data_wr_en,     // write enable 
    output reg [31:0]                data_out,       // data read back (MSB first, LSB last)
    
    input wire                       valid,          // request is valid
    output reg                       ready,          // command is done (must be low before sending next command)
    output wire                      idle,           // waiting in IDLE state

    // I/O
    input wire [3:0]                 sio_din,        // QPI data in
    output wire [3:0]                sio_dout,       // QPI data out
    output wire                      sio_en,         // QPI output enable (1 == output, 0 == input)
    output wire                      cs_pin,         // active low CS pin
    output wire                      sck_pin         // SPI clock
);

`ifdef MODEL_SIM
	reg [31:0] stats_hit;
	reg [31:0] stats_miss;
	reg [31:0] stats_evicts;
	reg [31:0] stats_fills;
	reg [31:0] stats_fill_cycles;
	reg [31:0] stats_evict_cycles;
`endif
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
    
    assign data_line_offset = data_addr[CACHE_LINE-1:0];                              // offset into line
    assign data_line_index  = data_addr[CACHE_LINES+CACHE_LINE-1:CACHE_LINE];         // which line
    assign data_tag         = data_addr[SRAM_ADDR_WIDTH-1:CACHE_LINE+CACHE_LINES];    // tag 

    // tag memory
    reg [TAG_BITS-1:0]      tag_mem_out;                          // tag mem output
    reg [TAG_BITS-1:0]      tag_mem_out_tmp;                      // registered staging output
    reg [TAG_BITS-1:0]      tag_mem_in;                           // input
    reg [CACHE_LINES-1:0]   tag_mem_addr;                         // address
    reg                     tag_mem_wren;                         // write enable
    reg [TAG_BITS-1:0]      tag_mem[0:(1<<CACHE_LINES)-1];        // the tag memory itself
    
    // block that drives the tag memory in single ported mode
    always @(posedge clk) begin
        if (tag_mem_wren) begin
            tag_mem[tag_mem_addr] <= tag_mem_in;
        end else begin
			if (CACHE_REGISTERED == 0) begin
				tag_mem_out <= tag_mem[tag_mem_addr];
			end else begin
				tag_mem_out_tmp <= tag_mem[tag_mem_addr];
				tag_mem_out     <= tag_mem_out_tmp;
			end
        end
    end
    
    // cache memory
    // port 1
    reg [7:0]                cache_mem_out;                        // cache mem out
    reg [7:0]                cache_mem_out_tmp;                    // registered staging output
    reg [7:0]                cache_mem_in;                         // input
    reg [CACHE_SIZE-1:0]     cache_mem_addr;                       // address
    reg                      cache_mem_wren;                       // write enable
    reg [7:0]                cache_mem[0:(1<<CACHE_SIZE)-1];       // the cache memory itself

    // some helper wires for advancing inside a cache line
    wire [CACHE_LINE-1:0]    cache_mem_next;                       // next address
    wire [CACHE_LINE-1:0]    cache_mem_next2;                      // address + 2 for dual ported memory builds
    assign cache_mem_next =  cache_mem_addr[CACHE_LINE-1:0] + 1'd1;
    assign cache_mem_next2 = cache_mem_addr[CACHE_LINE-1:0] + 2'd2;  // advance by two for DP cache hits

    // port 2
    reg [7:0]                cache_mem_out2;                       // 2nd port for DP builds
    reg [7:0]                cache_mem_out2_tmp;
    reg [7:0]                cache_mem_in2;
    wire [CACHE_SIZE-1:0]    cache_mem_addr2;
    reg                      cache_mem_wren2;

    // the 2nd port always points to the next byte in the cache line based on where the first port is pointing
    // this simplifies a lot of logic 
    assign cache_mem_addr2 = { cache_mem_addr[CACHE_SIZE-1:CACHE_LINE], cache_mem_next };  
   
    always @(posedge clk) begin
        // we operate these in write OR read mode like a single ported memory
        if (cache_mem_wren) begin
			cache_mem[cache_mem_addr] <= cache_mem_in;
        end else begin
			// if we are using registered memory type builds then we do a two-stage load first into tmp and then into out
			if (CACHE_REGISTERED == 0) begin
				cache_mem_out <= cache_mem[cache_mem_addr];
			end else begin
				cache_mem_out_tmp <= cache_mem[cache_mem_addr];
				cache_mem_out     <= cache_mem_out_tmp;
			end			
        end

        // If dual ported is enabled then we drive the '2' memory ports here in the same manner
        if (CACHE_DP == 1) begin
            if (cache_mem_wren2) begin
                cache_mem[cache_mem_addr2] <= cache_mem_in2;
            end else begin
			if (CACHE_REGISTERED == 0) begin
				cache_mem_out2     <= cache_mem[cache_mem_addr2];
			end else begin
				cache_mem_out2_tmp <= cache_mem[cache_mem_addr2];
				cache_mem_out2     <= cache_mem_out2_tmp;
			end			
            end
        end
    end
    
    // psram interface
    reg [7:0]                 psram_data_in;             // byte to write to PSRAM memory
    reg                       psram_wr_en;               // PSRAM write enable
    wire [7:0]                psram_data_out;            // byte read from PSRAM memory
    reg                       psram_start_trans;         // hold this high while we are still shifting bytes in or out
    reg [SRAM_ADDR_WIDTH-1:0] psram_addr;                // address into the PSRAM to access
    wire                      psram_busy;
    wire                      psram_idle;                // this is high when we can start a transaction
    wire                      psram_ready;
    wire                      psram_read_strobe;         // read strobe goes high the very cycle psram_data_out is valid
    wire                      psram_write_strobe;        // write strobe goes high the cycle just before psram_data_in is read from
    wire [CACHE_LINE-1:0]     psram_zero;                // helper for starting at the start of a cache line
    assign psram_zero = 0;
    
    nanosram #(
        .SRAM_ADDR_WIDTH(SRAM_ADDR_WIDTH),
        .DUMMY_BYTES(DUMMY_BYTES),
        .PSRAM(1),                                       // only work with PSRAMS
        .FREQ(FREQ),
        .WAKEUP_DELAY_US(WAKEUP_DELAY_US),
        .HANGUP_DELAY_NS(HANGUP_DELAY_NS)) memory(
            .clk(clk), .rst_n(rst_n),
            .addr(psram_addr), .data_in(psram_data_in), .wr_en(psram_wr_en), .data_out(psram_data_out),
            .start_trans(psram_start_trans), .busy(psram_busy), .idle(psram_idle),
            .ready(psram_ready), .read_strobe(psram_read_strobe), .write_strobe(psram_write_strobe),
            .sio_din(sio_din), .sio_dout(sio_dout), .sio_en(sio_en), .cs_pin(cs_pin), .sck_pin(sck_pin)
        );
    
    // controller logic
    reg [2:0]               ctrl_fsm;                // what FSM state are we in
    reg [CACHE_LINE-1:0]    ctrl_idx;                // counter used for evicting/filling cache lines
    reg                     ctrl_spin;               // this is used to add a 1 cycle delay to various FSM states
    reg [4:0]               ctrl_write_mask;         // local copy of write_mask the host passes in so we can shift it around
    
    localparam
        FSM_CLEAR_TAGS        = 3'd0,                // Initialize tags to zero on POR
        FSM_IDLE              = 3'd1,                // Idle state waiting for next valid
        FSM_COMPARE_TAG       = 3'd2,                // Loading and comparing the tag, for cache hits this is the state we shift out in
        FSM_EVICT             = 3'd3,                // Evict a full cache line
        FSM_FILL              = 3'd4,                // Fill a full cache line
        FSM_COMPARE_TAG_DELAY = 3'd5,                // Delay cycle before comparing tag when using registered memory
        FSM_EVICT_DELAY       = 3'd6;                // Delay cycle before starting eviction when using registered memory

    // idle signal
    assign idle = (ctrl_fsm == FSM_IDLE ? 1'b1 : 1'b0) & ~ctrl_spin;

    always @(posedge clk) begin
		// global resets happen every cycle which simplifes logic a bit no need to manually turn things off everywhere.
        ctrl_spin       <= 1'b0;
        tag_mem_wren    <= 1'b0;
        cache_mem_wren  <= 1'b0;
        cache_mem_wren2 <= 1'b0;
        ready           <= 1'b0;
        case ({ctrl_spin, ctrl_fsm})
            // zero out all of the tags
            {1'b0, FSM_CLEAR_TAGS}:
                begin
                    tag_mem_wren     <= 1'b1;
                    if (tag_mem_addr == ((1<<CACHE_LINES) - 1)) begin
						// we jump to IDLE at the same time the last write happens.
                        ctrl_fsm     <= FSM_IDLE;
                    end else begin
                        tag_mem_addr <= tag_mem_addr + 1'b1;
                    end
                end

			// land here after an evict in case we need to shift data_out more 
            {1'b1, FSM_IDLE}:
                begin
                    // if we did a read with shifts left near the end of a line fill we need to shift it here
                    // here we're trading a giant mux for a few cycles.  If you want to avoid this don't do reads starting
                    // closer than <4 bytes from the end of a cache line
                    if (ctrl_write_mask[3:0] != 4'b0) begin
                        ctrl_spin       <= 1;
                        data_out        <= {data_out[23:0], 8'h00};
                        ctrl_write_mask <= {ctrl_write_mask[3:0], 1'b0};
                    end
                end

            // idle state waiting for a command
            {1'b0, FSM_IDLE}:
                begin
                    if (valid) begin
                        // start reading tag and reading from cache
                        tag_mem_addr    <= data_line_index;
                        cache_mem_addr  <= {data_line_index, data_line_offset};
                        if (CACHE_REGISTERED == 0) begin
							ctrl_fsm    <= FSM_COMPARE_TAG;
							ctrl_spin   <= 1'b1;
						end else begin
							// registered memory needs an extra cycle for the output
							ctrl_fsm    <= FSM_COMPARE_TAG_DELAY;
						end
                        data_out        <= data_in;              // latch the input locally so we only need one shift register
                        ctrl_write_mask <= { write_mask, 1'b1 }; // LSB is "data is active" where we test ctrl_write_mask[3:0] for non zero
                    end
                end

			// delay for registered mem
			{1'b0, FSM_COMPARE_TAG_DELAY}:
				begin
					if (CACHE_REGISTERED == 1) begin
						ctrl_fsm  <= FSM_COMPARE_TAG;
						ctrl_spin <= 1'b1;
						if (!data_wr_en) begin
							cache_mem_addr[CACHE_LINE-1:0] <= (CACHE_DP == 1) ? cache_mem_next2 : cache_mem_next;        // only advance if we're reading
						end
					end
				end

            // tag compare state
            {1'b1, FSM_COMPARE_TAG}:
                begin
                    // since we want to pipeline reads if we hit we need to keep incrementing the cache addr
                    if (!data_wr_en) begin
						// only advance if we're reading (by 2 for dual ported, by 1 for single)
                        cache_mem_addr[CACHE_LINE-1:0] <= (CACHE_DP == 1) ? cache_mem_next2 : cache_mem_next;
                    end else begin
						// rewind if we're writing since we advance in the COMPARE_TAG state (by 2 for dual ported, 1 for single)
						cache_mem_addr[CACHE_LINE-1:0] <= cache_mem_addr[CACHE_LINE-1:0] - ((CACHE_DP == 1) ? 2'd2 : 1'b1);
					end
                end
            {1'b0, FSM_COMPARE_TAG}:
                begin
                    // at this point cache_mem_out is the initial data_line_offset and by the next cycle
                    // it'll be data_line_offset+1 which allows nice read streaming from the cache
                    if (tag_mem_out[VALID_BIT] && data_tag == tag_mem_out[TAG_SIZE-1:0]) begin
                        if (CACHE_DP == 0) begin
                            // this path is for semi dual ported memory
                            ctrl_write_mask <= { ctrl_write_mask[3:0], 1'b0 };
                            cache_mem_addr[CACHE_LINE-1:0] <= cache_mem_next;

                            // shift data and write mask
                            data_out        <= { data_out[23:0], cache_mem_out };
                            if (data_wr_en & ctrl_write_mask[4]) begin
                                // write the tag as dirty since we wrote to it
                                tag_mem_in               <= tag_mem_out; // tag bits
                                tag_mem_in[DIRTY_BIT]    <= 1'b1;
                                tag_mem_wren             <= 1'b1;
                                // write to cache memory
                                cache_mem_in             <= data_out[31:24];
                                cache_mem_wren           <= 1'b1;
                            end
                            if (ctrl_write_mask[3:0] == 4'b1000) begin
`ifdef MODEL_SIM
								stats_hit <= stats_hit + 1;
`endif						
                                ready     <= 1;
                                ctrl_fsm  <= FSM_IDLE;
                                ctrl_spin <= 1'b0;
                            end
                        end else if (CACHE_DP == 1) begin
                            // this path is for true dual ported memory
                            ctrl_write_mask <= { ctrl_write_mask[2:0], 2'b0 }; // shift by 2
                            cache_mem_addr[CACHE_LINE-1:0] <= cache_mem_next2; // advance by 2

                            // shift data and write mask
                            data_out        <= { data_out[15:0], cache_mem_out, cache_mem_out2 };
                            if (data_wr_en & ctrl_write_mask[4]) begin                  // 1st byte
                                // write the tag as dirty since we wrote to it
                                tag_mem_in               <= tag_mem_out; // tag bits
                                tag_mem_in[DIRTY_BIT]    <= 1'b1;
                                tag_mem_wren             <= 1'b1;
                                // write to cache memory
                                cache_mem_in             <= data_out[31:24];
                                cache_mem_wren           <= 1'b1;
                            end
                            if (data_wr_en & ctrl_write_mask[3]) begin                  // 2nd byte
                                // write the tag as dirty since we wrote to it
                                tag_mem_in               <= tag_mem_out; // tag bits
                                tag_mem_in[DIRTY_BIT]    <= 1'b1;
                                tag_mem_wren             <= 1'b1;
                                // write to cache memory
                                cache_mem_in2            <= data_out[23:16];
                                cache_mem_wren2          <= 1'b1;
                            end
                            if (ctrl_write_mask[2:0] == 3'b100) begin
`ifdef MODEL_SIM
								stats_hit <= stats_hit + 1;
`endif						
                                ready     <= 1;
                                ctrl_fsm  <= FSM_IDLE;
                                ctrl_spin <= 1'b0;
                            end
                        end
                    end else begin
`ifdef MODEL_SIM
						stats_miss <= stats_miss + 1;
`endif						
                        // miss is it a valid line we need to evict?
                        ctrl_idx                           <= (1 << CACHE_LINE) - 1;
						cache_mem_addr[CACHE_LINE-1:0]     <= psram_zero;
                        if (tag_mem_out[DIRTY_BIT]) begin
                            // line is dirty we need to evict it first
                            if (CACHE_REGISTERED == 0) begin
								ctrl_fsm                   <= FSM_EVICT;
								ctrl_spin                  <= 1;   // add delay to wait for cache data
							end else begin
								ctrl_fsm                   <= FSM_EVICT_DELAY;
							end
                        end else begin
                            // line is clean so we can fill first
                            ctrl_fsm                       <= FSM_FILL;
                        end
                    end
                end

			// delay for registered mem on eviction
			{1'b0, FSM_EVICT_DELAY}:
				begin
					if (CACHE_REGISTERED == 1) begin
						ctrl_fsm  <= FSM_EVICT;
						ctrl_spin <= 1;   // add delay to wait for cache data
					end
				end

            // Evict a line to PSRAM then jump to fill it
            // For registered mem this relies on the fact taht psram_write_strobes occur every
            // 4 cycles giving the necessary time for the registered cache memory to respond
            {1'b0, FSM_EVICT}:
                begin
`ifdef MODEL_SIM
					stats_evict_cycles <= stats_evict_cycles + 1;
`endif					

                    // initiate the transaction only if idle and we haven't already started it.
                    if (~psram_start_trans & psram_idle) begin
`ifdef MODEL_SIM
						stats_evicts <= stats_evicts + 1;
`endif						
                        // start at byte zero of the cache line and write it out to PSRAM
                        psram_start_trans                  <= 1'b1;
                        psram_wr_en                        <= 1'b1;
                        psram_addr                         <= {tag_mem_out[TAG_SIZE-1:0], data_line_index, psram_zero};
                        psram_data_in                      <= cache_mem_out;                            // we previously ready this: during EVICT+spin
                        // note we have at least 4 cycles between write strobes so we don't need to
                        // per cycle pipeline reads from the cache mem
                        cache_mem_addr[CACHE_LINE-1:0]     <= cache_mem_next;    // advance cache addr for write strobe
                    end

					// the PSRAM is asking for the next byte to write out to PSRAM memory
                    if (psram_write_strobe) begin
                        ctrl_idx                           <= ctrl_idx - 1'b1;
						psram_data_in                      <= cache_mem_out;
						cache_mem_addr[CACHE_LINE-1:0]     <= cache_mem_next;
                        if (ctrl_idx == 0) begin
                            // evict is done
// not needed since 0 - 1 is 1<<CACHE_LINE - 1
//                            ctrl_idx                       <= (1 << CACHE_LINE) - 1;
                            ctrl_fsm                       <= FSM_FILL;
                            psram_start_trans              <= 1'b0;
                        end
                    end
                end

            // fill a line and write out the new tag then jump to retire (remember to honour data_in/data_out mid fill)
            {1'b0, FSM_FILL}:
                begin
`ifdef MODEL_SIM
					stats_fill_cycles <= stats_fill_cycles + 1;
`endif					
                    // only write data once (there will be multiple cycles per data)
                    if (~psram_start_trans & psram_idle) begin
`ifdef MODEL_SIM
						stats_fills <= stats_fills + 1;
`endif						
                        // configure cache
                        cache_mem_addr           <= {data_line_index, ~psram_zero};    // start at -1 in the cache line since we preincrement during the strobe

                        // start PSRAM read
                        psram_start_trans        <= 1'b1;
						psram_wr_en              <= 1'b0;
                        psram_addr               <= {data_tag, data_line_index, psram_zero};

                        // start write of tag mem
                        tag_mem_in[TAG_SIZE-1:0] <= data_tag;
                        tag_mem_in[DIRTY_BIT]    <= data_wr_en;
                        tag_mem_in[VALID_BIT]    <= 1'b1;
                        tag_mem_wren             <= 1'b1;
                    end
                    
                    // The PSRAM is informing us a byte is available to be used (stored in the cache line)
                    if (psram_read_strobe) begin
                        ctrl_idx                       <= ctrl_idx - 1'b1;

                        // write to to cache (if we're writing to memory check against address)
                        cache_mem_wren                 <= 1'b1;
                        cache_mem_addr[CACHE_LINE-1:0] <= cache_mem_next;
                        
                        // store data_out matching the corresponding line byte read from PSRAM
                        // This looks for matching the first address and then that the LSB of ctrl_write_mask is non-zero
                        // which indicates we started.  Then we stop once ctrl_write_mask's lower bits are zero indicating
                        // 4 bytes have been processed
                        // This is more efficient than a >= && <= check
                        if ((cache_mem_next == data_line_offset || ~ctrl_write_mask[0]) && ctrl_write_mask[3:0] != 4'b0000) begin
                            data_out         <= { data_out[23:0], psram_data_out };				// shift data
							ctrl_write_mask  <= { ctrl_write_mask[3:0], 1'b0 };					// shift write mask
                            if (data_wr_en & ctrl_write_mask[4]) begin
                                cache_mem_in <= data_out[31:24]; // host is writing so store input (which we stuff in data_out) into cache
                            end else begin
                                cache_mem_in <= psram_data_out;  // host is reading so store psram backed data in cache
                            end
                        end else begin
                            // we're not aligned with the host read/write cache line offset
                            // so just store what we read from psram
                            cache_mem_in     <= psram_data_out;
                        end

                        // we hit the last byte of the cache line fill
                        if (ctrl_idx == 0) begin
                            // last byte
                            ctrl_fsm          <= FSM_IDLE; // IDLE
                            // we need to spin if we have to shift data_out to be in the correct alignment
                            // this happens when we initiate a <4 byte read less than 4 bytes away from the
                            // end of a cache line.
                            ctrl_spin         <= ctrl_write_mask[2:0] == 0 ? 1'b0 : 1'b1;
                            ready             <= ctrl_write_mask[2:0] == 0 ? 1'b1 : 1'b0; // only set ready if there's no spin
                            // turn off PSRAM transaction
                            psram_start_trans <= 1'b0;
                        end
                    end
                end
        endcase
        if (~rst_n) begin
`ifdef MODEL_SIM
			stats_hit    <= 0;
			stats_miss   <= 0;
			stats_evicts <= 0;
			stats_fills  <= 0;
			stats_fill_cycles <= 0;
			stats_evict_cycles <= 0;
`endif	
            ctrl_fsm          <= FSM_CLEAR_TAGS;
            ctrl_idx          <= 0;
            ctrl_write_mask   <= 0;
            psram_start_trans <= 1'b0;
            tag_mem_in        <= 0;
            tag_mem_addr      <= 0;
            tag_mem_wren      <= 1'b1;
        end
    end
endmodule
