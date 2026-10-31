#include "lt1000.h"

// viewport dimensions
#define VIEW_WIDTH  70
#define VIEW_HEIGHT 45

enum {
    KEY_UP = 0,
    KEY_DOWN,
    KEY_RIGHT,
    KEY_LEFT,
    KEY_HOME,
    KEY_END,
    KEY_PGUP,
    KEY_PGDN,
    KEY_BS,
    KEY_TAB,
    KEY_STAB,
    KEY_INS,
    KEY_DEL,
    KEY_ENTER,
    KEY_CTRLC,
    KEY_CTRLX,
    KEY_CTRLK,
    KEY_CTRLU,
    KEY_CTRLW,
    KEY_CTRLO,
    KEY_CTRLR,
    KEY_F1,
    KEY_F2,
    KEY_F3,
    KEY_F4,
    KEY_F5,
    KEY_F6,
    KEY_F7,
    KEY_F8,
    KEY_F9,
    KEY_F10,
    KEY_F11,
    KEY_F12,
    KEY_LTR,
} key_commands;

struct line {
    char *txt;
    int size, len;
    struct line *prev, *next;
};

static struct {
    char filename[512];
    struct line *work;
    struct {
        int x, y;                   // top left of viewport
    } viewport;
    struct {
        int x, y;
    } cursor;
} editor;

// insert a new line 
static int insert_blank_line_after(int x, struct line *el)
{
    struct line *tmp;

    // create new blank line
    tmp = calloc(1, sizeof *tmp);
    if (!tmp) {
        return -1;
    }
    tmp->txt = calloc(el->len - x + 128, sizeof *(tmp->txt));
    if (!tmp->txt) {
        free(tmp);
        return -1;
    }
    tmp->size = el->len - x + 128;
    tmp->len  = el->len - x;
    tmp->prev = el;

    // copy from el from position x on
    memcpy(tmp->txt, el->txt + x, el->len - x);
    el->len = x ? x : 0;

    // move next time down
    if (el->next) {
        tmp->next = el->next;
        el->next->prev = tmp; 
    }
    el->next = tmp;

    return 0;
}

// insert a line at a given x, y
static int insert_line(int x, int y)
{
    struct line *el, *tmp;

    el = editor.work;
    while (y-- && el->next) {
        el = el->next;
    }
    return insert_blank_line_after(x, el);
}

// delete a line
static int delete_line(int y)
{
    struct line *el = NULL;

    // deleting the first line changes a named pointer
    if (!y) {
        if (editor.work->next) {
            // just shift up
            el = editor.work->next;
            el->prev = NULL;
            free(editor.work->txt);
            free(editor.work);
            editor.work = el;
            return 0;
        } else {
            // there's no other lines just zero out this line
            memset(editor.work->txt, 0, editor.work->size);
            editor.work->len = 0;
            return 0;
        }
    }

    el = editor.work;
    while (y-- && el->next) {
        el = el->next;
    }
    if (el->next) {
        // link the neighbours
        el->next->prev = el->prev;
        el->prev->next = el->next;
    } else {
        // terminate list
        el->prev->next = NULL;
    }
    free(el->txt);
    free(el);
    return 0;    
}

// insert a char at a point inside the string
static int line_insert_char_at(int x, int y, char c)
{
    struct line *el;

    el = editor.work;
    while (y-- && el->next) {
        el = el->next;
    }

    // resize line?
    if ((el->len + 1) == el->size) {
        void *tmp;
        tmp = realloc(el->txt, el->size + 64);
        if (tmp) {
            // zero new bytes
            memset(el->txt + el->size, 0, 64);
            el->txt   = tmp;
            el->size += 64;
        } else {
            return -1;
        }
    }

    // insert it 
    if (x != el->len) {
        memmove(el->txt + x + 1, el->txt + x, el->len - x);
    }
    el->txt[x] = c;
    el->len += 1;
    return 0;
}

