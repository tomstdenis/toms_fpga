VT100 Project
-------------

So here's the deal, I'll level with you.  This wasn't meant to be a project but like you know how you get going
on one thing and like ooh shiny and next thing you know you wrote a vt100 emulator in verilog for a nano1k FPGA?  
Yeah it's that sort of thing.

Anyways, as I was saying what I actually was doing is testing if my Nano1K Carrier board works.  See I picked a group of 
pins to make three dual PMODs out of but I had no idea if they would interfere with anything on the breakout board.  But
just like me, I fumbled the rev1 PCB layout and I had to use jumper wires to even hook it up.  To test the gpio I setup a VGA
demo.  This demo was a port of a demo I made for the primer25k which renders some font text and that's it.  So to test the
third PMOD port I hooked up my ESP32-C3 PMOD to try doing some serial and before you know it I was doing some basic
character positioning logic, then ooh colour is easy to add to the vga driver, and then my top.v had a near complete vt100
emulator in it.

Thinking that was a fools mess I done set out to refactor the vt100 code out.  I ended up putting the RGB gen and the UART
under the vt100 module because it works more naturally like that.  You need to bring a few things.  The nano1k demos top
for this is probably a good place to look.  Basically you need a VGA timer, VGA char generator, dual ported 16-bit memory,
and a 8-bit ROM for the font.

The 16-bit memory should be bypass mode for now I haven't really worked out getting pipelined working.  The top needs
to provide for a text_out net too that tells the VT100 when a font pixel is true or not.  Anyways just look at the nano1k
demo it's not that hard to hook up.

Cheerio,
Tom
