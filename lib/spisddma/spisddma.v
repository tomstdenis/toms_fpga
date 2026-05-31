/* SPI SD DMA Block
 
  Facilitates transferring memory between SPI SD cards and host synchronous memories.

            ┌──────────────────┐                 ┌─────────────────┐            ┌──────────────────┐
            │                  │                 │                 │  cs/sck    │                  │
            │                  ├────────────────►│                 ├───────────►│                  │
            │   Host Memory    │   host_mem_*    │                 │ miso/mosi  │      SPI SD      │
            │                  │◄────────────────┤                 │◄──────────►┤                  │
            │                  │                 │     SPI DMA     │            │                  │
            └──────────┬───────┘                 │                 │            └──────────────────┘
                    ▲  │                         │                 │                              
                    │  │                         │                 │                              
                    │  │                         │                 │                              
                    │  ▼                         └──────────┬──────┘                              
            ┌───────┴──────────┐                       ▲    │                                     
            │                  │    cmd_*              │    │                                     
            │                  ├───────────────────────┘    │                                     
            │  SPI DMA Driver  │                            │                                     
            │                  │◄───────────────────────────┘                                     
            │                  │    ready, error, card_is_init                                                         
            └──────────────────┘                                                                  
*/

`timescale 1ns/1ps
`default_nettype none

