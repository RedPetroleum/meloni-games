# Meloni API (Version 1)

Meloni-Spiele sind Lua-Programme (Lua 5.4), die auf der HU-086 in der Firmware-App **meloni** laufen
([open-086](https://github.com/RedPetroleum/open-086)) und am Rechner im Runner. Beide nutzen
dieselbe Engine aus [`engine/`](../engine/). Die API ist an PICO-8 angelehnt, hat aber 320×240 Pixel und echte Farben.

- Bildschirm: **320×240**, Ursprung oben links, `SCREEN_W`, `SCREEN_H`
- Takt: **60 Frames pro Sekunde**, fest. Zeit wird in Frames gezählt, nicht in Millisekunden.
- Zahlen: 32 Bit (Ganzzahlen bis ±2 147 483 647, Kommazahlen in einfacher Genauigkeit)
- Kein `io`, `os`, `debug`, `dofile`, `loadfile`. Dateien nur über `loadimg`, `loadsound`, `require`,
  Speichern nur über `savedata`/`loaddata`.

## Aufbau eines Spiels

```
games/<id>/
  main.lua      Pflicht, wird zuerst geladen
  meta.json     Pflicht: {"id", "name", "version", "api": 1, "description"}
  cover.png     optional: Bild im Launcher (etwa 160×120)
  *.lua         weitere Module, laden mit require('name') bzw. require('ordner.name')
  *.png, *.wav  Grafiken und Sounds
```

Auf dem Gerät wird der Ordner zu einer Datei `<id>.mlg` gepackt (`roms/meloni/<id>.mlg`).

## Ablauf

```lua
function _init()   end  -- einmal beim Start
function _update() end  -- 60× pro Sekunde: Logik, Eingabe
function _draw()   end  -- nach jedem _update: zeichnen
function _quit()   end  -- optional: vor dem Beenden über das Menü, z. B. zum Speichern
```

Der Bildschirm bleibt zwischen Frames erhalten, `_draw` beginnt üblicherweise mit `cls()`.
Ein Lua-Fehler zeigt einen Fehlerbildschirm mit Traceback, das Spiel läuft dann nicht weiter.
SELECT+START öffnet auf dem Gerät immer das Menü (Weiter, Neustart, Optionen, Beenden),
SELECT+A die Optionen. Diese Kombinationen sollte ein Spiel nicht selbst belegen.

## Eingabe

| Konstante | Taste |
|---|---|
| `BTN_LEFT`, `BTN_RIGHT`, `BTN_UP`, `BTN_DOWN` | Steuerkreuz |
| `BTN_A`, `BTN_B` | A, B |
| `BTN_START`, `BTN_SELECT` | START, SELECT |

- `btn(b)`: `true`, solange die Taste gehalten wird. `btn()` ohne Argument: Bitmaske aller Tasten.
- `btnp(b)`: `true` im Frame des Drückens, bei gehaltener Taste nach 15 Frames alle 4 Frames erneut.

## Farben

Farben sind entweder **Palettenindizes 0–255** oder Werte aus **`rgb(r, g, b)`** (0–255 je Kanal).

| | | | | | | | |
|---|---|---|---|---|---|---|---|
| 0 schwarz | 1 dunkelblau | 2 lila | 3 dunkelgrün | 4 braun | 5 dunkelgrau | 6 hellgrau | 7 weiß |
| 8 rot | 9 orange | 10 gelb | 11 grün | 12 blau | 13 lavendel | 14 rosa | 15 pfirsich |

16–31 sind die dunkleren/zusätzlichen Farben der PICO-8-Palette, 32–255 sind schwarz.
- `pal(i, r, g, b)`: Palettenfarbe `i` ändern. `pal()`: Palette zurücksetzen.

## Grafik

Alle Koordinaten sind Pixel, Kommazahlen werden abgerundet. Rechtecke nehmen **zwei Ecken**
(wie PICO-8), nicht Breite/Höhe.

| Funktion | |
|---|---|
| `cls([c=0])` | Bildschirm füllen |
| `pset(x, y, [c=7])` / `pget(x, y)` | Pixel setzen / lesen (liefert einen `rgb`-Wert) |
| `line(x0, y0, x1, y1, [c=7])` | Linie |
| `rect(x0, y0, x1, y1, [c=7])` / `rectfill(...)` | Rechteck, Ecken inklusive |
| `circ(x, y, r, [c=7])` / `circfill(...)` | Kreis um Mittelpunkt |
| `print(text, [x=0], [y=0], [c=7], [scale=1])` | Text, 8×8-Font, `\n` für Zeilenumbruch, Umlaute gehen. Gibt das x nach dem Text zurück |
| `textw(text, [scale=1])` | Breite eines Textes in Pixeln (zum Zentrieren) |
| `camera([x, y])` | verschiebt alles Gezeichnete um −x, −y (Scrolling). Ohne Argumente: zurücksetzen |
| `clip([x, y, w, h])` | nur innerhalb dieses Rechtecks zeichnen. Ohne Argumente: zurücksetzen |

`print` zeichnet auf den Bildschirm. Für Debug-Ausgaben gibt es `log(...)`.

### Bilder

PNG-Dateien aus dem Spielordner. Pixel mit Alpha unter 128 sind transparent.

| Funktion | |
|---|---|
| `img = loadimg('sprites.png')` | laden (einmal, z. B. in `_init`), `img.w`, `img.h` |
| `spr(img, x, y, [flip_x], [flip_y])` | ganzes Bild zeichnen |
| `sspr(img, sx, sy, sw, sh, dx, dy, [dw], [dh], [flip_x], [flip_y])` | Ausschnitt zeichnen, optional skaliert |
| `tile(img, n, x, y, [size=16], [flip_x], [flip_y])` | Kachel `n` eines Spritesheets (zeilenweise ab 0) |

## Sound

8 Kanäle (0–7). Ohne Kanalangabe wird ein freier aus 0–5 genommen, 6 und 7 bleiben für Melodien.
Lautstärken gehen von 0 bis 1.

| Funktion | |
|---|---|
| `tone(freq, [dur=0.2], [wave='square'], [vol=0.5], [ch])` | Ton in Hz für `dur` Sekunden. Wellen: `square`, `pulse`, `triangle`, `saw`, `sine`, `noise`. Gibt den Kanal zurück |
| `note('A4')` | Frequenz einer Note: `C4`, `F#3`, `Bb5` … |
| `tune(text, [bpm=120], [wave='square'], [vol=0.3], [loop=false], [ch=7])` | Melodie, z. B. `'C4 E4 G4:2 - C5:0.5'`: Noten mit Länge in Schlägen (Standard 1), `-` ist eine Pause |
| `stoptune([ch])` | Melodie auf Kanal `ch` (oder alle) stoppen |
| `snd = loadsound('hit.wav')` | WAV (PCM, 8/16 Bit, mono/stereo, beliebige Rate) |
| `play(snd, [vol=0.5], [loop=false], [ch])` | Sample abspielen, gibt den Kanal zurück |
| `stop([ch])` / `playing([ch])` | Kanal (oder alle) stoppen / läuft etwas? |

## Speichern

Eine Tabelle pro Spiel, bleibt über Neustarts und Updates erhalten. Erlaubt sind Zahlen, Strings,
Booleans und verschachtelte Tabellen (keine Funktionen, keine Zyklen).

```lua
savedata({best = 12, level = 3})
local s = loaddata()   -- nil, wenn noch nichts gespeichert ist
```

Speichern kostet SD-Karten-Zugriffe: bei Ereignissen speichern (Level geschafft, neuer Rekord),
nicht in jedem Frame. Auf dem Gerät liegt die Datei unter `/retro-go/saves/meloni/<id>.mlg.sram`.

## Hilfsfunktionen

| Funktion | |
|---|---|
| `time()` | Sekunden seit Spielstart (Frames / 60) |
| `frame()` | Frame-Zähler |
| `rnd([x=1])` | Zufallszahl 0 ≤ r < x. `rnd(tabelle)`: zufälliges Element |
| `srand(seed)` | Zufall reproduzierbar machen |
| `flr`, `ceil`, `abs`, `min`, `max`, `sgn`, `mid(a, b, c)` | wie PICO-8 (`mid` = mittlerer der drei Werte) |
| `require('modul')` | lädt `modul.lua` aus dem Spiel, `require('lib.karte')` lädt `lib/karte.lua` |
| `log(...)` | Ausgabe im Terminal (Runner) bzw. im seriellen Log (Gerät) |
| `API_VERSION` | Version dieser API (1) |

Die normale Lua-Standardbibliothek (`math`, `string`, `table`, `utf8`, `coroutine`) ist vorhanden.
`math.sin` und `math.cos` rechnen im Bogenmaß (anders als in PICO-8).

## Performance

Das Gerät ist ein ESP32-S3 mit 240 MHz. Zeichenfunktionen laufen nativ in C und sind schnell,
Lua-Code ist deutlich langsamer als auf dem PC. Faustregeln:

- Pro Frame keine Schleifen über alle 76 800 Pixel in Lua, dafür `rectfill`, `sspr`, `tile` nutzen.
- Bilder und Sounds einmal laden, nicht in `_update`/`_draw`.
- Tabellen in heißen Schleifen wiederverwenden statt jedes Frame neu anzulegen.
- Das Display überträgt nur geänderte Zeilen. Ruhige Hintergründe halten die Bildrate hoch.
