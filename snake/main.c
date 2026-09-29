/*
 * Meloni Snake for the HU-086 / Retro-Go.
 *
 * Uses the NES text screen for a clean, native 8-bit look. The field spans
 * almost the full screen; the boxed frame is the wall, and '*' is the food.
 */
#include <conio.h>
#include <joystick.h>
#include <nes.h>
#include <stdlib.h>

#define BOARD_X 2
#define BOARD_Y 5
#define BOARD_W 28
#define BOARD_H 20
#define MAX_SNAKE (BOARD_W * BOARD_H)

#define DIR_UP    0
#define DIR_RIGHT 1
#define DIR_DOWN  2
#define DIR_LEFT  3

#define STATE_READY  0
#define STATE_PLAY   1
#define STATE_PAUSE  2
#define STATE_OVER   3
#define STATE_WON    4

static unsigned char snake_x[MAX_SNAKE];
static unsigned char snake_y[MAX_SNAKE];
static unsigned int snake_length;
static unsigned char food_x, food_y;
static unsigned char direction, queued_direction, has_queued_turn;
static unsigned char game_state, frame_count, frames_per_step;
static unsigned char previous_pad;
static unsigned int score, best_score;

static const signed char dx[4] = { 0, 1, 0, -1 };
static const signed char dy[4] = { -1, 0, 1, 0 };

static void put_at(unsigned char x, unsigned char y, const char *text)
{
    cputsxy(x, y, text);
}

static void write_number(unsigned char x, unsigned char y, unsigned int value)
{
    cputcxy(x, y, (char)('0' + (value / 100U) % 10U));
    cputcxy((unsigned char)(x + 1), y, (char)('0' + (value / 10U) % 10U));
    cputcxy((unsigned char)(x + 2), y, (char)('0' + value % 10U));
}

static void draw_score(void)
{
    put_at(3, 2, "SCORE");
    write_number(9, 2, score);
    put_at(20, 2, "BEST");
    write_number(25, 2, best_score);
}

static char head_glyph(void)
{
    if (direction == DIR_UP) return '^';
    if (direction == DIR_RIGHT) return '>';
    if (direction == DIR_DOWN) return 'v';
    return '<';
}

static void draw_cell(unsigned char x, unsigned char y, char tile)
{
    cputcxy((unsigned char)(BOARD_X + x),
            (unsigned char)(BOARD_Y + y), tile);
}

static void draw_board(void)
{
    unsigned char i, y;

    bgcolor(COLOR_BLACK);
    textcolor(COLOR_ORANGE);
    clrscr();

    put_at(10, 1, "MELONI SNAKE");
    draw_score();

    cputcxy(1, 4, CH_ULCORNER);
    chlinexy(2, 4, BOARD_W);
    cputcxy(30, 4, CH_URCORNER);
    for (y = 0; y < BOARD_H; ++y) {
        cputcxy(1, (unsigned char)(BOARD_Y + y), CH_VLINE);
        cputcxy(30, (unsigned char)(BOARD_Y + y), CH_VLINE);
        for (i = 0; i < BOARD_W; ++i)
            cputcxy((unsigned char)(BOARD_X + i),
                    (unsigned char)(BOARD_Y + y), ' ');
    }
    cputcxy(1, 25, CH_LLCORNER);
    chlinexy(2, 25, BOARD_W);
    cputcxy(30, 25, CH_LRCORNER);

    put_at(3, 27, "* FOOD   |   FRAME = WALL");
    put_at(5, 28, "D-PAD: MOVE    B: PAUSE");
}

static void place_food(void)
{
    unsigned int i;
    unsigned char occupied;

    do {
        food_x = (unsigned char)(rand() % BOARD_W);
        food_y = (unsigned char)(rand() % BOARD_H);
        occupied = 0;
        for (i = 0; i < snake_length; ++i) {
            if (snake_x[i] == food_x && snake_y[i] == food_y) {
                occupied = 1;
                break;
            }
        }
    } while (occupied);

    draw_cell(food_x, food_y, '*');
}

static void draw_ready_screen(void)
{
    clrscr();
    put_at(10, 8, "MELONI SNAKE");
    put_at(7, 12, "EAT *   AVOID THE FRAME");
    put_at(8, 16, "D-PAD TO MOVE");
    put_at(6, 20, "START OR A TO PLAY");
    put_at(8, 24, "BEST SCORE");
    write_number(20, 24, best_score);
}

static void draw_overlay_lines(void)
{
    unsigned char x, y;
    for (y = 14; y <= 18; ++y)
        for (x = 5; x <= 26; ++x)
            cputcxy(x, y, ' ');
}

static void show_message(unsigned char state)
{
    game_state = state;
    draw_overlay_lines();

    if (state == STATE_PAUSE) {
        put_at(13, 15, "PAUSED");
        put_at(9, 17, "PRESS B TO RESUME");
    } else {
        put_at(12, 14, state == STATE_WON ? "YOU WIN!" : "GAME OVER");
        put_at(10, 16, "SCORE");
        write_number(16, 16, score);
        put_at(6, 18, "START OR A TO RETRY");
    }
}

