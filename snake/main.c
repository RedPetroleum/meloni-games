/*
 * Meloni Snake — native Game Boy Color ROM for Retro-Go on the HU-086.
 * 20x18 tile screen, calm four-colour palettes, no external graphics.
 */
#include <gb/gb.h>
#include <gb/cgb.h>
#include <gbdk/console.h>
#include <gbdk/font.h>
#include <stdio.h>
#include <stdlib.h>

#define BW 18
#define BH 12
#define BX 1
#define BY 4
#define MAX_SNAKE (BW * BH)

#define UP 0
#define RIGHT 1
#define DOWN 2
#define LEFT 3

#define READY 0
#define PLAY 1
#define PAUSE 2
#define OVER 3

/* Four-colour 8x8 tiles: floor, body, head, fruit, frame. */
static const uint8_t tiles[5 * 16] = {
    0x00,0x00, 0x00,0x00, 0x00,0x00, 0x00,0x00, 0x00,0x00, 0x00,0x00, 0x00,0x00, 0x00,0x00,
    0x00,0x00, 0x3C,0x00, 0x7E,0x00, 0x7E,0x00, 0x7E,0x00, 0x3C,0x00, 0x00,0x00, 0x00,0x00,
    0x00,0x00, 0x3C,0x00, 0x7E,0x00, 0x7E,0x00, 0x7E,0x00, 0x3C,0x00, 0x00,0x00, 0x00,0x00,
    0x00,0x00, 0x18,0x00, 0x3C,0x00, 0x7E,0x00, 0x7E,0x00, 0x3C,0x00, 0x18,0x00, 0x00,0x00,
    0xFF,0x00, 0x81,0x00, 0xBD,0x00, 0xA5,0x00, 0xA5,0x00, 0xBD,0x00, 0x81,0x00, 0xFF,0x00
};

static const palette_color_t palettes[5 * 4] = {
    RGBHTML(0x17232B), RGBHTML(0x89989A), RGBHTML(0xD6DDC9), RGBHTML(0xF5EBD2), /* ink */
    RGBHTML(0x17232B), RGBHTML(0x4F8068), RGBHTML(0x8DBA83), RGBHTML(0xC9DFA0), /* body */
    RGBHTML(0x17232B), RGBHTML(0x5D9974), RGBHTML(0xB5D989), RGBHTML(0xF5EBD2), /* head */
    RGBHTML(0x17232B), RGBHTML(0xC9574B), RGBHTML(0xF18A62), RGBHTML(0xF5D487), /* fruit */
    RGBHTML(0x17232B), RGBHTML(0x34464D), RGBHTML(0x50636A), RGBHTML(0x89989A)  /* frame */
};

static uint8_t sx[MAX_SNAKE], sy[MAX_SNAKE];
static uint16_t length, score, best_score;
static uint8_t fx, fy, direction, queued, has_turn;
static uint8_t state, ticks, step_delay, previous_keys;

static const int8_t dx[4] = { 0, 1, 0, -1 };
static const int8_t dy[4] = { -1, 0, 1, 0 };

static void set_tile(uint8_t x, uint8_t y, uint8_t tile, uint8_t palette) {
    set_bkg_tiles(x, y, 1, 1, &tile);
    set_bkg_attribute_xy(x, y, palette);
}

static void draw_text(uint8_t x, uint8_t y, const char *text) {
    gotoxy(x, y);
    printf("%s", text);
}

static void draw_number(uint8_t x, uint8_t y, uint16_t n) {
    gotoxy(x, y);
    putchar((char)('0' + (n / 100U) % 10U));
    putchar((char)('0' + (n / 10U) % 10U));
    putchar((char)('0' + n % 10U));
}

static void draw_frame(void) {
    uint8_t x, y;
    for (x = 0; x < 20; ++x) {
        set_tile(x, 3, 4, BKGF_CGB_PAL4);
        set_tile(x, 16, 4, BKGF_CGB_PAL4);
    }
    for (y = 4; y < 16; ++y) {
        set_tile(0, y, 4, BKGF_CGB_PAL4);
        set_tile(19, y, 4, BKGF_CGB_PAL4);
    }
    draw_text(5, 0, "MELONI  /  SNAKE");
    draw_text(2, 1, "SCORE");
    draw_text(12, 1, "BEST");
    draw_text(3, 17, "D-PAD MOVE   B PAUSE");
}

static void draw_hud(void) {
    draw_number(8, 1, score);
    draw_number(16, 1, best_score);
}

static void draw_cell(uint8_t x, uint8_t y, uint8_t tile, uint8_t palette) {
    set_tile((uint8_t)(BX + x), (uint8_t)(BY + y), tile, palette);
}

static uint8_t occupied(uint8_t x, uint8_t y) {
    uint16_t i;
    for (i = 0; i < length; ++i)
        if (sx[i] == x && sy[i] == y) return 1;
    return 0;
}

static void place_food(void) {
    do {
        fx = (uint8_t)(rand() % BW);
        fy = (uint8_t)(rand() % BH);
    } while (occupied(fx, fy));
    draw_cell(fx, fy, 3, BKGF_CGB_PAL3);
}

static void redraw_snake(void) {
    uint16_t i;
    for (i = 1; i < length; ++i)
        draw_cell(sx[i], sy[i], 1, BKGF_CGB_PAL1);
    draw_cell(sx[0], sy[0], 2, BKGF_CGB_PAL2);
}

