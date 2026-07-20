`timescale 1ns/1ps

module toy_isa_tb();

    reg clk;
    reg rst_n;
    wire is_halted;

    // Clock Generation
    localparam CLK_PERIOD = 20; // 50MHz Clock
    always #(CLK_PERIOD/2) clk = ~clk;

    wire [7:0] bus_addr_a;
    wire [7:0] bus_data_in_a;
    reg [7:0] bus_data_out_a;
    wire bus_wr_en_a;
    wire bus_valid_a;
    reg bus_ready_a;

    wire [7:0] bus_addr_b;
    wire [7:0] bus_data_in_b;
    reg [7:0] bus_data_out_b;
    wire bus_wr_en_b;
    wire bus_valid_b;
    reg bus_ready_b;

    reg [7:0] mem[0:255];
    reg [7:0] state[0:261];
    reg [31:0] cycles;

    always @(posedge clk) begin
        if (!rst_n) begin
            cycles      <= 0;
            bus_ready_a <= 0;
            bus_ready_b <= 0;
            bus_data_out_a <= 0;
            bus_data_out_b <= 0;
        end else begin
            bus_data_out_a <= mem[bus_addr_a];
            bus_ready_a <= bus_valid_a;
            if (bus_valid_a) begin
                if (bus_wr_en_a)
                    mem[bus_addr_a] <= bus_data_in_a;
            end

            bus_data_out_b <= mem[bus_addr_b];
            bus_ready_b <= bus_valid_b;
            if (bus_valid_b) begin
                if (bus_wr_en_b)
                    mem[bus_addr_b] <= bus_data_in_b;
            end

            if (!is_halted) begin
                cycles <= cycles + 1;
            end
        end
    end

    always @(posedge clk) begin
        if (!rst_n)
            rst_n <= 1;
    end

    toy_isa cpu_dut(
        .clk(clk), .rst_n(rst_n), .is_halted(is_halted),

        .bus_addr_a(bus_addr_a), .bus_data_in_a(bus_data_in_a),
        .bus_data_out_a(bus_data_out_a), .bus_wr_en_a(bus_wr_en_a),
        .bus_valid_a(bus_valid_a), .bus_ready_a(bus_ready_a),

        .bus_addr_b(bus_addr_b), .bus_data_in_b(bus_data_in_b),
        .bus_data_out_b(bus_data_out_b), .bus_wr_en_b(bus_wr_en_b),
        .bus_valid_b(bus_valid_b), .bus_ready_b(bus_ready_b));

	integer x;
    initial begin
        // Setup for OSS CAD (GTKWave)
        $dumpfile("toy_isa.vcd");
        $dumpvars(0, toy_isa_tb);

        $readmemh(`PROGRAM_HEX, mem);
        $readmemh(`PROGRAM_STATE, state);

        clk   = 0;
        rst_n = 0;

        wait(is_halted == 1);

        // compare memory
        for (x = 0; x < 256; x++) begin
            if (state[x] != mem[x]) begin
                $display("Mem byte %x differs (expected %x got %x)", x, state[x], mem[x]);
                $fatal;
            end
        end
        // compare registers
        if (state[256] != cpu_dut.PC) begin
            $display("PC reg differs (expected %x got %x)", state[x], cpu_dut.PC);
            $fatal;
        end
        if (state[257+x] != cpu_dut.R[x]) begin
            $display("R[%d] reg differs (expected %x got %x)", x, state[257+x], cpu_dut.R[x]);
            $fatal;
        end
        if (state[261][0] != cpu_dut.ZF) begin
            $display("ZF reg differs (expected %x got %x)", state[261], cpu_dut.ZF);
            $fatal;
        end
        $display("PASSED in %d cycles", cycles);
        $finish;
    end
endmodule

