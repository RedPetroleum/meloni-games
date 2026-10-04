# Hoofy 3D 🐎

[Hoofy](../../games/hoofy/README_HOOFY.md) als realistisches 3D-Reitspiel für das **Steam Deck**,
gespielt aus der Third-Person-Sicht, angelehnt an Red Dead Redemption, Ostwind und Star Stable.
Alle Mechaniken aus dem 2D-Hoofy sollen erhalten bleiben (Fahrplan unten); Rassen, Farben,
Werte und Charakterzüge kommen direkt aus den Hoofy-Daten.

Engine: **Godot 4.7** (frei, läuft am Mac zum Entwickeln und exportiert nativ für Linux/Steam Deck,
Szenen und Skripte sind Text, also gut mit KI-Assistenten zu bearbeiten).

## Loslegen

```sh
python3 tools/assets.py        # Grafik laden (~30 MB, nicht im Git)
python3 tools/hoofy_daten.py   # Rassen/Farben aus games/hoofy/data/*.lua → data/hoofy.json
~/Applications/Godot.app/Contents/MacOS/Godot --path .    # spielen
~/Applications/Godot.app/Contents/MacOS/Godot -e --path . # im Editor öffnen
```

Godot ist nach `~/Applications/Godot.app` installiert (von godotengine.org, macOS universal).

| Steam Deck / Gamepad | Tastatur/Maus | |
|---|---|---|
| linker Stick | WASD | reiten (Richtung relativ zur Kamera) |
| rechter Stick | Maus | Kamera |
| A | Shift | antreiben: tippen = eine Gangart schneller, halten = Tempo halten |
| B | Strg | zügeln: eine Gangart langsamer, halten = anhalten |
| X | Leertaste | springen |
| L3 | mittlere Maustaste | Kamera hinter das Pferd |
| | F3 | Leistungsanzeige (fps, Dreiecke) |

Gangarten: Schritt → Trab → Galopp → Renngalopp. Der Renngalopp kostet Energie (Vorrat =
Hoofy-Ausdauer); fehlt Energie, fällt das Pferd in den Galopp zurück. Tempo und Sprunghöhe
hängen vom Tempo- und Stärke-Wert des Pferdes ab.

## Aufs Steam Deck

```sh
tools/deck_export.sh                                 # baut export/steamdeck/hoofy3d.x86_64 + .pck
DECK=deck@steamdeck.local tools/deck_export.sh       # und kopiert per SSH nach ~/Games/hoofy3d
```

1. Beim ersten Mal lädt das Skript Godots Export-Vorlagen (~1 GB).
2. Den Ordner `export/steamdeck/` aufs Deck bringen: USB-Stick, Netzwerkfreigabe oder per SSH
   (auf dem Deck im Desktop-Modus einmalig `passwd` setzen und `sudo systemctl enable --now sshd`).
3. Auf dem Deck im **Desktop-Modus**: Steam → *Spiel hinzufügen* → *Nicht-Steam-Spiel
   hinzufügen* → `hoofy3d.x86_64` auswählen.
4. Zurück in den **Gaming-Modus**: Hoofy 3D steht in der Bibliothek. Im Schnellmenü (…) ein
   Bildraten-Limit von **40 fps** einstellen.

Das Spiel erkennt das Deck (`SteamDeck=1`) und schaltet auf die Deck-Grafikstufe: FSR-Hochskalierung
von 77 %, weniger Gras, kürzere Schatten, kein Volumennebel. Erzwingen am Mac: `-- --deck`.

## Aufbau

