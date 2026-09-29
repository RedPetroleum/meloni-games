CC65 ?= cl65
OUT ?= snake.nes
SOURCES := main.c

.PHONY: all clean
all: $(OUT)

$(OUT): $(SOURCES)
	$(CC65) -t nes -Oirs -o $@ $(SOURCES)

clean:
	rm -f $(OUT) *.o *.s