static void render_editor(void)
{
    static int blink = 0;
    int x, y;
    struct line *el;

    blink += 1;
    if (blink == 15) {
        blink = 0;
    }
    txt_cursor(0, 0, 0x70);

    // fine the line corresponding to editor.viewport.y
    el = editor.work;
    y = editor.viewport.y;
    while (y-- && el) {
        el = el->next;
    }

    // draw editor
    for (y = 0; y < VIEW_HEIGHT; y++) {
        if (el) {
            txt_cursor(0, y, 0x80 | 0x40 | 0x20);
            txt_puts_dec(y + editor.viewport.y, 5);
            txt_cursor(5, y, 0x70);
            txt_putc(':');
        } else {
            int z;
            txt_cursor(0, y, 0x70);
            z = 6;
            while (z--) {
                txt_putc(' ');
            }
        }
        for (x = 0; x < VIEW_WIDTH; x++) {
            // move txt cursor and set color based on editor cursor
            if ((blink < 8) && (editor.viewport.y + y == editor.cursor.y) && (editor.viewport.x + x == editor.cursor.x)) {
                txt_cursor(x + 10, y, 0x0F);
            } else {
                txt_cursor(x + 10, y, 0x70);
            }
            // draw char
            if (el && (editor.viewport.x + x) < el->len) {
                txt_putc(el->txt[editor.viewport.x + x]);
            } else if (el && (editor.viewport.x + x) == el->len && (editor.viewport.y + y == editor.cursor.y)) {
                txt_putc('`');
            } else {
                txt_putc(' ');
            }
        }
        if (el) {
            el = el->next;
        }
    }

    // write out status line
    txt_cursor(0, VIEW_HEIGHT+1, 0x80 | 0x40 | 0x20); // bright yellow
    txt_puts_dec(editor.cursor.x, 5);
    txt_putc(':');
    txt_puts_dec(editor.cursor.y, 5);
    txt_puts(", ");
    txt_puts(editor.filename);
}

int create_editor(void)
{
    memset(&editor, 0, sizeof editor);
    strcpy(editor.filename, "untitled");
    editor.work = calloc(1, sizeof *editor.work);
    if (!editor.work) {
        return -1;
    }
    editor.work->txt = calloc(128, sizeof *(editor.work->txt));
    if (!editor.work->txt) {
        free(editor.work);
        return -1;
    }
    editor.work->size = 128;
}

