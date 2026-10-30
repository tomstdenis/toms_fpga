#include "lt1000.h"

// viewport dimensions
#define VIEW_WIDTH  80
#define VIEW_HEIGHT 47

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
static int insert_blank_line_after(struct line *el)
{
    struct line *tmp;

    // create new blank line
    tmp = calloc(1, sizeof *tmp);
    if (!tmp) {
        return -1;
    }
    tmp->txt = calloc(128, sizeof *(tmp->txt));
    if (!tmp->txt) {
        free(tmp);
        return -1;
    }
    tmp->size = 128;
    tmp->prev = el;

    // move next time down
    if (el->next) {
        tmp->next = el->next;
        el->next->prev = tmp; 
    }
    el->next = tmp;

    return 0;
}

// insert a line at a given y
static int insert_line(int y)
{
    struct line *el, *tmp;

    el = editor.work;
    while (y-- && el->next) {
        el = el->next;
    }

    return insert_blank_line_after(el);
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
    int x, y;
    struct line *el;

    // clear scr
    txt_cursor(0, 0, 0x70);
    txt_clrscr();

    // fine the line corresponding to editor.viewport.y
    el = editor.work;
    y = editor.viewport.y;
    while (y-- && el) {
        el = el->next;
    }

    // draw editor
    for (y = 0; y < VIEW_HEIGHT; y++) {
        for (x = 0; x < VIEW_WIDTH; x++) {
            // move txt cursor and set color based on editor cursor
            if ((editor.viewport.y + y == editor.cursor.y) && (editor.viewport.x + x == editor.cursor.x)) {
                txt_cursor(x, y+1, 0xF0);
            } else {
                txt_cursor(x, y+1, 0x70);
            }
            // draw char
            if (el && (editor.viewport.x + x) < el->len) {
                txt_putc(el->txt[editor.viewport.x + x]);
            }
        }
        if (el) {
            el = el->next;
        }
    }

    // write out status line
    txt_cursor(0, VIEW_HEIGHT, 0xF1);
    txt_printf("%d:%d, %s", editor.cursor.x, editor.cursor.y, editor.filename);
}

int create_editor(void)
{
    memset(&editor, 0, sizeof editor);
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
static void cmd_editor(int key, int ch)
{
    int y;
    struct line *el;
    printf("key == %d, ch == %x\n", key, ch);

    y = editor.cursor.y;
    el = editor.work;
    while (y-- && el) {
        el = el->next;
    }

    switch(key) {
        case KEY_UP: // cursor up
            if (editor.cursor.y) {
                editor.cursor.y--;
                if (el) {
                    el = el->prev;
                }
            }
            break;
        case KEY_DOWN: // cursor down
            if (el && el->next) {
                editor.cursor.y++;
                el = el->next;
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
        case KEY_LTR: // a letter
            {
                int at_end = 0;
                if (el && el->len == editor.cursor.x) {
                    at_end = 1;
                }
                line_insert_char_at(editor.cursor.x, editor.cursor.y, ch);
                if (at_end) {
                    editor.cursor.x++;
                }
            }
            break;            
    }

    // TODO: snap cursor to text
    if (el) {
        if (editor.cursor.x > el->len) {
            editor.cursor.x = el->len;
        }
    }

    // sanity check
    if (editor.cursor.x < 0) {
        editor.cursor.x = 0;
    }
    if (editor.cursor.y < 0) {
        editor.cursor.y = 0;
    }

    // TODO: snap viewport to cursor (e.g. if it's to the right or beneath the viewport)
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
    if (ch == 'q') {
        exit(0);
    }

    // handle escape keys
    for (x = 0; x < (sizeof(key_lut) / sizeof(key_lut[0])); x++) {
        if ((key_lut[x].pppch == 0 || key_lut[x].pppch == pppch) && 
             ppch == key_lut[x].ppch &&
             pch == key_lut[x].pch &&
             ch == key_lut[x].ch) {
            cmd_editor(key_lut[x].key, ch);
            render_editor();
            esc = 0;
            return;
        }
    }

    // nothing match so just dealing with ch
    switch (ch) {
        case '\t': cmd_editor(KEY_TAB, ch); break;
        case 0xb: cmd_editor(KEY_CTRLK, ch); break;
        case 0xd: cmd_editor(KEY_ENTER, ch); break;
        case 0x7f: cmd_editor(KEY_BS, ch); break;
        case 3: cmd_editor(KEY_CTRLC, ch); break;
        case 0x18: cmd_editor(KEY_CTRLX, ch); break;
        case 0x15: cmd_editor(KEY_CTRLU, ch); break;
        case 0x17: cmd_editor(KEY_CTRLW, ch); break;
        default: if (!esc) { cmd_editor(KEY_LTR, ch); } break;
    }

    render_editor();
}

int main(void) {
    char c;
    getch();
    yield_init();
    yield_sei();
    yield_add_irq(YIELD_IRQ_UART_RX_READY, 0, 0, kbd_handler);
    create_editor();
    insert_line(0);
    line_insert_char_at(0, 0, 'H');
    line_insert_char_at(0, 1, 'T');
    printf("first line == [%s]\n", editor.work->txt);
    printf("second time == [%s]\n", editor.work->next->txt);
    render_editor();
    for (;;) {
        yield();
    }
    return 0;
}