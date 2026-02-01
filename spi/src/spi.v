module spi_master(
    input clk,
    input rst,
    input [15:0] baud_div,
    input miso_pin,
    input CPHA,
    input CPOL,
    input [7:0] mosi_in,   // Renamed for clarity: data to send
    input start,

    output reg mosi_pin,
    output reg sclk_pin,
    output reg [7:0] miso_out, // data received
    output reg done
);
    reg [15:0] counter;
    reg [3:0] ticks;
    reg [1:0] state;
    reg [7:0] shift_reg;
    
    // Synchronize MISO to avoid metastability
    reg miso_sync;
    always @(posedge clk) miso_sync <= miso_pin;

    localparam STATE_IDLE=0, STATE_TRANS=1, STATE_DONE=2;

    always @(posedge clk) begin
        if (!rst) begin
        end else begin
            case (state)
                STATE_IDLE: begin
                    done <= 1'b0;
                    sclk_pin <= CPOL; // Use input directly for idle state
                    if (start) begin
                        counter <= baud_div;
                        ticks <= 0;
                        state <= STATE_TRANS;
                        
                        // Handle Bit 7 Setup immediately
                        if (CPHA == 1'b0) begin
                            mosi_pin <= mosi_in[7];
                            shift_reg <= {mosi_in[6:0], 1'b0};
                        end else begin
                            // In CPHA=1, MOSI often changes on the first edge
                            shift_reg <= mosi_in; 
                            mosi_pin <= CPOL; // Placeholder
                        end
                    end
                end

                STATE_TRANS: begin
                    if (counter == 0) begin
                        counter <= baud_div;
                        ticks <= ticks + 1'b1;
                        sclk_pin <= ~sclk_pin; // Toggle clock

                        // 1. Sampling (MISO)
                        // If CPHA=0, sample on leading edges (0, 2, 4...)
                        // If CPHA=1, sample on trailing edges (1, 3, 5...)
                        if (ticks[0] == CPHA) begin
                            miso_out <= {miso_out[6:0], miso_sync};
                        end

                        // 2. Shifting (MOSI)
                        // Shift on the opposite edge of sampling
                        if (ticks[0] == ~CPHA) begin
                            if (ticks < 15) begin
                                mosi_pin <= shift_reg[7];
                                shift_reg <= {shift_reg[6:0], 1'b0};
                            end
                        end

                        if (ticks == 15) state <= STATE_DONE;
                    end else begin
                        counter <= counter - 1'b1;
                    end
                end

                STATE_DONE: begin
                    done <= 1'b1;
                    sclk_pin <= CPOL;
                    state <= STATE_IDLE;
                end
            endcase
        end
    end
endmodule

module spi_slave (
    input rst,
    input sclk,
    input mosi,
    output miso,
    input cs,
    input [7:0] tx_data,   // Data we want to send to Master
    output reg [7:0] rx_data, // Data received from Master
    output reg done
);
    reg [3:0] bit_count;
    reg [7:0] shift_reg;

    // We shift out on the opposite edge the master samples on
    // For Mode 0: Master samples Rising, so Slave changes on Falling
    assign miso = shift_reg[7];

    always @(posedge sclk or posedge cs or negedge rst) begin
        if (!rst) begin end else begin
            if (cs) begin
                bit_count <= 0;
                // rx_data <= 0; // Optional: clear on CS
            end else begin
                // Sample MOSI
                rx_data <= {rx_data[6:0], mosi};
                bit_count <= bit_count + 1'b1;
            end
        end
    end

    always @(negedge sclk or posedge cs or negedge rst) begin
        if (!rst) begin
        end else begin 
            if (cs) begin
                shift_reg <= tx_data; // Load data to send when CS goes low
                done <= 0;
            end else begin
                // Shift out next bit
                shift_reg <= {shift_reg[6:0], 1'b0};
                if (bit_count == 8) done <= 1;
            end
        end
    end
endmodule