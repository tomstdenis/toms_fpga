module goamd(
	input wire clk,	// 12MHz clock
	output reg led
);
	localparam
		FREQ    = 12_000_000,
		ui_time = FREQ / 10,			// 100ms
		CHAR_G   = 8'h00,
		CHAR_O   = 8'h01,
		CHAR_SPC = 8'h02,
		CHAR_A   = 8'h03,
		CHAR_M   = 8'h04,
		CHAR_D   = 8'h05,
		CHAR_EXC = 8'h06;
/* morse code primer...
    so a UI is 100ms, each letter is made up of dots and dashes
    
    dot            = 1 UI high
    dash           = 3 UI high
    inter dot/dash = 1 UI low
    character gap  = +2 UI (including the 1 inter)
    word gap       = 7 UI
*/    

	// the morse coded message "go amd!!"
	reg [63:0] message;
	reg [7:0] char_letter;
	reg [7:0] char_morse;
	reg [2:0] char_bits;

	// timing
	reg [31:0] timer;
	
	// fsm
	reg [1:0] fsm_state;
	reg [1:0] fsm_tag;
	
	localparam
		STATE_INIT=0,
		STATE_NEXT_CHAR=1,
		STATE_NEXT_BIT=2,
		STATE_DELAY=3;
		
	initial begin
		fsm_state = STATE_INIT;
		message   = { CHAR_G, CHAR_O, CHAR_SPC, CHAR_A, CHAR_M, CHAR_D, CHAR_EXC, CHAR_EXC };
	end
	
	always @(posedge clk) begin
		case (fsm_state)
			STATE_INIT: begin
				led       <= 1'b0;
				fsm_state <= STATE_NEXT_CHAR;
			end
			STATE_NEXT_CHAR: begin
				char_letter <= message[63:56];
				message     <= {message[55:0], message[63:56]};
				fsm_state   <= STATE_NEXT_BIT;
				case (message[63:56])
					CHAR_G: begin // --.
						char_morse <= 3'b011; // reversed 
						char_bits  <= 3;
					end
					CHAR_O: begin // ---
						char_morse <= 3'b111; // reversed 
						char_bits  <= 3;
					end
					CHAR_SPC: begin // intra word gap
						timer <= ui_time * 7;
						fsm_state <= STATE_DELAY;
						fsm_tag   <= fsm_state;
					end
					CHAR_A: begin // .-
						char_morse <= 2'b10;
						char_bits  <= 2;
					end
					CHAR_M: begin // --
						char_morse <= 2'b11;
						char_bits  <= 2;
					end
					CHAR_D: begin // -..
						char_morse <= 3'b001;
						char_bits  <= 3;
					end
					CHAR_EXC: begin // -.-.--
						char_morse <= 6'b110101;
						char_bits  <= 6;
					end
				endcase
			end
			STATE_NEXT_BIT: begin
				// dot (0) 1UI, dash (1) 3UI, inter 1UI
				timer      <= char_morse[0] ? (3 * ui_time) : ui_time;
				char_morse <= {1'b0, char_morse[7:1]};
				char_bits  <= char_bits - 1'b1;
				led        <= 1'b1;
				fsm_state  <= STATE_DELAY;
				fsm_tag    <= (char_bits == 1) ? STATE_NEXT_CHAR : fsm_state;
			end
			STATE_DELAY: begin
				timer <= timer - 1'b1;
				if (timer == 1) begin
					led <= 1'b0;
					if (led == 1) begin // inter delay (character, or element)
						timer <= (char_bits == 0) ? (3 * ui_time) : ui_time;
					end else begin
						fsm_state <= fsm_tag;
					end
				end
			end
		endcase
	end
endmodule