`include "spisddma.vh"

module spisddma #(
    // =========================================================================
    // PARAMETERS
    // =========================================================================
    parameter HOST_MEM_ADDR   = 11,                   // Address width (default 11 matches 2048x8 / 18kBit DPRAM)
    parameter CLK_FREQ_MHZ    = 50,                   // Core module clock frequency in MHz
    parameter SLOW_CLK        = 100_000,              // SPI initialization clock rate (must be < 400kHz)
    parameter FAST_CLK        = 25_000_000,           // Operational SPI clock rate (typically <= 25MHz)
    parameter READ_CRC_CHK    = 1                     // 1 - CRC must match, 0 - ignore
)(
    // =========================================================================
    // SYSTEM SIGNALS
    // =========================================================================
    input wire clk,                                   // Core system clock
    input wire rst_n,                                 // active-low reset

    // =========================================================================
    // HOST CONTROL BUS
    // =========================================================================
    output reg ready,                                 // Active-high: Module has finished processing current request
    output reg [2:0] error,                           // Error reporting codes (`SPISD_ERR_OK == 2'b00)
    
    // =========================================================================
    // SD CARD STATUS INFO
    // =========================================================================
    output reg card_is_v1,                            // High if Legacy SD v1 (Byte addressing mode)
    output reg card_is_init,                          // High when card initialization sequence finishes successfully
    
    // =========================================================================
    // HOST MEMORY INTERFACE
    // =========================================================================
    output reg [HOST_MEM_ADDR-1:0] host_mem_addr,     // Memory byte address for host reads/writes
    output reg host_mem_wr_en,                        // Write enable strobe to host memory
    output reg [7:0] host_mem_data_in,                // Byte-wide data written TO host memory
    input  wire [7:0] host_mem_data_out,              // Byte-wide data read FROM host memory
    
    // =========================================================================
    // HOST OPERATION REQUESTS (COMMAND PORT)
    // =========================================================================
    input wire cmd_wr_en,                             // Operation type: 0 = Read Sector, 1 = Write Sector
    input wire cmd_valid,                             // Asserted high when command wires are valid and stable
    input wire [31:0] cmd_sector,                     // 32-bit physical 512-byte block/sector address
    input wire [HOST_MEM_ADDR-1:0] cmd_host_address,  // Target base address in host memory

    // =========================================================================
    // PHYSICAL SPI INTERFACE PINS
    // =========================================================================
    input  wire miso_pin,                             // Master In Slave Out (Data from SD card)
    output reg  mosi_pin,                             // Master Out Slave In (Data to SD card)
    output reg  sck_pin,                              // SPI Serial Clock output
    output reg  cs_pin                                // SPI Chip Select (Active Low)
);
    // -------------------------------------------------------------------------
    // Clock Divider Math
    // Half-cycles required to derive target clocks from the core system clock
    // -------------------------------------------------------------------------
    localparam
        SLOW_CLKDIV     = ((CLK_FREQ_MHZ * 500_000) / SLOW_CLK) - 1, 
        FAST_CLKDIV     = ((CLK_FREQ_MHZ * 500_000) / FAST_CLK) - 1; 

    // -------------------------------------------------------------------------
    // Finite State Machine (FSM) State & Sequence Control Registers
    // -------------------------------------------------------------------------
    reg [4:0] state;                              // Primary execution state pointer
    reg [4:0] tag;                                // Callback state pointer used by generalized bit-shifters
    reg [4:0] cmd_tag;                            // Callback state pointer designated for SD command handlers
    reg       fst_clk;                            // Clock select flag: 0 = SLOW_CLKDIV, 1 = FAST_CLKDIV
    reg [3:0] state_step;                         // Multi-purpose step/iteration counter for nested state tracking

    // -------------------------------------------------------------------------
    // SPI Bit-Level and Timing Registers
    // -------------------------------------------------------------------------
    reg [3:0]   bit_cnt;                          // Counter for tracking 0-to-7 serial bits inside byte phases
    wire [3:0]  bit_cnt_orig;
    reg [$clog2(SLOW_CLKDIV):0]  sck_timer;       // Clock divider ticker matching current active speed
    wire [$clog2(SLOW_CLKDIV):0] sck_timer_orig;
    reg [$clog2(FAST_CLK):0]     sck_cycles;      // Counter tracking clock cycles to enforce timeouts
    wire [$clog2(FAST_CLK):0]    timeout;
    reg [7:0]   temp_wire_bits;                   // Shift register capturing incoming/outgoing byte slices
    
    // -------------------------------------------------------------------------
    // SD Command & Block Counters
    // -------------------------------------------------------------------------
    reg [8:0]  cmd_pos;                           // Byte tracking index inside the 512-byte payload data loop
    reg [15:0] cmd_crc16;
    
    // -------------------------------------------------------------------------
    // Command Buffers Mapping to a 48-bit Command Word Packet
    // -------------------------------------------------------------------------
    reg [7:0]   spi_cmd_opcode;                   // Byte 0: Start-bit, Transmission-bit, and 6-bit Command Code
    reg [31:0]  spi_cmd_payload;                  // Bytes 1-4: 32-bit Command Arguments
    reg [7:0]   spi_cmd_crc;                      // Byte 5: 7-bit CRC checksum value shifted with a Stop-bit (1b)
    wire [47:0] spi_cmd_block;                    // Combined bus aggregating the structural layout above
    reg [7:0]   spi_cmd58_byte0;                  // Register to hold the initial OCR response byte from a CMD58
    
    assign bit_cnt_orig   = 7;
    assign timeout        = fst_clk ? FAST_CLK : SLOW_CLK;
    assign sck_timer_orig = ($clog2(SLOW_CLKDIV)+1)'(fst_clk ? FAST_CLKDIV : SLOW_CLKDIV);
    assign spi_cmd_block  = { spi_cmd_opcode, spi_cmd_payload, spi_cmd_crc };
    
    // -------------------------------------------------------------------------
    // FSM State Encodings
    // -------------------------------------------------------------------------
    localparam
        // --- Card Initialization Phases ---
        STATE_INIT_SPI              = 0,        // Output 74+ dummy clock cycles with CS high to wake up SD logic
        STATE_INIT_CMD0             = 1,        // Issue software reset command (CMD0) to force card into SPI mode
        STATE_INIT_CMD0_R1          = 2,        // Validate R1 response for CMD0 (expecting 0x01: Idle), then issue CMD8
        STATE_INIT_CMD8_R1          = 3,        // Evaluate R1 response for CMD8; checking for illegal command (v1 card)
        STATE_INIT_CMD8_READ        = 4,        // Process trailing 32-bit payload of CMD8 to evaluate operational voltage compatibility
        STATE_INIT_CMD55            = 5,        // Transmit App-Command Escape prefix (CMD55) required ahead of ACMD41
        STATE_INIT_CMD55_R1         = 6,        // Process CMD55 response; if accepted, immediately transition to ACMD41
        STATE_INIT_ACMD41_R1        = 7,        // Check ACMD41 R1; loop back if card is still busy initializing (0x01)
        STATE_INIT_CMD58            = 8,        // Request Operating Conditions Register (CMD58) to read capacity info
        STATE_INIT_CMD58_R1         = 9,        // Evaluate R1 status for CMD58 before attempting to parse its register structure
        STATE_INIT_CMD58_READ       = 10,       // Process OCR data: test bit 30 to categorize High Capacity (SDHC) vs Standard (SDSC)
        STATE_INIT_CMD16            = 11,       // Issue CMD16 to force block lengths to standard 512 bytes (Standard Capacity Only)
        STATE_INIT_CMD16_R1         = 12,       // Confirm execution status of CMD16
        STATE_INIT_DONE             = 13,       // Initialization sequence successfully concluded; flag module ready
        
        // --- Shared Core Subroutines ---
        STATE_SEND_CMD              = 14,       // Unload a 6-byte command buffer over MOSI, then pivot to read R1 response
        STATE_READ_R1               = 15,       // Monitor MISO for dropping edge; capture response byte then branch via `cmd_tag`
        STATE_SHIFT_DATA            = 16,       // General-purpose 8-bit full-duplex serializer subroutine
        STATE_IDLE                  = 17,       // Idle resting loop; listening for incoming requests from host system
        STATE_DONE                  = 18,       // End transaction routine: release chip select and clear interface pipelines
        STATE_WAIT_VALID_LOW        = 19,       // Handshake trap: Assert ready flag, block execution until host lowers `cmd_valid`
        
        // --- Write Sector Sequences ---
        STATE_START_WRITE_RESP      = 20,       // Inspect R1 for write access, clear pipeline byte, and route to write token token
        STATE_WRITE_TOKEN           = 21,       // Output Start Block token (0xFE) pointing card logic to data streams
        STATE_WRITE_SHIFT           = 22,       // Sequence 512 data bytes out of host RAM onto physical SPI buses
        STATE_WRITE_CRC             = 23,       // Stream out trailing uncalculated dummy CRC bytes (0xFFFF) and read token status
        STATE_WRITE_BLOCK_RESP      = 24,       // Evaluate block response token; capture data errors or jump to busy checks
        STATE_WRITE_WAIT            = 25,       // Poll MISO lines; keep processing clocks while card pulls bus low (Write Busy)
        
        // --- Read Sector Sequences ---
        STATE_START_READ_RESP       = 26,       // Inspect R1 response returned from read sector command (CMD17)
        STATE_WAIT_TOKEN            = 27,       // Consume padding frames (0xFF) until block start flag (0xFE) drops on MISO
        STATE_READ_SHIFT            = 28,       // Shift in data block from SD card, writing words into host RAM registers
        STATE_READ_CRC              = 29,       // Capture trailing 16-bit CRC framing sequence to close reading cycle
        STATE_READ_CRCCHK           = 30;       // Compare the computed CRC16 to the received one

    // -------------------------------------------------------------------------
    // Macro Routine: setup_spi_cmd
    // Configures command state tracking registers to orchestrate a 6-byte sequence
    // -------------------------------------------------------------------------
	task setup_spi_cmd;
	  input  [7:0] cmd_num;						// Command index code (automatically masks off structural bits 7 and 6)
	  input  [31:0] payload_val;				// 32-bit payload arguments mapping into packet
	  input  [7:0] crc;							// Valid pre-calculated CRC7 with active stop bit (Mandatory for CMD0/CMD8)
	  input  [4:0] ctag;						// Specific FSM return tag pointing where to jump following an R1 capture
	  begin
		spi_cmd_opcode  <= 8'h40 + cmd_num;
		spi_cmd_payload <= payload_val;
		spi_cmd_crc     <= crc;
		state           <= STATE_SEND_CMD;
		cmd_tag         <= ctag;
	  end
	endtask
	
	// compute a bytewise update to the CRC16
	function automatic [15:0] next_crc16_byte;
		input [15:0] current_crc;
		input [7:0]  data_in;
		integer i;
		begin
			next_crc16_byte = current_crc;
			// Process MSB (bit 7) to LSB (bit 0) for SD SPI
			for (i = 7; i >= 0; i = i - 1) begin
				if ((data_in[i] ^ next_crc16_byte[15]) == 1'b1) begin
					next_crc16_byte = (next_crc16_byte << 1) ^ 16'h1021;
				end else begin
					next_crc16_byte = (next_crc16_byte << 1);
				end
			end
		end
	endfunction	
	
/* 
	============================================================================
	SD CARD INITIALIZATION PROTOCOL FLOWCHART
	============================================================================
	
	1. POWER-UP / CLOCK PRECONDITIONING:
	   Cards boot natively in SD Native Bus Mode. Driving at least 74 SCK pulses with 
	   MOSI and CS asserted high transitions internal states into a ready condition. 
	   Handled during `STATE_INIT_SPI` at the slow initialization rate.
	    
	2. INITIAL SOFTWARE RESET (GO_IDLE_STATE):
	   Transmitting a standard CMD0 packet forces internal card control units to map 
	   SPI architectures. Checks for an "In Idle State" response code (0x01).
	    
	3. PROTOCOL VERSION DIFFERENTIATION:
	   A CMD8 packet is issued next. If rejected with an Illegal Opcode error (0x04) 
	   or if a timeout occurs, the target device is classified as a Legacy SD v1 Card. 
	   Valid acceptance and echo tracking confirms an SD v2 Standard/High Capacity device.
	    
	4. OPERATIONAL WAKE-UP SEQUENCE:
	   The system enters a repetitive inquiry loop sending an ACMD41 sequence 
	   (prefixed by application command escape code CMD55). Loop exits once response 
	   flags turn 0x00, signaling structural initialization complete.
	    
	5. CAPACITY INTERROGATION:
	   SD v2 branches to query configuration data via CMD58. Extracting bits inside 
	   the Operating Conditions Register distinguishes Block Addressing (SDHC/SDXC) 
	   from Byte Addressing (SDSC).
	    
	6. BLOCK REGISTRATION:
	   Byte-addressable variants (v1 and v2 Standard Capacity) execute CMD16 to force 
	   the system block size window exactly to 512 bytes. High-capacity variants 
	   natively defaults here, bypassing the state completely.
	
	============================================================================
	HOST CONTROLLER APPLICATION INTERFACE RULES
	============================================================================
	1. Poll for the `card_is_init` status indicator to go high.
	2. Configure control parameters across the `cmd_*` input wire busses.
	3. Assert `cmd_valid` high to execute. Monitor for `ready == 1` or an `error != 0`.
	4. De-assert `cmd_valid` once operations finish to reset handshake channels.
*/

    always @(posedge clk) begin
        if (!rst_n) begin
            // mandatory for proper reset
            state               <= STATE_INIT_SPI;                          // Jump to initial FSM state
            tag                 <= 0;
            sck_timer           <= 0;
            mosi_pin            <= 1'b1;
            sck_pin             <= 1'b0;                                    // default low
            cs_pin              <= 1'b1;                                    // default high
            temp_wire_bits      <= 8'h00;
            bit_cnt             <= 4'h0;
            error               <= `SPISD_ERR_OK;
            card_is_init        <= 1'b0;
            state_step          <= 0;

            // shared reset/init_spi nets
            host_mem_addr       <= 0;
            host_mem_wr_en      <= 0; //keep
            host_mem_data_in    <= 0;
            ready               <= 0; //keep
            spi_cmd_opcode      <= 0;
            spi_cmd_payload     <= 0;
            spi_cmd_crc         <= 0;
            card_is_init        <= 1'b0; //keep
            card_is_v1          <= 1'b0; //keep
            fst_clk             <= 1'b0; //keep    
        end else begin
            case(state)
                // this performs a partial reset of the module, then sends 10 'FFs with the CS pin high
                STATE_INIT_SPI:
                    begin
                        if (!cmd_valid) begin
                            // wait for host to drop valid if there's an error (marked keeps we must have to have sanity)
                            host_mem_addr        <= 0;
                            host_mem_wr_en       <= 0;                            // keep
                            host_mem_data_in     <= 0;
                            ready                <= 0;                            // keep
                            spi_cmd_opcode       <= 0;
                            spi_cmd_payload      <= 0;
                            spi_cmd_crc          <= 0;
                            card_is_init         <= 1'b0;                        // keep
                            card_is_v1           <= 1'b0;                        // keep
                            fst_clk               <= 1'b0;                        // keep

                            // send 8 FF's with CS high
                            sck_cycles             <= 0;
                            cs_pin                 <= 1'b1;
                            state_step             <= (state_step == 9) ? 0 : (state_step + 1'b1);
                            temp_wire_bits         <= 8'hFF;
                            mosi_pin               <= 1'b1;
                            bit_cnt                <= bit_cnt_orig;
                            sck_timer              <= ($clog2(SLOW_CLKDIV)+1)'(SLOW_CLKDIV);
                            state                  <= STATE_SHIFT_DATA;
                            tag                    <= (state_step == 9) ? STATE_INIT_CMD0 : STATE_INIT_SPI;
                        end
                    end
                
                // Send the initial CMD0 to see if we're in SPI mode
                STATE_INIT_CMD0:
                    begin
                        // send a CMD0
                        cs_pin          <= 1'b0;
                        sck_pin         <= 1'b0;
                        setup_spi_cmd(8'd0, 32'h0, 8'h95, STATE_INIT_CMD0_R1);
                    end
                    
                // process the R1, should get 01 (in idle state) back if not we're not in SPI mode
                STATE_INIT_CMD0_R1:
                    begin
                        if (temp_wire_bits != 8'h01) begin
                            // not in idle state try again (TODO: with delay...)
                            state           <= STATE_INIT_SPI;
                        end else begin
                            // Got idle state, send CMD8(0x1AA) CRC: 0x87, this command checks if we have a v2 card
                            setup_spi_cmd(8'd8, 32'h1AA, 8'h87, STATE_INIT_CMD8_R1);
                        end
                    end
                
                // process CMD8 R1, a 04h indicates an opcode error (v1 card), otherwise if idle read the OCR payload
                STATE_INIT_CMD8_R1:
                    begin
                        if ((temp_wire_bits & 8'h04) == 8'h04) begin
                            // card is v1 so skip to switching to ready mode CMD55
                            card_is_v1     <= 1'b1;
                            state          <= STATE_INIT_CMD55;
                        end else begin
                            if (temp_wire_bits == 8'h01) begin
                                // command successful so read the 32-bits of payload back (preload first byte)
                                tag        <= STATE_INIT_CMD8_READ;
                                state      <= STATE_SHIFT_DATA;
                                state_step <= 0;
                            end else begin
                                // not getting 01 back means it's a card error
                                state <= STATE_INIT_SPI;
                            end
                        end
                    end
                
                // read 32-bits from CMD8 response, should get back voltage ok (01) and echo back of our data (AA)
                STATE_INIT_CMD8_READ:
                    begin
                        state <= (state_step == 3) ? STATE_INIT_CMD55 : STATE_SHIFT_DATA;
                        case (state_step)
                            0: if (temp_wire_bits != 8'h00) state <= STATE_INIT_SPI;
                            1: if (temp_wire_bits != 8'h00) state <= STATE_INIT_SPI;
                            2: if (temp_wire_bits != 8'h01) state <= STATE_INIT_SPI;
                            3: if (temp_wire_bits != 8'hAA) state <= STATE_INIT_SPI;
                        endcase
                        state_step <= (state_step == 3) ? 0 : (state_step + 1'b1);
                    end

				// *** at this point we know if the card is V1 or V2, now we need to ready the card ***
                
                // send CMD55 (Application commands such as ACMD41 below need a CMD55 prefix)
                STATE_INIT_CMD55:
                    begin
						setup_spi_cmd(8'd55, 32'h0, 8'h0, STATE_INIT_CMD55_R1);
                    end
                
                // read CMD55 R1 response (should be in idle state so we expect 01 here)
                STATE_INIT_CMD55_R1:
                    begin
                        if (temp_wire_bits != 8'h01) begin
							// no need to set error since card_is_init is still 0
                            state        <= STATE_INIT_SPI;
                        end else begin
                            // Send ACMD41 to ready the card
                            setup_spi_cmd(8'd41, 32'h40000000, 8'h0, STATE_INIT_ACMD41_R1);
                        end
                    end
                
                // process the R1 from ACMD41 we're looking for R1(00) (not in idle state)
                STATE_INIT_ACMD41_R1:
                    begin
                        if (temp_wire_bits != 8'h00) begin
                            // not ready so send CMD55+ACMD41 again
                            state <= STATE_INIT_CMD55;
                        end else begin
                            // we're ready now we can enable the fast clock
                            fst_clk <= 1'b1;
                            // now if we're SDv1 we definitely jump to setting block length
                            if (card_is_v1) begin
                                state <= STATE_INIT_CMD16;
                            end else begin
                                // otherwise we jump to CMD58 to determine if it's a v2 SDSC card (byte) or a v2 SDHC card (block)
                                state <= STATE_INIT_CMD58;
                            end
                        end
                    end

                // send CMD58 to determine if the card is a v2 SDSC or v2 SDHC card
                STATE_INIT_CMD58:
                    begin
                        // issue opcode 58 to see if we need to set the block length (SDSC vs SDHC)
						setup_spi_cmd(8'd58, 32'h0, 8'h0, STATE_INIT_CMD58_R1);
                    end

                // read R1 from CMD58
                STATE_INIT_CMD58_R1:
                    begin
                        if (temp_wire_bits != 8'h00) begin
                            state <= STATE_INIT_SPI;
                        end else begin
                            // now we need to read the 32-bit code back
                            tag   <= STATE_INIT_CMD58_READ;
                            state <= STATE_SHIFT_DATA;
                        end
                    end
                
                // read 32-bits of reply from CMD58 of which we only care abous bits 31 and 30.
                STATE_INIT_CMD58_READ:
                    begin
                        state <= STATE_SHIFT_DATA;
                        tag   <= state;
                        if (state_step == 0) begin
                            // save the top bits to compare later
                            spi_cmd58_byte0 <= temp_wire_bits;
                        end else if (state_step == 3) begin
							// bit 31 (7 of the first byte) indicates if the card is powered up full or not
                            if (spi_cmd58_byte0[7]) begin 
                                // if bit 30 (bit 6 of the first byte) is set it's block based
                                state <= spi_cmd58_byte0[6] ? STATE_INIT_DONE : STATE_INIT_CMD16;
                            end else begin
                                // read again because the v2 card isn't fully powered up yet
                                state <= STATE_INIT_CMD58;
                            end
                        end
                        state_step <= (state_step == 3) ? 0 : (state_step + 1'b1);
                    end
                
                // send CMD16 (set block length) to 512 bytes
                STATE_INIT_CMD16:
                    begin
						setup_spi_cmd(8'd16, 32'h200, 8'h00, STATE_INIT_CMD16_R1);
                    end
                
                // read R1 response from CMD16 (should get 00 back)
                STATE_INIT_CMD16_R1:
                    begin
                        if (temp_wire_bits != 8'h00) begin
                            state <= STATE_INIT_SPI;
                        end else begin
                            state <= STATE_INIT_DONE;
                        end
                    end
                
                // card is initialized by now into 512-byte sector mode
                STATE_INIT_DONE:
                    begin
                        card_is_init <= 1'b1;
                        error        <= `SPISD_ERR_OK;
                        state        <= STATE_IDLE;
                    end
                
                // send the 6 byte command packet
                STATE_SEND_CMD:
                    begin
                        // send the 6 bytes of the command
                        temp_wire_bits <= spi_cmd_block[40 - (state_step * 8) +: 8];
                        mosi_pin       <= spi_cmd_block[47 - (state_step * 8)];
                        bit_cnt        <= bit_cnt_orig;
                        sck_timer      <= sck_timer_orig;
                        state          <= STATE_SHIFT_DATA;
                        tag            <= (state_step == 5) ? STATE_READ_R1 : STATE_SEND_CMD;
                        state_step     <= (state_step == 5) ? 0 : (state_step + 1'b1);
                        sck_cycles     <= 0;
                    end

                // R1 responses have a variable number of MISO=1 bits (not necessarily a multiple of 8)
                // before clocking out 7 bits of R1 value
                // wait and then read an R1 code, jumps back to cmd_tag, puts code in temp_wire_bits
                STATE_READ_R1:
                    begin
                        case(sck_pin)
                            1'b0:
                                begin
                                    if (sck_timer == 0) begin
                                        sck_timer   <= sck_timer_orig;                     // time to switch to SCK high
                                        sck_pin     <= ~sck_pin;
                                    end else begin
                                        sck_timer   <= sck_timer - 1'b1;
                                    end
                                end
                            1'd1:                                        // SCK high phase, keep data steady, move to next bit at end of phase
                                begin
                                    if (sck_timer == 0) begin
                                        sck_cycles     <= sck_cycles + 1'b1;        // count how many SCK cycles there have been for timeout
                                        sck_timer      <= sck_timer_orig;           // reset timer in case we chain SEND_8's
                                        sck_pin        <= ~sck_pin;                 // set SCK to low for either the next bit of this transaction or the start of the next transaction
                                        if (~miso_pin) begin
                                            // went low so now we should read 7 more bits 
                                            temp_wire_bits <= 0;
                                            state          <= STATE_SHIFT_DATA;
                                            tag            <= cmd_tag;
                                            bit_cnt        <= bit_cnt_orig - 1;
                                        end else begin
                                            if (sck_cycles == timeout) begin
                                                // no response in 1 second == card not present
                                                if (spi_cmd_opcode == 8'h48) begin // CMD8 may timeout on v1 cards
                                                    temp_wire_bits <= 8'h04; // invalid opcode
                                                    state          <= cmd_tag;
                                                end else begin
                                                    state          <= STATE_INIT_SPI;
                                                    error          <= `SPISD_ERR_TIMEOUT;
                                                end
                                            end
                                        end
                                    end else begin
                                        sck_timer <= sck_timer - 1'b1;
                                    end
                                end
                        endcase
                    end
            
                /* STATE_SHIFT_DATA:
                    in: bit_cnt = bit_cnt_orig, sck_timer = sck_timer_origin, temp_wire_bits = data to shift out MOSI/SIO
                    out: bit_cnt, sck_timer: unchanged, temp_wire_bits = data shifted in MISO/SIO
                */
                STATE_SHIFT_DATA:                                        // shift 8 bits in/out temp_spi_bits    
                    begin
                        case(sck_pin)
                            1'd0:                                        // SCK low phase, put data on wire
                                begin
                                    // write during low
                                    mosi_pin <= temp_wire_bits[7];
                                    if (sck_timer == 0) begin
                                        sck_timer   <= sck_timer_orig;                     // time to switch to SCK high
                                        sck_pin     <= ~sck_pin;
                                    end else begin
                                        sck_timer   <= sck_timer - 1'b1;
                                    end
                                end
                            1'd1:                                        // SCK high phase, keep data steady, move to next bit at end of phase
                                begin
                                    if (sck_timer == 0) begin
                                        temp_wire_bits <= {temp_wire_bits[6:0], miso_pin}; // shift wire bits, and insert MISO bit
                                        mosi_pin       <= temp_wire_bits[6];
                                        bit_cnt        <= bit_cnt - 1'b1;
                                        sck_pin        <= ~sck_pin;                            // set SCK to low for either the next bit of this transaction or the start of the next transaction
                                        sck_timer      <= sck_timer_orig;                    // reset timer in case we chain SEND_8's
                                        if (bit_cnt == 0) begin
                                            bit_cnt    <= bit_cnt_orig;                        // reset bit count in case we chain SEND_8's
                                            state      <= tag;
                                        end
                                    end else begin
                                        sck_timer <= sck_timer - 1'b1;
                                    end
                                end
                        endcase
                    end

                // IDLE waiting for cmd_valid
                STATE_IDLE:
                    begin
                        if (cmd_valid) begin
                            // ensure cs_pin drops before SCK goes high
                            cs_pin              <= 1'b0;
                            sck_pin             <= 1'b0;
                            
                            // latch the command
                            cmd_pos             <= 9'd0;
                            cmd_crc16           <= 16'h0;
                            
                            // default to ok
                            error               <= `SPISD_ERR_OK;
                    
                            // branch to the next state
                            case(cmd_wr_en)
                                1'b0:  
                                    begin
                                        // send READ SECTOR(CMD17) command
                                        setup_spi_cmd(8'd17, cmd_sector, 8'h00, STATE_START_READ_RESP);
                                        // our write to host mem loop +1's the addr so we pre decrement
                                        // so it'll be aligned for the 0'th byte back from the SD card
                                        host_mem_addr <= cmd_host_address - 1'b1;
                                    end
                                1'b1:
                                    begin
                                        // send WRITE SECTOR(CMD24) command
                                        setup_spi_cmd(8'd24, cmd_sector, 8'h00, STATE_START_WRITE_RESP);
                                        host_mem_addr <= cmd_host_address;
                                    end
                            endcase
                        end else begin
                            // TODO: every 250ms send a STATUS request
                        end
                    end

                // parse R1 (expect 00), then shift out 0xFF, followed by 0xFE (the write block token)
                STATE_START_WRITE_RESP:
                    begin
                        if (temp_wire_bits != 8'h00) begin
                            error            <= `SPISD_ERR_READ;
                            state            <= STATE_DONE;
                        end else begin
                            // clock out 8 bits before sending the write token
                            temp_wire_bits   <= 8'hFF;
                            mosi_pin         <= 1'b1;
                            state            <= STATE_SHIFT_DATA;
                            tag              <= STATE_WRITE_TOKEN;
                        end
                    end
                
                // shift out the write block token FE letting the card know payload follows
                STATE_WRITE_TOKEN:
                    begin
                        temp_wire_bits     <= 8'hFE;
						mosi_pin           <= 1'b1;
                        state              <= STATE_SHIFT_DATA;
                        tag                <= STATE_WRITE_SHIFT;
                    end

                // write 512 bytes from host memory to SD SPI
                // by time we get here the host memory should have loaded the first byte
                STATE_WRITE_SHIFT:
                    begin
						cmd_crc16      <= next_crc16_byte(cmd_crc16, host_mem_data_out);
                        temp_wire_bits <= host_mem_data_out;
                        mosi_pin       <= host_mem_data_out[7];
                        host_mem_addr  <= host_mem_addr + 1'b1;
                        state          <= STATE_SHIFT_DATA;
                        tag            <= (cmd_pos == 9'd511) ? STATE_WRITE_CRC : state;
                        cmd_pos        <= (cmd_pos == 9'd511) ? 0 : (cmd_pos + 1'b1);
                    end
                
                // shift out CRC16, then we shift out another 0xFF to read the response back
                STATE_WRITE_CRC:
                    begin
						if (state_step == 2) begin
							temp_wire_bits <= 8'hFF;
							mosi_pin       <= 1'b1;
						end else begin							
							temp_wire_bits <= cmd_crc16[8 - (state_step * 8) +: 8];
							mosi_pin       <= cmd_crc16[7 - (state_step * 8)];
						end
                        tag            <= (state_step == 2) ? STATE_WRITE_BLOCK_RESP : state;
                        state          <= STATE_SHIFT_DATA;
                        state_step     <= (state_step == 2) ? 0 : (state_step + 1'b1);
                    end
                
                // Read the write response back, the bottom 5 bits have the code we care about
                STATE_WRITE_BLOCK_RESP:
                    begin
                        state <= STATE_DONE;
                        case (temp_wire_bits & 8'h1F)
                            8'h05: 
                                begin
                                    error          <= `SPISD_ERR_OK;
                                    state          <= STATE_WRITE_WAIT;
                                    temp_wire_bits <= 8'h00;                // next state is waiting for MISO to go high so preload low
                                    sck_cycles     <= 0;
                                end
                            8'h0B, 8'h0D:     error <= `SPISD_ERR_WRITE;
                            default:
                                begin
                                    error <= `SPISD_ERR_TIMEOUT;
                                    state <= STATE_INIT_SPI;
                                end
                        endcase
                    end
                
                // The card will hold MISO low until the write is complete so we just
                // use SHIFT_DATA to re-use clocking
                STATE_WRITE_WAIT:
                    begin
                        if (temp_wire_bits != 8'h00) begin
                            // write done when MISO goes high at any point
                            state      <= STATE_DONE;
                        end else begin
                            state      <= STATE_SHIFT_DATA;
                            tag        <= state;
                            // increment by 8 since we're shifting bytes here
                            sck_cycles <= sck_cycles + 8;
                            if (sck_cycles >= timeout) begin
                                error <= `SPISD_ERR_TIMEOUT;
                                state <= STATE_INIT_SPI;
                            end
                        end
                    end

                // Read the read sector R1 (should be 00)
                STATE_START_READ_RESP:
                    begin
                        if (temp_wire_bits != 8'h00) begin
                            error            <= `SPISD_ERR_READ;
                            state            <= STATE_DONE;
                        end else begin
                            // preload temp wire so we can jump into wait token with a known value
                            temp_wire_bits <= 8'hFF;
                            state          <= STATE_WAIT_TOKEN;
                            sck_cycles     <= 0;
                            cmd_tag        <= STATE_READ_SHIFT;
                        end
                    end

                // The SD card shifts out 0xFF bytes until it's ready to provide payload
                // which start with a 0xFE token followed by the payload (512 bytes) followed by 2 bytes of CRC
                // wait for a byte aligned 0xFE token
                STATE_WAIT_TOKEN:
                    begin
                        sck_cycles <= sck_cycles + 8;                    // add 8 since we're shifting 8 bits per iteration
                        if (sck_cycles >= timeout) begin
                            error <= `SPISD_ERR_TIMEOUT;
                            state <= STATE_INIT_SPI;
                        end else begin
                            state      <= STATE_SHIFT_DATA;
                            if (temp_wire_bits == 8'hFE) begin
                                // proceed to shift data out of the SD card into host memory
                                tag   <= cmd_tag;
                            end else begin
                                // keep shifting until we hit the read token
                                tag   <= state;
                            end
                        end
                    end

                // we enter this having already shifted the first byte so the loop is slightly diff
                // from the STATE_WRITE_SHIFT
                STATE_READ_SHIFT:
                    begin
                        host_mem_data_in  <= temp_wire_bits;
                        cmd_crc16		  <= next_crc16_byte(cmd_crc16, temp_wire_bits);
                        host_mem_wr_en    <= 1'b1;
                        host_mem_addr     <= host_mem_addr + 1'b1;
                        cmd_pos           <= (cmd_pos == 9'd511) ? 0 : (cmd_pos + 1'b1);
                        state             <= (cmd_pos == 9'd511) ? STATE_READ_CRC : STATE_SHIFT_DATA;
                        tag               <= state;
                    end
                
                // read the 16-bit CRC from the read sector command
                STATE_READ_CRC:
                    begin
                        host_mem_wr_en    <= 1'b0;
                        state_step        <= (state_step == 1) ? 0 : (state_step + 1'b1);
                        state             <= (state_step == 1) ? STATE_READ_CRCCHK : STATE_SHIFT_DATA;
                        tag               <= state;
                        
                        // XOR the received CRC against the computed one
                        cmd_crc16[8 - (state_step * 8) +: 8] <= cmd_crc16[8 - (state_step * 8) +: 8] ^ temp_wire_bits;
                    end
                
                // ensure CRC is valid
                STATE_READ_CRCCHK:
					begin
						state <= STATE_DONE;
						if (READ_CRC_CHK == 1 && cmd_crc16 != 16'h0) begin
							error <= `SPISD_ERR_READCRC;
						end
					end
					
                // where commands go before idle, we raise CS, clock out a byte
                STATE_DONE:
                    begin
                        cs_pin            <= 1'b1;
                        temp_wire_bits    <= 8'hFF;
                        mosi_pin          <= 1'b1;
                        host_mem_wr_en    <= 1'b0;
                        state             <= STATE_SHIFT_DATA;
                        tag               <= STATE_WAIT_VALID_LOW;
                    end
                
                // here we raise valid and wait for ready to drop before returning to idle
                STATE_WAIT_VALID_LOW:
                    begin
                        ready <= 1'b1;
                        if (!cmd_valid) begin
                            ready <= 1'b0;
                            state <= STATE_IDLE;
                        end
                    end 
            endcase
        end
    end
endmodule
