#define HOSTPC

#include <stdio.h>
#include <termios.h>
#include <unistd.h>
#include <ncurses.h>
#include <signal.h>
#include <stdlib.h>
#include <stdint.h>
#include <sys/time.h>
#include "00_top.ino"

#ifdef BOARD_APPLE1
#include "roms/apple1_wozmon.h"
#define ROM_START 0xFF00
#define ROM_SIZE  0x100
#endif

#ifdef BOARD_APPLE2
// hello demo
#include "roms/apple2_hello.h"
#if 1
#include "roms/apple2_bare.h"
#define ROM_START 0xE000
#define ROM_SIZE  0x2000
#elif 1
#include "roms/apple2_plus.h"
#define ROM_START 0xD000
#define ROM_SIZE 0x3000
#else
#include "roms/apple2iie.h"
#define ROM_START 0xC000
#define ROM_SIZE 0x4000
#endif
#endif


// Call this once at the start of your main() program
static struct timeval start_time;
extern unsigned long cachehit0, cachehit1;
extern uint64_t cache_trace_hit, cache_trace_miss, cache_trace_split_read, cache_trace_split_write;
void init_host_terminal() {
    initscr();             // Start ncurses mode
    cbreak();              // Line buffering disabled
    noecho();              // Don't echo() while we do getch
    nodelay(stdscr, TRUE); // Make getch() non-blocking
    scrollok(stdscr, TRUE); // Allow the screen to scroll
	keypad(stdscr, TRUE);  // <--- THIS IS REQUIRED for F1, F2, etc.
	gettimeofday(&start_time, NULL);
}

// Call this before exiting the program
void stop_host_terminal(int foo) {
	struct timeval end_time;
    endwin();
    gettimeofday(&end_time, NULL);
    uint64_t start_us, end_us, runtime_us, period;
    start_us = start_time.tv_sec * 1000000ULL + start_time.tv_usec;
    end_us = end_time.tv_sec * 1000000ULL + end_time.tv_usec;
    runtime_us = end_us - start_us;
    period = (runtime_us * 1000ULL) / cpu_cycles;
    printf("Total platform cycles: %lu (cpu cycles: %lu) in %llu uS (period: %llu nS)\n", (unsigned long)platform_cycles, (unsigned long)cpu_cycles, (unsigned long long)end_us - start_us, (unsigned long long)period);
	printf("Cache hits to 0th and 1st cachelines: %lu, %lu (both represent %llu %%)\n", cachehit0, cachehit1, ((cachehit0 + cachehit1) * 100ULL) / (unsigned long long)(cache_trace_hit + cache_trace_miss));
	printf("Cache: hits:%llu (%llu %%), miss:%llu, split_read:%llu, split_write:%llu\n", (unsigned long long)cache_trace_hit, (unsigned long long)(cache_trace_hit * 100ULL) / (unsigned long long)(cache_trace_hit + cache_trace_miss), (unsigned long long)cache_trace_miss, (unsigned long long)cache_trace_split_read, (unsigned long long)cache_trace_split_write);
    exit(-1);
}

int main(void)
{
	signal(SIGINT, stop_host_terminal);
	init_host_terminal();

	// init platform
	platform_init();

	// cpu might have tried to init some cache entries so we invalidate here
	cache_invalidate();

#ifdef ROM_START
	// load firmware
	mem_write_block(ROM_START, ROM_SIZE, (uint8_t*)rom);
	#ifdef BOARD_APPLE2
		// copy cl65 demo to 0800 for size bytes
		mem_write_block(0x0800, sizeof apple2_hello_bin, (uint8_t*)apple2_hello_bin);
	#endif	
#endif

	// we loaded firmware so the CPU is likely running garbage so reset it
	cpu_reset();
	
	// execute machine
	for (;;) {
		platform_step();
	}
}
