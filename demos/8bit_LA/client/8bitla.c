#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <termios.h>
#include <errno.h>
#include <inttypes.h>

// FPGA clock in Hz
// normal system clock
//#define FPGA_CLOCK 27000000ULL

// 5x PLL
#define FPGA_CLOCK 135000000ULL

#define NS_PER_SAMPLE (((uint64_t)((uint64_t)prescale + 1ULL) * 1000000000ULL) / (double)FPGA_CLOCK)

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

uint8_t prescale, trigger_mask, trigger_pol, post_trigger;
char names[8][256];
uint16_t WPTR;
uint8_t outbuf[65538];


static void read_config(char *fname)
{
	FILE *f;
	int x;
	
	f = fopen(fname, "r");
	if (f) {
		if (fscanf(f, "%"SCNx8"\n", &prescale) != 1) {
			fprintf(stderr, "ERROR: Expecting prescale hex value\n");
			exit(-1);
		}
		if (fscanf(f, "%"SCNx8"\n", &trigger_mask) != 1) {
			fprintf(stderr, "ERROR: Expecting trigger mask hex value\n");
			exit(-1);
		}
		if (trigger_mask == 0) {
			fprintf(stderr, "ERROR: trigger mask cannot be zero (it would never trigger)\n");
			exit(-1);
		}
		if (fscanf(f, "%"SCNx8"\n", &trigger_pol) != 1) {
			fprintf(stderr, "ERROR: Expecting trigger polarity hex value\n");
			exit(-1);
		}
		if (fscanf(f, "%"SCNx8"\n", &post_trigger) != 1) {
			fprintf(stderr, "ERROR: Expecting post trigger count hex value\n");
			exit(-1);
		}
		if (post_trigger == 0) {
			fprintf(stderr, "WARNING: Post trigger cannot be zero, setting to 1...\n");
			post_trigger = 1;
		}
		
		for (x = 0; x < 8; x++) {
			if (fgets(names[x], sizeof(names[0]) - 1, f) == NULL) {
				fprintf(stderr, "ERROR: was expecting the %d'th pin name\n", x);
				exit(-1);
			}
			if (names[x][strlen(names[x])-1] == '\n') {
				names[x][strlen(names[x])-1] = 0;
			}
		}
	} else {
		fprintf(stderr, "ERROR: Could not open file '%s'\n", fname);
		exit(-1);
	}
	fclose(f);
}

static void program_and_read(int fd)
{
	uint8_t cmd[4];
	int x;
	
	cmd[0] = trigger_mask;
	cmd[1] = trigger_pol;
	cmd[2] = prescale;
	cmd[3] = post_trigger;
	
	if (write(fd, cmd, 4) != 4) {
		fprintf(stderr, "ERROR: Could not write command to logic analyzer...\n");
		exit(-1);
	}
	tcdrain(fd);
	
	x = 0;
	for (x = 0; x < 65538; ) {
		if (read(fd, &cmd[0], 1) == 1) {
			outbuf[x++] = cmd[0];
		}
	}
	
	// load write pointer
	WPTR = ((uint16_t)outbuf[0]) | ((uint16_t)outbuf[1] << 8);
	memmove(outbuf, outbuf + 2, 65536);							// shift array down so 0..65535 is the buffer
}

#include <time.h>

#include <time.h>
#include <inttypes.h>

void emit_vcd(const char *filename, uint8_t *buffer, uint16_t wptr, uint8_t post_trigger_val, uint16_t prescale_val)
{
    FILE *f = fopen(filename, "w");
    if (!f) return;

    // 1. Header and Timescale
    time_t now = time(NULL);
    fprintf(f, "$date %s $end\n", ctime(&now));
    fprintf(f, "$version 8-bit Logic Analyzer v1.0 $end\n");
    
    double ns_per_sample = (uint64_t)(prescale_val + 1) * 1000000000.0 / FPGA_CLOCK;
    fprintf(f, "$timescale 1ns $end\n");

    // 2. Variable Definitions
    fprintf(f, "$scope module top $end\n");
    fprintf(f, "$var wire 8 ! bus [7:0] $end\n"); 
    for (int i = 0; i < 8; i++) {
        fprintf(f, "$var wire 1 %c %s $end\n", 'A' + i, names[i]); 
    }
    fprintf(f, "$upscope $end\n");
    fprintf(f, "$enddefinitions $end\n");

    // 3. Logic to center the trigger
    // Total buffer is 65536 samples.
    // In FPGA, timer_post_cnt = post_trigger_val * 256.
    uint32_t total_samples = 65536;
    uint32_t post_trigger_samples = (uint32_t)post_trigger_val * 256;
    
    // 4. Initial Values
    fprintf(f, "#0\n$dumpvars\nbxxxxxxxx !\n");
    for (int i = 0; i < 8; i++) fprintf(f, "x%c\n", 'A' + i);

    // 5. Data Dump
    uint8_t prev_val = 0; 
    double current_time = 0;

	// we want to map 0..65535 such that 65535 == wptr + post_trigger_samples
    uint16_t idx = (wptr + post_trigger_samples) & 0xFFFF;

    for (uint32_t i = 0; i < total_samples; i++) {
        uint8_t val = buffer[(idx++) & 0xFFFF];

        // Force output on first sample, last sample, or any data change
        if (i == 0 || i == (total_samples - 1) || val != prev_val) {
            fprintf(f, "#%llu\n", (unsigned long long)current_time);
            
            // Output 8-bit Bus
            fprintf(f, "b");
            for (int b = 7; b >= 0; b--) fprintf(f, "%d", (val >> b) & 1);
            fprintf(f, " !\n");

            // Output Individual Pins
            for (int b = 0; b < 8; b++) {
                if (i == 0 || i == (total_samples - 1) || ((val ^ prev_val) >> b) & 1) {
                    fprintf(f, "%d%c\n", (val >> b) & 1, 'A' + b);
                }
            }
            prev_val = val;
        }

        // Optional: Add a text marker in the VCD at the trigger point
        if (i == (total_samples - post_trigger_samples - 1)) {
            fprintf(f, "$comment TRIGGER_EVENT $end\n");
        }

        current_time += ns_per_sample;
    }

    fclose(f);
    printf("VCD emitted. Trigger is %u samples before the end of the file.\n", post_trigger_samples);
}

	
int main(int argc, char **argv)
{
	char outname[256];
	FILE *f;
	int x;
	
    int fd = open(argv[1], O_RDWR | O_NOCTTY);
    if (fd < 0) { perror("Open port"); return 1; }
    set_interface_attribs(fd, B115200);
    usleep(1000000);
	tcflush(fd, TCIOFLUSH);
	
	read_config(argv[2]);
	printf("Using a prescale of %u (%g ns per sample), mask=%02x, pol=%02x, post=%lu samples\n", prescale + 1, NS_PER_SAMPLE, trigger_mask, trigger_pol, (unsigned long)post_trigger * 256);
	program_and_read(fd);
	
	sprintf(outname, "%s.raw", argv[2]);
	f = fopen(outname, "w");
	fprintf(f, "WPTR == %x\n", WPTR);
	for (x = 0; x < 65536; x++) {
		fprintf(f, "%02x\n", outbuf[x]);
	}
	sprintf(outname, "%s.vcd", argv[2]);
	emit_vcd(outname, outbuf, WPTR, post_trigger, prescale);
	fclose(f);
}
