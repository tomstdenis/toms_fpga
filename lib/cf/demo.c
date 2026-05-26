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
	strcpy(dst, s);
}

// put a centered string
putscentered(char *s, unsigned y)
{
	putsxy(s, 40 - (strlen(s) >> 1), y);
}

hline(unsigned char col, unsigned x1, unsigned y1, unsigned x2)
{
	unsigned char *dst;
	dst = vidmem + (y1 * 48) + x1;
	while (x1++ <= x2) {
		*dst++ = col;
	}
}

vline(unsigned char col, unsigned x1, unsigned y1, unsigned y2)
{
	unsigned char *dst;
	dst = vidmem + (y1 * 48) + x1;
	while (y1++ <= y2) {
		*dst = col;
		dst += 48;
	}
}

plotxy(unsigned char col, unsigned x1, unsigned y1)
{
	vidmem[y1 * 48 + x1] = col;
}

#define STARS 64
struct {
	unsigned x[STARS], y[STARS], sx[STARS], sy[STARS], sdx[STARS], sdy[STARS];
} stars;

unsigned randy = 4;
unsigned rng()
{
	randy = (randy * 13709) + 13849;
	return randy;
}

main()
{
	unsigned x, y, z, sx, sy;
	char msg[80];

	// boot
	clrscr();
	vid_mode(0);
	
	for (x = 0; x < 10; x++) {
		sprintf(msg, "Lead: %d...", x);
		putsxy(msg, 0, 0);
		wait_xms(1000);
		clrscr();
	}
	
	putsxy("Booting C-FLEA Primer25K CISC Thingy...", 0, 1);
	for (x = 0; x < 8; x++) {
		sprintf(msg, "Testing memory: %02d KB", x);
		putsxy(msg, 0, 2);
		wait_xms(500);
	}
	y = strlen(msg);
	wait_xms(1000);
	// fake out a block not being found...
	for (x = 0; x < 4; x++) {
		putsxy(".", y++, 2);
		wait_xms(750);
	}
	putsxy("Where the f is the 8'th KB....", 0, 3);
	wait_xms(1500);
	putsxy("G'damn Chinese slop....", 0, 4);
	wait_xms(1500);
	putsxy("Aha, off by one in the memory map, ok back to the show!", 0, 5);
	wait_xms(2000);
	clrscr();
	putsxy("Booting C-FLEA Primer25K CISC Thingy...", 0, 1);	
	for (x = 8; x < 61; x++) {
		sprintf(msg, "Testing memory: %02d KB", x);
		putsxy(msg, 0, 2);
		wait_xms(100);
	}
	putsxy("Booted, now experience the raw power of 10 MIPS.", 0, 3);
	wait_xms(1000);
	
	// show impressive graphics
	clrscr();
	putsxy("Star field", 0, 1);
	putsxy("*", 10, 10);
	wait_xms(3000);
	putsxy("Plural?", 0, 2);
	wait_xms(1500);
	putsxy("Fine (I had to fix a bug in the RTL...", 0, 3);
	wait_xms(1500);
	
	// actual star field?
starsf:
	clrscr();
	memset(stars, 0, sizeof(stars));
	
	for (z = 0; z < (8 * 30); z++) {
		for (x = 0; x < STARS; x++) {
			// If the star is dead (0), spawn it in the middle
			if (stars.x[x] == 0) {
				stars.x[x] = ((35 + ((rng() >> 1) & 7)) << 4); // Center X in .4 fixed point (640)
				stars.y[x] = ((8 + ((rng() >> 7) & 7)) << 4); // Center Y in .4 fixed point (192)
				
				// Give it a valid delta speed between 1 and 16 (0.06 to 1.0 pixels/frame)
				stars.sx[x] = ((rng() >> 5) & 15) + 1; 
				stars.sy[x] = ((rng() >> 7) & 15) + 1; 
				
				// Direction: 0 = Positive (Right/Down), 1 = Negative (Left/Up)
				stars.sdx[x] = (rng() >> 7) & 1;
				stars.sdy[x] = (rng() >> 3) & 1;
			} else { 
				// --- MOVE X ---
				if (stars.sdx[x] == 0) {
					stars.x[x] += stars.sx[x];
				} else {
					// Safe unsigned subtraction: check if it would underflow 0
					if (stars.x[x] > stars.sx[x]) {
						stars.x[x] -= stars.sx[x];
					} else {
						stars.x[x] = 0; // Force to edge
					}
				}

				// --- MOVE Y ---
				if (stars.sdy[x] == 0) {
					stars.y[x] += stars.sy[x];
				} else {
					// Safe unsigned subtraction
					if (stars.y[x] > stars.sy[x]) {
						stars.y[x] -= stars.sy[x];
					} else {
						stars.y[x] = 0;
					}
				}

				// Convert fixed-point back to actual screen coordinates
				sx = stars.x[x] >> 4;
				sy = stars.y[x] >> 4;

				// Kill the star if it hits the screen boundaries
				// On an 80x25 screen, valid pixels are X: 0-79, Y: 0-24
				if (sx <= 1 || sx >= 78 || sy <= 1 || sy >= 23) {
					stars.x[x] = 0; // Mark as dead so it respawns next frame
				}
			}

			// Draw the star only if it didn't just get killed
			if (stars.x[x] != 0) {
				sx = stars.x[x] >> 4;
				sy = stars.y[x] >> 4;
				vidmem[sx + (sy * 80)] = '*';
			}
//			printf("star %u: x=%u, y=%u, sx=%u, sy=%u, sdx=%u, sdy=%u, rng == %u\n", x, stars.x[x], stars.y[x], stars.sx[x], stars.sy[x], stars.sdx[x], stars.sdy[x], rng());  
		}
		if (z > (30 * 3)) {
			putsxy("Look I'm not good at demos...", 7, 3);
		}
	
		wait_ms(33);
		clrscr();
	}
	clrscr();
	putsxy("Demo by Tom St Denis", 0, 1); wait_xms(500);
	putsxy("RTL by Tom St Denis", 0, 2);  wait_xms(500);
	putsxy("Videography by Tom St Denis", 0, 3);  wait_xms(500);
	putsxy("Editing by Tom St Denis", 0, 4);  wait_xms(500);
	putsxy("Executive Producer: Larry David", 0, 5);  wait_xms(1250);
	putsxy("                        and", 0, 6);  wait_xms(500);
	putsxy("                    Tom St Denis", 0, 7);  wait_xms(500);
	putsxy("That...", 0, 8);  wait_xms(1250);
	putsxy("THAT is how you ATTENTION WHORE!!!! :-)", 0, 9);  wait_ms(250);
	
	for (;;);
}

