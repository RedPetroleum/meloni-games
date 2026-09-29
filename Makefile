# Meloni games: build, test and pack for the HU-086.
#
#   make run GAME=snake      play in a window (needs SDL2: brew install sdl2), reloads on save
#   make test                every game 10 s headless with button presses, screenshots in build/screens/
#   make shot GAME=snake INPUT="5:START,60-90:RIGHT" FRAMES=120   one screenshot, prints the path
#   make shot GAME=snake INPUT=... SHOTS=60,120,180                 one screenshot after each of these frames
#   make cover GAME=snake INPUT=... FRAMES=120                      games/snake/cover.png for the launcher
#   make sprites             games/*/sprites.txt -> sprites.png + sprites.lua (test, run, shot, dist do it too)
#   make new GAME=name       new game from template/
#   make dist                dist/ with .mlg files and manifest.json (what the CI publishes)
RUNNER_DIR := runner
RUNNER := $(RUNNER_DIR)/build/meloni-run
GAMES := $(patsubst games/%/main.lua,%,$(wildcard games/*/main.lua))
FRAMES ?= 600
# Press START and A, then walk around: enough to get past title screens and into the game
INPUT ?= 5:START,20:A,40-80:RIGHT,90-130:DOWN,140-180:LEFT,190-230:UP,240:A,300:START,320-360:RIGHT
# Same random numbers on every run, so screenshots can be compared (SEED=0: random)
SEED ?= 1
SHOTS ?=
EXTRA ?=

.PHONY: runner sprites run test shot cover new dist clean

runner:
	@$(MAKE) --no-print-directory -C $(RUNNER_DIR)

sprites:
	@python3 tools/sprites.py games/*/

run: runner sprites
	@test -n "$(GAME)" || { echo "usage: make run GAME=<name> (games: $(GAMES))"; exit 1; }
	$(RUNNER) --save build/$(GAME).sav games/$(GAME)

test: runner sprites
	@mkdir -p build/screens
	@fail=0; for g in $(GAMES); do \
		$(RUNNER) --headless --seed $(SEED) --frames $(FRAMES) --input "$(INPUT)" --screenshot build/screens/$$g.png games/$$g || fail=1; \
	done; exit $$fail

shot: runner sprites
	@test -n "$(GAME)" || { echo "usage: make shot GAME=<name> [INPUT=...] [FRAMES=...] [SHOTS=...] [SEED=...]"; exit 1; }
	@mkdir -p build/screens
	@$(RUNNER) --headless --seed $(SEED) $(if $(SHOTS),--shots $(SHOTS),--frames $(FRAMES)) --input "$(INPUT)" \
		--screenshot build/screens/$(GAME)-shot.png games/$(GAME)
	@$(if $(SHOTS),true,echo build/screens/$(GAME)-shot.png)

cover: runner sprites
	@test -n "$(GAME)" || { echo "usage: make cover GAME=<name> [INPUT=...] [FRAMES=...]"; exit 1; }
	@$(RUNNER) --headless --seed $(SEED) --frames $(FRAMES) --input "$(INPUT)" --cover games/$(GAME)/cover.png games/$(GAME)

new:
	@test -n "$(GAME)" || { echo "usage: make new GAME=<name> (lowercase, no spaces)"; exit 1; }
	@echo "$(GAME)" | grep -Eq '^[a-z0-9_-]+$$' || { echo "name: lowercase letters, digits, - and _ only"; exit 1; }
	@test ! -e games/$(GAME) || { echo "games/$(GAME) exists"; exit 1; }
	cp -R template games/$(GAME)
	sed -i.bak 's/__ID__/$(GAME)/g' games/$(GAME)/meta.json && rm games/$(GAME)/meta.json.bak
	@echo "games/$(GAME) created: make run GAME=$(GAME)"

dist: sprites
	python3 tools/release.py $(foreach e,$(EXTRA),--extra $(e))

clean:
	rm -rf build dist $(RUNNER_DIR)/build
