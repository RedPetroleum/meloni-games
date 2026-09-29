# Meloni Games – Hinweise für Claude

Spiele für die HU-086 (ESP32-S3-Handheld mit retro-go-Firmware aus
[open-086](https://github.com/RedPetroleum/open-086)). Neue Spiele sind **Lua-Spiele für die
Meloni-Engine**: Die vollständige API steht in [docs/API.md](docs/API.md). Lies sie, bevor du ein
Spiel schreibst oder änderst, und nutze nur Funktionen, die dort stehen.

## Aufbau

- `games/<id>/`: ein Spiel pro Ordner, `main.lua` + `meta.json` (+ `cover.png`, Grafiken, Sounds, Module)
- `template/`: Vorlage für `make new GAME=<id>`
- `tools/release.py`: packt `.mlg`-Dateien und `manifest.json` für den Updater
- Engine und Runner liegen in open-086 (`retro-go/meloni/`), erwartet unter `../open-086`

## Arbeitsweise

1. Nach jeder Änderung testen, ohne Fenster:
   ```sh
   make test                     # alle Spiele 10 s mit Tastendrücken, Screenshots in build/screens/
   make shot GAME=<id> INPUT="5:START,30-90:RIGHT" FRAMES=120
   ```
   Der Runner beendet sich mit Status 1 und gibt den Lua-Traceback aus, wenn das Spiel einen Fehler
   wirft. Die Screenshots (PNG, 320×240) ansehen, um zu prüfen, ob das Bild stimmt.
   Für Ton: `../open-086/retro-go/meloni/runner/build/meloni-run --headless --frames 300 --wav out.wav games/<id>`
2. Das Menü der Konsole liegt auf SELECT+START und SELECT+A, diese Kombinationen nicht im Spiel belegen.
3. Das Gerät ist viel langsamer als der PC: keine Lua-Schleifen über alle Pixel pro Frame,
   Bilder und Sounds nur in `_init` laden (siehe „Performance“ in docs/API.md).
4. Bei neuen Spielen `meta.json` ausfüllen (`name`, `version`, `api: 1`, `description`) und
   die `version` erhöhen, wenn sich ein Spiel merklich ändert.
5. Die Readme-Tabelle in `README.md` pflegen.

Wenn eine Funktion fehlt, die ein Spiel wirklich braucht, gehört sie in die Engine (open-086,
`retro-go/meloni/components/meloni/`), nicht als Workaround ins Spiel. Dann auch `docs/API.md`
anpassen und, falls ältere Firmware das Spiel nicht mehr laufen lassen kann, die API-Version erhöhen.

## Veröffentlichen

Ein Push auf `main` baut und testet alles und veröffentlicht das Release `latest`
(`.github/workflows/release.yml`). Die Konsole lädt es über den Eintrag „Update games“ im
Meloni-Tab herunter.
