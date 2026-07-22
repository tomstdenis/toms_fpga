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
    reg [3:0] wait_a;
    reg [3:0] wait_b;

    localparam
        WAIT_STATES = 0;

    always @(posedge clk) begin
        if (!rst_n) begin
            cycles      <= 0;
            bus_ready_a <= 0;
            bus_ready_b <= 0;
            bus_data_out_a <= 0;
            bus_data_out_b <= 0;
            wait_a <= 0;
            wait_b <= 0;
        end else begin
            if (bus_valid_a && !bus_ready_a) begin
                wait_a         <= wait_a + 1;
                bus_ready_a    <= wait_a == WAIT_STATES;
                if (bus_wr_en_a) begin
                    mem[bus_addr_a] <= bus_data_in_a;
                end else begin
                    bus_data_out_a <= mem[bus_addr_a];
                end
            end else if (bus_ready_a) begin
                bus_ready_a <= bus_valid_a;
                wait_a      <= 0;
            end

            if (bus_valid_b && !bus_ready_b) begin
                wait_b         <= wait_b + 1;
                bus_ready_b    <= wait_b == WAIT_STATES;
                if (bus_wr_en_b) begin
                    mem[bus_addr_b] <= bus_data_in_b;
                end else begin
                    bus_data_out_b <= mem[bus_addr_b];
                end
            end else if (bus_ready_b) begin
                bus_ready_b <= bus_valid_b;
                wait_b      <= 0;
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

        wait(is_halted == 1 || (cycles == 1_000_000));

        if (!is_halted) begin
            $display("Core did not halt.");
            $fatal;
        end

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
        for (x = 0; x < 4; x++) begin
            if (state[257+x] != cpu_dut.R[x]) begin
                $display("R[%d] reg differs (expected %x got %x)", x, state[257+x], cpu_dut.R[x]);
                $fatal;
            end
        end
        if (state[261][0] != cpu_dut.ZF) begin
            $display("ZF reg differs (expected %x got %x)", state[261], cpu_dut.ZF);
            $fatal;
        end
        $display("PASSED in %d cycles", cycles);
        $finish;
    end
endmodule
