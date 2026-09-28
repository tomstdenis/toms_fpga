`default_nettype none

module fdiv_serial (
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
        if (~rst_n) begin
            ready   <= 1'b0;
            count   <= 5'd0;
            rem     <= 25'b0;
            q_reg   <= 25'b0;
            div_reg <= 24'b0;
        end else if (valid) begin
            rem     <= {1'b0, sig_a}; // Pre-load dividend into remainder
            q_reg   <= 25'b0;
            div_reg <= sig_b;
            count   <= 5'd25;
            ready   <= 1'b0;
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
        end else begin
            ready <= 1'b0;
        end
    end
endmodule

`default_nettype none

module fdiv
(
    input wire clk,
    input wire rst_n,
    
    input wire [31:0] in_a,
    input wire [31:0] in_b,
    input wire        valid,        // command valid
    
    output reg [31:0] out,          // result
    output reg        ready         // result is valid
);
    reg        a_sign;
    reg [7:0]  a_exp;
    reg [23:0] a_mant;
    reg [23:0] b_mant;
    reg [22:0] res_frac;
    
    wire [24:0] quot;
    reg [1:0]  fsm_state;
    reg        divider_valid;
    wire       divider_ready;
    
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
        FSM_START_DIV = 2'd1,
        FSM_CORE      = 2'd2,
        FSM_NORM      = 2'd3;
    
    always @(posedge clk) begin
        ready         <= 1'b0;
        divider_valid <= 1'b0;
        
        case (fsm_state)
            FSM_IDLE: begin
                if (valid) begin
                    a_sign    <= in_a[31] ^ in_b[31];
                    a_exp     <= in_a[30:23] - in_b[30:23] + 8'd127;
                    a_mant    <= {1'b1, in_a[22:0]};
                    b_mant    <= {1'b1, in_b[22:0]};
                    fsm_state <= FSM_START_DIV;
                end
            end
            
            FSM_START_DIV: begin
                divider_valid <= 1'b1;
                fsm_state     <= FSM_CORE;
            end
            
            FSM_CORE: begin
                if (divider_ready) begin
                    fsm_state <= FSM_NORM;
                    if (quot[24]) begin
                        // Q in [1.0, 2.0): Bit 24 is implicit 1, fraction is quot[23:1]
                        res_frac <= quot[23:1];
                    end else begin
                        // Q in [0.5, 1.0): Bit 23 is implicit 1, fraction is quot[22:0]
                        res_frac <= quot[22:0];
                        a_exp    <= a_exp - 1'b1;
                    end
                end
            end
            
            FSM_NORM: begin
                out       <= {a_sign, a_exp, res_frac};
                ready     <= 1'b1;
                fsm_state <= FSM_IDLE;
            end
        endcase 
        
        if (~rst_n) begin
            ready         <= 1'b0;
            divider_valid <= 1'b0;
            fsm_state     <= FSM_IDLE;
            out           <= 32'b0;
        end
    end
endmodule
