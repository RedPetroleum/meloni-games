# Meloni-Spiele auf dem Steam Deck

Stand: 2026-09-29. Nur ein Plan, noch nichts davon umgesetzt oder auf einem Steam Deck getestet.
Offenes To-do.

## Ziel

Die Meloni-Spiele sollen auf dem Steam Deck laufen. Dabei gilt:

- Sie laufen im Spielmodus mit dem Controller.
- Sie stehen in derselben Oberfläche wie die übrigen Retro-Spiele (ES-DE).
- Sie aktualisieren sich wie auf der HU-086 aus dem Release `latest`.

## EmuDeck oder RetroDECK?

Beide bündeln nur fertige Emulatoren (RetroArch, Dolphin …) mit ES-DE als Oberfläche. Keiner
davon kann `.mlg` öffnen. Die Spiele laufen dort erst, wenn es die Engine als **Libretro-Core**
gibt, also als Plug-in für RetroArch. RetroArch ist in beiden enthalten.

Tendenz: **EmuDeck**. Dort ist RetroArch ein eigenes Flatpak mit beschreibbarem Cores-Ordner.
Bei RetroDECK steckt alles in *einem* Flatpak. Ob man dort einen eigenen Core ablegen kann, ist
offen (siehe unten).

Übergangslösung ohne Core: den Runner für Linux bauen und als Nicht-Steam-Spiel eintragen, zum
Beispiel `meloni-run --save ~/meloni/saves/snake.sav ~/meloni/snake.mlg`. Den Controller dann per
Steam Input auf Tasten legen. Das ist nur eine Notlösung, weil der Runner keine Gamepads kennt.

## Der Libretro-Core

Libretro ist eine C-Schnittstelle (`libretro.h`, eine Header-Datei). Die Aufgaben sind so verteilt:

- **RetroArch (Frontend):** Fenster, Vollbild, Skalierung, Shader, Ton, Controller und
  Tastenbelegung, Menü, Speicherordner, Screenshots.
- **Core** (`meloni_libretro.so`): liefert bei jedem Aufruf von `retro_run()` ein Bild und den
  Ton dazu.

Die Engine ist schon passend aufgeteilt. Der Core ist eine dritte Plattform-Hülle neben
`runner/runner.c` (Desktop) und `retro-go/meloni/main/main.c` in open-086 (Konsole). Er braucht
geschätzt 150–200 Zeilen und keine Änderung an der Engine.

| Libretro | Meloni |
|---|---|
| `retro_get_system_info` | `library_name` „Meloni“, `valid_extensions` „mlg“, `need_fullpath = true` (die Engine öffnet die Datei selbst) |
| `retro_get_system_av_info` | 320×240, Seitenverhältnis 4:3, 60 fps (`MEL_FPS`), 32 000 Hz (`MEL_SAMPLE_RATE`) |
| `retro_load_game` | `RETRO_PIXEL_FORMAT_RGB565` anmelden, Speicherordner holen (`RETRO_ENVIRONMENT_GET_SAVE_DIRECTORY`), `mel_init(pfad, <speicherordner>/meloni/<spiel>.sav)` |
| `retro_run` | Tasten über `input_state_cb` → `MEL_BTN_*`, `mel_frame(buttons)`, `video_cb(mel_framebuffer(), 320, 240, 640)`, `mel_audio_mix` → `audio_batch_cb` |
| `retro_reset` | `mel_quit()`, dann `mel_init()` erneut (wie „Restart“ auf der Konsole) |
| `retro_unload_game` | `mel_quit()` (das Spiel speichert in `_quit()`), dann `mel_shutdown()` |
| `retro_serialize_size` | `0`: keine Save-States |
| `mel_plat_*` | `log` über `RETRO_ENVIRONMENT_GET_LOG_INTERFACE`, `time_us` über `clock_gettime`, `realloc` = `realloc` |

Einzelheiten:

- **Ton:** 32 000 Hz / 60 fps sind 533⅓ Samples pro Bild. Mit einem Zähler abwechselnd 533, 533
  und 534 Samples ausgeben, sonst driftet der Ton.
- **Tasten:** Meloni A ← RetroPad A, B ← B, dazu START, SELECT und das Steuerkreuz. RetroArch
  belegt nach Position: RetroPad A ist die rechte Taste, auf dem Deck also „B“, und RetroPad B die
  untere („A“). Das entspricht dem Game Boy. Wer es anders will, stellt es in RetroArch um.
- **`.info`-Datei** (`meloni_libretro.info`): Anzeigename, Dateiendung `mlg`, Hinweis „keine
  Save-States“. Ohne sie zeigt RetroArch den Core nur mit Dateinamen.

Grenzen:

- **Keine Save-States.** Dafür müsste der ganze Lua-Zustand gespeichert und wiederhergestellt
  werden. Die normalen Spielstände über `savedata()`/`loaddata()` funktionieren.
