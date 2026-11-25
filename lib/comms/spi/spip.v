// SPI peripheral controller
`default_nettype none

module spip (
	input wire       clk,
	input wire       rst_n,
	
	output reg       ready,         // high the cycle mosi_byte is valid

	output reg [7:0] mosi_byte,		// byte from controller
	input wire [7:0] miso_byte,		// byte to send to controller
	
	input wire       cs_pin,
	input wire       sck_pin,
    input wire       mosi_pin,
	output reg       miso_pin
);

    reg [7:0] miso;
    reg [2:0] bitcnt;
    reg       fsmstate;
    reg       prev_sck;

    localparam 
        FSM_IDLE     = 0,
        FSM_TRANSFER = 1;

    always @(posedge clk) begin
        prev_sck <= sck_pin;
        ready    <= 1'b0;

        case (fsmstate)
            FSM_IDLE: begin
                if (~cs_pin) begin 
                    miso     <= {miso_byte[6:0], 1'b0};
                    miso_pin <= miso_byte[7];                                   // preload MISO pin with first bit
                    bitcnt   <= 7;
                    fsmstate <= FSM_TRANSFER;
                end
            end
            FSM_TRANSFER: begin
                if (~prev_sck & sck_pin) begin
                    // posedge of SCK
                    mosi_byte <= {mosi_byte[6:0], mosi_pin};
                    bitcnt    <= bitcnt - 1'b1;
                    if (bitcnt == 0) begin
                        ready  <= 1'b1;
                        bitcnt <= 7;
                    end
                end if (prev_sck & ~sck_pin) begin
                    // negedge of SCK
                    miso_pin  <= miso[7];
                    miso      <= {miso[6:0], 1'b0};
                end else if (bitcnt == 7) begin
                    // haven't hit the first bit yet so latch the MISO byte
                    miso      <= {miso_byte[6:0], 1'b0};
                    miso_pin  <= miso_byte[7];
                end
                if (cs_pin) begin
                    // CS went high
                    fsmstate  <= FSM_IDLE;
                end
            end
        endcase

        if (~rst_n) begin
            prev_sck  <= 1'b1;
            mosi_byte <= 8'h00;
            miso      <= 8'h00;
            bitcnt    <= 7;
            fsmstate  <= FSM_IDLE;
            ready     <= 1'b0;
        end
    end
endmodule