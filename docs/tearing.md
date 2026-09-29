# Tearing auf der HU-086

Stand: 29.09.2026. Nichts davon ist bisher auf dem Gerät gemessen. Die Ursache ist aus Code,
Datenblattwerten und Symptom erschlossen. Die Behebung betrifft die Firmware
([open-086](https://github.com/RedPetroleum/open-086)), nicht die Spiele oder `engine/`.

## Symptom

In Huf-Hüpfer laufen Hindernisse horizontal über den Bildschirm. Auf der Konsole wirken sie
manchmal zerteilt: Der obere Teil eines Objekts ist gegenüber dem unteren um ein paar Pixel
horizontal verschoben, in wechselnder Höhe. Im Desktop-Runner und auf dessen Screenshots tritt
das nicht auf.

## Warum es nicht am Spiel oder an der Engine liegt

- Jedes Hindernis wird pro Frame in einem Stück (ein Sprite, eine x-Koordinate) gezeichnet.
- `present()` in `open-086/retro-go/meloni/main/main.c` kopiert den Framebuffer per `memcpy` in
  eine von zwei `rg_surface_t` und ruft `rg_display_submit()` auf, aber nur, wenn
  `rg_display_sync(false)` meldet, dass das Display frei ist. Sonst wird der Frame ausgelassen.
  Halb kopierte Frames kommen in der Software also nicht vor.

## Wahrscheinliche Ursache: SPI-LCD-Tearing ohne Sync-Signal

- **Display:** ST7789, nativ 240×320, im Querformat genutzt. SPI Mode 3, 40 MHz
  (`RG_SCREEN_SPEED` in `open-086/retro-go/hu-086/config.h`), CS nicht angeschlossen, kein MISO.
- **Übertragungszeit:** 320×240×16 bit ≈ 1,23 Mbit, bei 40 MHz etwa 31 ms. Das Panel frischt mit
  etwa 60 Hz auf (16,7 ms, FRCTRL2 `0xC6` Standard). Eine Übertragung dauert also etwa zwei
  Panel-Refreshes, das Panel zeigt dabei teils alte, teils neue Daten.
- **Partial Updates:** `write_update()` in retro-go (`components/retro-go/rg_display.c`) sendet nur
  Zeilen mit geänderter Checksumme. Die Übertragungszeit schwankt deshalb. In Huf-Hüpfer scrollt
  der Boden, viele Zeilen ändern sich jeden Frame.
- **Ausrichtung:** Die Init setzt MADCTL `0x36 = 0x60` (MV|MX). MADCTL ändert nur die
  Schreibadressierung, nicht die Scanrichtung des Panels. Geschrieben werden Querformat-Zeilen,
  gescannt werden native Zeilen, im Querformat also Spalten. Die Tearing-Kante liegt dadurch
  schräg im Bild; an einem kleinen Objekt sieht das wie ein horizontaler Schnitt in wechselnder
  Höhe aus.
- **Größe des Versatzes:** Hindernisse bewegen sich 3,2 (Level 1) bis 8 px (Level 5) pro
  Logik-Frame. Angezeigt werden unregelmäßig etwa 30 fps, zwischen zwei angezeigten Bildern liegen
  also 6 bis 24 px. So groß ist der Versatz an der Kante.
- **TE-Pin:** Am Display sind laut `open-086/docs/HU-086_notes.md` nur MOSI 39, CLK 40, DC 38,
  RST 41 und Backlight 42 bekannt. Ein TE-Pin ist nicht dokumentiert.

## Wichtig: TE hilft nur mit nativer Ausrichtung

Mit MV überstreicht jede gesendete Querformat-Zeile alle Panel-Zeilen. Jede Übertragung, die in
einen Scan fällt, reißt, und jede Übertragung ist länger als die Austastlücke. Mit TE läge die
schräge Kante nur an fester Stelle.

In nativer Ausrichtung (ohne MV) mit Start auf die TE-Flanke:

- **40 MHz** (31 ms): Der Scan ist schneller als das Schreiben und bleibt in Refresh 1 vorne, der
  zeigt komplett das alte Bild. In Refresh 2 holt der Scan das Schreiben erst nach etwa 36 ms
  ein, da ist die Übertragung fertig. Sauber bei 30 fps.
- **80 MHz** (15 ms): auch 60 fps ohne Tearing möglich.

Aufwand der nativen Ausrichtung:

- Das Drehen selbst ist billig: in `present()` ein gekacheltes Transponieren statt `memcpy`
  (geschätzt wenige ms, nicht gemessen).
- Schwierig ist das Zusammenspiel mit `rg_gui` (Menü, Optionen), das weiter im Querformat
  zeichnet. Meloni müsste MADCTL beim Öffnen des Menüs zurückschalten oder die Spielbilder am
  `rg_display` vorbei senden. `config.h` global ändern geht nicht, Launcher und Emulatoren hängen
  daran.
- Native Zeilen verlaufen quer zum scrollenden Boden, Partial Updates bringen dann nichts mehr.
  Bei 30 fps ist das in Ordnung.

## Ansätze

| Ansatz | Einschätzung |
|---|---|
| TE-Pin suchen | In der Init TEON (`0x35`, Parameter `0x00`) senden, freie GPIOs nach einem ~60-Hz-Rechteck abtasten. Kandidaten laut `open-086/README.md`: GPIO3, GPIO12, GPIO13, GPIO6. Gegenprobe: FRCTRL2 ändern, die Frequenz muss mitgehen. Schneller: Panel-Typ am FPC bestimmen und mit dem Multimeter prüfen, ob der TE-Kontakt überhaupt zum ESP32 führt. Nur zusammen mit nativer Ausrichtung wirksam. |
| Panel auslesen (GSCAN) | Ersatz für TE ohne zusätzlichen Pin. Beim ST7789 ist die Datenleitung im 4-Line-Serial-Modus I oft bidirektional. Über ein zweites SPI-Device am selben Bus (`SPI_DEVICE_3WIRE \| SPI_DEVICE_HALFDUPLEX`, wenige MHz) über GPIO39 lesen. Test: RDDID (`0x04`), beim ST7789V `85 85 52`. Klappt das, liefert GSCAN (`0x45`) die aktuelle Scanzeile. Hängt von der Verdrahtung der IM-Pins ab. |
| SPI auf 80 MHz | `SPI_MASTER_FREQ_80M`. Halbiert die Übertragungszeit, verdoppelt die mögliche Bildrate, halbiert den Versatz. Beseitigt Tearing nicht. Zwischenwerte gibt es nicht (Takt ganzzahlig aus 80 MHz: 80 / 40 / 26,7). Datenblatt garantiert nur ~62,5 MHz; GPIO 39/40 laufen über die GPIO-Matrix. Mögliche Fehlerbilder: Bildfehler, falsche Farben. |
| Feste Bildrate | Jeden zweiten Frame zeigen (30 fps) statt „wenn frei“. Tearing bleibt, die Bewegung wird gleichmäßiger. Bei 40 MHz knapp (31 ms plus Aufwand in `write_update` gegen 33 ms), kann auf 20 fps abrutschen; mit 80 MHz sicher. Vorher messen. |
| FRCTRL2 ändern | Ohne Sync-Signal nutzlos, verschiebt nur die Frequenz, mit der die Kante wandert. |

## Plan

1. **Messen, ohne Firmware:** Testspiel mit einem weißen Balken über die volle Höhe, der auf
   Schwarz mit 4 px pro Frame wandert, dazu ein Frame-Zähler. Mit Handy-Zeitlupe (240 fps)
   filmen. Schräge Kante bestätigt die Vermutung zur Ausrichtung.
2. **Ein Test-Build der Firmware:** Übertragungszeit und angezeigte fps loggen, 80 MHz, feste
   Bildrate, TEON mit GPIO-Abtastung, RDDID/GSCAN-Test. Beantwortet alle offenen Fragen mit einem
   Flash.
3. **Mit TE oder GSCAN:** native Ausrichtung mit Sync, das beseitigt das Tearing. **Ohne:** bei
   80 MHz und fester Bildrate bleiben.

## Relevante Stellen

- `open-086/retro-go/hu-086/config.h`: SPI-Takt, SPI-Mode, Display-Init (MADCTL, COLMOD, Inversion)
- `open-086/retro-go/meloni/main/main.c`: `present()`, Hauptschleife mit `rg_display_sync(false)`
- `open-086/retro-go/retro-go.patch`: Patch für `drivers/display/ili9341.h` (SPI-Mode konfigurierbar)
- retro-go-Quelle `~/Dev/ext/retro-go` auf Commit 4ced120 (retro-go 1.46-8):
  `components/retro-go/rg_display.c` (`write_update`, `display_task`, Partial Updates),
  `components/retro-go/drivers/display/ili9341.h` (SPI-Setup, `lcd_set_window`, `lcd_send_buffer`)
- Bauen mit `open-086/build_retro_go.sh`, flashen mit `open-086/flash_firmware.sh`
