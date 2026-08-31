// These are reference blocks for nanocache

`ifndef EXTERN_CONFIG
// your cache config, this is an example
// 16KB cache, 32byte line, registered, DP
`define CACHE_SIZE      14
`define CACHE_LINE       5
`define CACHE_LINES      (`CACHE_SIZE - `CACHE_LINE)
`define CACHE_REGISTERED 1
`define CACHE_DP         1
`define SRAM_ADDR_WIDTH 24
`endif

// this is the wrapper for our TAG memory
module nanocache_tag_mem #(
    parameter WIDTH=2 + `SRAM_ADDR_WIDTH - `CACHE_LINE - `CACHE_LINES,      // width of data in bits
    parameter DEPTH=`CACHE_LINES,                                           // address width in bits
    parameter REG=`CACHE_REGISTERED
)(
    input wire clk,
    input wire rst_n,

    output reg [WIDTH-1:0] mem_out,
    input wire [WIDTH-1:0]  mem_in,
    input wire [DEPTH-1:0] addr,
    input wire wren
);  
    reg [WIDTH-1:0] tagmem [0:(1<<DEPTH)-1];
    reg [WIDTH-1:0] tmpout;
    always @(posedge clk) begin
        if (wren) begin
            tagmem[addr] <= mem_in;
        end else begin
            if (REG == 1) begin
                tmpout  <= tagmem[addr];
                mem_out <= tmpout;
            end else begin
                mem_out <= tagmem[addr];
            end
        end
    end
endmodule

// wrapper for our cache memory
module nanocache_cache_mem #(
    parameter WIDTH=8,                      // width of data in bits
    parameter DEPTH=`CACHE_SIZE,            // address width in bits
    parameter REG=`CACHE_REGISTERED,
    parameter DP=`CACHE_DP
)(
    input wire clk,
    input wire rst_n,

    output reg [WIDTH-1:0] mem_out_1,
    input wire [WIDTH-1:0]  mem_in_1,
    input wire [DEPTH-1:0]  mem_addr_1,
    input wire              mem_wren_1,

    output reg [WIDTH-1:0] mem_out_2,
    input wire [WIDTH-1:0]  mem_in_2,
    input wire [DEPTH-1:0]  mem_addr_2,
    input wire              mem_wren_2
);
    reg [WIDTH-1:0] cachemem[0:(1<<DEPTH)-1];
    reg [WIDTH-1:0] tmpout;
    reg [WIDTH-1:0] tmpout2;

    always @(posedge clk) begin
        if (mem_wren_1) begin
            cachemem[mem_addr_1] <= mem_in_1;
        end else begin
            if (REG == 1) begin
                tmpout    <= cachemem[mem_addr_1];
                mem_out_1 <= tmpout;
            end else begin
                mem_out_1 <= cachemem[mem_addr_1];
            end
        end
        if (DP == 1) begin
            if (mem_wren_2) begin
                cachemem[mem_addr_2] <= mem_in_2;
            end else begin
                if (REG == 1) begin
                    tmpout2   <= cachemem[mem_addr_2];
                    mem_out_2 <= tmpout2;
                end else begin
                    mem_out_2 <= cachemem[mem_addr_2];
                end
            end
        end
    end
endmodule

