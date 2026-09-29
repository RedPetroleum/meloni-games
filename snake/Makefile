GBDK_HOME ?= gbdk
LCC ?= $(GBDK_HOME)/bin/lcc
OUT ?= snake.gbc
SOURCES := main.c

.PHONY: all clean FORCE
all: $(OUT)

$(OUT): $(SOURCES) FORCE
	$(LCC) -Wm-yc -Wm-yn"SNAKE" -o $@ $(SOURCES)

FORCE:

clean:
	rm -f $(OUT) *.o *.asm *.lst
