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

## Im Browser spielen

`make web` baut `build/web/meloni-konsole.html`: eine einzelne Datei mit der Engine (dieselben
C-Quellen wie auf der Konsole, als WebAssembly) und allen Spielen. Im Browser öffnen, auch am Handy:
Steuerkreuz und Tasten zum Antippen, am Rechner Pfeiltasten, X/Leertaste (A), Z/Y (B),
Enter (START), Shift (SELECT), Gamepads gehen auch. Spielstände bleiben im Browser.
Die GitHub-Action hängt die Datei bei jedem Push auf `main` ans Release `latest` an
(`meloni-konsole.html`). Braucht `clang` mit WebAssembly-Ziel und `wasm-ld`
(Linux: `apt install clang lld`, macOS: `brew install llvm lld`), den WASI-Sysroot lädt `make web`
beim ersten Mal selbst. Quellen in [web/](web/).

## Spiele

| Spiel | Details |
|---|---|
| [Snake](games/snake/main.lua) | Fressen, wachsen, nicht in die Wand fahren. Der Highscore wird gespeichert |
| [Bärger dich nicht!](games/baerger-dich-nicht/main.lua) | Vier Gummibärchen-Teams, 1–4 Menschen mit Farb- und Namenswahl (Namen werden gespeichert), CPU. Bär 1–4 mit links/rechts wählen, hoch = vor, runter = zurück (nur zum Schlagen); Lauf- und Schlag-Animation |
| [Huf-Hüpfer](games/hufhuepfer/main.lua) | Pferde-Jump-and-Run: springen (hoch), unter Ästen rutschen (runter), Bretterwände kaputt treten (A), Snacks in der Luft und am Boden, Pause (START) |
| [Mieznake](games/mieznake/main.lua) | Snake mit einer flauschigen Britisch Kurzhaar in Blue Silver Shaded Shell: Leckerli sammeln, wachsen und nicht in die Wand oder den eigenen Körper laufen. |
| [Ausgebüxt!](games/ausgebuext/main.lua) | Die Pferde sind ausgebüxt: vor Sonnenuntergang zurück auf die Koppel führen (A: nehmen/loslassen, B: rennen). Pferde sind brav, faul, scheu oder verfressen, in Level 3 („Zickenalarm“) auch zickig (nur von vorne nehmen, am Strick nicht rennen), launisch (bei Gewitterwolke warten) oder eine Diva (nur allein am Strick, will unterwegs Möhren). Technik-Test für Hoofy: scrollende Kachelkarte in 3/4-Ansicht, Tiefensortierung, Level als Daten |
| [Kuschelwiese](games/kuschelwiese/main.lua) | Ein ganz liebes Hasenspiel: Hoppel sammelt Möhren auf der Blumenwiese. Bis die Gartenzwerge kommen. Dann Kettensäge (A halten), Hechtsprung (B), Wellen, Combos und sehr viel Pixelblut. Rekord wird gespeichert |
| [Roller-Rowdy](games/roller-rowdy/main.lua) | Fake-3D-Rennen mit dem Leih-E-Scooter durch den Feierabendverkehr: A Gas, B Bremse, links/rechts lenken. Der Akku ist die Zeit (Ladestationen geben Sekunden), die Polizei holt bei jedem Sturz auf. Autos knapp überholen, über Rampen springen und in der Luft Tricks machen (A Tailwhip, B No-Hander, links/rechts 360), sauber gelandet gibt es Turbo. Rekord und weiteste Fahrt werden gespeichert |
| [Schnösel im Gym](games/schnoesel-sprint/main.lua) | Gym-Arcade: Langhantel im grünen Takt curlen und mit links/rechts ausbalancieren. A: Wiederholung, ↓: atmen, B: Monster-Boost mit extra Wackeln. Mit jeder sauberen Wiederholung wird der blonde Schnösel mit runder Brille und Dreitagebart sichtbar fitter: von moppelig über pummelig und sportlich bis zum Muskelprotz |
| [Levi & Yrsa](games/levi-yrsa/main.lua) | Nachtschicht: zwei Katzen schubsen alles von den Möbeln (B: Tatze, A: springen, unten: vom Brett runter), bevor um 6 Uhr der Wecker klingelt. SELECT wechselt die Katze. Levi, dicker weißgrauer Britisch Kurzhaar, springt niedrig und landet laut, schafft aber Vasen und Kochtöpfe, drückt die klemmende Küchentür auf und ist Yrsas Taxi: von seinem Rücken springt sie auf Hängeschrank und Kühlschrank. Yrsa, klein und getigert, springt hoch und leise und passt als Einzige durch die Katzenklappe ins Arbeitszimmer. Nacht 1 Wohnzimmer, Nacht 2 auch Küche (Fliesen, lauter), ab Nacht 3 auch Arbeitszimmer (Teppich, leiser). Jedes Klirren weckt den Menschen ein Stück (mal eine Dame im hellblauen Kimono, mal ein blonder Typ in grüner Schlafanzughose), Sofa und Sitzsack dämpfen. Rekord wird gespeichert |
| [Hoofy](games/hoofy/README_HOOFY.md) | Größeres Pferdespiel-Konzept |

## Engine ändern

Fehlt einem Spiel eine Funktion, wird sie in [engine/meloni/](engine/meloni/) ergänzt und im
selben Commit in [docs/API.md](docs/API.md) beschrieben. Auf die Konsole kommt sie erst mit einer
Firmware, die diesen Commit einbindet (`MELONI_COMMIT` in open-086).

## Offene To-dos

- **Tearing auf der Konsole beheben:** Schnell bewegte Objekte wirken auf der HU-086 manchmal
  zerteilt (SPI-Display ohne Sync-Signal). Betrifft die Firmware, nicht die Spiele. Befund und
  Plan in open-086:
  [docs/display_tearing.md](https://github.com/RedPetroleum/open-086/blob/main/docs/display_tearing.md)

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
