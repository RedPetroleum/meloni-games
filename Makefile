# Meloni games: build, test and pack for the HU-086.
#
#   make run GAME=snake      play in a window (needs SDL2: brew install sdl2), reloads on save
#   make test                every game 10 s headless with button presses, screenshots in build/screens/,
#                            then the Hoofy self-tests (tools/hoofy-test.sh selftest)
#   make shot GAME=snake INPUT="5:START,60-90:RIGHT" FRAMES=120   one screenshot, prints the path
#   make shot GAME=snake INPUT=... SHOTS=60,120,180                 one screenshot after each of these frames
#   make cover GAME=snake INPUT=... FRAMES=120                      games/snake/cover.png for the launcher
#   make sprites             games/*/sprites.txt -> sprites.png + sprites.lua (test, run, shot, dist do it too)
#   make run GAME=hoofy SCENARIO=reise   Hoofy direkt in einem Szenario aus game/scenarios.lua starten
#   make katalog             games/hoofy/KATALOG.md -> games/hoofy/data/*.lua (test, run, shot, dist do it too)
#   make pferde              Hoofy: Pferdekörper und Fellmuster in games/hoofy/sprites.txt (vor sprites)
#   make new GAME=name       new game from template/
#   make dist                dist/ with .mlg files and manifest.json (what the CI publishes)
#   make web                 build/web/meloni-konsole.html: all games playable in the browser (engine as WebAssembly)
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

.PHONY: runner pferde sprites katalog run test shot cover new dist web clean

runner:
	@$(MAKE) --no-print-directory -C $(RUNNER_DIR)

pferde:
	@python3 tools/hoofy_pferde.py

sprites: pferde
	@python3 tools/sprites.py games/*/

katalog:
	@python3 tools/hoofy_katalog.py

run: runner sprites katalog
	@test -n "$(GAME)" || { echo "usage: make run GAME=<name> (games: $(GAMES))"; exit 1; }
	@if [ -n "$(SCENARIO)" ]; then \
	  echo 'return {scenario = "$(SCENARIO)"}' > build/$(GAME)-$(SCENARIO).sav; \
	  $(RUNNER) --save build/$(GAME)-$(SCENARIO).sav games/$(GAME); \
	else $(RUNNER) --save build/$(GAME).sav games/$(GAME); fi

test: runner sprites katalog
	@mkdir -p build/screens
	@fail=0; for g in $(GAMES); do \
		$(RUNNER) --headless --seed $(SEED) --frames $(FRAMES) --input "$(INPUT)" --screenshot build/screens/$$g.png games/$$g || fail=1; \
	done; \
	tools/hoofy-test.sh selftest || fail=1; \
	exit $$fail

shot: runner sprites katalog
	@test -n "$(GAME)" || { echo "usage: make shot GAME=<name> [INPUT=...] [FRAMES=...] [SHOTS=...] [SEED=...]"; exit 1; }
	@mkdir -p build/screens
	@$(RUNNER) --headless --seed $(SEED) $(if $(SHOTS),--shots $(SHOTS),--frames $(FRAMES)) --input "$(INPUT)" \
		--screenshot build/screens/$(GAME)-shot.png games/$(GAME)
	@$(if $(SHOTS),true,echo build/screens/$(GAME)-shot.png)

cover: runner sprites katalog
	@test -n "$(GAME)" || { echo "usage: make cover GAME=<name> [INPUT=...] [FRAMES=...]"; exit 1; }
	@$(RUNNER) --headless --seed $(SEED) --frames $(FRAMES) --input "$(INPUT)" --cover games/$(GAME)/cover.png games/$(GAME)

new:
	@test -n "$(GAME)" || { echo "usage: make new GAME=<name> (lowercase, no spaces)"; exit 1; }
	@echo "$(GAME)" | grep -Eq '^[a-z0-9_-]+$$' || { echo "name: lowercase letters, digits, - and _ only"; exit 1; }
	@test ! -e games/$(GAME) || { echo "games/$(GAME) exists"; exit 1; }
	cp -R template games/$(GAME)
	sed -i.bak 's/__ID__/$(GAME)/g' games/$(GAME)/meta.json && rm games/$(GAME)/meta.json.bak
	@echo "games/$(GAME) created: make run GAME=$(GAME)"

dist: sprites katalog
	python3 tools/release.py $(foreach e,$(EXTRA),--extra $(e))

# Browser player: the same engine compiled to WebAssembly (clang with wasm32 target + wasm-ld,
# e.g. Linux: apt install clang lld, macOS: brew install llvm lld). The WASI sysroot is downloaded once.
WASI_VERSION := 24
WASI_DIR := build/wasi
WASI_SYSROOT := $(WASI_DIR)/wasi-sysroot-$(WASI_VERSION).0
WASI_RT := $(WASI_DIR)/libclang_rt.builtins-wasm32-wasi-$(WASI_VERSION).0/libclang_rt.builtins-wasm32.a
WASI_URL := https://github.com/WebAssembly/wasi-sdk/releases/download/wasi-sdk-$(WASI_VERSION)
WASM_CC ?= clang
WASM_SRCS := web/web.c runner/lodepng/lodepng.c $(wildcard engine/meloni/*.c) \
	$(filter-out %/lua.c %/luac.c %/loslib.c %/liolib.c %/linit.c,$(wildcard engine/lua/src/*.c))

$(WASI_SYSROOT) $(WASI_RT):
	@mkdir -p $(WASI_DIR)
	curl -fsSL $(WASI_URL)/wasi-sysroot-$(WASI_VERSION).0.tar.gz | tar xz -C $(WASI_DIR)
	curl -fsSL $(WASI_URL)/libclang_rt.builtins-wasm32-wasi-$(WASI_VERSION).0.tar.gz | tar xz -C $(WASI_DIR)

build/web/meloni.wasm: $(WASM_SRCS) engine/meloni/meloni.h | $(WASI_SYSROOT) $(WASI_RT)
	@mkdir -p build/web
	$(WASM_CC) --target=wasm32-wasi --sysroot=$(WASI_SYSROOT) -O2 -std=gnu11 \
		-Iengine/meloni -Iengine/lua/src -Irunner/lodepng \
		-mllvm -wasm-enable-sjlj -mexec-model=reactor -D_WASI_EMULATED_SIGNAL -D_WASI_EMULATED_PROCESS_CLOCKS \
		-nodefaultlibs -Wl,-z,stack-size=1048576 -o $@ $(WASM_SRCS) \
		-lc -lsetjmp -lwasi-emulated-signal -lwasi-emulated-process-clocks $(WASI_RT)

web: build/web/meloni.wasm dist
	python3 web/build.py build/web/meloni.wasm dist build/web/meloni-konsole.html

clean:
	rm -rf build dist $(RUNNER_DIR)/build
