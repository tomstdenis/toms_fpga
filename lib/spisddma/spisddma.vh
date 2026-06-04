`ifndef SPISDDMA_VH
`define SPISDDMA_VH

`define SPISD_ERR_OK      0     // CMD ok
`define SPISD_ERR_TIMEOUT 1     // CMD timed out (card is being reset)
`define SPISD_ERR_WRITE   2     // WRITE was not accpted
`define SPISD_ERR_READ    3     // READ was not accepted
`define SPISD_ERR_READCRC 4     // READ data failed CRC check
`define SPISD_ERR_WRITE_CMD 5   // the WRITE SECTOR cmd was rejected
`endif
