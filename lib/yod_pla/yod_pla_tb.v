`timescale 1ns/1ps

module pla_tb();
	reg clk;
	reg rst_n;

    // Parameters for the simulation
    localparam CLK_PERIOD = 20; // 50MHz Clock
    // Clock Generation
    always #(CLK_PERIOD/2) clk = ~clk;

    localparam PINS = 8;								// how many in/out signals
    localparam TERMS = 16;							// the # of AND blocks
    localparam W_WIDTH = 2 * (PINS + 2); 			// width of the AND block input (determines how many fuses are needed per AND)
	localparam TOTAL_FUSES = 2 * PINS + PINS * TERMS + (1 + W_WIDTH) * TERMS;

	// TB Registers - matching the logic of your offsets
	reg							tb_clk;
	reg [(TERMS * W_WIDTH)-1:0] tb_and_fuses;    // AND[x]'s input signal y is x * W_WIDTH + y
	reg [TERMS-1:0]             tb_and_outsel;
	reg [(PINS * TERMS)-1:0]    tb_or_fuses;     // OR[x]'s AND[y] input is at x * TERMS + y
	reg [PINS-1:0]              tb_or_outsel;
	reg [PINS-1:0]              tb_or_invert;
	wire [PINS-1:0] 			tb_out;
	reg [PINS-1:0]				tb_in;

	// The "Giant Wire" that feeds the PLA
	wire [TOTAL_FUSES-1:0] all_fuses = {
		tb_or_invert,
		tb_or_outsel,
		tb_or_fuses,
		tb_and_outsel,
		tb_and_fuses
	};

	// Instantiate your cleaner PLA
	pla #(.PINS(PINS), .TERMS(TERMS)) dut (
		.clk(tb_clk),
		.rst_n(rst_n),
		.in_sig(tb_in),
		.out_sig(tb_out),
		.fuses(all_fuses)
	);

    integer i;
    integer test_phase;
	
	initial begin
        // Waveform setup
        $dumpfile("yod_pla.vcd");
        $dumpvars(0, pla_tb);
		clk = 0;
		rst_n = 0;

		// clear out fuses
		tb_and_fuses = -1;
		tb_and_outsel = 0;
		tb_or_fuses = 0;
		tb_or_outsel = 0;
		tb_or_invert = 0;
		tb_in = 0;
		tb_clk = 0;
		test_phase = 0;
		
		// Reset system
        repeat(3) @(posedge clk);
        rst_n = 1;
		@(posedge clk); #1;

		// test 1: AND two input together (a & b)
		test_phase = 1;
			// let's try some basic stuff let's AND two inputs
			tb_and_fuses[0] = 0; // select input[0] (note sense is inverted since we OR unused inputs with 1 before ANDing to effectively cancel them out)
			tb_and_fuses[2] = 0; // select input[1]
			tb_or_fuses[0]  = 1; // select and[0]   (the OR fuses are normal sense, 1==selected, 0==ignore)
			
			// a AND b
			for (i = 0; i < 4; i = i + 1) begin
				@(posedge clk);
				tb_in[0] = i[0];
				tb_in[1] = i[1];
				@(posedge clk);
				expect_out(tb_out[0], i[0] & i[1]);
			end
			// reset fuses
			tb_and_fuses = -1;
			tb_or_fuses = 0;

		// test 2: OR two input together, this requires two AND blocks... (a) | (b)
		test_phase = 2;
			// let's try some basic stuff let's AND two inputs
			// AND[0] select input[0]
			tb_and_fuses[0] = 0; // select input[0] (note sense is inverted since we OR unused inputs with 1 before ANDing to effectively cancel them out)
			// AND[1] select input[1]
			tb_and_fuses[1 * W_WIDTH + 2] = 0; // select input[1]
			tb_or_fuses[0]  = 1; // select and[0]   (the OR fuses are normal sense, 1==selected, 0==ignore)
			tb_or_fuses[1]  = 1; // select and[1]
			// a OR b
			for (i = 0; i < 4; i = i + 1) begin
				@(posedge clk);
				tb_in[0] = i[0];
				tb_in[1] = i[1];
				@(posedge clk);
				expect_out(tb_out[0], i[0] | i[1]);
			end
			// reset fuses
			tb_and_fuses = -1;
			tb_or_fuses = 0;
			
		// test 3: XOR two inputs together (a & ~b) | (~a & b)
		test_phase = 3;
			// let's try some basic stuff let's AND two inputs
			// AND[0] select input[0] and ~input[1]
			// the fuses are arranged as (from lsb up) input[0], ~input[0], input[1], ~input[1], ...
			tb_and_fuses[0] = 0; // select input[0] (note sense is inverted since we OR unused inputs with 1 before ANDing to effectively cancel them out)
			tb_and_fuses[3] = 0; // select ~input[1]
			// AND[1] select input[1] and ~input[0]
			tb_and_fuses[1 * W_WIDTH + 1] = 0; // select ~input[0]
			tb_and_fuses[1 * W_WIDTH + 2] = 0; // select input[1]
			tb_or_fuses[0]  = 1; // select and[0]   (the OR fuses are normal sense, 1==selected, 0==ignore)
			tb_or_fuses[1]  = 1; // select and[1]
			// a OR b
			for (i = 0; i < 4; i = i + 1) begin
				@(posedge clk);
				tb_in[0] = i[0];
				tb_in[1] = i[1];
				@(posedge clk);
				expect_out(tb_out[0], i[0] ^ i[1]);
			end
			// reset fuses
			tb_and_fuses = -1;
			tb_or_fuses = 0;
		
		// test 4: AND two inputs but one of them is clocked
		test_phase = 4;
			// let's try some basic stuff let's AND two inputs
			tb_and_fuses[0] = 0; // select input[0] (note sense is inverted since we OR unused inputs with 1 before ANDing to effectively cancel them out)
			tb_and_fuses[2] = 0; // select input[1]
			tb_and_outsel[0] = 1; // AND[0] output is from the DFF
			tb_or_fuses[0]  = 1; // select and[0]   (the OR fuses are normal sense, 1==selected, 0==ignore)

			// a AND b
			for (i = 0; i < 4; i = i + 1) begin
				tb_in[0] = i[0];
				tb_in[1] = i[1];
				@(posedge clk); #1;
				tb_clk = 1;
				@(posedge clk); #1;
				tb_clk = 0;
				expect_out(tb_out[0], i[0] & i[1]);
			end
			// reset fuses
			tb_and_fuses = -1;
			tb_or_fuses = 0;
			tb_and_outsel = 0;
			tb_clk = 0;

		// test 5: XNOR two inputs together (a & ~b) | (~a & b) ^ 1
		test_phase = 5;
			// let's try some basic stuff let's AND two inputs
			// AND[0] select input[0] and ~input[1]
			// the fuses are arranged as (from lsb up) input[0], ~input[0], input[1], ~input[1], ...
			tb_and_fuses[0] = 0; // select input[0] (note sense is inverted since we OR unused inputs with 1 before ANDing to effectively cancel them out)
			tb_and_fuses[3] = 0; // select ~input[1]
			// AND[1] select input[1] and ~input[0]
			tb_and_fuses[1 * W_WIDTH + 1] = 0; // select ~input[0]
			tb_and_fuses[1 * W_WIDTH + 2] = 0; // select input[1]
			tb_or_fuses[0]  = 1; // select and[0]   (the OR fuses are normal sense, 1==selected, 0==ignore)
			tb_or_fuses[1]  = 1; // select and[1]
			// set output polarity
			tb_or_invert[0] = 1; // invert out[0]
			// a OR b
			for (i = 0; i < 4; i = i + 1) begin
				@(posedge clk);
				tb_in[0] = i[0];
				tb_in[1] = i[1];
				@(posedge clk);
				expect_out(tb_out[0], i[0] ^ i[1] ^ 1);
			end
			// reset fuses
			tb_and_fuses = -1;
			tb_or_fuses = 0;
			tb_or_invert = 0;
			
		// test 6: XOR two inputs together (a & ~b) | (~a & b) and use registered output
		test_phase = 6;
			// let's try some basic stuff let's AND two inputs
			// AND[0] select input[0] and ~input[1]
			// the fuses are arranged as (from lsb up) input[0], ~input[0], input[1], ~input[1], ...
			tb_and_fuses[0] = 0; // select input[0] (note sense is inverted since we OR unused inputs with 1 before ANDing to effectively cancel them out)
			tb_and_fuses[3] = 0; // select ~input[1]
			// AND[1] select input[1] and ~input[0]
			tb_and_fuses[1 * W_WIDTH + 1] = 0; // select ~input[0]
			tb_and_fuses[1 * W_WIDTH + 2] = 0; // select input[1]
			tb_or_fuses[0]  = 1; // select and[0]   (the OR fuses are normal sense, 1==selected, 0==ignore)
			tb_or_fuses[1]  = 1; // select and[1]
			tb_or_outsel[0] = 1; // use registered output
			// a OR b
			for (i = 0; i < 4; i = i + 1) begin
				tb_in[0] = i[0];
				tb_in[1] = i[1];
				@(posedge clk);
				tb_clk = 1;
				@(posedge clk);
				tb_clk = 0;
				expect_out(tb_out[0], i[0] ^ i[1]);
			end
			// reset fuses
			tb_and_fuses = -1;
			tb_or_fuses = 0;
			tb_or_outsel = 0;
			tb_clk = 0;

		$finish;
	end

	task expect_out(input data, input val);
		begin
			if (data !== val) begin
				$display("Expecting %d as output got %d", val, data);
				$fatal;
			end;
		end
	endtask
endmodule
