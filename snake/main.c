/*
 * Meloni Snake for the HU-086 / Retro-Go.
 *
 * Built as an iNES ROM for Retro-Go's NES emulator.
 * The TGI graphics mode fills nearly the whole NES screen with a two-colour
 * palette: navy playfield and bright green snake, food, and frame.
 */
#include <conio.h>
#include <joystick.h>
#include <nes.h>
#include <stdlib.h>
#include <tgi.h>

#define BOARD_X 4
#define BOARD_Y 7
#define BOARD_W 28
#define BOARD_H 22
#define CELL 2
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
static const unsigned char snake_palette[2] = { COLOR_BLUE, COLOR_LIGHTGREEN };

static void text_at(unsigned char x, unsigned char y, const char *text)
{
    tgi_setcolor(1);
    tgi_outtextxy(x, y, text);
}

static void number_at(unsigned char x, unsigned char y, unsigned int value)
{
    char digits[4];
    digits[0] = (char)('0' + (value / 100U) % 10U);
    digits[1] = (char)('0' + (value / 10U) % 10U);
    digits[2] = (char)('0' + value % 10U);
    digits[3] = 0;
    text_at(x, y, digits);
}

static void draw_score(void)
{
    tgi_setcolor(0);
    tgi_bar(0, 0, 63, 3);
    text_at(2, 1, "SCORE");
    number_at(14, 1, score);
    text_at(34, 1, "BEST");
    number_at(44, 1, best_score);
}

static unsigned char pixel_x(unsigned char x)
{
    return (unsigned char)(BOARD_X + x * CELL);
}

static unsigned char pixel_y(unsigned char y)
{
    return (unsigned char)(BOARD_Y + y * CELL);
}

static void draw_cell(unsigned char x, unsigned char y, unsigned char color)
{
    unsigned char px = pixel_x(x);
    unsigned char py = pixel_y(y);
    tgi_setcolor(color);
    tgi_bar(px, py, (unsigned char)(px + CELL - 1),
            (unsigned char)(py + CELL - 1));
}

static void draw_head(unsigned char x, unsigned char y)
{
    unsigned char px = pixel_x(x);
    unsigned char py = pixel_y(y);
    unsigned char eye_x = px;
    unsigned char eye_y = py;

    tgi_setcolor(1);
    tgi_bar(px, py, (unsigned char)(px + 1), (unsigned char)(py + 1));
    if (direction == DIR_RIGHT) eye_x = (unsigned char)(px + 1);
    else if (direction == DIR_DOWN) eye_y = (unsigned char)(py + 1);
    else if (direction == DIR_LEFT) {
        eye_x = px;
        eye_y = (unsigned char)(py + 1);
    }
    tgi_setcolor(0);
    tgi_setpixel(eye_x, eye_y);
}

static void draw_food(void)
{
    unsigned char px = pixel_x(food_x);
    unsigned char py = pixel_y(food_y);
    tgi_setcolor(1);
    tgi_bar(px, py, (unsigned char)(px + 1), (unsigned char)(py + 1));
    /* A cut-out corner makes the food symbol distinct from a snake segment. */
    tgi_setcolor(0);
    tgi_setpixel((unsigned char)(px + 1), (unsigned char)(py + 1));
}

static void draw_frame(void)
{
    tgi_clear();
    draw_score();

    /* Thick, bright frame around an almost full-screen playfield. */
    tgi_setcolor(1);
    tgi_bar(2, 5, 61, 52);
    tgi_setcolor(0);
    tgi_bar(4, 7, 59, 50);
}

static void draw_all_snake(void)
{
    unsigned int i;
    for (i = snake_length; i > 1; --i)
        draw_cell(snake_x[i - 1U], snake_y[i - 1U], 1);
    draw_head(snake_x[0], snake_y[0]);
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

    draw_food();
}

static void draw_ready_screen(void)
{
    tgi_clear();
    text_at(27, 17, "SNAKE");
    text_at(16, 25, "START OR A TO PLAY");
    text_at(14, 33, "D-PAD TO MOVE");
    text_at(15, 39, "B PAUSES THE GAME");
    text_at(19, 47, "BEST SCORE");
    number_at(41, 47, best_score);
}

static void show_message(unsigned char state)
{
    const char *title;
    game_state = state;
    if (state == STATE_PAUSE) title = "PAUSED";
    else if (state == STATE_WON) title = "YOU WIN!";
    else title = "GAME OVER";

    tgi_setcolor(0);
    tgi_bar(10, 20, 53, 35);
    text_at(22, 23, title);
    if (state == STATE_PAUSE) {
        text_at(15, 29, "B TO CONTINUE");
    } else {
        text_at(18, 29, "SCORE");
        number_at(32, 29, score);
        text_at(12, 33, "START OR A TO RETRY");
    }
}

static void redraw_game(void)
{
    draw_frame();
    draw_all_snake();
    draw_food();
    draw_score();
}

static void start_game(void)
{
    draw_frame();
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
    draw_all_snake();
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
        draw_cell(tail_x, tail_y, 0);
        for (i = snake_length - 1U; i > 0; --i) {
            snake_x[i] = snake_x[i - 1U];
            snake_y[i] = snake_y[i - 1U];
        }
    }

    snake_x[0] = (unsigned char)next_x;
    snake_y[0] = (unsigned char)next_y;
    draw_cell(snake_x[1], snake_y[1], 1);
    draw_head(snake_x[0], snake_y[0]);
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

    joy_install(joy_static_stddrv);
    bgcolor(COLOR_BLUE);
    tgi_install(tgi_static_stddrv);
    tgi_init();
    tgi_setpalette(snake_palette);
    tgi_clear();
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
