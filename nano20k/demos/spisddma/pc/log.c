#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <termios.h>
#include <errno.h>
#include <inttypes.h>
#include <time.h>
#include <sys/time.h>

char *spi_states[32] = {
	"INIT_SPI",
	"INIT_CMD0",
	"INIT_CMD0_R1",
	"INIT_CMD8_R1",
	"INIT_CMD8_READ",
	"INIT_CMD55",
	"INIT_CMD55_R1",
	"INIT_ACMD41_R1",
	"INIT_CMD58",
	"INIT_CMD58_R1",
	"INIT_CMD58_READ",
	"INIT_CMD16",
	"INIT_CMD16_R16",
	"INIT_DONE",
	
	"SEND_CMD",
	"READ_R1",
	"SHIFT_DATA",
	"IDLE",
	"DONE",
	"WAIT_VALID_LOW",
	
	"START_WRITE_RESP",
	"WRITE_SHIFT",
	"WRITE_CRC",
	"WRITE_BLOCK_RESP",
	"WRITE_WAIT",
	
	"START_READ_RESP",
	"WAIT_TOKEN",
	"READ_SHIFT",
	"READ_CRC",
	"READ_CRCCHK",
	"CMD13_R1",
	"UNK31"
};

char *tst_states[16] = {
	"INIT_WAIT",
	"DELAY",
	"DELAY2",
	"READY",
	"ISSUE_READ",
	"TEST_READ_TOP",
	"TEST_READ_CHK",
	"ISSUE_WRITE",
	"WRITE_DONE",
	"DONE",
	"UNK10",
	"UNK11",
	"UNK12",
	"UNK13",
	"UNK14",
	"UNK15",
};

static int set_interface_attribs(int fd, int speed) {
    struct termios tty;
    if (tcgetattr(fd, &tty) != 0) return -1;

    // cfmakeraw sets the terminal to a state where bytes are
    // passed exactly as received: no echo, no translations, no signals.
    cfmakeraw(&tty);

    // Set baud rate
    cfsetospeed(&tty, speed);
    cfsetispeed(&tty, speed);

    // 8-bit chars, enable receiver, ignore modem control lines
    tty.c_cflag &= ~CSIZE & ~HUPCL;
    tty.c_cflag |= CS8 | CREAD | CLOCAL;

    // Setup timing: non-blocking read with 0.5s timeout
    tty.c_cc[VMIN]  = 0;
    tty.c_cc[VTIME] = 10;

    if (tcsetattr(fd, TCSANOW, &tty) != 0) return -1;
    return 0;
}

/* data is 
 * 

     wire [(done_msg_bytes*8)-1:0] done_msg = {
                8'hFF,
                8'h00,
                1'b0, test_sector[6:0],
                5'b0, test_done, test_read_pass, test_write_pass,
                
                4'b0, test_state,
                4'b0, test_tag,
                6'b0, test_x[8:7],
                1'b0, test_x[6:0],
                spi_debug                                   // 8-bytes, 64-bits

    assign debug = {
                    3'b0, state,
                    3'b0, tag,
                    3'b0, cmd_tag,
                    2'b0, bit_cnt, temp_wire_bits[7], spi_cmd_opcode[7],

                    1'b0, temp_wire_bits[6:0],
                    1'b0, spi_cmd_opcode[6:0],
                    2'b0, state_step, card_is_init, card_is_v1,
                    1'b0, cmd_wr_en, cmd_valid, ready, fst_clk, error
                   };

*/

