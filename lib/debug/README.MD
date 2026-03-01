# Simple Serial Debugger
## Introduction
This directory has an implementation of a chainable debug node that can be embedded inside modules that allows for
reading and writing 128-bit payloads are arbitrary addressing.  The theory of operation is you'd map useful things to a 
wire that you send as "debug_outgoing_data" and then you can react to things on "debug_incoming_data" when the
toggle "debug_incoming_tgl" changes value from one clock to the next.

The outgoing data doesn't have to be a wire composite of things it could be registered as well the round trip delay means
that unless you take a really long time to compute "debug_outgoing_data" you should be fine.

## Identities
Each node also gets a 128-bit "identity" that is meant to be used by the host debugger to tell what the node is.  The identity net
likely should include information like an IP identifier (e.g. CPU, DMA, RAMDAC, whatever), instantiation numbering (e.g. CPU #3),
hardware revision information, etc.  The host tool that runs on the PC side can then present to the user "address XYZ is a CPU with revision 1.2" or 
whatever.  In reality it's just 128 bits and it's up to the design to specify how to parse that.

## Operation
The debugger uses a store-and-forward architecture where each node first receives and entire 144-bit packet (15-bit address, read/write command, 128-bit
payload), inspects it, and then transmits a response or forwards it on.  This means ideally the nodes outgoing/incoming data should be close to the
transmission process.

## Initialization
On init, the host transmits a broadcast packet with a payload of all zeroes.  Each node increments the 2nd 16-bits of the payload
and uses that to self-assign their address. In this way as you add/remove nodes from your design as long as they're all chained properly
each node is addressable.  After enumeration each node will only respond to its own address and it forwards anything not destined for it on.

The host will receive a broadcast with a payload indicating how many nodes are in the chain.  This is handy to speed up scanning the chain but
it's not needed all the time (e.g. if you connect after it inits) since unmatched packets simply flow through to the outside so you can tell
if a node doesn't exist or not based on whether it responds to say an identity call.

## Using
Each packet is 144 bits long made up by a direction bit [0], address [15:1], and payload [143:16].  A direction bit of 0 means read, a direction
of 1 means write.  The address 7FFF is a broadcast meaning this supports upto 32,766 nodes.

When a read matches the address of a node, the value of "debug_outgoing_data" is placed in the payload field and forwarded on.  The payload field
is used by the node to indicate commands in the first byte of the payload [23:16].  A value of 0 means "read identity" anything else just copies
the outgoing data.  

When writing hits a matching node the value is copied to "debug_incoming_data" and the "debug_incoming_tgl" value is inverted.

If you want to interact with a node you should first write a command in a format of your choosing in the payload and then issue a read to the same node
(with the command byte [23:16] being non-zero).

## Fetch Identity
The identity field is read by sending a read request with the command byte [23:16] set to zero.  The 128-bit payload that is fetched is design
defined and used to identify what the node actually is from the outside.

## Clock Considerations
Each node must set the prescaler so that it's clock / prescaler >= 4 meaning each bit transmitted takes at least 4 cycles.  The idea being is
you want to configure this so that for the /slowest/ clock in your design there are 4 cycles per bit.  This is to allow this to be cross domain compatible.
The prescaler controls how many cycles per half-cycle, so a value of 2 means a 4 clock cycle data bit cycle.

The rx clock/data are synchronized with a 4-level flip flop which should help with placement to keep the length of the wires short even if the varios debug nodes
are physically far apart.   

## Data Throughput
At a minimum a packet takes 144 * 4 = 576 cycles to transmit.  So if you have N nodes it will take 576 * N cycles to transit the entire chain.  As a result
this is really not meant to be a high speed bus.  It's meant to be small and lightweight and easy to embed deep inside designs.

```
module serial_debug(
	input clk,
	input rst_n,
	
	// baud rate
	input [7:0] prescaler,						// prescaler against clk to control tx_clk (ideally >= 2) (meant to be a constant wire not subject to reset)
	
	// serial input
	input rx_data,								// incoming serial data
	input rx_clk,								// incoming serial clock
	
	// serial output
	output reg tx_data,							// outgoing serial data
	output reg tx_clk,							// outgoing serial clock
	
	// controller input
	input [127:0] debug_outgoing_data,			// default data we want to provide when given a READ (cmd != IDENT)
	
	// control output
	output reg debug_incoming_tgl,				// toggle indicating whether debug_incoming_data changed
	output reg [127:0] debug_incoming_data,		// data the host is writing to us
	
	// identity
	input [127:0] identity						// 128-bit identity provided with a read and CMD == IDENT used to tell the host what module this address is
);
```

# UART Bridge

To make this easy to integrate into designs there is also a serial_debug_uart module which makes uses of the FIFO based UART
from lib/uart/blocks/.  This is used by instantiating your node(s) as required and then you hook up debug_rx_* to **input of the FIRST
node** in the chain, and attach debug_tx_* to the ((output of the LAST node in the chain**.  The bridge reads 18 bytes at a time from the UART RX
pin, sends it over the simple serial bus, reads the 18 byte output and sends it to the UART TX pin.  

```
[Host/UART Bridge] -> [Node 0] -> [Node 1] -> [Node 2] -> [Host/UART Bridge]
      (TX) ----------> (RX)
                       (TX) ------> (RX)
                                    (TX) ------> (RX)
                                                 (TX) ------> (RX)
```

The "prescaler" is like above and relative to the clock domain the UART bridge lives in.  The "uart_bauddiv" is your clock rate divided by
the baud rate (e.g. 50_000_000 / 115200 for 115.2K when using a 50MHz system clock).


```
module serial_debug_uart (
	input clk,
	input rst_n,
	
	// baud rate
	input [7:0] prescaler,						// prescaler against clk to control tx_clk (ideally >= 2) (meant to be a constant wire not subject to reset)
	
	// serial input
	input debug_tx_data,						// incoming debug serial data (from the last debug node)
	input debug_tx_clk,							// incoming debug serial clock
	
	// serial output
	output reg debug_rx_data,					// outgoing debug serial data
	output reg debug_rx_clk,					// outgoing debug serial clock
	
	// uart
	input [15:0] uart_bauddiv,
	input uart_rx_pin,
	output uart_tx_pin
);
```