- **Kein eigenes Menü (SELECT+START).** Neustart und Beenden laufen über das RetroArch-Menü.

Nebeneffekt: Derselbe Core läuft überall, wo es RetroArch gibt, zum Beispiel auf Windows, Android
und Anbernic- oder Miyoo-Handhelds. Er muss dafür nur pro Plattform gebaut werden.

## Aufbau im Repo

```
libretro/meloni_libretro.c      die Hülle
libretro/libretro.h             unverändert aus libretro-common (MIT)
libretro/meloni_libretro.info
libretro/Makefile               .so (Linux), .dylib (macOS), Quellen wie runner/Makefile
libretro/test_frontend.c        Mini-Frontend für Tests ohne RetroArch
```

Der Runner bleibt. Er ist das Entwicklungswerkzeug (F5 neu laden, Screenshots, feste
Zufallszahlen, `make test`). Der Core ist zum Spielen.

## Testen ohne RetroArch

`test_frontend.c` lädt den Core per `dlopen` so, wie RetroArch es tut. Es startet ein Spiel und
lässt N Bilder mit einem Tasten-Drehbuch laufen, in derselben Syntax wie `--input` beim Runner.
Dann speichert es den letzten Frame als PNG. Mit demselben Seed muss das Bild **pixelgleich** mit
`make shot` sein. Außerdem prüft es:

- ob pro Sekunde 32 000 Samples ankommen,
- ob Spielstände im Speicherordner landen.

Als Make-Ziel (`make core-test`) läuft das in der CI bei jedem Push mit.

Wer es im echten Frontend sehen will: RetroArch für macOS installieren und unter „Core laden“
die `.dylib` wählen.

## Veröffentlichen (CI)

`release.yml` baut schon auf `ubuntu-latest` (x86_64, wie das Deck). Dazu kommt:

1. `make core` und `make core-test`.
2. `meloni_libretro.so` und `.info` mit ins Release `latest`, als Einträge in `manifest.json`,
   zum Beispiel mit `"path": "libretro/meloni_libretro.so"` und `"api": MEL_API_VERSION`.
   **Die HU-086 lädt diese Einträge nicht:** `path_allowed()` in `meloni_update.c` (open-086)
   lässt nur `roms/` und `romart/` zu. Ein zweites Manifest ist also nicht nötig.
3. Optional `tools/deck_update.py` ebenfalls ins Release, damit es sich selbst aktualisiert.

Die `.so` sollte gegen eine alte glibc gebaut werden, sonst läuft sie im RetroArch-Flatpak
vielleicht nicht. Entweder in einem älteren Container oder ohne weitere Abhängigkeiten außer libc
und libm. Der Core braucht kein SDL.

## Auf dem Deck einrichten (einmalig)

Die Pfade sind nicht geprüft und müssen auf dem Deck nachgesehen werden:

| | EmuDeck | RetroDECK |
|---|---|---|
| ROMs | `~/Emulation/roms/meloni/` (oder auf der SD-Karte) | `~/retrodeck/roms/meloni/` |
| Cores | `~/.var/app/org.libretro.RetroArch/config/retroarch/cores/` | offen, möglicherweise schreibgeschützt im Flatpak |
| ES-DE eigene Systeme | `~/ES-DE/custom_systems/es_systems.xml` | offen |

Eintrag für ES-DE, ungefähr so:

```xml
<system>
  <name>meloni</name>
  <fullname>Meloni Games</fullname>
  <path>%ROMPATH%/meloni</path>
  <extension>.mlg .MLG</extension>
  <command label="Meloni">%EMULATOR_RETROARCH% -L %CORE_RETROARCH%/meloni_libretro.so %ROM%</command>
  <platform>meloni</platform>
  <theme>meloni</theme>
</system>
```

Ein Theme für „meloni“ gibt es in ES-DE nicht, das System erscheint dann ohne Logo. Die
Wassermelonen-Grafik aus open-086 (`retro-go/themes/artbook_v03/`) könnte man dafür verwenden.

## Updates auf dem Deck: `tools/deck_update.py`

Das Skript macht dasselbe wie `meloni_update.c` auf der Konsole. Python 3 ist auf SteamOS
vorhanden, also reicht die Standardbibliothek.

1. `manifest.json` aus dem Release `latest` laden. Eine andere Quelle lässt sich wie auf der
   Konsole per Konfigurationsdatei setzen.
2. Die Pfade aus dem Manifest auf das Deck übertragen:
   - `roms/meloni/*.mlg` → ROM-Ordner
   - `romart/meloni/*.png` → Cover-Ordner von ES-DE (`downloaded_media/meloni/covers/`, Pfad
     prüfen)
   - `libretro/*` → Cores-Ordner
