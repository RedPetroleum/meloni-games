# Meloni games: build, test and pack for the HU-086.
#
#   make run GAME=snake      play in a window (needs SDL2: brew install sdl2), reloads on save
#   make test                every game 10 s headless with button presses, screenshots in build/screens/
#   make shot GAME=snake INPUT="5:START,60-90:RIGHT" FRAMES=120   one screenshot, prints the path
#   make new GAME=name       new game from template/
#   make dist                dist/ with .mlg files and manifest.json (what the CI publishes)
#
# The engine (and the runner) live in open-086: OPEN086 points to a checkout of it.
OPEN086 ?= ../open-086
RUNNER_DIR := $(OPEN086)/retro-go/meloni/runner
RUNNER := $(RUNNER_DIR)/build/meloni-run
GAMES := $(patsubst games/%/main.lua,%,$(wildcard games/*/main.lua))
FRAMES ?= 600
# Press START and A, then walk around: enough to get past title screens and into the game
INPUT ?= 5:START,20:A,40-80:RIGHT,90-130:DOWN,140-180:LEFT,190-230:UP,240:A,300:START,320-360:RIGHT
EXTRA ?=

.PHONY: runner run test shot new dist clean

runner:
	@test -d $(RUNNER_DIR) || { echo "open-086 not found at $(OPEN086) (make OPEN086=/path/to/open-086)"; exit 1; }
	@$(MAKE) --no-print-directory -C $(RUNNER_DIR)

run: runner
	@test -n "$(GAME)" || { echo "usage: make run GAME=<name> (games: $(GAMES))"; exit 1; }
	$(RUNNER) --save build/$(GAME).sav games/$(GAME)

test: runner
	@mkdir -p build/screens
	@fail=0; for g in $(GAMES); do \
		$(RUNNER) --headless --frames $(FRAMES) --input "$(INPUT)" --screenshot build/screens/$$g.png games/$$g || fail=1; \
	done; exit $$fail

shot: runner
	@test -n "$(GAME)" || { echo "usage: make shot GAME=<name> [INPUT=...] [FRAMES=...]"; exit 1; }
	@mkdir -p build/screens
	$(RUNNER) --headless --frames $(FRAMES) --input "$(INPUT)" --screenshot build/screens/$(GAME)-shot.png games/$(GAME)
	@echo build/screens/$(GAME)-shot.png

new:
	@test -n "$(GAME)" || { echo "usage: make new GAME=<name> (lowercase, no spaces)"; exit 1; }
	@echo "$(GAME)" | grep -Eq '^[a-z0-9_-]+$$' || { echo "name: lowercase letters, digits, - and _ only"; exit 1; }
	@test ! -e games/$(GAME) || { echo "games/$(GAME) exists"; exit 1; }
	cp -R template games/$(GAME)
	sed -i.bak 's/__ID__/$(GAME)/g' games/$(GAME)/meta.json && rm games/$(GAME)/meta.json.bak
	@echo "games/$(GAME) created: make run GAME=$(GAME)"

dist:
	python3 tools/release.py $(foreach e,$(EXTRA),--extra $(e))

clean:
	rm -rf build dist