// do editor command
static struct line *render_el = NULL;
static void cmd_editor(int key, int ch)
{
    if (!render_el) {
        int y;
        y = editor.cursor.y;
        render_el = editor.work;
        while (y-- && render_el) {
            render_el = render_el->next;
        }
    }

    switch(key) {
        case KEY_UP: // cursor up
            if (editor.cursor.y) {
                editor.cursor.y--;
                if (render_el) {
                    render_el = render_el->prev;
                }
            }
            break;
        case KEY_DOWN: // cursor down
            if (render_el && render_el->next) {
                editor.cursor.y++;
                render_el = render_el->next;
            }
            break;
        case KEY_LEFT: // cursor left
            if (editor.cursor.x) {
                editor.cursor.x--;
            }
            break;
        case KEY_RIGHT: // cursor right
            editor.cursor.x++;
            break;
        case KEY_HOME: // home key
            editor.cursor.x = 0;
            break;
        case KEY_END: // end key
            if (render_el) {
                editor.cursor.x = render_el->len;
            }
            break;
        case KEY_PGUP: // page up
            if (render_el) {
                int z = 25;
                // move up, upto 25 lines up
                while (z-- && render_el->prev) {
                    render_el = render_el->prev;
                    editor.cursor.y -= 1;
                }
                if (editor.cursor.x > render_el->len) {
                    editor.cursor.x = render_el->len;
                }
            }
            break;
        case KEY_PGDN: // page down
            if (render_el) {
                int z = 25;
                // move up, upto 25 lines down
                while (z-- && render_el->next) {
                    render_el = render_el->next;
                    editor.cursor.y += 1;
                }
                if (editor.cursor.x > render_el->len) {
                    editor.cursor.x = render_el->len;
                }
            }
            break;
        case KEY_TAB: // tab == 4 spaces
        {
            int atend = render_el ? (editor.cursor.x == render_el->len) : 0;
            line_insert_char_at(editor.cursor.x, editor.cursor.y, ' ');
            line_insert_char_at(editor.cursor.x, editor.cursor.y, ' ');
            line_insert_char_at(editor.cursor.x, editor.cursor.y, ' ');
            line_insert_char_at(editor.cursor.x, editor.cursor.y, ' ');
            editor.cursor.x += atend ? 4 : 0;
        }
            break;
        case KEY_ENTER: // enter
            insert_line(editor.cursor.x, editor.cursor.y);
            render_el = render_el->next;
            editor.cursor.y++;
            editor.cursor.x = 0;
            break;
        case KEY_DEL: // delete
            if (render_el) {
                if (editor.cursor.x == render_el->len) {
                    // bring the previous line up to the cursor
                    if (render_el->next) {
                        void *tmp = realloc(render_el->txt, render_el->size + render_el->next->len + 128);
                        if (tmp) {
                            render_el->txt  = tmp;
                            render_el->size = render_el->size + render_el->next->len + 128;
                        }
                        memcpy(render_el->txt + render_el->len, render_el->next->txt, render_el->next->len);
                        render_el->len += render_el->next->len;
                        delete_line(editor.cursor.y + 1);
                    }
                } else {
                    // delete the char at the cursor
                    memmove(render_el->txt + editor.cursor.x,
                            render_el->txt + editor.cursor.x + 1,
                            render_el->len - editor.cursor.x);
                    render_el->len -= 1;
                }
            }
            break;
        case KEY_BS: // backspace
            if (editor.cursor.x) {
                // delete char to the left of the cursor
                memmove(render_el->txt + editor.cursor.x - 1,
                        render_el->txt + editor.cursor.x,
                        render_el->len - editor.cursor.x);
                render_el->len -= 1;
                editor.cursor.x -= 1;
            } else {
                // at start of line delete line
                if (render_el && render_el->prev) {
                    int oldplen = render_el->prev->len;
                    // append the current line to the end of the previous line
                    if (render_el->prev->size < (render_el->prev->len + render_el->len)) {
                        void *tmp;
                        tmp = realloc(render_el->prev->txt, render_el->prev->size + render_el->len + 128);
                        if (!tmp) return;
                        render_el->prev->txt = tmp;
                    }
                        render_el->prev->size = render_el->prev->size + render_el->len + 128;
                        memcpy(render_el->prev->txt + render_el->prev->len, render_el->txt, render_el->len);
                        render_el->prev->len += render_el->len;

                    // delete the line
                    render_el = render_el->prev;
                    delete_line(editor.cursor.y--);
                    editor.cursor.x = oldplen;
                }
            }
            break;
        case KEY_LTR: // a letter
            {
                int at_end = 0;
                if (render_el && render_el->len == editor.cursor.x) {
                    at_end = 1;
                }
                line_insert_char_at(editor.cursor.x, editor.cursor.y, ch);
                editor.cursor.x++;
            }
            break;
        case KEY_CTRLX: // ^X
            exit(0);
            break;     
    }

    // snap cursor to text
    if (render_el) {
        if (editor.cursor.x > render_el->len) {
            editor.cursor.x = render_el->len;
        }
    }

    // sanity check
    if (editor.cursor.x < 0) {
        editor.cursor.x = 0;
    }
    if (editor.cursor.y < 0) {
        editor.cursor.y = 0;
    }

    // snap viewport to cursor (e.g. if it's to the right or beneath the viewport)
    if (editor.cursor.x < editor.viewport.x) {
        // if the cursor is to the left the viewport jump back 5 chars
        editor.viewport.x = editor.cursor.x - 5;
        if (editor.viewport.x < 0) {
            editor.viewport.x = 0;
        }
    }

    if (editor.cursor.x >= (editor.viewport.x + VIEW_WIDTH)) {
        // cursor is to the right of the viewpot
        editor.viewport.x = editor.cursor.x - VIEW_WIDTH + 1;
    }

    if (editor.cursor.y < editor.viewport.y) {
        // if the cursor is above the viewport jump ahead 5 lines
        editor.viewport.y = editor.cursor.y - 5;
        if (editor.viewport.y < 0) {
            editor.viewport.y = 0;
        }
    }

    if (editor.cursor.y >= (editor.viewport.y + VIEW_HEIGHT)) {
        // cursor is below the viewport
        editor.viewport.y = editor.cursor.y - VIEW_HEIGHT + 1;
    }
}

