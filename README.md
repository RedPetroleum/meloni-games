# Meloni Games

Hier werden verschiedene Spiele für den open-086 entwickelt.

## Hardware

- HXFB HU-086 mit custom firmware: [open-086](https://github.com/RedPetroleum/open-086), basierend auf [retro-go](https://github.com/ducalex/retro-go).

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

## Spieleüberblick

| Spiel | Details |
|---|---|
| [Snake](games/snake/main.lua) | Lua-Spiel für die Meloni-Engine |
| [Snake (GBC)](snake/README_SNAKE.md) | Game-Boy-Color-ROM für Retro-Go |
| [Hoofy](hoofy/README_HOOFY.md) | Noch zu bauen |

## Wie die Spiele auf die Konsole kommen

Neue Spiele sind Lua-Programme für die **Meloni-Engine**. Sie ist als eigenes System „Meloni Games“
in die open-086-Firmware eingebaut (`retro-go/meloni/`), die API steht in [docs/API.md](docs/API.md).

```
games/<id>/  ──push auf main──▶  GitHub Actions: testen, packen, Release "latest"
                                                         │
HU-086: Tab "Meloni Games" → [ Update games ]  ◀── WLAN ─┘
        lädt neue/geänderte Spiele nach roms/meloni/, Cover nach romart/meloni/
        (Snake GBC kommt als roms/gbc/meloni-snake.gbc mit)
```

### Am Rechner entwickeln

Voraussetzungen: open-086 liegt neben diesem Repo (`../open-086`, sonst `OPEN086=…` angeben),
ein C-Compiler, Python 3 und für das Spielfenster SDL2 (`brew install sdl2`).

```sh
make new GAME=pferde      # neues Spiel aus template/
make run GAME=pferde      # spielen im Fenster, lädt beim Speichern einer Datei automatisch neu
make test                 # alle Spiele headless testen, Screenshots in build/screens/
make dist                 # dist/ wie im Release: .mlg-Dateien + manifest.json
```

Tasten im Fenster: Pfeile/WASD, A = X/K/Leertaste, B = Z/Y/J, START = Enter, SELECT = Backspace,
F5 neu laden, F12 Screenshot, Esc beenden.

Beim Vibe-Coden mit Claude: [CLAUDE.md](CLAUDE.md) beschreibt, wie Spiele geschrieben und
ohne Gerät geprüft werden (headless mit Screenshots).

### Auf der Konsole

1. Firmware mit Meloni bauen und flashen (open-086: `./build_retro_go.sh`, `./flash_firmware.sh`).
2. WLAN eintragen: `/retro-go/config/wifi.json` auf der SD-Karte, z. B.
   `{"ssid0": "mein-netz", "password0": "passwort"}`.
3. Im Launcher zum Tab **Meloni Games**, oben **[ Update games ]** wählen.

Das Release muss öffentlich abrufbar sein (das Repo also öffentlich), sonst bekommt die Konsole
HTTP 404. Eine andere Quelle lässt sich in `/retro-go/config/meloni.json` eintragen:
`{"manifest_url": "https://…/manifest.json"}`.

Ohne WLAN geht es auch von Hand: `make dist`, dann `dist/<id>.mlg` nach `roms/meloni/` kopieren.
