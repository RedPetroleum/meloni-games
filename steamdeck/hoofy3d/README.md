# Hoofy 3D 🐎

[Hoofy](../../games/hoofy/README_HOOFY.md) als realistisches 3D-Reitspiel für das **Steam Deck**,
gespielt aus der Third-Person-Sicht, angelehnt an Red Dead Redemption, Ostwind und Star Stable.
Alle Mechaniken aus dem 2D-Hoofy sollen erhalten bleiben (Fahrplan unten); Rassen, Farben,
Werte und Charakterzüge kommen direkt aus den Hoofy-Daten.

Engine: **Godot 4.7** (frei, läuft am Mac zum Entwickeln und exportiert nativ für Linux/Steam Deck,
Szenen und Skripte sind Text, also gut mit KI-Assistenten zu bearbeiten).

## Loslegen

```sh
python3 tools/assets.py        # Grafik laden (~50 MB, nicht im Git; das Pferd von Sketchfab
                               # braucht einen API-Token in ~/.sketchfab_token)
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

Gangarten: Schritt → Trab → Galopp → Renngalopp (Trab ist vorerst ein zügiger Schritt, dem
Pferdemodell fehlt die Animation).

## Regeln aus dem 2D-Hoofy

Alle Werte und Regeln kommen aus [KATALOG.md](../../games/hoofy/KATALOG.md) und
[ENTSCHEIDUNGEN.md](../../games/hoofy/ENTSCHEIDUNGEN.md); Daten liest `tools/hoofy_daten.py`
direkt aus `games/hoofy/data/*.lua` und `games/hoofy/game/horse_model.lua`. Umgesetzt:

- Wildpferde wie `H.wild`: Rasse (Gebiet dreifach), Farbe nach Farbtabelle der Rasse und
  Seltenheit je Gebiet, versteckte Farbe, Gen-Werte (σ 8), Max-Potenzial (Spanne ± σ 5),
  Bindung (Rasse ± 5 + Charakterzug), Hunger/Gewicht/Sauberkeit, Name aus den Hoofy-Listen.
  4 gleichzeitig im Heimattal, alle 3 Tage wechseln 1–2.
- Reiten wie `game/ride.lua`: Tempo = wirksames Tempo (Gewichtsmalus) + Sattel-Bonus, wirkt im
  Hoofy-Verhältnis auf Schritt und Galopp; Sprunghöhe 6 + 0,3 × Stärke (16 px = 1 m), Sprung
  5 Energie; bei 0 Energie nur langsamer Schritt, kein Sprung.
- Anzeige wie E9/E82: oben Sonne/Mond mit Balken, Gebiet, Geld; unten beim Reiten Energie;
  „Tag N“ groß zum Tagesbeginn.
- Heimattal wie E12/E20: Hof in der Mitte, Dorf östlich, Fluss von Nord nach Süd im Westen, nur
  über die Brücke passierbar, Wege zu Dorf, Nord-, Süd- und Westrand, dichter Waldrand.

Für 3D angepasst (entschieden 2026-10-05):

| Hoofy | Hoofy 3D | Warum |
|---|---|---|
| Tag 5 min (3 hell, 2 dunkel) | 10 min (6 hell, 4 dunkel), Start am Morgen | in 3D braucht man länger durchs Tal |
| Energie: Reiten 1 je 10 s, Galopp doppelt | 1 je 20 s, Galopp doppelt, Renngalopp vierfach | gleicher Tagesvorrat bei doppelt langem Tag |
| Steuerkreuz + B halten = Galopp, A = Sprung | wie Red Dead: A tippen = schneller, B = langsamer, X = Sprung | Wunsch |
| Schritt, Galopp | Schritt, Trab, Galopp, Renngalopp | Wunsch |
| Heimattal 96 × 80 Kacheln | 1 × 1 km, Berge ringsum | 3D-Maßstab |
| Zähm-Zone 110 px (≈ 7 m), Zähmen ab 26 px | Zone 20 m, Zähmen ab 3,5 m | man sieht in 3D weiter |
| Zähmen nur zu Fuß | vorerst auch vom Pferd aus (Y/E halten) | bis es die Spielfigur gibt |

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

- **Pferd:** Neues Modell in `MODELLE` (`pferd_modell.gd`) eintragen: Pfad, Knochen für Hufe,
  Widerrist, Kopf, Schweif, Materialnamen (Fell, Haar, Ausrüstung) und die Animationen je
  Gangart. Ausrichtung, Rassengröße, Hoofy-Fellfarben und Muster passen sich von selbst an.
  Quellen: Sketchfab (viele kostenlos, CC-BY, Account nötig), Fab/CGTrader (kostenpflichtig),
  KI-Generatoren (Meshy, Tripo).
- **Spielfigur:** Mixamo (kostenlos, Adobe-Account): Figur „Ch37“ und die Animationen aus
  `FigurModell.ANIMATIONEN` als FBX nach `assets/download/figur/` kopieren (nicht im Git).

## Fahrplan

Alles aus [README_HOOFY.md](../../games/hoofy/README_HOOFY.md) in 3D. ✅ = in Hoofy 3D vorhanden.

### Grundlage
- [x] Godot-Projekt, Steam-Deck-Export, Grafikstufen, Gamepad-Steuerung
- [x] Heimattal aus festem Seed wie im 2D-Hoofy: Hof in der Mitte, Dorf, Fluss mit Brücke, Wege, Waldrand, Berge
- [x] Gras, Bäume, Büsche, Felsen, Farne, Blumen
- [x] Tag/Nacht, Sterne, Nebel
- [x] Reiten aus der Third-Person-Sicht: Schritt, Trab, Galopp, Renngalopp, Springen
- [x] Hoofy-Daten: Rassen, Farben (Seltenheit), Werte, Charakterzüge
- [x] Fellfarben und Muster aller 30 Hoofy-Farben
- [x] Wildpferde wie im 2D-Hoofy (4, Wechsel alle 3 Tage; grasen, wandern, fliehen)
- [x] Realistisches Pferdemodell (Sketchfab, henry_7) mit Sattel und Zaumzeug
- [ ] Trab-Animation
- [ ] Rassen mit eigenen Proportionen (Knochen je Rasse) sowie Mähne, Schweif und Behang
- [ ] Schönere Bäume: mehrere Arten (Birke, Eiche, Buche, Fichte), feinere Blätter
- [ ] Abendhimmel und Wasserspiegelungen verbessern
- [ ] Geräusche: Hufe je Untergrund, Schnauben, Wind, Vögel, Musik
- [x] Spielfigur (Mixamo): laufen, rennen, schleichen, springen; Start zu Fuß ohne Pferd wie in Hoofy
- [x] Aufsitzen (Aktionsmenü; frisch gezähmt nicht, Bindung < 20 verweigert zu 50 %), Absteigen (Y halten)
- [x] Reitsitz: Sitz aus den Steigbügel-Knochen, Beine und Hände per IK, Zügel
- [x] Training beim Reiten (E31): Ausdauer, Tempo im Galopp, Stärke beim Sprung, Bindung je Minute
- [ ] Reitsitz: noch nicht wie im Vorlagebild (Hände, Oberschenkel). Besser als weiteres Nachbiegen:
      eine fertige Reitanimation suchen (Sketchfab/Animationspaket) und aufs Pferd setzen.
      Messen: `tools/shot.sh --probepferd --rasse=mustang --mess --frames=90` (Lagen relativ zum Sitz)
- [ ] Figur beim Auf-/Absteigen animieren, Oberkörper im Galopp mitgehen lassen
- [x] Pausenmenü (E34): Weiter, Pferde, Speichern; Inventar, Karte, Bauen, Album ausgegraut; Bestellungen, Zeitung, Tauschen erst ab ihrem Tag
- [x] Pferdeliste, Info-Seite mit 3D-Bild, Balken und Wert (KATALOG §6), Umbenennen mit Bildschirmtastatur
- [x] Speichern/Laden (E35): Geld, eigene Pferde, Namen, Tag; Wildpferde werden neu gewürfelt
- [ ] Titelbild mit „Weiter“ / „Neues Spiel“, Speichern beim Schlafen und Beenden

### Das Pferd (Hoofy §2)
- [ ] Werte: Gen- und Trainingsanteil, Max-Potenzial, Hunger, Gewicht, Sauberkeit, Bindung
- [ ] Merkmale: Fohlen/erwachsen, Geschlecht, Charakterzug, Name vergeben
- [ ] Emojis als Sprechblasen über dem Pferd (Hunger, Schmutz, Charakter)
- [ ] Aufspüren von Schätzen, Blumen, Samen
- [ ] Ausrüstung: Sättel, Satteltaschen, Lampen
- [ ] Stammbaum

### Mit Pferden spielen (Hoofy §3)
- [x] Zähmen wie im 2D-Hoofy: Lärmpegel mit ❗, Flucht, Taste halten und stillstehen
- [x] Leine: führen (2 am Strick, 4 insgesamt), Ausreißen je Sekunde gewürfelt, neue Pferde werden wieder wild
- [x] Folgen ohne Leine ab Bindung 100
- [ ] Pfiff ab Bindung 90, Aufsitzen auf eigene Pferde, frisch gezähmt nicht reitbar
- [ ] Heimbringen auf Weide oder in den Stall
- [x] Aktionsmenü am eigenen Pferd: Streicheln, Füttern (Vorrat), Striegeln (mit Bürste), Leine, Unterbringen, Info
- [ ] Schmücken, Ausrüsten, Aufsitzen auf eigene Pferde
- [ ] Training durch Reiten und Springen
- [ ] Jobs: Regeln fertig (`scripts/jobs.gd`: Voraussetzung, Lohn nach Ergebnis, Energie, Training).
      Gespielt werden sie später in der 3D-Welt (entschieden 2026-10-07, die 2D-Minispiele passten nicht):
      Postritt = Briefe im Vorbeireiten in Briefkästen, Kutschtaxi = Fahrgäste mit der Kutsche,
      Pflügen = Takt auf dem Feld neben dem Hof
- [x] Unterbringung: Stall S (2 Plätze), Weide (4), frei (8, ab Stärke 60 und Bindung 70); Herausholen am Stall
- [x] Tageswechsel wie days.lua: Bindung aus Hunger/Sauberkeit, Gewicht, Unterbringungs-Verlust, Hunger, Energie, Fohlenalter, Nachteule
- [x] Heimgebracht: auf dem Grundstück gewesen = nicht mehr „neu“
- [ ] Zucht: Gen-Vererbung, Farbgenetik (sichtbar/versteckt), Rassen mischen, Inzucht-Malus, Fohlen wachsen

### Geld (Hoofy §4)
- [x] Laden mit sechs Reitern (Futter, Sättel, Zubehör, Schmuck, Samen, Fahrzeuge), Inventar, Ausrüsten
- [x] Schlafen im Wohnwagen (ab dem Abend), überspringt die Nacht, speichert
- [x] Pferdemarkt (E39): 4 Pferde, alle 3 Tage neu, Wert ×1,5, gekaufte an die Leine
- [x] Käufer (E40): ab Tag 5 täglich einer im Dorf (Sammlerin ab Tag 9), Formeln, Sprüche, Folgen, Rückfrage
- [x] Freischalten nach Spieltag mit Meldung am Morgen (fortschritt.lua)
- [ ] Bestellungen
- [ ] Turniere: Schönheitswettbewerb, Springreiten, Rennen, Siegerpodest

### Hof und Dorf im Heimattal (E12, E20, E32)
- [x] Grundstück 20 × 20 Kacheln (1 Kachel = 2,5 m), Wohnwagen und Stall S im Norden, Weide mit Tor im Süden
- [x] Dorf: Laden, Pferdemarkt mit Koppel, Jobbrett, Turnierplatz mit Hindernissen, Namensschilder
- [ ] Wohnhaus im Dorf

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

- Hof und Dorf von Sketchfab, alle CC-BY 4.0:
  „Mobile Home“ von geevisual55, „House Farm wood“ von Mehdi Shahsavan, „General Store“ von
  sixpence, „Medieval Market Stall Asset 4/4“ von Uğur Yakışık, „Show jumping“ von Every 3D
  (Links: `SKETCHFAB` in tools/assets.py, https://sketchfab.com/3d-models/<id>)
- Spielfigur und Animationen: Mixamo (Adobe), frei nutzbar
- Pferd: „Horse“ von henry_7, https://sketchfab.com/3d-models/horse-a6f860e43e364619bccb174a1ac7d0c9 (CC-BY 4.0)
- Poly Haven (polyhaven.com): CC0
- Ersatz-Pferd ohne Sketchfab-Token: three.js-Beispiel `Horse.glb` (aus „ROME“ von Mirada), nur privat
