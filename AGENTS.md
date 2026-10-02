# Meloni Games – Hinweise für KI-Assistenten

Diese Datei richtet sich an KI-Coding-Assistenten (Claude, Codex, Cursor, Copilot …) und
Menschen gleichermaßen.

Spiele für die HU-086 (ESP32-S3-Handheld mit retro-go-Firmware aus
[open-086](https://github.com/RedPetroleum/open-086)). Neue Spiele sind **Lua-Spiele für die
Meloni-Engine**: Die vollständige API steht in [docs/API.md](docs/API.md). Vor dem Schreiben oder
Ändern eines Spiels lesen und nur Funktionen nutzen, die dort stehen.

## Aufbau

- `games/<id>/`: ein Spiel pro Ordner, `main.lua` + `meta.json` (+ `cover.png`, Grafiken, Sounds, Module).
  Ordner ohne `main.lua` (z. B. ein Konzept wie `games/hoofy/`) werden nicht getestet und nicht veröffentlicht.
- `template/`: Vorlage für `make new GAME=<id>`
- `engine/`: die Meloni-Engine (C, plattformunabhängig: `engine/meloni/`) und Lua 5.4 (`engine/lua/`).
  Dieselben Quellen laufen in der Firmware und im Runner.
- `runner/`: die Engine als Desktop-Programm (Fenster mit SDL2 oder headless), wird von `make` gebaut
- `tools/release.py`: packt `.mlg`-Dateien und `manifest.json` für den Updater
- `web/`: Browser-Player (`make web`): Engine als WebAssembly (`web/web.c`), JS-Glue (`web/core.js`),
  Seite (`web/player.html`), `web/build.py` packt alles mit den Spielen aus `dist/` in eine HTML-Datei.
  Spiele brauchen dafür nichts Besonderes; bei Engine-Änderungen `make web` mitlaufen lassen.

## Arbeitsweise

1. Nach jeder Änderung testen, ohne Fenster:
   ```sh
   make test                     # alle Spiele 10 s mit Tastendrücken, Screenshots in build/screens/
   make shot GAME=<id> INPUT="5:START,30-90:RIGHT" FRAMES=120
   make shot GAME=<id> INPUT="5:START,30-90:RIGHT" SHOTS=60,90,120,150
   ```
   Der Runner beendet sich mit Status 1 und gibt den Lua-Traceback aus, wenn das Spiel einen Fehler
   wirft. Die Screenshots (PNG, 320×240) ansehen, um zu prüfen, ob das Bild stimmt.
   `INPUT` ist ein Drehbuch `FRAME[-FRAME]:TASTE[+TASTE],…` (60 Frames = 1 Sekunde, Tasten
   `LEFT RIGHT UP DOWN A B START SELECT`), `FRAMES` die Anzahl Frames bis zum Screenshot.
   `SHOTS` macht in einem Lauf ein Bild nach jedem dieser Frames und legt alle zusammen in
   `build/screens/<id>-shot-sheet.png`: ein Bild ansehen statt vieler.
   Der Zufall (`rnd`) ist fest (`SEED=1`), jeder Lauf mit demselben `INPUT` sieht gleich aus.
   So lässt sich gezielt ein Moment ansteuern und vorher/nachher vergleichen; mit `SEED=2`, `3` …
   andere Abläufe ausprobieren. Zum Prüfen von Spielmechanik lieber so und mit `log(...)` arbeiten
   als raten.
   `make test` drückt START und A und läuft dann herum: Spiele sollten mit START oder A aus dem
   Titelbildschirm ins Spiel kommen, sonst testet `make test` nur den Titel.
   Für Ton: `runner/build/meloni-run --headless --frames 300 --wav out.wav games/<id>`
2. Das Menü der Konsole liegt auf SELECT+START und SELECT+A, diese Kombinationen nicht im Spiel belegen.
3. Das Gerät ist viel langsamer als der PC: keine Lua-Schleifen über alle Pixel pro Frame,
   Bilder und Sounds nur in `_init` laden (siehe „Performance“ in docs/API.md). Wo die Zeit hingeht,
   zeigt `make profile GAME=<id> INPUT=…` (Lua-Befehle pro Frame und Funktion). Auf dem Gerät wird
   `_draw` ausgelassen, wenn es nicht hinterherkommt: Spiellogik und Timer gehören in `_update`.
4. Bei neuen Spielen `meta.json` ausfüllen (`name`, `version`, `api: 1`, `description`) und
   die `version` erhöhen, wenn sich ein Spiel merklich ändert.
5. Die Readme-Tabelle in `README.md` pflegen.
6. **Grafik als Sprites, nicht als Zeichencode.** Figuren und Gegenstände gehören in
   `games/<id>/sprites.txt` (ein Zeichen pro Pixel, Palette oben, Format in `tools/sprites.py`),
   nicht in Dutzende `rectfill`/`line`-Aufrufe. `make test/run/shot` erzeugen daraus `sprites.png`
   und `sprites.lua`; beide mit committen. Im Spiel: `local S = require('sprites')`,
   `S.draw('name', x, y)`. Eine Pose ändern heißt dann: die Textzeilen ändern und mit
   `make shot` ansehen. Vorhandene Grafik (Screenshot, Bild aus einem Malprogramm) übernimmt
   `python3 tools/sprites.py import BILD X Y B H NAME --palette games/<id>/sprites.txt`.
   Hintergründe aus großen Flächen (Himmel, Hügel) dürfen weiter `rectfill`/`circfill` sein.
7. Ein Bild für den Launcher: `make cover GAME=<id> FRAMES=… INPUT=…` schreibt
   `games/<id>/cover.png` (160×120) aus dem Bild nach diesen Frames.

## Engine ändern

Wenn eine Funktion fehlt, die ein Spiel wirklich braucht, gehört sie in die Engine
(`engine/meloni/`), nicht als Workaround ins Spiel. **Vorher mit dem Menschen absprechen:** Eine
Engine-Änderung kommt erst mit neu gebauter und geflashter Firmware auf die Konsole, das Spiel aber
sofort nach dem Push. Dann:

- `docs/API.md` im selben Commit anpassen.
- Jede neue oder geänderte Funktion heißt: API-Version erhöhen (`MEL_API_VERSION` in
  `engine/meloni/meloni.h`) und in jedem Spiel, das sie nutzt, `"api"` in `meta.json` auf die
  neue Nummer setzen. Konsolen mit älterer Firmware überspringen das Spiel dann beim Update,
  statt es mit einem Lua-Fehler zu starten.
- Die Engine muss auf dem Gerät und am Rechner gleich laufen: nur Standard-C, keine Abhängigkeit
  von retro-go oder SDL in `engine/`; Plattformzugriffe laufen über die `mel_plat_*`-Funktionen.
- Auf die Konsole kommt eine Engine-Änderung erst mit einer neuen Firmware: in open-086
  `MELONI_COMMIT` in `build_retro_go.sh` auf den neuen Commit setzen, bauen, flashen
  (bei neuer API-Version auch `MELONI_API_VERSION` in `retro-go/launcher/meloni_update.c`).

## Veröffentlichen

Ein Push auf `main` baut und testet alles und veröffentlicht das Release `latest`
(`.github/workflows/release.yml`). Die Konsole lädt es über den Eintrag „Update games“ im
Meloni-Tab herunter.

**Direkt auf `main` pushen ist in diesem Projekt erwünscht**, ohne Branch, Pull Request oder
Rückfrage: Richtig getestet wird auf der Konsole, und dorthin kommt ein Spiel nur über den Push.
Also: Spiel ändern, `make test` muss durchlaufen, committen, auf `main` pushen.
(Engine-Änderungen weiterhin vorher absprechen, siehe oben.)

**Nach dem Push warten, bis das Release fertig ist, und dann Bescheid sagen.** Erst dann
bringt „Update games“ den neuen Stand, ein früheres Update holt noch die alte Version. Prüfen
ohne `gh` (Repo ist öffentlich):

```sh
# Lauf zum eigenen Commit (head_sha): status "completed", conclusion "success"?
curl -s "https://api.github.com/repos/RedPetroleum/meloni-games/actions/runs?per_page=3"
# Enthält das Release den Commit und die neue Spielversion?
curl -sL "https://github.com/RedPetroleum/meloni-games/releases/download/latest/manifest.json"
```

Ein Lauf dauert etwa eine Minute. Schlägt er fehl, den Fehler melden und beheben. Wenn es fertig
ist, dem Menschen sagen, welche Spielversion jetzt über „Update games“ kommt.