static void redraw_game(void)
{
    unsigned int i;
    draw_board();
    draw_score();
    for (i = 1; i < snake_length; ++i)
        draw_cell(snake_x[i], snake_y[i], 'o');
    draw_cell(snake_x[0], snake_y[0], head_glyph());
    draw_cell(food_x, food_y, '*');
}

static void start_game(void)
{
    draw_board();
    snake_length = 3;
    snake_x[0] = 13; snake_y[0] = 10;
    snake_x[1] = 12; snake_y[1] = 10;
    snake_x[2] = 11; snake_y[2] = 10;
    direction = DIR_RIGHT;
    queued_direction = DIR_RIGHT;
    has_queued_turn = 0;
    score = 0;
    frames_per_step = 16;
    frame_count = 0;
    draw_score();
    draw_cell(snake_x[2], snake_y[2], 'o');
    draw_cell(snake_x[1], snake_y[1], 'o');
    draw_cell(snake_x[0], snake_y[0], head_glyph());
    place_food();
    game_state = STATE_PLAY;
}

static void queue_direction(unsigned char next)
{
    if (has_queued_turn) return;
    if ((unsigned char)((next + 2U) & 3U) == direction) return;
    queued_direction = next;
    has_queued_turn = 1;
}

static void resume_game(void)
{
    game_state = STATE_PLAY;
    frame_count = 0;
    redraw_game();
}

static void handle_input(unsigned char pad, unsigned char pressed)
{
    if (pad & JOY_UP_MASK) queue_direction(DIR_UP);
    else if (pad & JOY_RIGHT_MASK) queue_direction(DIR_RIGHT);
    else if (pad & JOY_DOWN_MASK) queue_direction(DIR_DOWN);
    else if (pad & JOY_LEFT_MASK) queue_direction(DIR_LEFT);

    if (pressed & JOY_BTN_B_MASK) {
        if (game_state == STATE_PLAY) show_message(STATE_PAUSE);
        else if (game_state == STATE_PAUSE) resume_game();
    }

    if (pressed & (JOY_START_MASK | JOY_BTN_A_MASK)) {
        if (game_state == STATE_READY || game_state == STATE_OVER || game_state == STATE_WON)
            start_game();
        else if (game_state == STATE_PAUSE)
            resume_game();
    }
}

static void move_snake(void)
{
    signed int next_x, next_y;
    unsigned int i, body_count;
    unsigned char ate, tail_x, tail_y;

    direction = queued_direction;
    has_queued_turn = 0;
    next_x = (signed int)snake_x[0] + dx[direction];
    next_y = (signed int)snake_y[0] + dy[direction];
    ate = (next_x == food_x && next_y == food_y);

    if (next_x < 0 || next_x >= BOARD_W || next_y < 0 || next_y >= BOARD_H) {
        show_message(STATE_OVER);
        return;
    }

    body_count = snake_length - (ate ? 0U : 1U);
    for (i = 0; i < body_count; ++i) {
        if (snake_x[i] == (unsigned char)next_x && snake_y[i] == (unsigned char)next_y) {
            show_message(STATE_OVER);
            return;
        }
    }

    tail_x = snake_x[snake_length - 1U];
    tail_y = snake_y[snake_length - 1U];

    if (ate) {
        if (snake_length >= MAX_SNAKE) {
            show_message(STATE_WON);
            return;
        }
        for (i = snake_length; i > 0; --i) {
            snake_x[i] = snake_x[i - 1U];
            snake_y[i] = snake_y[i - 1U];
        }
        ++snake_length;
        ++score;
        if (score > best_score) best_score = score;
        if ((score % 5U) == 0 && frames_per_step > 8) --frames_per_step;
    } else {
        draw_cell(tail_x, tail_y, ' ');
        for (i = snake_length - 1U; i > 0; --i) {
            snake_x[i] = snake_x[i - 1U];
            snake_y[i] = snake_y[i - 1U];
        }
    }

    snake_x[0] = (unsigned char)next_x;
    snake_y[0] = (unsigned char)next_y;
    draw_cell(snake_x[1], snake_y[1], 'o');
    draw_cell(snake_x[0], snake_y[0], head_glyph());

    if (ate) {
        draw_score();
        if (snake_length >= MAX_SNAKE) {
            show_message(STATE_WON);
            return;
        }
        place_food();
    }
}

int main(void)
{
    unsigned char pad, pressed;
    unsigned int seed = 1;

    bgcolor(COLOR_BLACK);
    textcolor(COLOR_ORANGE);
    bordercolor(COLOR_BLACK);
    clrscr();
    joy_install(joy_static_stddrv);
    game_state = STATE_READY;
    best_score = 0;
    draw_ready_screen();

    for (;;) {
        waitvsync();
        pad = joy_read(JOY_1);
        pressed = (unsigned char)(pad & (unsigned char)~previous_pad);
        previous_pad = pad;

        if (game_state == STATE_READY) {
            seed = (unsigned int)(seed * 109U + pad + 17U);
            srand(seed);
        }

        handle_input(pad, pressed);
        if (game_state == STATE_PLAY) {
            if (++frame_count >= frames_per_step) {
                frame_count = 0;
                move_snake();
            }
        }
    }
}