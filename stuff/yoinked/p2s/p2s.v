module p2s (
    input        clk,
    input        reset,
    input        valid_in,
    input  [7:0] data_in,
    output       valid_out,
    output       data_out
);

    reg [7:0] shift_reg;
    reg [2:0] count;
    reg       valid_out_r;

    wire done        = (count == 3'd7);
    wire valid_out_d = valid_in | (valid_out_r & ~done);

 
    always @(posedge clk or posedge reset)
        if (reset)             shift_reg <= #1 8'b0;
        else if (valid_in)     shift_reg <= #1 data_in;
        else                   shift_reg <= #1 {shift_reg[6:0], 1'b0};


    always @(posedge clk or posedge reset)
        if (reset)             count <= #1 3'b0;
        else if (valid_in)     count <= #1 3'b0;
        else if (valid_out_r)  count <= #1 count + 3'b1;


    always @(posedge clk or posedge reset)
        if (reset)  valid_out_r <= #1 1'b0;
        else        valid_out_r <= #1 valid_out_d;

    assign valid_out = valid_out_r;
    assign data_out  = shift_reg[7];
endmodule
