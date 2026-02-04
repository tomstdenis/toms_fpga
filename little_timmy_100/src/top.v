module top(
    input clk,
    input rx_pin,
    output tx_pin,
    output led,
    output cpu_pin
);

    reg [3:0] rstcnt = 4'b0;
    assign rst_n = rstcnt[3];

    always @(posedge clk) begin
        rstcnt <= {rstcnt[2:0], 1'b1};
    end

    lt100 lt(.clk(clk), .rst_n(rst_n), .rx_pin(rx_pin), .tx_pin(tx_pin), .pwm(led), .cpu_pin(cpu_pin));

endmodule