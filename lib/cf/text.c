#include <cflea.h>

// some handy defines for the entire game demo
#define vidmem ((unsigned char *)0xF800)
#define RGB(r, g, b) (((r & 7) << 0) | ((g & 7) << 3) | ((b & 3) << 6))

// directions
#define UP 0
#define RIGHT 1
#define DOWN 2
#define LEFT 3

// video signals (sync are active low, EN is active high)
#define VSYNC 0x02
#define HSYNC 0x04
#define VIDEN 0x08


// wait upto 255 ms
wait_ms(unsigned ms)
{
	asm {		
		OUT $11			* clear timer
wait_ms_top
		IN $11			* read timer
		CMP 2,S			* compare to ms 
		JZ wait_ms_top  * wait till ms passes
	}
}

// wait arbitrary amount of ms.
wait_xms(unsigned ms)
{
	while (ms) {
		if (ms > 255) {
			wait_ms(255);
			ms -= 255;
		} else {
			wait_ms(ms);
			return;
		}
	}
}

// set the video mode (0 == text, 1 == LRG)
vid_mode(unsigned mode)
{
	asm {
		LD 2,S
		OUT $12
	}
}

unsigned read_video_status(void)
{
	asm {
		IN $12
	}
}
// wait till start of VGA vsync
wait_vsync(void)
{
// active low so a 0 bit means we're in VSYNC
	asm {
wait_vsync_top
		IN $12
		ANDB #2
		JNZ wait_vsync_top
	}
}

// wait till end of VGA vsync
wait_nvsync(void)
{
	asm {
wait_nvsync_top
		IN $12
		ANDB #2
		JZ wait_vsync_top
	}
}

// wait till start of VGA hsync
wait_hsync(void)
{
// active low HSYNC as well
	asm {
wait_hsync_top
		IN $12
		ANDB #4
		JNZ wait_vsync_top
	}
}

// wait to be in active video (this would be time to update your app logic)
void wait_active_video(void)
{
	asm {
wait_active_top
		IN $12
		ANDB #8
		JZ wait_active_top
	}
}

clrscr(void)
{
	memset(vidmem, 0, 2048);
}

// put a string on the text display at (x,y)
putsxy(char *s, unsigned x, unsigned y)
{
	char *dst;
	dst = vidmem + (y * 80) + x;
	while (*s)
		*dst++ = *s++;
}

plotxy(unsigned char col, unsigned x1, unsigned y1)
{
	vidmem[y1 * 48 + x1] = col;
}


int main() {
	unsigned x, y;

	for (;;) {
		vid_mode(0);
		clrscr();	
		for (x = 0; x < 80; x++) {
			putsxy("A", x, 0);
			putsxy("B", x, 24);
		}
		for (y = 0; y < 25; y++) {
			putsxy("C", 0, y);
			putsxy("D", 79, y);
		}
		wait_xms(5000);
		
		vid_mode(1);
		clrscr();
		
		plotxy(RGB(7,0,0),0,0);
		plotxy(RGB(0,7,0),47,0);
		plotxy(RGB(0,0,3),0,39);
		plotxy(RGB(7,7,3),47,39);
		wait_xms(5000);
	}
	
}
