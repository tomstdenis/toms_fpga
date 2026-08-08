Tom's Perfectly Cromulent Boards
--------------------------------

Me boards, y'arr matey:

   - **console_hat**:  A 4x dual PMOD hat for the Sipeed Tang Console 60K/138K FPGAs.  Provides four dual PMODs and one AUX (4 GPIO) port.
   - **nano1k_carrier**: A 3x dual PMOD carrier board that seats a Sipeed Tang Nano1K FPGA.  Two of the PMODs should be fine for high speed inout, the third shares some onboard RGB LED pins so care should be taken.
   - **pmod_esp32c3**: A ESP32-C3 Super Mini to PMOD board that breaks out I2C/SPI/UART to the PMOD header, and then four more ESP32 GPIOs to a single PMOD on the back end.
   - **pmod_psram**: A 8-SOIC PSRAM/SRAM/NOR memory to dual PMOD (8-pin) header.  Tested with ESP PSRAMH and ISSI PSRAM mostly but I have in the past tried a SRAM too.
   - **primer_hat**: Like the **console_hat** but for the Sipeed Tang Primer25K FPGA.  Breaks out four dual-PMODs and one AUX (4 GPIO) port.
   
In each directory you'll find

   - Gerber files exported from Easy EDA (hey don't judge me!!!)
   - Images (**top.png**, **bottom.png**, **inner1.png**, and **inner2.png**)
   - **BOM.TXT** brief BOM list 
   - Sometimes a Schematic PDF but honestly if you don't get where parts go that's on you they're not that complicated.
