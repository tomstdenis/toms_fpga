/*
	float divide, rounds to zero, tracks overflow/underflow, and subnorm

*/

`default_nettype none

module fdiv
#(
    parameter USE_TWO_STAGE_CMP = 1,
	parameter USE_BARREL = 1
)
(
    input wire clk,
    input wire rst_n,
    
    input wire [31:0] in_a,
    input wire [31:0] in_b,
    input wire        valid,
    
    output wire [31:0] out,
    output reg        ready
);
    reg               a_sign;
    reg signed [9:0]  a_exp;
    reg [23:0]        a_mant;
    reg [23:0]        b_mant;
    reg [23:0]        res_frac;  // 24 bits: includes implicit 1 bit [23]
    
    assign out = {a_sign, a_exp[7:0], res_frac[22:0]};
    
    wire [24:0] quot;
    reg [2:0]   fsm_state;
    reg         divider_valid;
    wire        divider_ready;
    
    fdiv_serial fdiv_serial(
        .clk(clk), 
        .rst_n(rst_n), 
        .valid(divider_valid), 
        .sig_a(a_mant), 
        .sig_b(b_mant), 
        .quot(quot), 
        .ready(divider_ready)
    );

    localparam
        FSM_IDLE      = 3'd0,
        FSM_CMP       = 3'd1,
        FSM_CORE      = 3'd2,
        FSM_NORM      = 3'd3,
        FSM_OUT       = 3'd4;
        
    reg signed [9:0] shift;

    reg isnan_a;
    reg isnan_b;
    reg isaz;
    reg isbz;
	wire isnan_a_next = (in_a[30:23] == 8'hFF && (|in_a[22:0] == 1'b1)) ? 1'b1 : 1'b0;
	wire isnan_b_next = (in_b[30:23] == 8'hFF && (|in_b[22:0] == 1'b1)) ? 1'b1 : 1'b0;
    wire isaz_next    = (in_a[30:23] == 0) ? 1'b1 : 1'b0;
    wire isbz_next    = (in_b[30:23] == 0) ? 1'b1 : 1'b0;
    
    always @(posedge clk) begin
        ready         <= 1'b0;
        divider_valid <= 1'b0;
        
        case (fsm_state)
            FSM_IDLE: begin
                if (~ready & valid) begin
                    a_sign        <= in_a[31] ^ in_b[31];
                    if (USE_TWO_STAGE_CMP == 1) begin
                        isnan_a   <= isnan_a_next;
                        isnan_b   <= isnan_b_next;
                        isaz      <= isaz_next;
                        isbz      <= isbz_next;
                        fsm_state <= FSM_CMP;
                    end else begin
                        if (isbz_next || isnan_a_next || isnan_b_next) begin
                            // one of the terms is NaN
                            a_exp          <= 8'hFF;
                            res_frac       <= {1'b1, 22'b0};
                            ready          <= 1;
                        end else if (isaz_next) begin
                            // dividing zero by something shortcut to output zero
                            a_exp          <= 0;
                            res_frac[22:0] <= 0;
                            ready          <= 1;
                        end else begin
                            // doing division prepare inputs to serial divider
                            a_exp         <= $signed({2'b0, in_a[30:23]}) - $signed({2'b0, in_b[30:23]}) + 10'sd127;
                            a_mant        <= {1'b1, in_a[22:0]};
                            b_mant        <= {1'b1, in_b[22:0]};
                            divider_valid <= 1'b1;
                            fsm_state     <= FSM_CORE;
                        end
                    end
				end
            end
            FSM_CMP: begin
                if (USE_TWO_STAGE_CMP == 1) begin
                    if (isbz || isnan_a || isnan_b) begin
                        // one of the terms is NaN
                        a_exp          <= 8'hFF;
                        res_frac       <= {1'b1, 22'b0};
                        ready          <= 1;
                        fsm_state      <= FSM_IDLE;
                    end else if (isaz) begin
                        // dividing zero by something shortcut to output zero
                        a_exp          <= 0;
                        res_frac[22:0] <= 0;
                        ready          <= 1;
                        fsm_state      <= FSM_IDLE;
                    end else begin
                        // doing division prepare inputs to serial divider
                        a_exp         <= $signed({2'b0, in_a[30:23]}) - $signed({2'b0, in_b[30:23]}) + 10'sd127;
                        a_mant        <= {1'b1, in_a[22:0]};
                        b_mant        <= {1'b1, in_b[22:0]};
                        divider_valid <= 1'b1;
                        fsm_state     <= FSM_CORE;
                    end
                end
            end
            
            // wait for serial divide to finish then normalize mantissa
			FSM_CORE: begin
				if (divider_ready) begin
                    // divider is ready and quotient is stored in quot
					fsm_state <= FSM_NORM;
					if (quot[24]) begin
						// Bit 24 is implicit 1, fraction is in quot[23:1]
						res_frac <= {1'b1, quot[23:1]};
                        // we shift until exp==1 (before implied bias)
						shift    <= 10'sd1 - a_exp;
					end else begin
						// Bit 23 is implicit 1, fraction is in quot[22:0]
						res_frac <= {1'b1, quot[22:0]};
						a_exp    <= a_exp - 1'b1;
                        // shift changes because we moved the starting point
                        // of the quotient since bit 24 was 0
						shift    <= 10'sd2 - a_exp;
					end
				end
			end

			FSM_NORM: begin
				if (a_exp < 10'sd1) begin
                    // here we're handling the case that the final exponent was 
                    // smaller than -127 so we shift the quotient right while 
                    // adding to the exponent until it's in range.  This captures
                    // subnormal data
					if (shift >= 10'sd32) begin
                        // excessive shift just zero out
						res_frac  <= 24'd0;
						a_exp     <= 10'sd0;
						fsm_state <= FSM_OUT;
					end else if (shift > 10'sd0) begin
                        // shift quotient right shift bits
						if (USE_BARREL == 0) begin
                            // without a barrel shifter
							res_frac  <= res_frac >> 1; // Drag implicit 1 down
							shift     <= shift - 1'b1;
						end else begin // (USE_BARREL == 1)
                            // use a barrel shifter in one shot
							res_frac  <= res_frac >> shift[4:0];
							a_exp     <= 0;
							fsm_state <= FSM_OUT;
						end
					end else begin
                        // done (via serial shift)
						a_exp     <= 10'sd0;
						fsm_state <= FSM_OUT;
					end
				end else begin // (a_exp >= 10'sd1)
					// Normal number: no shift needed
					fsm_state <= FSM_OUT;
				end
			end

            // generate output
            FSM_OUT: begin
                if (a_exp >= 10'sd255) begin
                    // exponent is overflow just output max
                    a_exp    <= 10'sd254;   // Set exponent to 0xFE (max finite float)
                    res_frac <= 24'h7FFFFF; // Max finite mantissa
                end
                ready     <= 1'b1;
                fsm_state <= FSM_IDLE;
            end
        endcase 
        
        if (~rst_n) begin
            ready         <= 1'b0;
            divider_valid <= 1'b0;
            a_sign        <= 1'b0;
            a_exp         <= 10'sd0;
            res_frac      <= 24'd0;
            fsm_state     <= FSM_IDLE;
        end
    end
endmodule

module fdiv_serial #(
    parameter USE_TWO_STAGE_CMP = 1,
	parameter USE_BARREL=1
)
(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        valid,
    input  wire [23:0] sig_a,   // Dividend (24 bits)
    input  wire [23:0] sig_b,   // Divisor  (24 bits)
    output wire [24:0] quot,    // Quotient (25 bits)
    output reg         ready
);
    reg [24:0] rem;
    reg [24:0] q_reg;
    reg [23:0] div_reg;
    reg [4:0]  count;
    reg        fsm_state;

    assign quot = q_reg;

    wire [24:0] current_rem = (count == 5'd25) ? rem : {rem[23:0], 1'b0};
    wire [24:0] sub_res     = current_rem - {1'b0, div_reg};
    wire        sub_fits    = ~sub_res[24]; // 1 if current_rem >= div_reg

    localparam
        FSM_IDLE   = 0,
        FSM_REDUCE = 1;

    always @(posedge clk) begin
		ready       <= 1'b0;

        case (fsm_state)
            FSM_IDLE: begin
                if (~ready & valid) begin
                    rem       <= {1'b0, sig_a}; // Pre-load dividend into remainder
                    q_reg     <= 25'b0;
                    div_reg   <= sig_b;
                    count     <= 5'd25;
                    fsm_state <= FSM_REDUCE;
                end
            end
            FSM_REDUCE: begin
                // In a schoolbook approach you'd shift both left by X bits 
                // and then shift the divisor right one bit each step
                //
                // instead, this version shifts the remainder left by one bit
                // and keeps the divisor in place.  So it brings the remainder to
                // the divisor instead of bringing the divisor to the remainder.
                //
                // as a result we don't need a 48-bit compare/subtract
                if (sub_fits) begin
                    rem <= sub_res;      // rem = (rem << 1) - div_reg
                end else begin
                    rem <= current_rem;  // rem = (rem << 1)
                end

                // store whether divisor fits
                q_reg <= {q_reg[23:0], sub_fits};

                count <= count - 1'b1;
                if (count == 5'd1) begin
                    ready     <= 1'b1;
                    fsm_state <= FSM_IDLE;
                end
            end
        endcase

        if (~rst_n) begin
            fsm_state <= FSM_IDLE;
            count     <= 5'd0;
            rem       <= 25'b0;
            q_reg     <= 25'b0;
            div_reg   <= 24'b0;
        end
    end
endmodule
