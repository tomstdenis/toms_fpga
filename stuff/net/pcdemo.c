#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <unistd.h>
#include <termios.h>
#include <inttypes.h>
#include <sys/time.h>

// include network code
//#define NET_DEBUG
#include "network.src"

// pcdemo net code
int fd;

static int set_interface_attribs(int speed)
{
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

int net_read_byte(void)                // read byte (-1 on error)
{
    unsigned char b;
    if (read(fd, &b, 1) == 1) {
        return b;
    } else {
        return -1;
    }
}

int net_write_byte(const int x)        // write a byte (-1 on error)
{
    unsigned char b = x;
    if (write(fd, &b, 1) == 1){ 
        return 0;
    } else {
        return -1;
    }
}

uint64_t millis_cnt = 0;
unsigned long net_millis(void)         // millisecond counter
{
    struct timeval tv;
    uint64_t ms;

    gettimeofday(&tv, NULL);
    ms = (tv.tv_sec * 1000ULL) + (tv.tv_usec / 1000UL);
    if (millis_cnt == 0) {
        millis_cnt = ms;
        return 0;
    }
    return ms - millis_cnt;
}

void print_frame(char *msg, struct net_frame *f)
{
    uint8_t x;
    printf("%sframe: sync=%02x src_addr=%02x dst_addr=%02x cmd=%02x payload=[",
        msg, f->sync, f->src_addr, f->dst_addr, f->cmd);
    for (x = 0; x < 8; x++) {
        printf("%02x", f->payload[x]);
        if (x < 7) {
            printf(" ");
        }
    }
    printf("] crc8=%02x\n", f->crc8);
}

void random_payload(struct net_frame *f)
{
    uint8_t x;
    for (x = 0; x < 8; x++) {
        f->payload[x] = rand() & 255;
    }
}

// we're running as the host side of things
void run_host(void)
{
    struct net_frame f;

    fd = open("/dev/ttyUSB0", O_RDWR);
    if (fd < 0) {
        printf("Could not open ttyUSB0\n");
        return;
    }
    set_interface_attribs(B9600);

    printf("Host ready.\n");

    // run test/demo
        // #1. send a ping to device 0x01
        memset(&f, 0, sizeof f);
        random_payload(&f);
        f.cmd = NET_CMD_PING;
        printf("HOST: net_send_frame(PING) == %d\n", net_send_frame(&f, 0x01));
        print_frame("HOST: Sending ping: ", &f);

        // #2. send a ping but the other side should wait and we expect a failure
        random_payload(&f);
        f.cmd = NET_CMD_PING;
        printf("HOST: net_send_frame(PING) (expect timeout) == %d\n", net_send_frame(&f, 0x01));
        print_frame("HOST: Sending ping: ", &f);

        // we should get an ACK (the command timed out above)
        while (net_recv_frame(&f) < 0);
        print_frame("HOST: Received ack: ", &f);

        // #3. Send a broadcast
        random_payload(&f);
        f.cmd = 0x12; // random app command 
        printf("HOST: net_send_frame(bcast) == %d\n", net_send_frame(&f, NET_ADDR_BROADCAST));
        print_frame("HOST: Sending bcast: ", &f);

        // force sleep here since there's no reply to a bcast
        sleep(1);

        // #4. Send a turbo command
        random_payload(&f);
        f.cmd = 0x87; // turbo command
        printf("HOST: net_send_frame(turbo) == %d\n", net_send_frame(&f, 0x01));
        print_frame("HOST: Sending turbo: ", &f);

        while (net_recv_frame(&f) < 0);
        print_frame("HOST: Received turbo command reply: ", &f);
}

// we're running as device side of things
void run_device(void)
{
    struct net_frame f;
    net_addr = 0x01; // we're a device
    fd = open("/dev/ttyUSB1", O_RDWR);
    if (fd < 0) {
        printf("Could not open ttyUSB1\n");
        return;
    }
    set_interface_attribs(B9600);

    printf("Device ready.\n");

    // run test/demo
        // #1. we should get a ping first
        if (net_recv_frame(&f) == 0) {
            print_frame("DEV: Got ping packet: ", &f);
        } else {
            print_frame("DEV: did not receive ping: ", &f);
            return;
        }

        // #2. next we wait before receiving the next frame to trigger a timeout
        sleep(4);
        if (net_recv_frame(&f) == 0) {
            print_frame("DEV: Got ping packet: ", &f);
        } else {
            print_frame("DEV: did not receive ping: ", &f);
            return;
        }

        // #3. Receive broadcast
        if (net_recv_frame(&f) == 0) {
            print_frame("DEV: Got bcast packet: ", &f);
        } else {
            print_frame("DEV: did not receive bcast: ", &f);
            return;
        }

        // #4. Should be turbo code
        if (net_recv_frame(&f) == 0 && f.cmd == 0x87) {
            print_frame("DEV: Got turbo command packet: ", &f);
            // reply, in this case we just echo back
            net_send_frame(&f, f.src_addr);
        } else {
            print_frame("DEV: did not receive turbo: ", &f);
            return;
        }
}

int main(void)
{
    if (fork()) {
        run_host();
        sleep(1);
    } else {
        run_device();
        sleep(1);
    }
    return 0;
}