static void draw_ready(void) {
    uint8_t x, y;
    cls();
    draw_frame();
    for (y = 0; y < BH; ++y)
        for (x = 0; x < BW; ++x)
            draw_cell(x, y, 0, BKGF_CGB_PAL0);
    draw_text(5, 7, "A NEW RUN");
    draw_text(3, 9, "EAT THE ORBS");
    draw_text(2, 10, "AVOID WALLS + TAIL");
    draw_text(3, 12, "PRESS A OR START");
    draw_hud();
}

static void start_game(void) {
    uint8_t x, y;
    for (y = 0; y < BH; ++y)
        for (x = 0; x < BW; ++x)
            draw_cell(x, y, 0, BKGF_CGB_PAL0);

    length = 3;
    sx[0] = 8; sy[0] = 6;
    sx[1] = 7; sy[1] = 6;
    sx[2] = 6; sy[2] = 6;
    direction = RIGHT;
    queued = RIGHT;
    has_turn = 0;
    score = 0;
    step_delay = 12;
    ticks = 0;
    draw_hud();
    redraw_snake();
    place_food();
    state = PLAY;
}

static void show_message(uint8_t new_state) {
    state = new_state;
    draw_text(7, 8, new_state == PAUSE ? "PAUSED" : "RUN OVER");
    draw_text(3, 10, new_state == PAUSE ? "B TO CONTINUE" : "A / START RETRY");
    if (new_state == OVER) {
        draw_text(5, 9, "YOUR SCORE");
        draw_number(13, 9, score);
    }
}

static void queue_direction(uint8_t next) {
    if (has_turn || (uint8_t)((next + 2U) & 3U) == direction) return;
    queued = next;
    has_turn = 1;
}

static void input(uint8_t keys, uint8_t pressed) {
    if (keys & J_UP) queue_direction(UP);
    else if (keys & J_RIGHT) queue_direction(RIGHT);
    else if (keys & J_DOWN) queue_direction(DOWN);
    else if (keys & J_LEFT) queue_direction(LEFT);

    if (pressed & J_B) {
        if (state == PLAY) show_message(PAUSE);
        else if (state == PAUSE) {
            state = PLAY;
            ticks = 0;
            draw_frame();
            draw_hud();
            redraw_snake();
            draw_cell(fx, fy, 3, BKGF_CGB_PAL3);
        }
    }
    if (pressed & (J_A | J_START)) {
        if (state == READY || state == OVER) start_game();
        else if (state == PAUSE) {
            state = PLAY;
            ticks = 0;
            draw_frame();
            draw_hud();
            redraw_snake();
            draw_cell(fx, fy, 3, BKGF_CGB_PAL3);
        }
    }
}

static void move_snake(void) {
    int16_t nx, ny;
    uint16_t i, body_count;
    uint8_t ate, tail_x, tail_y;

    direction = queued;
    has_turn = 0;
    nx = (int16_t)sx[0] + dx[direction];
    ny = (int16_t)sy[0] + dy[direction];
    ate = (nx == fx && ny == fy);

    if (nx < 0 || nx >= BW || ny < 0 || ny >= BH) {
        show_message(OVER);
        return;
    }

    body_count = length - (ate ? 0U : 1U);
    for (i = 0; i < body_count; ++i) {
        if (sx[i] == (uint8_t)nx && sy[i] == (uint8_t)ny) {
            show_message(OVER);
            return;
        }
    }

    tail_x = sx[length - 1U];
    tail_y = sy[length - 1U];
    if (!ate)
        draw_cell(tail_x, tail_y, 0, BKGF_CGB_PAL0);

    if (ate && length < MAX_SNAKE) {
        for (i = length; i > 0; --i) {
            sx[i] = sx[i - 1U];
            sy[i] = sy[i - 1U];
        }
        ++length;
        ++score;
        if (score > best_score) best_score = score;
        if ((score % 5U) == 0 && step_delay > 7) --step_delay;
    } else {
        for (i = length - 1U; i > 0; --i) {
            sx[i] = sx[i - 1U];
            sy[i] = sy[i - 1U];
        }
    }

    sx[0] = (uint8_t)nx;
    sy[0] = (uint8_t)ny;
    draw_cell(sx[1], sy[1], 1, BKGF_CGB_PAL1);
    draw_cell(sx[0], sy[0], 2, BKGF_CGB_PAL2);

    if (ate) {
        draw_hud();
        if (length >= MAX_SNAKE) {
            show_message(OVER);
            return;
        }
        place_food();
    }
}

static void init_video(void) {
    DISPLAY_OFF;
    set_bkg_palette(0, 5, palettes);
    set_bkg_data(0, 5, tiles);
    SHOW_BKG;
    DISPLAY_ON;
}

void main(void) {
    uint8_t keys, pressed;
    uint16_t seed = 1;

    init_video();
    state = READY;
    best_score = 0;
    draw_ready();

    for (;;) {
        wait_vbl_done();
        keys = joypad();
        pressed = keys & (uint8_t)~previous_keys;
        previous_keys = keys;

        if (state == READY) {
            seed = (uint16_t)(seed * 109U + keys + 17U);
            srand(seed);
        }
        input(keys, pressed);

        if (state == PLAY && ++ticks >= step_delay) {
            ticks = 0;
            move_snake();
        }
    }
}