3. Laden, was fehlt oder sich geändert hat (Vergleich über sha256). Erst in eine temporäre Datei
   schreiben, dann umbenennen, damit kein halber Core liegen bleibt.
4. Merken, was installiert wurde, in `~/.local/share/meloni/installed.json`. Nur Dateien löschen,
   die dort stehen und aus dem Manifest verschwunden sind, andere nie.
5. Spiele mit `api` größer als die API des installierten Cores überspringen. Da der Core im selben
   Lauf mit aktualisiert wird, passiert das nur, wenn dessen Download fehlschlägt.
6. Am Ende kurz ausgeben: neu, aktualisiert, gelöscht, übersprungen.

Auslösen:

- **Per Knopfdruck:** als Nicht-Steam-Spiel „Meloni aktualisieren“ eintragen. Das ist das
  Gegenstück zu *[ Update games ]* auf der Konsole.
- **Automatisch:** als Startskript von ES-DE (`scripts/startup/`). Dafür müssen in den
  ES-DE-Einstellungen die eigenen Event-Skripte eingeschaltet sein. Ohne Netz muss das Skript
  still und schnell aufgeben, sonst hängt der Start von ES-DE.

Der Unterschied zur Konsole: Dort steckt die Engine in der Firmware, eine neue Engine heißt neu
bauen und flashen. Auf dem Deck ist sie nur eine Datei im Release, Engine und Spiele sind nach
jedem Update auf demselben Stand.

Alternative: den Core bei libretro einreichen. Dann aktualisiert ihn der Core-Updater von
RetroArch. Man wäre aber von deren Build-Ablauf abhängig. Für ein privates Projekt ist das eigene
Skript einfacher.

## Plan

1. **Core schreiben und am Mac testen:** `libretro/` mit Hülle, `.info`, Makefile und
   `test_frontend.c`. Der Test-Screenshot muss pixelgleich mit `make shot` sein. Das geht in einem
   Durchgang ohne Deck.
2. **CI:** `.so` bauen, testen und ins Release `latest` legen (`release.yml`, `tools/release.py`).
3. **`tools/deck_update.py`** mit Tests gegen ein lokales Manifest (Download, Update, Löschen,
   API-Grenze).
4. **Auf dem Deck** (von Hand): EmuDeck installieren, Pfade aus der Tabelle oben prüfen und hier
   eintragen, Core und ES-DE-System einrichten, Update-Skript eintragen. Ton und Controller
   ausprobieren.
5. Danach diese Datei auf den tatsächlichen Stand bringen und in eine Anleitung umschreiben.

## Offene Fragen

- **RetroDECK:** Kann man dort einen eigenen Core ablegen, oder sind die Cores nur im
  schreibgeschützten Flatpak? Wenn nicht, bleibt nur EmuDeck.
- **Pfade auf dem Deck:** die Tabelle oben prüfen, auch bei ROMs auf der SD-Karte.
- **glibc-Version** der RetroArch-Flatpak-Laufzeit: gegen welche Version bauen?
- **Tastenbelegung:** Soll Meloni A auf der Deck-Taste „A“ liegen statt nach Position? Das wäre
  ein Core-Optionsschalter.
- **Wird ES-DE überschrieben?** Überschreiben Updates von EmuDeck `custom_systems`, oder beim
  Zurücksetzen der Konfiguration?

## Nebenbei: Runner am Mac

Auf dem Entwicklungs-Mac (Intel, macOS 26) ist Homebrew 3.5.9 zu alt und bricht ab. Deshalb ist
SDL2 als offizielles Framework (2.32.10) in `~/Library/Frameworks/SDL2.framework` installiert.
`runner/Makefile` findet es nur über `sdl2-config`. Ohne das baut `make` den Runner still ohne
Fenster.

- Das Makefile sollte das Framework als Rückfall erkennen: `-F ~/Library/Frameworks -framework
  SDL2 -Wl,-rpath,…`, wenn `sdl2-config` fehlt, das Framework aber da ist.
- Außerdem sollte es neu bauen, wenn sich die SDL-Einstellung ändert. Bisher ist dafür
  `make -C runner clean` nötig.
- Alternativ Homebrew neu installieren, dann `brew install sdl2`.

## Relevanter Code

- `engine/meloni/meloni.h`: die Schnittstelle, die der Core nutzt (`mel_init`, `mel_frame`,
  `mel_audio_mix`, `mel_framebuffer`, `mel_quit`, `mel_shutdown`, `mel_plat_*`, `MEL_API_VERSION`)
- `runner/runner.c`: Vorbild für Hülle, Tasten-Drehbuch und PNG-Ausgabe
- `runner/Makefile`: Liste der Quellen
- `tools/release.py`, `.github/workflows/release.yml`: Manifest und Release
- open-086 `retro-go/launcher/meloni_update.c`: Vorbild für das Update-Skript (`path_allowed`,
  `installed.json`, API-Prüfung)
