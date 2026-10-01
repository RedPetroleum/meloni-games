# Desktop runner for Meloni games: the engine from ../engine, built for macOS/Linux.
#   make            -> build/meloni-run (with a window when SDL2 is installed, else headless only)
#   make SDL=0      -> headless only
MELONI := ../engine/meloni
LUA    := ../engine/lua/src
BUILD  := build

# sdl2-config from PATH, else a self-built SDL2 in ~/.local (./configure --prefix=$HOME/.local)
SDL2_CONFIG ?= $(shell command -v sdl2-config 2>/dev/null || ls $(HOME)/.local/bin/sdl2-config 2>/dev/null)
SDL ?= $(if $(SDL2_CONFIG),1,0)

CFLAGS  ?= -O2 -g
CFLAGS  += -std=gnu11 -Wall -Wno-unused-function -I$(MELONI) -I$(LUA) -Ilodepng
LDLIBS  += -lm

ifeq ($(SDL),1)
CFLAGS  += -DMEL_SDL $(shell $(SDL2_CONFIG) --cflags)
LDLIBS  += $(shell $(SDL2_CONFIG) --libs)
endif

SRCS := runner.c lodepng/lodepng.c $(wildcard $(MELONI)/*.c) $(wildcard $(LUA)/*.c)
OBJS := $(patsubst %.c,$(BUILD)/%.o,$(subst ../,,$(SRCS)))

$(BUILD)/meloni-run: $(OBJS)
	$(CC) -o $@ $^ $(LDLIBS)

$(BUILD)/%.o: %.c $(MELONI)/meloni.h
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -c -o $@ $<

$(BUILD)/engine/%.o: ../engine/%.c $(MELONI)/meloni.h
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -c -o $@ $<

clean:
	rm -rf $(BUILD)

.PHONY: clean