| Datei | Inhalt |
|---|---|
| [scripts/main.gd](scripts/main.gd) | baut die Welt zusammen |
| [scripts/gelaende.gd](scripts/gelaende.gd) | Heimattal 1 × 1 km aus festem Seed: Höhen, See, Wege, Wald- und Wiesenmasken, Kollision |
| [scripts/bewuchs.gd](scripts/bewuchs.gd) | verteilt Bäume, Büsche, Felsen, Farne, Blumen (MultiMesh in Zellen, zwei Detailstufen) |
| [scripts/baumbauer.gd](scripts/baumbauer.gd) | erzeugt Laubbäume, Fichten, Büsche und Blatttexturen aus Code |
| [scripts/gras.gd](scripts/gras.gd) | Grashalme um das Pferd, weichen dem Pferd aus |
| [scripts/himmel.gd](scripts/himmel.gd) | Tag/Nacht (Sommer, 24 Minuten pro Tag), Sonne, Mond, Sterne, Nebel |
| [scripts/pferd.gd](scripts/pferd.gd) | Reitsteuerung, Gangarten, Energie, Sprung, Neigung am Hang und in Kurven |
| [scripts/pferd_modell.gd](scripts/pferd_modell.gd) | Modell laden, Größe je Rasse, Fell, Animation je Gangart |
| [scripts/wildpferde.gd](scripts/wildpferde.gd) | Herden: grasen, wandern, fliehen |
| [scripts/anzeige.gd](scripts/anzeige.gd) | Bildschirmanzeige |
| [scripts/hoofy_daten.gd](scripts/hoofy_daten.gd) | Hoofy-Daten plus Fellfarben und Körpermaße |
| [shaders/fell.gdshader](shaders/fell.gdshader) | alle 30 Hoofy-Farben inkl. Schecke, Tupfen, Äpfel, Zebra, Regenbogen, Schlamm |
| [scripts/einstellungen.gd](scripts/einstellungen.gd) | Tastenbelegung, Grafikstufen |
| [scripts/testlauf.gd](scripts/testlauf.gd) | automatische Testläufe mit Screenshots |

### Testen

Wie `make shot` bei den Konsolenspielen, mit Drehbuch (60 Frames = 1 s, Aktionen aus
`einstellungen.gd`). Screenshots landen in `../../build/hoofy3d/`.

```sh
tools/shot.sh --shots=150,400 --zeit=17.5 --pos=-140,150 --yaw=146 --input="60-400:vor,90:antreiben"
tools/shot.sh --deck --frames=600 --ohne=gras,schatten     # Leistung messen, Teile abschalten
```

Weitere Optionen: `--farbe=palomino`, `--rasse=friese`, `--seed=3`.

### Grafik austauschen

- **Pferd:** Das jetzige Pferd ist ein kantiger Platzhalter (three.js-Beispiel, nur Galopp).
  Ein besseres Modell als `.glb` ablegen und `MODELL` in `pferd_modell.gd` darauf setzen.
  Animationen werden über Namen gefunden (`idle`, `walk`, `trot`, `canter`/`gallop`, `jump`,
  `eat`); Fell, Rassengröße und Steuerung funktionieren ohne weitere Änderungen.
  Quellen: Sketchfab (viele kostenlos, CC-BY, Account nötig), Fab/CGTrader (kostenpflichtig),
  KI-Generatoren (Meshy, Tripo).
- **Spielfigur:** Mixamo (kostenlos, Account nötig) für Figur und Animationen.

## Fahrplan

Alles aus [README_HOOFY.md](../../games/hoofy/README_HOOFY.md) in 3D. ✅ = in Hoofy 3D vorhanden.

