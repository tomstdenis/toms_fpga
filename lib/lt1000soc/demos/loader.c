#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <fcntl.h>
#include <unistd.h>
#include <termios.h>
#include <string.h>

static int setup_serial(const char *portname, speed_t baud) {
    int fd = open(portname, O_RDWR | O_NOCTTY | O_SYNC);
    if (fd < 0) {
        perror("Error opening serial port");
        return -1;
    }

    struct termios tty;
    if (tcgetattr(fd, &tty) != 0) {
        perror("Error getting termios attributes");
        close(fd);
        return -1;
    }

    cfsetospeed(&tty, baud);
    cfsetispeed(&tty, baud);

    // 8N1 mode, raw I/O, no flow control
    tty.c_cflag = (tty.c_cflag & ~CSIZE) | CS8;
    tty.c_iflag &= ~(IGNBRK | BRKINT | PARMRK | ISTRIP | INLCR | IGNCR | ICRNL | IXON | IXOFF | IXANY);
    tty.c_oflag &= ~OPOST;
    tty.c_lflag &= ~(ECHO | ECHONL | ICANON | ISIG | IEXTEN);
    tty.c_cflag |= (CLOCAL | CREAD);
    tty.c_cflag &= ~(PARENB | PARODD | CSTOPB | CRTSCTS);

    // Set timeout: read blocks until at least 1 byte arrives, or 0.5s timeout
    tty.c_cc[VMIN]  = 1;
    tty.c_cc[VTIME] = 5;

    if (tcsetattr(fd, TCSANOW, &tty) != 0) {
        perror("Error setting termios attributes");
        close(fd);
        return -1;
    }

    return fd;
}

// Helper to transmit 1 byte and verify its echo
static int send_and_verify_byte(int tty_fd, uint8_t byte_to_send, size_t byte_index, const char *stage) {
    if (write(tty_fd, &byte_to_send, 1) != 1) {
        perror("\nError writing to serial port");
        return -1;
    }

    uint8_t rx_byte = 0;
    ssize_t n = read(tty_fd, &rx_byte, 1);
    
    if (n < 0) {
        perror("\nError reading echo from serial port");
        return -1;
    } else if (n == 0) {
        fprintf(stderr, "\nTimeout waiting for echo at %s index %zu (sent 0x%02X)\n", stage, byte_index, byte_to_send);
        return -1;
    }

    if (rx_byte != byte_to_send) {
        fprintf(stderr, "\nMismatch at %s index %zu! Sent: 0x%02X, Echoed: 0x%02X\n", 
                stage, byte_index, byte_to_send, rx_byte);
        return -1;
    }

    return 0;
}

int main(int argc, char *argv[]) {
    if (argc < 3) {
        printf("Usage: %s <tty_device> <binary_file>\n", argv[0]);
        printf("Example: %s /dev/ttyUSB0 app.bin\n", argv[0]);
        return 1;
    }

    const char *port = argv[1];
    const char *filepath = argv[2];

    FILE *f = fopen(filepath, "rb");
    if (!f) {
        perror("Failed to open binary file");
        return 1;
    }

    fseek(f, 0, SEEK_END);
    uint32_t filesize = ftell(f);
    fseek(f, 0, SEEK_SET);

    uint8_t *buffer = malloc(filesize);
    if (!buffer) {
        perror("Failed to allocate memory");
        fclose(f);
        return 1;
    }

    if (fread(buffer, 1, filesize, f) != filesize) {
        perror("Failed to read file");
        free(buffer);
        fclose(f);
        return 1;
    }
    fclose(f);

    int tty_fd = setup_serial(port, B1000000);
    if (tty_fd < 0) {
        free(buffer);
        return 1;
    }

    // Flush any stale bytes sitting in host serial buffers before sending
    tcflush(tty_fd, TCIOFLUSH);

    printf("Sending payload size (%u bytes, little-endian)...\n", filesize);
    
    uint8_t header[4] = {
        (uint8_t)(filesize & 0xFF),
        (uint8_t)((filesize >> 8) & 0xFF),
        (uint8_t)((filesize >> 16) & 0xFF),
        (uint8_t)((filesize >> 24) & 0xFF)
    };

    // Send and verify the 4-byte header
    for (size_t i = 0; i < 4; i++) {
        if (send_and_verify_byte(tty_fd, header[i], i, "header") < 0) {
            free(buffer);
            close(tty_fd);
            return 1;
        }
    }

    printf("Streaming %s to PSRAM (0x08000000)...\n", filepath);
    
    // Send and verify the payload bytes with progress display
    for (size_t i = 0; i < filesize; i++) {
        if (send_and_verify_byte(tty_fd, buffer[i], i, "payload") < 0) {
            free(buffer);
            close(tty_fd);
            return 1;
        }

        if ((i + 1) % 1024 == 0 || (i + 1) == filesize) {
            printf("\rVerified %zu / %u bytes (%.1f%%)", 
                   i + 1, filesize, ((float)(i + 1) / filesize) * 100.0f);
            fflush(stdout);
        }
    }

    printf("\nSuccessfully verified and loaded %u bytes into PSRAM!\n", filesize);

    free(buffer);
    close(tty_fd);
    return 0;
}
