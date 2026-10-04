/*
	float divide, rounds to zero, tracks overflow/underflow, and subnorm

*/

`default_nettype none

module fdiv
#(
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
    reg [1:0]   fsm_state;
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
        FSM_IDLE      = 2'd0,
        FSM_CORE      = 2'd1,
        FSM_NORM      = 2'd2,
        FSM_OUT       = 2'd3;
        
    reg signed [9:0] shift;
    
    always @(posedge clk) begin
        ready         <= 1'b0;
        divider_valid <= 1'b0;
        
        case (fsm_state)
            FSM_IDLE: begin
                if (~ready & valid) begin
                    a_sign        <= in_a[31] ^ in_b[31];
					if (in_a[30:23] == 0) begin
						a_exp          <= 0;
						res_frac[22:0] <= 0;
						ready          <= 1;
					end else begin
						a_exp         <= $signed({2'b0, in_a[30:23]}) - $signed({2'b0, in_b[30:23]}) + 10'sd127;
						a_mant        <= {1'b1, in_a[22:0]};
						b_mant        <= {1'b1, in_b[22:0]};
						divider_valid <= 1'b1;
						fsm_state     <= FSM_CORE;
					end
				end
            end
                        
			FSM_CORE: begin
				if (divider_ready) begin
					fsm_state <= FSM_NORM;
					if (quot[24]) begin
						// Bit 24 is implicit 1, fraction is in quot[23:1]
						res_frac <= {1'b1, quot[23:1]};
						shift    <= 10'sd1 - a_exp;
					end else begin
						// Bit 23 is implicit 1, fraction is in quot[22:0]
						res_frac <= {1'b1, quot[22:0]};
						a_exp    <= a_exp - 1'b1;
						shift    <= 10'sd2 - a_exp;
					end
				end
			end

			FSM_NORM: begin
				if (a_exp < 10'sd1) begin
					if (shift >= 10'sd32) begin
						res_frac  <= 24'd0;
						a_exp     <= 10'sd0;
						fsm_state <= FSM_OUT;
					end else if (shift > 10'sd0) begin
						if (USE_BARREL == 0) begin
							res_frac  <= res_frac >> 1; // Drag implicit 1 down
							shift     <= shift - 1'b1;
						end else begin
							res_frac  <= res_frac >> shift[4:0];
							a_exp     <= 0;
							fsm_state <= FSM_OUT;
						end
					end else begin
						a_exp     <= 10'sd0;
						fsm_state <= FSM_OUT;
					end
				end else begin
					// Normal number: no shift needed
					fsm_state <= FSM_OUT;
				end
			end

            FSM_OUT: begin
                if (a_exp >= 10'sd255) begin
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

    assign quot = q_reg;

    // Cycle 1 compares rem directly; subsequent cycles shift rem left by 1 first
    wire [24:0] current_rem = (count == 5'd25) ? rem : {rem[23:0], 1'b0};
    wire [24:0] sub_res     = current_rem - {1'b0, div_reg};
    wire        sub_fits    = ~sub_res[24]; // 1 if current_rem >= div_reg

    always @(posedge clk) begin
		ready   <= 1'b0;
        if (~rst_n) begin
            count   <= 5'd0;
            rem     <= 25'b0;
            q_reg   <= 25'b0;
            div_reg <= 24'b0;
        end else if (valid) begin
            rem     <= {1'b0, sig_a}; // Pre-load dividend into remainder
            q_reg   <= 25'b0;
            div_reg <= sig_b;
            count   <= 5'd25;
        end else if (count > 5'd0) begin
            if (sub_fits) begin
                rem <= sub_res;
            end else begin
                rem <= current_rem;
            end

            q_reg <= {q_reg[23:0], sub_fits};

            count <= count - 1'b1;
            if (count == 5'd1) begin
                ready <= 1'b1;
            end
        end
    end
endmodule
