LT_WAIT_FOR_READY:
    begin
        if (bus_ready) begin
            bus_enable <= 0;
            state <= tag;
        end
    end
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