### Grundlage
- [x] Godot-Projekt, Steam-Deck-Export, Grafikstufen, Gamepad-Steuerung
- [x] Heimattal aus festem Seed: Hügel, Berge ringsum, See, Wege, Wald, Wiesen
- [x] Gras, Bäume, Büsche, Felsen, Farne, Blumen
- [x] Tag/Nacht, Sterne, Nebel
- [x] Reiten aus der Third-Person-Sicht: Schritt, Trab, Galopp, Renngalopp, Springen
- [x] Hoofy-Daten: Rassen, Farben (Seltenheit), Werte, Charakterzüge
- [x] Fellfarben und Muster aller 30 Hoofy-Farben
- [x] Wildpferdeherden (grasen, wandern, fliehen)
- [ ] Realistisches Pferdemodell mit Animationen für alle Gangarten
- [ ] Rassen mit eigenen Proportionen (Knochen je Rasse) sowie Mähne, Schweif und Behang
- [ ] Schönere Bäume: mehrere Arten (Birke, Eiche, Buche, Fichte), feinere Blätter
- [ ] Abendhimmel und Wasserspiegelungen verbessern
- [ ] Geräusche: Hufe je Untergrund, Schnauben, Wind, Vögel, Musik
- [ ] Spielfigur: zu Fuß laufen, auf- und absteigen, im Sattel sitzen
- [ ] Hauptmenü, Pause, Speichern/Laden

### Das Pferd (Hoofy §2)
- [ ] Werte: Gen- und Trainingsanteil, Max-Potenzial, Hunger, Gewicht, Sauberkeit, Bindung
- [ ] Merkmale: Fohlen/erwachsen, Geschlecht, Charakterzug, Name vergeben
- [ ] Emojis als Sprechblasen über dem Pferd (Hunger, Schmutz, Charakter)
- [ ] Aufspüren von Schätzen, Blumen, Samen
- [ ] Ausrüstung: Sättel, Satteltaschen, Lampen
- [ ] Stammbaum

### Mit Pferden spielen (Hoofy §3)
- [ ] Zähmen als Anschleich-Minispiel (bewegen, wenn es wegschaut; stehen bleiben, wenn es guckt)
- [ ] Leine: führen zu Fuß und beim Reiten, Ausreißen bei niedriger Bindung
- [ ] Folgen ohne Leine, Pfiff bei hoher Bindung
- [ ] Heimbringen auf Weide oder in den Stall
- [ ] Füttern, Striegeln, Streicheln, Schmücken
- [ ] Training durch Reiten und Springen
- [ ] Jobs: Kutschtaxi, Postritt, Pflügen
- [ ] Unterbringung: Stall, Weide, frei auf dem Grundstück
- [ ] Zucht: Gen-Vererbung, Farbgenetik (sichtbar/versteckt), Rassen mischen, Inzucht-Malus, Fohlen wachsen

### Geld (Hoofy §4)
- [ ] Laden, Pferdemarkt, Futter und Samen kaufen
- [ ] Käufer: Sammlerin, Reithof, Züchter, Schlachter; Bestellungen
- [ ] Turniere: Schönheitswettbewerb, Springreiten, Rennen, Siegerpodest

### Hof (Hoofy §5)
- [ ] Baumodus: Haus, Stall, Weiden mit Zäunen und Tor, Garage, Deko
- [ ] Maschinen: Göpel/Stromgenerator mit Pferd
- [ ] Beete, Felder, Obstbäume; Ernte ins Hausinventar
- [ ] Land dazukaufen

### Fahrzeuge und Welt (Hoofy §6, §7)
- [ ] Fahrzeuge vom Fahrrad bis zum Flugzeug, Pferdeanhänger
- [ ] Weitere Gebiete: Birkenwald, Flussauen mit Furten, Steppe, Canyon, Nebelinsel
- [ ] Wetter (Regen macht Pferde schmutzig)
- [ ] Karte (nur Erkundetes)
- [ ] Regierungsreformen mit Zeitung: Steuern, Tierangriffe (Hunde, Wölfe, Krokodile)

### Extras (Hoofy §8)
- [ ] Garderobe: Hut, Frisur, Haarfarbe, Ober- und Unterteil
- [ ] Sammelalbum
- [ ] Tauschcode (kompatibel zum 2D-Hoofy?)

## Lizenzen der Grafik

- Poly Haven (polyhaven.com): CC0
- Platzhalter-Pferd: three.js-Beispiel `Horse.glb` (aus „ROME“ von Mirada), nur privat
