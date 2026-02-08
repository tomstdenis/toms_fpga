`timescale 1ns/1ps

module sp_bram #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter WIDTH      = 8192
)(
    input  wire                   clk,
    input  wire                   rst_n,
    input  wire                   enable,
    input  wire                   wr_en,
    input  wire [ADDR_WIDTH-1:0]  addr,
    input  wire [DATA_WIDTH-1:0]  i_data,
    input  wire [DATA_WIDTH/8-1:0] be,

    output wire                    ready,
    output wire [DATA_WIDTH-1:0]  o_data,
    output wire                   irq,
    output wire                   bus_err
);

    // --- Internal Signals ---
    reg  [7:0]  addr_off;
    reg         error;
    reg         first;
    reg  [1:0]  pipe_byte_offset;

    wire [31:0] o_mem;
    wire [31:0] effective_addr = addr + addr_off;
    wire [1:0]  byte_offset    = effective_addr[1:0];

    // --- Input Steering (Write Data) ---
    // Using a more compact shift-based approach
    wire [31:0] i_mem = (be == 4'b1111) ? i_data : 
							(be == 4'b0011) ? (byte_offset[1] ? {i_data[15:0], 16'b0} : {16'b0, i_data[15:0]}) :
								(i_data[7:0] << (8 * byte_offset));

    // --- Write Enable Mapping ---
    wire [3:0] be_shifted = (be == 4'b1111) ? 4'b1111 :
								(be == 4'b0011) ? (byte_offset[1] ? 4'b1100 : 4'b0011) :
									(4'b0001 << byte_offset);
    
    wire [3:0] wren = (enable && wr_en) ? be_shifted : 4'b0000;

    // --- Output Steering (Read Data) ---
    // Note: pipe_byte_offset aligns this mux with the 1-cycle BRAM latency
    assign o_data  = !enable ? 32'b0 :
                     (be == 4'b1111) ? o_mem :
                     (be == 4'b0011) ? (pipe_byte_offset[1] ? o_mem[31:16] : o_mem[15:0]) :
                                       ((o_mem >> (8 * pipe_byte_offset)) & 8'hFF);

    assign bus_err = error;
    assign irq     = 1'b0;
    assign ready   = (!first || error) && enable;

    // --- Sequential Logic ---
    always @(posedge clk) begin
        if (!rst_n || !enable) begin
            first            <= 1'b1;
            error            <= 1'b0;
            addr_off         <= 8'h00;
            pipe_byte_offset <= 2'b00;
        end else if (error) begin
        end else begin
            pipe_byte_offset <= byte_offset;
            
            // Handle Ready Logic
			first <= 1'b0;

            // Address Auto-Increment & Alignment Check
            case(be)
                4'b1111: 
				begin
					addr_off <= addr_off + 3'd4;
					if (byte_offset != 2'b00) begin
						error <= 1'b1;
					end
				end
                4'b0011: 
                begin
                    addr_off <= addr_off + 3'd2;
                    if (byte_offset[0]) begin
						error <= 1'b1;
					end
                end
                4'b0001: 
				begin
                    addr_off <= addr_off + 3'd1;
                end
                default: error <= 1'b1;
            endcase
        end
    end

    // --- BRAM Instantiations ---
    // Map to the 4-byte lanes
    genvar k;
    generate
        for (k=0; k<4; k=k+1) begin : mem_lanes
            Gowin_SP b_inst (
                .dout  (o_mem[k*8 +: 8]),
                .clk   (clk),
                .oce   (1'b1),
                .ce    (1'b1),
                .wre   (wren[k]),
                .ad    (effective_addr[$clog2(WIDTH)+1:2]),
                .din   (i_mem[k*8 +: 8]),
                .reset (~rst_n)
            );
        end
    endgenerate

endmodule
