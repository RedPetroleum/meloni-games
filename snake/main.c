/*
 * Meloni Snake for the HU-086 / Retro-Go.
 *
 * Build with cc65's NES target. The resulting iNES ROM runs in Retro-Go's
 * NES emulator and can be copied to roms/nes/ on the FAT32 SD card.
 */
#include <conio.h>
#include <joystick.h>
#include <nes.h>
#include <stdlib.h>

#define BOARD_X 5
#define BOARD_Y 8
#define BOARD_W 22
#define BOARD_H 16
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
static unsigned char game_state;
static unsigned int score, best_score;
static unsigned char frame_count, frames_per_step;
static unsigned char previous_pad;

static const signed char dx[4] = { 0, 1, 0, -1 };
static const signed char dy[4] = { -1, 0, 1, 0 };

static void put_at(unsigned char x, unsigned char y, const char *text)
{
    gotoxy(x, y);
    cputs(text);
}

static void write_number(unsigned char x, unsigned char y, unsigned int value)
{
    cputcxy(x, y, (char)('0' + (value / 100U) % 10U));
    cputcxy((unsigned char)(x + 1), y, (char)('0' + (value / 10U) % 10U));
    cputcxy((unsigned char)(x + 2), y, (char)('0' + value % 10U));
}

static void draw_score(void)
{
    put_at(5, 5, "SCORE");
    write_number(11, 5, score);
    put_at(16, 5, "BEST");
    write_number(21, 5, best_score);
}

static void draw_cell(unsigned char x, unsigned char y, char tile)
{
    cputcxy((unsigned char)(BOARD_X + x), (unsigned char)(BOARD_Y + y), tile);
}

static void draw_board(void)
{
    unsigned char i, y;

    clrscr();
    put_at(10, 2, "MELONI SNAKE");
    draw_score();

    cputcxy(4, 7, '+');
    for (i = 0; i < BOARD_W; ++i) cputc('-');
    cputc('+');

    for (y = 0; y < BOARD_H; ++y) {
        cputcxy(4, (unsigned char)(BOARD_Y + y), '|');
        for (i = 0; i < BOARD_W; ++i)
            cputcxy((unsigned char)(BOARD_X + i), (unsigned char)(BOARD_Y + y), ' ');
        cputcxy(27, (unsigned char)(BOARD_Y + y), '|');
    }

    cputcxy(4, 24, '+');
    for (i = 0; i < BOARD_W; ++i) cputc('-');
    cputc('+');
    put_at(5, 26, "D-PAD MOVE  B PAUSE");
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
    put_at(10, 7, "MELONI SNAKE");
    put_at(7, 11, "EAT FOOD. AVOID YOUR TAIL.");
    put_at(9, 15, "D-PAD TO MOVE");
    put_at(8, 18, "START OR A TO PLAY");
    put_at(8, 22, "BEST SCORE");
    write_number(19, 22, best_score);
}

static void show_end_screen(unsigned char won)
{
    game_state = won ? STATE_WON : STATE_OVER;
    put_at(12, 14, won ? "YOU WIN!" : "GAME OVER");
    put_at(8, 16, "SCORE");
    write_number(14, 16, score);
    put_at(8, 19, "START OR A TO RETRY");
}

static void start_game(void)
{
    draw_board();
    snake_length = 3;
    snake_x[0] = 11; snake_y[0] = 8;
    snake_x[1] = 10; snake_y[1] = 8;
    snake_x[2] = 9;  snake_y[2] = 8;
    direction = DIR_RIGHT;
    queued_direction = DIR_RIGHT;
    has_queued_turn = 0;
    score = 0;
    frames_per_step = 8;
    frame_count = 0;
    draw_score();
    draw_cell(snake_x[2], snake_y[2], 'o');
    draw_cell(snake_x[1], snake_y[1], 'o');
    draw_cell(snake_x[0], snake_y[0], '@');
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

static void handle_input(unsigned char pad, unsigned char pressed)
{
    if (pad & JOY_UP_MASK) queue_direction(DIR_UP);
    else if (pad & JOY_RIGHT_MASK) queue_direction(DIR_RIGHT);
    else if (pad & JOY_DOWN_MASK) queue_direction(DIR_DOWN);
    else if (pad & JOY_LEFT_MASK) queue_direction(DIR_LEFT);

    if (pressed & JOY_BTN_B_MASK) {
        if (game_state == STATE_PLAY) {
            game_state = STATE_PAUSE;
            put_at(12, 14, "PAUSED");
            put_at(8, 16, "PRESS B TO CONTINUE");
        } else if (game_state == STATE_PAUSE) {
            game_state = STATE_PLAY;
            draw_board();
            /* Restore the moving pieces after repainting the board. */
            {
                unsigned int i;
                for (i = 1; i < snake_length; ++i)
                    draw_cell(snake_x[i], snake_y[i], 'o');
                draw_cell(snake_x[0], snake_y[0], '@');
                draw_cell(food_x, food_y, '*');
                draw_score();
            }
        }
    }

    if (pressed & (JOY_START_MASK | JOY_BTN_A_MASK)) {
        if (game_state == STATE_READY || game_state == STATE_OVER || game_state == STATE_WON)
            start_game();
        else if (game_state == STATE_PAUSE) {
            game_state = STATE_PLAY;
            draw_board();
            {
                unsigned int i;
                for (i = 1; i < snake_length; ++i)
                    draw_cell(snake_x[i], snake_y[i], 'o');
                draw_cell(snake_x[0], snake_y[0], '@');
                draw_cell(food_x, food_y, '*');
                draw_score();
            }
        }
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
        show_end_screen(0);
        return;
    }

    body_count = snake_length - (ate ? 0U : 1U);
    for (i = 0; i < body_count; ++i) {
        if (snake_x[i] == (unsigned char)next_x && snake_y[i] == (unsigned char)next_y) {
            show_end_screen(0);
            return;
        }
    }

    tail_x = snake_x[snake_length - 1U];
    tail_y = snake_y[snake_length - 1U];

    if (ate) {
        if (snake_length >= MAX_SNAKE) {
            show_end_screen(1);
            return;
        }
        for (i = snake_length; i > 0; --i) {
            snake_x[i] = snake_x[i - 1U];
            snake_y[i] = snake_y[i - 1U];
        }
        ++snake_length;
        ++score;
        if (score > best_score) best_score = score;
        if ((score % 4U) == 0 && frames_per_step > 3) --frames_per_step;
        place_food();
        draw_score();
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
    draw_cell(snake_x[0], snake_y[0], '@');
}

int main(void)
{
    unsigned char pad, pressed;
    unsigned int seed = 1;

    bgcolor(COLOR_BLACK);
    textcolor(COLOR_WHITE);
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
