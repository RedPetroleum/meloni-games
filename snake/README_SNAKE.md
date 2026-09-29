# Snake

Snake für die HU-086: als NES-ROM für den NES-Emulator in Retro-Go. Dazu gibt es eine Browser-Vorschau.

## ROM bauen

Mit installiertem cc65:

```sh
make -C snake
```

Das Ergebnis ist `snake/snake.nes`. Alternativ erzeugt der GitHub-Workflow nach jedem passenden Push ein herunterladbares Build-Artefakt namens `meloni-snake-nes`.

## Auf der HU-086 spielen

Kopiere `snake.nes` auf eine FAT32-MicroSD-Karte nach `roms/nes/` und starte es über den NES-Menüpunkt in Retro-Go.

- Steuerkreuz: bewegen
- START oder A: starten / nach Game Over erneut spielen
- B: pausieren und fortsetzen

Die Schlange wächst beim Fressen, wird schrittweise schneller und endet beim Zusammenstoß mit Wand oder eigenem Körper.

## Browser-Vorschau

Öffne `index.html` im Browser. Dort funktionieren Pfeiltasten, WASD, Touch-Steuerkreuz und Wischbewegungen. Der Bestwert wird dort lokal im Browser gespeichert.