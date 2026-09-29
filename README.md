# Meloni Games

Eigene Spiele für den Handheld **HXFB HU-086**. Die Spiele sind in Lua geschrieben, werden am
Rechner entwickelt und getestet und landen per WLAN direkt auf der Konsole.

## So kommt ein Spiel auf die Konsole

1. **KI-Agent:** entwickelt das Spiel in `games/<id>/` und pusht auf `main`.
2. **GitHub:** testet, packt und veröffentlicht automatisch.
3. **Handheld:** Tab *Meloni Games* → **[ Update games ]**.

Für Schritt 1: `make new GAME=<id>` legt ein neues Spiel an, `make test` prüft alle Spiele am
Rechner (Screenshots in `build/screens/`), `make run GAME=<id>` öffnet eins im Fenster (braucht
SDL2). Grafik wird als Text in `sprites.txt` gezeichnet und mit
[tools/sprites.py](tools/sprites.py) zum Bild. Die Anleitung für KI-Agenten steht in
[AGENTS.md](AGENTS.md), die Lua-Funktionen in [docs/API.md](docs/API.md).

Die Konsole läuft mit der Firmware [open-086](https://github.com/RedPetroleum/open-086), die die
Engine aus diesem Repo enthält.

## Spiele

| Spiel | Details |
|---|---|
| [Snake](games/snake/main.lua) | Fressen, wachsen, nicht in die Wand fahren. Der Highscore wird gespeichert |
| [Huf-Hüpfer](games/hufhuepfer/main.lua) | Pferde-Jump-and-Run: springen (hoch), unter Ästen rutschen (runter), Bretterwände kaputt treten (A), Snacks in der Luft und am Boden, Pause (START) |
| [Hoofy](games/hoofy/README_HOOFY.md) | Größeres Pferdespiel-Konzept |

## Engine ändern

Fehlt einem Spiel eine Funktion, wird sie in [engine/meloni/](engine/meloni/) ergänzt und im
selben Commit in [docs/API.md](docs/API.md) beschrieben. Auf die Konsole kommt sie erst mit einer
Firmware, die diesen Commit einbindet (`MELONI_COMMIT` in open-086).

## Offene To-dos

- **Tearing auf der Konsole beheben:** Schnell bewegte Objekte wirken auf der HU-086 manchmal
  zerteilt (SPI-Display ohne Sync-Signal). Betrifft die Firmware, nicht die Spiele. Befund und
  Plan: [docs/tearing.md](docs/tearing.md)

## Hardware

| Component | Details |
|---|---|
| MCU | ESP32-S3-N16R8 (16 MB flash, 8 MB PSRAM) |
| Display | 2.4" TFT, 240x320, 10-pin FPC, ST7789(V) controller |
| Audio amplifier | NS4168 |
| Microphone | PDM |
| External storage | MicroSD slot, SD_MMC in 1-bit mode |
| Battery | 3.7 V LiPo, approx. 350 mA at max volume and brightness |
| Case dimensions | 81.7 x 109.6 x 21.6 mm |
| Controls | D-pad, A, B, SELECT, START, power button |
