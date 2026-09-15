/* based on nanocache_comb.v but with some important changes

New here:
1.  Uses four parallel 8-bit lanes for the cache memory

From comb.v
1.  Uses combinatorial addressing so once valid goes high the memories start reading
2.  Must use DP=1 and REGISTERED=1
3.  Drops support for unaligned accesses, can only access at dword boundary (supports all write_mask combinations

*/
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
    output reg                       idle,           // waiting in IDLE state

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
    reg [TAG_SIZE-1:0]    data_tag;
    reg [CACHE_LINE-1:0]  data_line_offset;
    reg [CACHE_LINES-1:0] data_line_index;
    
    // tag memory (you must supply a nanocache_tag_mem that infers the corret 
    wire [TAG_BITS-1:0]      tag_mem_out;                          // tag mem output
    reg  [TAG_BITS-1:0]      tag_mem_in;                           // input
    reg  [CACHE_LINES-1:0]   tag_mem_addr;                         // address
    reg  [CACHE_LINES-1:0]   tag_mem_addr_ea;                      // address (effective address)
    reg                      tag_mem_wren;                         // write enable
    nanocache_tag_mem #(
        .WIDTH(TAG_BITS),
        .DEPTH(CACHE_LINES),
        .REG(CACHE_REGISTERED)
    ) tag_mem(
        .clk(clk), .rst_n(rst_n),
        .mem_out(tag_mem_out), .mem_in(tag_mem_in), .addr(tag_mem_addr_ea), .wren(tag_mem_wren)
    );

	// cache memories
	reg [7:0] cache_mem_lane1_out;     // data out
	reg [7:0] cache_mem_lane1_out_tmp; // reg buffer
	reg [7:0] cache_mem_lane1_in;      // data in
	reg [7:0] cache_mem_lane1[0:(1<<(CACHE_SIZE-2))-1];
	reg [7:0] cache_mem_lane2_out;
	reg [7:0] cache_mem_lane2_out_tmp; // reg buffer
	reg [7:0] cache_mem_lane2_in;
	reg [7:0] cache_mem_lane2[0:(1<<(CACHE_SIZE-2))-1];
	reg [7:0] cache_mem_lane3_out;
	reg [7:0] cache_mem_lane3_out_tmp; // reg buffer
	reg [7:0] cache_mem_lane3_in;
	reg [7:0] cache_mem_lane3[0:(1<<(CACHE_SIZE-2))-1];
	reg [7:0] cache_mem_lane4_out;
	reg [7:0] cache_mem_lane4_out_tmp; // reg buffer
	reg [7:0] cache_mem_lane4_in;
	reg [7:0] cache_mem_lane4[0:(1<<(CACHE_SIZE-2))-1];
	reg [CACHE_SIZE-1:0] cache_mem_addr;
	reg [CACHE_SIZE-1:0] cache_mem_addr_ea;
	reg [CACHE_LINE-1:0] cache_mem_next;
	reg [3:0]            cache_mem_wren;
	always @(posedge clk) begin
		cache_mem_lane1_out_tmp <= cache_mem_lane1[cache_mem_addr_ea[CACHE_SIZE-1:2]];
		cache_mem_lane2_out_tmp <= cache_mem_lane2[cache_mem_addr_ea[CACHE_SIZE-1:2]];
		cache_mem_lane3_out_tmp <= cache_mem_lane3[cache_mem_addr_ea[CACHE_SIZE-1:2]];
		cache_mem_lane4_out_tmp <= cache_mem_lane4[cache_mem_addr_ea[CACHE_SIZE-1:2]];
		cache_mem_lane1_out     <= cache_mem_lane1_out_tmp;
		cache_mem_lane2_out     <= cache_mem_lane2_out_tmp;
		cache_mem_lane3_out     <= cache_mem_lane3_out_tmp;
		cache_mem_lane4_out     <= cache_mem_lane4_out_tmp;
		if (cache_mem_wren[0]) begin
			cache_mem_lane1[cache_mem_addr_ea[CACHE_SIZE-1:2]] <= cache_mem_lane1_in;
		end
		if (cache_mem_wren[1]) begin
			cache_mem_lane2[cache_mem_addr_ea[CACHE_SIZE-1:2]] <= cache_mem_lane2_in;
		end
		if (cache_mem_wren[2]) begin
			cache_mem_lane3[cache_mem_addr_ea[CACHE_SIZE-1:2]] <= cache_mem_lane3_in;
		end
		if (cache_mem_wren[3]) begin
			cache_mem_lane4[cache_mem_addr_ea[CACHE_SIZE-1:2]] <= cache_mem_lane4_in;
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
    reg [3:0]               ctrl_write_mask;         // local copy of write_mask
    
    localparam
        FSM_CLEAR_TAGS        = 3'd0,                // Initialize tags to zero on POR
        FSM_IDLE              = 3'd1,                // Idle state waiting for next valid
        FSM_COMPARE_TAG       = 3'd2,                // Loading and comparing the tag, for cache hits this is the state we shift out in
        FSM_EVICT             = 3'd3,                // Evict a full cache line
        FSM_FILL              = 3'd4,                // Fill a full cache line
        FSM_COMPARE_TAG_DELAY = 3'd5,                // Delay cycle before comparing tag when using registered memory
        FSM_EVICT_DELAY       = 3'd6;                // Delay cycle before starting eviction when using registered memory

    always @(*) begin
		// idle signal
		idle                  = (ctrl_fsm == FSM_IDLE ? 1'b1 : 1'b0);

		// addressing
		data_line_offset      = data_addr[CACHE_LINE-1:0];                              // offset into line
		data_line_index       = data_addr[CACHE_LINES+CACHE_LINE-1:CACHE_LINE];         // which line
		data_tag              = data_addr[SRAM_ADDR_WIDTH-1:CACHE_LINE+CACHE_LINES];    // tag 

		// effective addressing into memories
		tag_mem_addr_ea       = tag_mem_addr;
		cache_mem_addr_ea     = cache_mem_addr;
		if (valid) begin
			// a command is starting so set the memory addresses to the data_addr input immediately
			tag_mem_addr_ea   = data_line_index;
			cache_mem_addr_ea = {data_line_index, data_line_offset};
		end

		// next address on cache line
		cache_mem_next        = cache_mem_addr_ea[CACHE_LINE-1:0] + 1'b1;
	end

    always @(posedge clk) begin
		// global resets happen every cycle which simplifes logic a bit no need to manually turn things off everywhere.
        ctrl_spin       <= 1'b0;
        tag_mem_wren    <= 1'b0;
        cache_mem_wren  <= 4'b0000;
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

            // idle state waiting for a command
            {1'b0, FSM_IDLE}:
                begin
                    if (valid) begin
                        // start reading tag and reading from cache
                        tag_mem_addr    <= data_line_index;
                        cache_mem_addr  <= {data_line_index, data_line_offset};
						ctrl_fsm        <= FSM_COMPARE_TAG;
						ctrl_spin       <= 1'b1;
                        ctrl_write_mask <= data_wr_en ? write_mask : 4'b0000;
                        data_out        <= data_in;              // latch the input locally so we only need one shift register
                    end
                end

            // tag compare state (delay cycle to load tag/cache through registered mem)
            {1'b1, FSM_COMPARE_TAG}:
                begin
                end

            {1'b0, FSM_COMPARE_TAG}:
                begin
                    // at this point cache_mem_out is the initial data_line_offset and by the next cycle
                    // it'll be data_line_offset+1 which allows nice read streaming from the cache
                    if (tag_mem_out[VALID_BIT] && data_tag == tag_mem_out[TAG_SIZE-1:0]) begin
						ctrl_fsm <= FSM_IDLE;
						ready    <= 1'b1;
						data_out <= {cache_mem_lane4_out, cache_mem_lane3_out, cache_mem_lane2_out, cache_mem_lane1_out};
						if (ctrl_write_mask != 4'b0000) begin
							// write the tag as dirty since we wrote to it
							tag_mem_in               <= tag_mem_out; // tag bits
							tag_mem_in[DIRTY_BIT]    <= 1'b1;
							tag_mem_wren             <= 1'b1;
							cache_mem_wren           <= ctrl_write_mask;
							{cache_mem_lane4_in, cache_mem_lane3_in, cache_mem_lane2_in, cache_mem_lane1_in} <= data_out;
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
							ctrl_fsm                       <= FSM_EVICT_DELAY;
                        end else begin
                            // line is clean so we can fill first
                            ctrl_fsm                       <= FSM_FILL;
                        end
                    end
                end

			// delay for registered mem on eviction
			{1'b0, FSM_EVICT_DELAY}:
				begin
					ctrl_fsm  <= FSM_EVICT;
					ctrl_spin <= 1;   // add delay to wait for cache data
				end

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
                        psram_data_in                      <= cache_mem_lane1_out;
                        cache_mem_addr[CACHE_LINE-1:0]     <= cache_mem_next;    // advance cache addr for write strobe
                    end

					// the PSRAM is asking for the next byte to write out to PSRAM memory
                    if (psram_write_strobe) begin
                        ctrl_idx                           <= ctrl_idx - 1'b1;
                        case (cache_mem_addr[1:0])
							2'b00: psram_data_in           <= cache_mem_lane1_out;
							2'b01: psram_data_in           <= cache_mem_lane2_out;
							2'b10: psram_data_in           <= cache_mem_lane3_out;
							2'b11: psram_data_in           <= cache_mem_lane4_out;
						endcase
						cache_mem_addr[CACHE_LINE-1:0]     <= cache_mem_next;
                        if (ctrl_idx == 0) begin
                            // evict is done
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
                        cache_mem_addr[CACHE_LINE-1:0] <= cache_mem_next;

						case (cache_mem_next[1:0]) 
							2'b00: cache_mem_wren <= 4'b0001;
							2'b01: cache_mem_wren <= 4'b0010;
							2'b10: cache_mem_wren <= 4'b0100;
							2'b11: cache_mem_wren <= 4'b1000;
						endcase
                        
                        // store data_out matching the corresponding line byte read from PSRAM
                        if (cache_mem_next[CACHE_LINE-1:2] == data_line_offset[CACHE_LINE-1:2]) begin
							// write to to cache (if we're writing to memory check against address)
							case (cache_mem_next[1:0]) 
								2'b00: cache_mem_lane1_in <= ctrl_write_mask[0] ? data_out[7:0]   : psram_data_out;
								2'b01: cache_mem_lane2_in <= ctrl_write_mask[1] ? data_out[15:8]  : psram_data_out;
								2'b10: cache_mem_lane3_in <= ctrl_write_mask[2] ? data_out[23:16] : psram_data_out;
								2'b11: cache_mem_lane4_in <= ctrl_write_mask[3] ? data_out[31:24] : psram_data_out;
							endcase
							case (cache_mem_next[1:0]) 
								2'b00: data_out[7:0]   <= psram_data_out;
								2'b01: data_out[15:8]  <= psram_data_out;
								2'b10: data_out[23:16] <= psram_data_out;
								2'b11: data_out[31:24] <= psram_data_out;
							endcase
                        end else begin
                            // we're not aligned with the host read/write cache line offset
                            // so just store what we read from psram
							case (cache_mem_next[1:0]) 
								2'b00: cache_mem_lane1_in <= psram_data_out;
								2'b01: cache_mem_lane2_in <= psram_data_out;
								2'b10: cache_mem_lane3_in <= psram_data_out;
								2'b11: cache_mem_lane4_in <= psram_data_out;
							endcase
                        end

                        // we hit the last byte of the cache line fill
                        if (ctrl_idx == 0) begin
                            ctrl_fsm          <= FSM_IDLE;
                            ready             <= 1'b1;
                            psram_start_trans <= 1'b0;     // turn off PSRAM transaction
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
            psram_start_trans <= 1'b0;
            tag_mem_in        <= 0;
            tag_mem_addr      <= 0;
            tag_mem_wren      <= 1'b1;
        end
    end
endmodule
