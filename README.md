# Meloni Games

Eigene Spiele für den Handheld **HXFB HU-086**. Die Spiele sind in Lua geschrieben, werden am
Rechner entwickelt und getestet und landen per WLAN direkt auf der Konsole.

## Wie das zusammenhängt

```
 meloni-games (dieses Repo)           GitHub                         HU-086
 ─────────────────────────            ──────                         ──────
 games/<id>/main.lua  ──push main──▶  Actions: testen, packen   ──▶  Launcher, Tab "Meloni Games"
                                      Release "latest"               → [ Update games ]
                                      (<id>.mlg + manifest.json)     lädt neue/geänderte Spiele
                                                                     per WLAN nach roms/meloni/
```

- **Die Konsole** läuft mit der Firmware [open-086](https://github.com/RedPetroleum/open-086)
  (basiert auf [retro-go](https://github.com/ducalex/retro-go)). Darin steckt die
  **Meloni-Engine**: ein eigenes System „Meloni Games“ im Launcher, das Lua-Spiele ausführt.
- **Dieses Repo** enthält die Spiele (ein Ordner pro Spiel unter `games/`), die Engine selbst
  ([engine/](engine/), C und Lua 5.4), einen Runner, der sie am Rechner ausführt ([runner/](runner/)),
  und die API-Doku ([docs/API.md](docs/API.md)). Die Firmware übernimmt die Engine von hier.
- **GitHub Actions** ([release.yml](.github/workflows/release.yml)) testet bei jedem Push alle
  Spiele. Auf `main` packt es jedes Spiel zu einer Datei `<id>.mlg` und veröffentlicht sie
  zusammen mit einer `manifest.json` (Pfad, Größe und sha256 jeder Datei) als Release `latest`.
- **„[ Update games ]“** oben im Meloni-Tab der Konsole liest dieses Manifest, lädt, was neu ist
  oder sich geändert hat, und löscht Spiele, die aus dem Release entfernt wurden.
  Spielstände bleiben erhalten.

## Spiele

| Spiel | Details |
|---|---|
| [Snake](games/snake/main.lua) | Fressen, wachsen, nicht in die Wand fahren. Der Highscore wird gespeichert |
| [Hoofy](hoofy/README_HOOFY.md) | Pferde-Spiel, bisher nur Konzept |

## Ein Spiel entwickeln

Nötig sind ein C-Compiler, Python 3 und für das Spielfenster SDL2 (`brew install sdl2`, ohne SDL2
läuft der Runner nur headless). Der Runner wird beim ersten `make` automatisch gebaut.

```sh
make new GAME=pferde      # neues Spiel aus template/ anlegen
make run GAME=pferde      # im Fenster spielen, lädt bei jeder gespeicherten Änderung neu
make test                 # alle Spiele 10 s headless mit Tastendrücken, Screenshots in build/screens/
make shot GAME=pferde INPUT="5:START,30-90:RIGHT" FRAMES=120   # ein Screenshot nach Drehbuch
make dist                 # dist/ bauen wie im Release: .mlg-Dateien + manifest.json
```

Tasten im Fenster: Pfeile/WASD, A = X/K/Leertaste, B = Z/Y/J, START = Enter, SELECT = Backspace,
F5 neu laden, F12 Screenshot, Esc beenden.

Ein Spielordner:

```
games/<id>/
  main.lua            Pflicht: _init(), _update(), _draw()
  meta.json           Pflicht: {"id", "name", "version", "api": 1, "description"}
  cover.png           optional: Vorschaubild im Launcher (etwa 160×120)
  *.lua *.png *.wav   Module, Grafiken, Sounds
```

Veröffentlichen heißt: auf `main` pushen. Sobald der Workflow grün ist, kann die Konsole das
Spiel laden.

**Mit Claude vibe-coden:** [CLAUDE.md](CLAUDE.md) beschreibt, wie Spiele geschrieben und ohne
Gerät geprüft werden (headless, mit Screenshots und Tonaufnahme).

## Die Konsole einrichten

Einmalig:

1. Firmware aus open-086 bauen und flashen (`./build_retro_go.sh`, `./flash_firmware.sh`, Details
   in dessen README).
2. WLAN auf der SD-Karte eintragen, Datei `/retro-go/config/wifi.json`:
   ```json
   {"ssid0": "mein-netz", "password0": "mein-passwort"}
   ```

Danach im Launcher zum Tab **Meloni Games** gehen und **[ Update games ]** wählen. Die Konsole
verbindet sich, zeigt, wie viel sich geändert hat, und lädt nach Bestätigung herunter.

- Das Release muss öffentlich abrufbar sein, sonst meldet die Konsole HTTP 404.
- Eine andere Quelle (z. B. ein Fork) lässt sich in `/retro-go/config/meloni.json` eintragen:
  `{"manifest_url": "https://github.com/<user>/<repo>/releases/download/latest/manifest.json"}`.
- Ohne WLAN: `make dist` ausführen und `dist/<id>.mlg` von Hand nach `roms/meloni/` kopieren.
- Im Spiel öffnet SELECT+START das Menü (Weiter, Neustart, Optionen, Beenden).
  Spielstände liegen unter `/retro-go/saves/meloni/`.

## Engine ändern, API-Versionen

Braucht ein Spiel eine Engine-Funktion, die es noch nicht gibt, wird sie in
[engine/meloni/](engine/meloni/) ergänzt und im selben Commit in [docs/API.md](docs/API.md)
beschrieben. Am Rechner und in der CI gilt sie sofort.

Auf die Konsole kommt sie mit der nächsten Firmware: open-086 baut die Engine aus einem fest
eingetragenen Commit dieses Repos (`MELONI_COMMIT` in `build_retro_go.sh`). Den setzt man auf
den neuen Stand, baut und flasht.

Jedes Spiel nennt in `meta.json` die API-Version, gegen die es geschrieben ist (`"api": 1`).
Kann ältere Firmware ein Spiel nicht mehr ausführen, wird die API-Version erhöht
(`MEL_API_VERSION` in `engine/meloni/meloni.h`). Konsolen mit älterer Firmware überspringen
solche Spiele beim Update und melden, dass ein Firmware-Update nötig ist.

```
engine/meloni/   Engine: Lua-API, Zeichnen, Mixer, .mlg-Archive (plattformunabhängig)
engine/lua/      Lua 5.4.7 mit LUA_32BITS (die FPU des ESP32-S3 rechnet nur einfach genau)
runner/          die Engine am Rechner: Fenster (SDL2) oder headless mit Screenshot/WAV
```

Die Geräte-Seite (Display, Ton, Tasten, Menü, Launcher-Tab und Updater) ist retro-go-spezifisch
und liegt in open-086.

## Hardware

| Component | Details |
|---|---|
| MCU | ESP32-S3-N16R8 (16 MB flash, 8 MB PSRAM) |
| Display | 2.4" TFT, 240x320, 10-pin FPC, ST7789(V) controller |
| Audio amplifier | NS4168 |
| Microphone | PDM |
| Power IC | ETA9640 |
| External storage | MicroSD slot, SD_MMC in 1-bit mode |
| Battery | 3.7 V LiPo, approx. 350 mA at max volume and brightness |
| Case dimensions | 81.7 x 109.6 x 21.6 mm |
| Controls | D-pad, A, B, SELECT, START, power button |