int main(int argc, char **argv)
{	
	struct {
		unsigned test_sector, 
		test_done, 
		test_read_pass, 
		test_write_pass, 
		test_state, 
		test_tag, 
		test_x, 
		state, 
		tag, 
		cmd_tag, 
		bit_cnt,
		r2_status,
		spi_cmd_opcode,
		state_step,
		card_is_init,
		card_is_v1,
		card_is_sdhc,
		cmd_wr_en,
		cmd_valid,
		ready,
		fst_clk,
		error;
	} log;
	unsigned char logdata[18], prevlogdata[18];
	unsigned char ch, prev_ch, x;
	uint32_t prev_sectors = 0;
	struct timeval start, now;
	
    int fd = open(argv[1], O_RDWR | O_NOCTTY);
    if (fd < 0) { perror("Open port"); return 1; }
    set_interface_attribs(fd, B1000000);
	tcflush(fd, TCIOFLUSH);
	
	memset(&log, 0, sizeof log);
	memset(prevlogdata, 0xFF, sizeof prevlogdata);
	prev_ch = 0x80;
	
	gettimeofday(&start, NULL);
	// loop forever
	for (;;) {
		// try to sync to 00 FF
		prev_ch = ch;
		if (read(fd, &ch, 1) == 1) {
			if (prev_ch == 0 && ch == 0xFF) {
				// we're in a frame
				for (x = 0; x < 18; ) {
					if (read(fd, &logdata[x], 1) == 1) {
						++x;
					}
				}
				// is it different?
				if (memcmp(logdata, prevlogdata, sizeof logdata)) {
					memcpy(prevlogdata, logdata, sizeof logdata);
					memset(&log, 0, sizeof log);
					// now we scan from the bottom of the wire up
					// byte 0
					log.error      = logdata[0] & 0x07;
					log.fst_clk    = (logdata[0] & 0x08) ? 1 : 0;
					log.ready      = (logdata[0] & 0x10) ? 1 : 0;
					log.cmd_valid  = (logdata[0] & 0x20) ? 1 : 0;
					log.cmd_wr_en  = (logdata[0] & 0x40) ? 1 : 0;
					// byte 1
					log.card_is_v1   = logdata[1] & 0x01;
					log.card_is_init = (logdata[1] & 0x02) ? 1 : 0;
					log.state_step   = (logdata[1] >> 2) & 0x0F;
					log.card_is_sdhc = (logdata[1] >> 6) & 1;
					// byte 2
					log.spi_cmd_opcode  = logdata[2] & 0x7F;
					// byte 3
					log.r2_status       = logdata[3] & 0x7F;
					// byte 4
					log.spi_cmd_opcode |= (logdata[4] & 0x01) ? 0x80 : 0x00;
					log.r2_status      |= (logdata[4] & 0x02) ? 0x80 : 0x00;
					log.bit_cnt         = (logdata[4] >> 2) & 0x0F;
					// byte 5
					log.cmd_tag = logdata[5] & 0x1F;
					// byte 6
					log.tag     = logdata[6] & 0x1F;
					// byte 7
					log.state   = logdata[7] & 0x1F;
					// byte 8
					log.test_x  = logdata[8] & 0x7F;
					// byte 9
					log.test_x |= (unsigned)(logdata[9] & 0x03) << 7;
					// byte 10
					log.test_tag = logdata[10] & 0x0F;
					// byte 11
					log.test_state = logdata[11] & 0x0F;
					// byte 12
					log.test_write_pass = logdata[12] & 0x01;
					log.test_read_pass  = (logdata[12] & 0x02) ? 1 : 0;
					log.test_done       = (logdata[12] & 0x04) ? 1 : 0;
					// byte 13-16 are 7 bit increments of test_sector
					log.test_sector     = logdata[13] & 0x7F;
					log.test_sector    |= ((unsigned)logdata[14] & 0x7F) << 7;
					log.test_sector    |= ((unsigned)logdata[15] & 0x7F) << 14;
					log.test_sector    |= ((unsigned)logdata[16] & 0x7F) << 21;
					if (log.error) {
						printf(">>> SD{state=%s, tag=%s, cmd_tag=%s}, TEST{state=%s, tag=%s}\n", spi_states[log.state], spi_states[log.tag], spi_states[log.cmd_tag], tst_states[log.test_state], tst_states[log.test_tag]);
						printf("Test: sector: %u, done: %d, read_pass: %d, write_pass: %d, state: %d, tag: %d, x: %d\n",
							log.test_sector, log.test_done, log.test_read_pass, log.test_write_pass, log.test_state, log.test_tag, log.test_x);
						printf("spisd: state: %d, tag: %d, cmd_tag: %d, bit_cnt: %d, r2_status: %02x, spi_cmd_opcode: %02x, state_step: %d\n",
							log.state, log.tag, log.cmd_tag, log.bit_cnt, log.r2_status, log.spi_cmd_opcode, log.state_step);
						printf("card: is_init: %d, is_v1: %d, is_sdhc: %d\n",
							log.card_is_init, log.card_is_v1, log.card_is_sdhc);
						printf("cmd: wr_en: %d, valid: %d, ready: %d, fst_clk: %d, error: %d\n",
							log.cmd_wr_en, log.cmd_valid, log.ready, log.fst_clk, log.error);
						printf("<<<\n");
					}

					// loop to next sector...(if passed and IDLE)
					gettimeofday(&now, NULL);
					fflush(stdout);
					if (now.tv_sec != start.tv_sec) {
						uint64_t delta;
						uint32_t n;
						delta = ((uint64_t)now.tv_sec * 1000000 + now.tv_usec) -
								((uint64_t)start.tv_sec * 1000000 + start.tv_usec);
						n = log.test_sector - prev_sectors;
						prev_sectors = log.test_sector;
						printf("Rate: %5llu usec per 512 bytes (current sector %9llu)\r", delta / n, prev_sectors);
						start = now;
						fflush(stdout);
					}
				}
			}
		}
	}
}
