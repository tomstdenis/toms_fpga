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

// display a menu on the screen
const char *menutxt[] = 
{
	"Snake",
	"Bootloader",
	NULL
};

int menu(void)
{
	char tmp[32];
	
	int x, ch;
	
	// draw menu
	clrscr();					// clear video memory
	vid_mode(0);				// set text mode
	putscentered("C-FLEA Game Menu -- Tom St Denis", 3);
	for (x = 0; menutxt[x]; x++) {
		sprintf(tmp, "#%d. %s", x+1, menutxt[x]);
		putsxy(tmp, 5, 5 + x);
	}
	putsxy("Enter choice: ", 5, 7 + x);
	do {
		ch = getch();
	} while ((ch < '0') || (ch > '9'));
	return ch - '0';
}

// snake game...
#define SNAKELEN 16
snake()
{
	// snake!
	unsigned char snake_x[SNAKELEN], snake_y[SNAKELEN]; // [0] is the head
	unsigned char snake_len, snake_dir, snake_dead;
	unsigned char food_x, food_y;
	int x, y, gr;
	unsigned ch;

replay:
	// init game state (snake at 4,4 facing right)
	memset(snake_x, 0, sizeof(snake_x));
	memset(snake_y, 0, sizeof(snake_y));
	snake_x[0] = 4;
	snake_y[0] = 4;
	snake_dir = RIGHT;
	food_x = food_y = 10;
	snake_len = 1;
	snake_dead = 0;
	gr = 0;
	
	// setup screen
	clrscr();
	vid_mode(1);
	
	// game loop
	for (;;) {
		// wait for active region...
		while (!(read_video_status() & VIDEN));

		do {
			ch = chkchr(); // returns FFFF if no char
			switch (ch) {
				case 'w': snake_dir = UP; break;
				case 's': snake_dir = DOWN; break;
				case 'a': snake_dir = LEFT; break;
				case 'd': snake_dir = RIGHT; break;
				case 'q': return;
			}
		} while ((read_video_status() & VSYNC)); // wait for VSYNC to start
		if (!(++gr == 2)) continue;
		gr = 0;
		
		// now we're in vsync we can draw to the screen memory...
		clrscr();
		
		// draw border
		hline(RGB(7, 0, 0), 0, 0, 47);		// 0,0 to 47,0
		hline(RGB(7, 0, 0), 0, 39, 47);     // 0,39, to 47,39
		vline(RGB(7, 0, 0), 0, 0, 39);
		vline(RGB(7, 0, 0), 47, 0, 39);
		
		// move snake
		for (x = snake_len; x > 0; x--) {
			snake_x[x] = snake_x[x-1];
			snake_y[x] = snake_y[x-1];
		}
		switch (snake_dir) {
			case UP: snake_y[0]--; break;
			case RIGHT: snake_x[0]++; break;
			case DOWN: snake_y[0]++; break;
			case LEFT: snake_x[0]--; break;
		}
		
		// draw from tail to head and detect body collision
		for (x = snake_len; x > 0; x--) {
			plotxy(RGB(0,7,0), snake_x[x], snake_y[x]);
			if (snake_x[x] == snake_x[0] || snake_y[x] == snake_y[0]) {
				// hitself
				snake_dead = 1;
			}
		}
		// draw head
		plotxy(RGB(0, 7, 3), snake_x[0], snake_y[0]);
		
		// draw food 
		plotxy(RGB(7, 7, 0), food_x, food_y);

		// handle collision with walls
		if (snake_x[0] == 0 || snake_x[0] == 47 || snake_y[0] == 0 || snake_y[0] == 39) {
			snake_dead = 1;
		}
		
		// handle collision with food pellet
		if (snake_x[0] == food_x && snake_y[0] == food_y) {
			if (snake_len < (SNAKELEN-1)) {
				++snake_len;
			}
			// pick new random spot for food....
		}
		
		// handle snake dead....
		if (snake_dead) {
			goto snek_ded;
		}
	}
snek_ded:
	clrscr();
	vid_mode(0); // text mode
	
	putscentered("Snek is ded... so sad.  Hit key play again...", 10);
	while (chkchr() != 0xFFFF);
	getch();
	goto replay;
}

main()
{
	int ch;
	
	vid_mode(1);
	clrscr();
	
	for (;;) {
		ch = menu();
		switch (ch) {
			case 1:
				snake();
				break;
			case 2:
				clrscr();
				putsxy("Jumping to bootloader...", 0, 0);
				asm {
					JMP $F000
				}
				break;
		}
	}
}
