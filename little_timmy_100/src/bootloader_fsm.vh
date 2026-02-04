LT_WAIT_FOR_READY:
    begin
        if (bus_ready) begin
            bus_enable <= 0;
            state <= tag;
        end
    end
LT_BOOTLOADER:
    begin
        bus_be <= 4'b0001;
        bus_addr <= 32'h20000000 + 32'h0008;
        bus_wr_en <= 0;
        bus_enable <= 1;
        tag <= LT_BOOT_WAIT_RX;
        state <= LT_WAIT_FOR_READY;
    end
LT_BOOT_WAIT_RX:
    begin
        if (bus_o_data[0]) begin
            state <= LT_BOOT_READ_CHAR;
        end else begin
            state <= LT_BOOTLOADER; // re-read the UART STATUS
        end
    end
LT_BOOT_READ_CHAR:
    begin
        bus_be <= 4'b0001;
        bus_addr <= 32'h20000000 + 32'h000C;
        bus_wr_en <= 0;
        bus_enable <= 1;
        tag <= LT_BOOT_STORE_CHAR;
        state <= LT_WAIT_FOR_READY;
    end
LT_BOOT_STORE_CHAR:
    begin
        bus_i_data <= bus_o_data;
        bus_be <= 4'b0001;
        bus_addr <= boot_addr;
        bus_wr_en <= 1;
        bus_enable <= 1;
        tag <= LT_BOOT_NEXT_CHAR;
        state <= LT_WAIT_FOR_READY;
        boot_addr <= boot_addr + 1;
    end
LT_BOOT_NEXT_CHAR:
    begin
        if (boot_addr == 17'h10000) begin
            state <= LT_FETCH;
        end else begin
            state <= LT_BOOTLOADER; // re-read UART status
        end
    end