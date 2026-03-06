# ECP5 Demos for the Colorlight-i9 Icesugar Pro

This directory contains some demos that run on the Colorlight-i9 IceSugar Pro board.
This board has an ECP5 45F.

Demos here are:

	-	**uart_echo**: Simple echo demo using serial over the USB-C connector
	-	**debug**: The 4 node debug chain demo using all four PLLs.
		- Note: If you flash this demo you will need to hit the reset button after each power up since the initial serial chatter seems to offset the serial buffer for the debugger.
		

