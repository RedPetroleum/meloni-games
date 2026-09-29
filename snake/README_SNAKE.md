# Snake

Snake für die HU-086 als Game-Boy-Color-kompatible ROM. Das Spiel nutzt die native Game-Boy-Auflösung von 160 × 144 Pixeln und vier ruhige Farben. Der vorhandene \`retro-core\` in eurer HU-086-Firmware lädt Game-Boy- und Game-Boy-Color-ROMs; dafür ist keine Firmware-Änderung nötig.

## ROM bauen

Mit [GBDK-2020 4.5.0](https://github.com/gbdk-2020/gbdk-2020/releases/tag/4.5.0):

\`\`\`sh
make -C snake GBDK_HOME=/pfad/zu/gbdk
\`\`\`

Das Ergebnis ist \`snake/snake.gbc\`. Nach einem passenden Push baut GitHub Actions die ROM, prüft das Game-Boy-Color-Header-Flag und legt sie sowohl als Build-Artefakt \`meloni-snake-gbc\` als auch im Repository ab.

## Auf der HU-086 spielen

Kopiere \`snake.gbc\` auf die FAT32-MicroSD-Karte nach \`roms/gb/\` und starte das Spiel im Game-Boy-Menü von Retro-Go. Die Firmware führt die Einträge \`gb\` und \`gbc\` über denselben Game-Boy-Core aus.

- Steuerkreuz: bewegen
- A oder START: starten / nach Game Over erneut spielen
- B: pausieren und fortsetzen

Die Schlange startet langsam und wird alle fünf gefressenen Früchte etwas schneller. Es gibt keine Hindernisse im Spielfeld; Wand und eigener Körper beenden den Lauf.
