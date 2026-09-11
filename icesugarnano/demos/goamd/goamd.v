module goamd(
	input wire clk,	// 12MHz clock
	output reg led
);
	localparam
		FREQ    = 12_000_000,
		ui_time = FREQ / 10,			// 100ms
		CHAR_G   = 3'h00,
		CHAR_O   = 3'h01,
		CHAR_SPC = 3'h02,
		CHAR_A   = 3'h03,
		CHAR_M   = 3'h04,
		CHAR_D   = 3'h05,
		CHAR_EXC = 3'h06;
/* morse code primer...
    so a UI is 100ms, each letter is made up of dots and dashes
    
    dot            = 1 UI high
    dash           = 3 UI high
    inter dot/dash = 1 UI low
    character gap  = +2 UI (including the 1 inter)
    word gap       = 7 UI
*/    

	// the morse coded message "go amd!!"
	reg [23:0] message;
	reg [7:0] char_morse;

	// timing
	reg [23:0] timer;
	
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
				message     <= {message[20:0], message[23:21]};
				fsm_state   <= STATE_NEXT_BIT;
				case (message[23:21])
					CHAR_G: begin // --.
						char_morse <= 4'b1011; // reversed 
					end
					CHAR_O: begin // ---
						char_morse <= 4'b1111; // reversed 
					end
					CHAR_SPC: begin // intra word gap
						timer <= ui_time * 7;
						fsm_state <= STATE_DELAY;
						fsm_tag   <= fsm_state;
					end
					CHAR_A: begin // .-
						char_morse <= 3'b110;
					end
					CHAR_M: begin // --
						char_morse <= 3'b111;
					end
					CHAR_D: begin // -..
						char_morse <= 4'b1001;
					end
					CHAR_EXC: begin // -.-.--
						char_morse <= 7'b1110101;
					end
				endcase
			end
			STATE_NEXT_BIT: begin
				// dot (0) 1UI, dash (1) 3UI, inter 1UI
				timer      <= char_morse[0] ? (3 * ui_time) : ui_time;
				char_morse <= {1'b0, char_morse[7:1]};
				led        <= 1'b1;
				fsm_state  <= STATE_DELAY;
				fsm_tag    <= (char_morse[7:1] == 1) ? STATE_NEXT_CHAR : fsm_state;
			end
			STATE_DELAY: begin
				timer <= timer - 1'b1;
				if (timer == 1) begin
					led <= 1'b0;
					if (led == 1) begin // inter delay (character, or element)
						timer <= (char_morse == 1) ? (3 * ui_time) : ui_time;
					end else begin
						fsm_state <= fsm_tag;
					end
				end
			end
		endcase
	end
endmodule
