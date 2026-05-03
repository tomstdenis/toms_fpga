`ifndef SPIDMA_VH
`define SPIDMA_VH

// perform reset
`define spidma_reset     4'h0
// enter quad mode I/O
`define spidma_eqio      4'h1
// leave quad mode I/o
`define spidma_qmex		 4'h2
// cmd_read == read from SPI memory, write to host memory
`define spidma_cmd_read  4'h3
// cmd_write == write to SPI memory, read from host memory
`define spidma_cmd_write 4'h4

`endif