// handle keyboardi input via serial
const static struct {
    int pppch, ppch, pch, ch, key;
} key_lut[] = {
    { 0x1b, 0x5b, 0x32, 0x7e, KEY_INS   },
    { 0x1b, 0x5b, 0x33, 0x7e, KEY_DEL   },
    { 0x1b, 0x5b, 0x35, 0x7e, KEY_PGUP   },
    { 0x1b, 0x5b, 0x36, 0x7e, KEY_PGDN   },
    { 0x00, 0x1b, 0x5b, 0x41, KEY_UP,    },
    { 0x00, 0x1b, 0x5b, 0x42, KEY_DOWN,  },
    { 0x00, 0x1b, 0x5b, 0x43, KEY_RIGHT, },
    { 0x00, 0x1b, 0x5b, 0x44, KEY_LEFT,  },
    { 0x00, 0x1b, 0x5b, 0x46, KEY_END,   },
    { 0x00, 0x1b, 0x5b, 0x48, KEY_HOME,  },
    { 0x00, 0x1b, 0x5b, 0x5a, KEY_STAB,  },
    { 0x00, 0x1b, 0x4f, 0x50, KEY_F1,  },
    { 0x00, 0x1b, 0x4f, 0x51, KEY_F2,  },
    { 0x00, 0x1b, 0x4f, 0x52, KEY_F3,  },
    { 0x00, 0x1b, 0x4f, 0x53, KEY_F4,  },
};

static void kbd_handler(uint32_t data)
{
    static int pppch = 0, ppch = 0, pch = 0, ch = 0, esc = 0;
    int x;

    pppch = ppch;
    ppch = pch;
    pch  = ch;
    ch = getch();
    if (ch == 0x1b) {
        esc = !esc;
    }
//    printf("ch == %x\n", ch);

    // handle escape keys
    for (x = 0; x < (sizeof(key_lut) / sizeof(key_lut[0])); x++) {
        if ((key_lut[x].pppch == 0 || key_lut[x].pppch == pppch) && 
             ppch == key_lut[x].ppch &&
             pch == key_lut[x].pch &&
             ch == key_lut[x].ch) {
            cmd_editor(key_lut[x].key, ch);
            esc = 0;
            return;
        }
    }

    // nothing match so just dealing with ch
    switch (ch) {
        case '\t': cmd_editor(KEY_TAB, ch); break;
        case 0xb: cmd_editor(KEY_CTRLK, ch); break;
        case 0xd: cmd_editor(KEY_ENTER, ch); break;
        case 0xf: cmd_editor(KEY_CTRLO, ch); break;
        case 0x7f: cmd_editor(KEY_BS, ch); break;
        case 3: cmd_editor(KEY_CTRLC, ch); break;
        case 0x12: cmd_editor(KEY_CTRLR, ch); break;
        case 0x15: cmd_editor(KEY_CTRLU, ch); break;
        case 0x17: cmd_editor(KEY_CTRLW, ch); break;
        case 0x18: cmd_editor(KEY_CTRLX, ch); break;
        default: if (!esc) { cmd_editor(KEY_LTR, ch); } break;
    }
}

static void render_loop(uint32_t data)
{
    static int half = 0;
    half ^= 1;
    if (half) {
        render_editor();
    }
}

int main(void) {
    yield_init();
    yield_sei();
    yield_add_irq(YIELD_IRQ_UART_RX_READY, 0, 0, kbd_handler);
    yield_add_irq(YIELD_IRQ_VBLANK, 0, 0, render_loop);
    create_editor();
    txt_init();
    txt_clrscr();
    for (;;) {
        yield();
    }
    return 0;
}