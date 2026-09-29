CC65 ?= cl65
OUT ?= snake.nes
SOURCES := main.c

.PHONY: all clean FORCE
all: $(OUT)

$(OUT): $(SOURCES) FORCE
	$(CC65) -t nes -Oirs -o $@ $(SOURCES)

FORCE:

clean:
	rm -f $(OUT) *.o *.s
