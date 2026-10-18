// single channel DMA controller
// supports copying data, or writing a constant, also can optionally stall the read and/or write pointer
`default_nettype none

module sc_dma #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
) (
    input wire                      clk,
    input wire                      rst_n,
    
    // command
    input wire [ADDR_WIDTH-1:0]     cmd_read_addr,        // read address
    input wire [15:0]               cmd_read_stride,
    input wire [15:0]               cmd_read_width,
    input wire [ADDR_WIDTH-1:0]     cmd_write_addr,       // write address
    input wire [15:0]               cmd_write_stride,
    input wire [15:0]               cmd_write_width,
    input wire [ADDR_WIDTH-1:0]     cmd_length,           // in 32-bit words
    input wire [DATA_WIDTH-1:0]     cmd_constant,         // if we're writing a constant this is the value
    input wire                      cmd_read_advance,     // do we advance the read pointer?
    input wire                      cmd_write_advance,    // do we advance the write pointer?
    input wire                      cmd_write_constant,   // are we writing a constant (so no bus reads)
    input wire                      cmd_scatter_gather,
    input wire                      cmd_valid,            // is the command valid?
    output reg                      cmd_ready,            // is the command ready(done)?
    
    // bus access
    output reg [ADDR_WIDTH-1:0]     bus_addr,             // bus address
    output reg [DATA_WIDTH-1:0]     bus_wdata,            // bus write data
    input wire [DATA_WIDTH-1:0]     bus_rdata,            // bus read data
    output reg [(DATA_WIDTH/8)-1:0] bus_wstrb,            // bus write strobe (1 == write)
    output reg                      bus_valid,            // bus command is valid
    input wire                      bus_ready,            // bus ready response
    output reg                      bus_busy              // bus should follow DMA not CPU
);

    // latch the input command
    reg [ADDR_WIDTH-1:0] job_next_ptr;
    reg [ADDR_WIDTH-1:0] job_read_addr;
    reg [15:0]           job_read_width;
    reg [15:0]           job_read_offset;
    reg [ADDR_WIDTH-1:0] job_read_pitch;
    reg [ADDR_WIDTH-1:0] job_write_addr;
    reg [15:0]           job_write_width;
    reg [15:0]           job_write_offset;
    reg [ADDR_WIDTH-1:0] job_write_pitch;
    reg [ADDR_WIDTH-1:0] job_length;
    reg [DATA_WIDTH-1:0] job_constant;
    reg                  job_read_advance;
    reg                  job_write_advance;
    reg                  job_write_constant;
    reg                  job_scatter_gather;
    reg [2:0]            fsm_state;
    reg [2:0]            job_load_idx;
    
    localparam
        FSM_IDLE        = 0,
        FSM_ISSUE_READ  = 1,
        FSM_WAIT_READ   = 2,
        FSM_ISSUE_WRITE = 3,
        FSM_WAIT_WRITE  = 4,
        FSM_READ_SG     = 5;

    always @(*) begin
        bus_busy = (fsm_state == FSM_IDLE) ? cmd_valid : 1'b1;
    end

    always @(posedge clk) begin
        cmd_ready <= 1'b0;
        
        case (fsm_state)
            // wait for a fresh command
            FSM_IDLE: begin
                if (~cmd_ready & cmd_valid) begin
                    job_next_ptr       <= cmd_read_addr;
                    job_read_addr      <= cmd_read_addr;
                    job_read_width     <= cmd_read_width;
                    job_write_addr     <= cmd_write_addr;
                    job_write_width    <= cmd_write_width;
                    job_length         <= cmd_length;
                    job_constant       <= cmd_constant;
                    job_read_advance   <= cmd_read_advance;
                    job_write_advance  <= cmd_write_advance;
                    job_write_constant <= cmd_write_constant;
                    job_scatter_gather <= cmd_scatter_gather;

                    job_load_idx       <= 0;
                    job_read_pitch     <= cmd_read_stride - cmd_read_width;
                    job_read_offset    <= 0;
                    job_write_pitch    <= cmd_write_stride - cmd_write_width;
                    job_write_offset   <= 0;
                    if (cmd_scatter_gather) begin
                        fsm_state      <= FSM_READ_SG;
                    end else begin
                        fsm_state      <= cmd_write_constant ? FSM_ISSUE_WRITE : FSM_ISSUE_READ;
                    end
                end
            end

            FSM_READ_SG: begin
                if (~bus_valid) begin
                    // issue next read
                    bus_addr     <= job_next_ptr;
                    bus_valid    <= 1'b1;
                    bus_wstrb    <= 0;
                    job_next_ptr <= job_next_ptr + (ADDR_WIDTH/8);
                end
                if (bus_ready) begin
                    bus_valid    <= 0;
                    job_load_idx <= job_load_idx + 1'b1;
                    case (job_load_idx)
                        0: job_read_addr                      <= bus_rdata;
                        1: {job_read_pitch, job_read_width}   <= { bus_rdata[31:16] - bus_rdata[15:0], bus_rdata[15:0] };
                        2: job_write_addr                     <= bus_rdata;
                        3: {job_write_pitch, job_write_width} <= { bus_rdata[31:16] - bus_rdata[15:0], bus_rdata[15:0] };
                        4: job_length                         <= bus_rdata;
                        5: job_constant                       <= bus_rdata;
                        6: {job_read_advance, job_write_advance, job_write_constant} <= bus_rdata[3:1];
                        7: begin
                            job_next_ptr                      <= bus_rdata;
                            fsm_state                         <= job_write_constant ? FSM_ISSUE_WRITE : FSM_ISSUE_READ;
                        end
                    endcase
                end
            end
            
            // issue a bus read
            FSM_ISSUE_READ: begin
                bus_addr   <= job_read_addr;
                bus_wstrb  <= 0;
                bus_valid  <= 1'b1;
                if (job_read_advance) begin
                    job_read_addr <= job_read_addr + (DATA_WIDTH/8);
                end
                job_read_offset <= job_read_offset + (DATA_WIDTH/8);
                fsm_state  <= FSM_WAIT_READ;
            end
            
            // wait for the read to finish (if reading), and then start the write bus transaction
            FSM_WAIT_READ: begin
				if (bus_ready) begin
					bus_valid <= 1'b0;
					fsm_state <= FSM_ISSUE_WRITE;
                    if (job_read_offset == job_read_width) begin
                        job_read_offset <= 0;
                        job_read_addr   <= job_read_addr + job_read_pitch;
                    end
				end
			end
			
			FSM_ISSUE_WRITE: begin
				bus_addr   <= job_write_addr;
				bus_wdata  <= job_write_constant ? job_constant : bus_rdata;
				bus_wstrb  <= (1<<(DATA_WIDTH/8))-1;
				bus_valid  <= 1'b1;
				if (job_write_advance) begin
					job_write_addr <= job_write_addr + (DATA_WIDTH/8);
				end
                job_write_offset <= job_write_offset + (DATA_WIDTH/8);
				job_length <= job_length - (DATA_WIDTH/8);
				fsm_state  <= FSM_WAIT_WRITE;
            end
            
            // wait for the write to complete
            FSM_WAIT_WRITE: begin
                if (bus_ready) begin
					bus_valid <= 1'b0;
                    fsm_state <= job_write_constant ? FSM_ISSUE_WRITE : FSM_ISSUE_READ;
                    if (job_write_offset == job_write_width) begin
                        job_write_offset <= 0;
                        job_write_addr   <= job_write_addr + job_write_pitch;
                    end
                    if (!job_length) begin
                        if (job_scatter_gather && job_next_ptr != 32'b0) begin
                            fsm_state <= FSM_READ_SG;
                        end else begin
                            cmd_ready  <= 1'b1;
                            fsm_state  <= FSM_IDLE;
                        end
                    end
                end
            end
        endcase
    
        if (~rst_n) begin
            fsm_state <= FSM_IDLE;
            bus_valid <= 1'b0;
            cmd_ready <= 1'b0;
        end    
    end
endmodule
