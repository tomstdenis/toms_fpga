LT_WAIT_FOR_READY:
    begin
        if (bus_ready) begin
            boot_step <= boot_step + 1'b1;
            state = tag;
            bus_enable <= 0;
        end
    end

`define BOOT_A
`ifdef BOOT_A
LT_BOOTLOADER:
    begin
        bus_be <= 4'b1111;
        bus_addr[31:0] <= boot_step << 2;
        bus_wr_en <= 1;
        bus_enable <= 1;
        case (boot_step)
            8'd0: 
            begin 
                bus_i_data = 32'h200002b7;  tag <= LT_BOOTLOADER; state <= LT_WAIT_FOR_READY;
            end
            8'd1:
            begin
                bus_i_data = 32'h04100313;  tag <= LT_BOOTLOADER; state <= LT_WAIT_FOR_READY;
            end
            8'd2:
            begin
                bus_i_data = 32'h00130313;  tag <= LT_BOOTLOADER; state <= LT_WAIT_FOR_READY;
            end
            8'd3:
            begin
                bus_i_data = 32'h0082a383;  tag <= LT_BOOTLOADER; state <= LT_WAIT_FOR_READY;
            end
            8'd4:
            begin
                bus_i_data = 32'h0023f393;  tag <= LT_BOOTLOADER; state <= LT_WAIT_FOR_READY;
            end
            8'd5:
            begin
                bus_i_data = 32'h00039263;  tag <= LT_BOOTLOADER; state <= LT_WAIT_FOR_READY;
            end
            8'd6:
            begin
                bus_i_data = 32'h0062a623;  tag <= LT_BOOTLOADER; state <= LT_WAIT_FOR_READY;
            end
            8'd7:
            begin
//                bus_i_data = 32'hfedff06f;  tag <= LT_BOOTLOADER; state <= LT_WAIT_FOR_READY;  // jmp
                bus_i_data = 32'h0062a623;  tag <= LT_BOOTLOADER; state <= LT_WAIT_FOR_READY; // store
            end
            8'd8:
            begin
                bus_i_data = 32'h00130313;  tag <= LT_BOOTLOADER; state <= LT_WAIT_FOR_READY;   // add
            end

/*
            8'd2: 
            begin
                bus_i_data = 32'h0082a383;  tag <= LT_BOOTLOADER; state <= LT_WAIT_FOR_READY;
            end
            8'd3:
            begin
                bus_i_data = 32'h0023f393;  tag <= LT_BOOTLOADER; state <= LT_WAIT_FOR_READY;
            end
            8'd4:
            begin
                bus_i_data = 32'h00039263;  tag <= LT_BOOTLOADER; state <= LT_WAIT_FOR_READY;
            end
            8'd5:
            begin
                bus_i_data = 32'h0062a623;  tag <= LT_BOOTLOADER; state <= LT_WAIT_FOR_READY;
            end
            8'd6:
            begin
                bus_i_data = 32'hff1ff06f;  tag <= LT_BOOTLOADER; state <= LT_WAIT_FOR_READY;
            end
*/            default: state <= LT_EXECUTE;
        endcase
    end
`else
// normal bootloader
LT_BOOTLOADER:
    begin
        bus_be <= 4'b0001;                      // 8-bit
        bus_addr <= 32'h20000000 + 32'h0008;    // read UART_STATUS
        bus_wr_en <= 0;                         // READ
        bus_enable <= 1;
        tag <= LT_BOOT_WAIT_RX;                 // check if RX_READY
        state <= LT_WAIT_FOR_READY;
    end
LT_BOOT_WAIT_RX:
    begin
        if (bus_o_data[0]) begin                // LSB of UART_STATUS is RX_READY
            state <= LT_BOOT_READ_CHAR;
        end else begin
            state <= LT_BOOTLOADER; // re-read the UART STATUS
        end
    end
LT_BOOT_READ_CHAR:
    begin
        bus_be <= 4'b0001;                      // 8-bit
        bus_addr <= 32'h20000000 + 32'h000C;    // from UART_DATA
        bus_wr_en <= 0;                         // READ
        bus_enable <= 1;
        tag <= LT_BOOT_STORE_CHAR;              // Store char
        state <= LT_WAIT_FOR_READY;
    end
LT_BOOT_STORE_CHAR:
    begin
        bus_i_data <= bus_o_data;               // register the received byte
        bus_be <= 4'b0001;                      // 8-bit
        bus_addr <= {15'b0, boot_addr};         // to BRAM
        bus_wr_en <= 1;                         // WRITE
        bus_enable <= 1;
        tag <= LT_BOOT_NEXT_CHAR;               // Check if we need another char
        state <= LT_WAIT_FOR_READY;
        boot_addr <= boot_addr + 1'b1;
    end
LT_BOOT_NEXT_CHAR:
    begin
        if (boot_addr == 16'h8000) begin        // only have 32KB ram 
            state <= LT_FETCH;
        end else begin
            state <= LT_BOOTLOADER; // re-read UART status
        end
    end
`endif