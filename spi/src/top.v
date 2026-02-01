// loop back SPI slave/master test doesn't require any external hookup
module top
(
    input clk,      // Pin 4
    input miso,     // Pin 28 (We'll use this for the Slave's MISO)
    output mosi,    // Pin 27
    output sclk,    // Pin 25
    output reg cs,  // Pin 26
    output [1:0]led      // Pin 15/16
);
    wire pll_clk;
    reg [3:0] rstcnt = 4'b0;
    wire rst;
    assign rst = rstcnt[3];

    Gowin_rPLL pllclk (.clkin(clk), .clkout(pll_clk));

    always @(posedge pll_clk) begin
        rstcnt <= {rstcnt[2:0], 1'b1};
    end

    // Clock math
    wire [15:0] baud_div = 16'd1; // should be 75MHz SPI with a 150MHz clk 
    reg [26:0] counter = 0;
    reg counter_target = 1;

    // Master Signals
    reg start;
    wire [7:0] master_rx_data;
    wire master_done;

    // Slave Signals
    wire slave_miso; // Internal wire from Slave to Master
    wire [7:0] slave_rx_data;
    wire slave_done;
    
    // LED Control (Active Low)
    reg [1:0] led_state = 2'b11; 
    assign led = led_state;

    // --- Master Instance ---
    spi_master master (
        .clk(pll_clk),
        .rst(rst),
        .baud_div(baud_div),
        .miso_pin(slave_miso), // Internal loopback connection
        .CPHA(1'b0),
        .CPOL(1'b0),
        .mosi_in(8'h5A),       // Master sends 0x5A
        .start(start),
        .mosi_pin(mosi),       // Goes to Pin 27
        .sclk_pin(sclk),       // Goes to Pin 25
        .miso_out(master_rx_data),
        .done(master_done)
    );

    // --- Slave Instance ---
    spi_slave slave (
        .rst(rst),
        .sclk(sclk),           // Wired internally
        .mosi(mosi),           // Wired internally
        .miso(slave_miso),     // Wired internally
        .cs(cs),               // Wired internally
        .tx_data(8'hC3),       // Slave sends 0xC3 back
        .rx_data(slave_rx_data),
        .done(slave_done)
    );

    // --- Control Logic ---
    always @(posedge pll_clk) begin
        counter <= counter + 1'b1;

        // trigger every 2**26 cycles
        if (counter[26] == counter_target) begin
            case (counter[1:0])
                2'b00: cs <= 1'b0;              // take CS low for a cycle
                2'b01: start <= 1'b1;           // issue start
                2'b10: start <= 1'b0;           // inhibit start
                2'b11: counter_target = ~counter_target; // wait another 2**26 cycles
            endcase
        end

        if (master_done) begin
            cs <= 1'b1;        // Raises Pin 26
            // Check if we received 0xC3 from the slave
            // If bit 0 is 1 (which it is in 0xC3), turn LED ON (0)
            if (master_rx_data == 8'hC3) 
                led_state[0] <= 1'b0; 
            else 
                led_state[0] <= 1'b1;
            if (slave_rx_data == 8'h5A) 
                led_state[1] <= 1'b0; 
            else 
                led_state[1] <= 1'b1;
        end
    end
endmodule