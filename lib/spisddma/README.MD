# SD SPI DMA Library

This directory contains a module **spisddma.v** that implements a controller for SDSC, SDHC, and SDXC cards.

Uses a simple synchronous interface:

```
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
```

Init
----

Upon POR the module enters STATE_INIT_SPI and it tries the 74+ SCK toggles with CS/MOSI high.  From there it will send a CMD0 followed by a bunch of other commands to get into a ready state.  It fetches the CID and CSD data before raising **card_is_init** to tell the parent module the card is ready for read/write commands.

At init the card will be in 512-byte sector mode using the FAST_CLK "fast clock" for future commands.  You can use the card_* nets to determine things about the card, e.g.

   - **card_is_init**: The card is ready (1) or not (0)
   - **card_is_v1**: The card is a V1 SDSC card (1) or V2 (0)
   - **card_is_sdhc**: The card is a high capacity SDHC card (1) or standard capacity (0)
   - **card_sectors**: A 32-bit integer representing the number of 512 byte sectors
   - **card_cid**, **card_csd**: The 128-bit CID and 128-bit CSD vectors (see the SD spec...)
   
Error Detection
---------------

The net **error** is non-zero (see spisddma.vh) if the FSM encountered an error.  Then the following nets maybe useful:

   - **error_read**: The 4 (5?)-bit error response returned from a read command.
   - **r2_status**: The 8-bit returned value from the SEND_STATUS command.
   
If no error is encounted you will find **error == 0** and **ready == 1** when a command is complete.

Any command that times out (1 second between response) triggers a FSM reset back to STATE_INIT_SPI which is gated by having to drive **cmd_valid** low.  This allows the parent module to read out any error codes before the FSM resets them.  To resume operation you must lower **cmd_valid** and then wait for **card_is_init** to go high again.


Theory of Operation
-------------------

To write to an SD card you're "reading from host memory" so you program the following nets:

   - **cmd_valid**: Set to 1
   - **cmd_wr_en**: Set to 1
   - **cmd_sector**: The 512-byte sector to write to
   - **cmd_host_address**: The address in host memory where byte 0 of the write payload sits.
   
You then wait for **error == 0** and **ready == 1** and then drop **valid** to 0 to complete the handshake.

To read from an SD card you do something similar except **cmd_wr_en** is set to 0.

Hooking up
----------

The rest of the module isn't super complicated.  You have to hook up the host memory ports:

   - **host_mem_addr**: The host memory address the module wants to access it is HOST_MEM_ADDR bits wide (defaults to 11)
   - **host_mem_wr_en**: The write enable to the host memory
   - **host_mem_data_in**: The data the module wants to write to the host memory
   - **host_mem_data_out**: The data the host memory provides to the module at address **host_mem_addr**.
    
The memory is assumed to have typical synchronous memory timing but because it's high latency (8 SCK cycles) you can use 
registered memories here.

The I/O is accomplished with the following pins:

   - **miso_pin**: The MISO pin from the SD card (DAT0)
   - **mosi_pin**: The MOSI pin from the SD card (CMD)
   - **cs_pin**: The CS pin from the SD card (CD/DAT3)
   - **sck_pin**: The SCK pin from the SD card (CLK);

Timing
------

Standard SD cards over SPI and 3.3V can top out at 25MHz which you can achieve by using a 50MHz core clock and a FAST_CLK of 25_000_000.  You can lower
the clock as needed but cannot raise it without doing further commands and voltage changes.

Each time **cmd_valid** goes high there's an unpredictable (but constrained) amount of cycles that pass for that operation so do not use assume because
fixed timing works on one card it will work on another.  Follow the bus protocol (wait for error/ready, etc).


