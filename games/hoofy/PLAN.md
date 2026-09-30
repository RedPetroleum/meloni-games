# Hoofy – Bauplan

Regeln: [LOOP.md](LOOP.md). Die Phasen geben nur die Reihenfolge vor, der Loop hält an keiner an.

## Rückmeldungen
Hier schreibt der Mensch, was nach dem Konsolentest anders sein soll. Der Loop erledigt das vor
der nächsten Aufgabe und hakt es ab.

- (noch nichts)

## Auf der Konsole testen
Checklisten des Loops für jede fertige Phase.

**Phase 0 (Version 0.0.1)**
- [ ] Hoofy erscheint nach „Update games“ im Meloni-Tab, mit Cover.
- [ ] Titel → START oder A → Welt; herumlaufen, B hält zum Rennen, START pausiert.
- [ ] Ruckelt das Scrollen? (Die Karte ist noch ein Platzhalter aus Ausgebüxt.)

## Stand
- Phase 0 fertig (0.0.1): Gerüst, Test-Werkzeug (Szenarien, Selbsttest), Katalog-Generator.
- Phase A läuft: A1–A6 fertig (Karte, Spieler, Pferdegrafik, Pferdemodell, Wildpferde, Blasen).

## Aufgaben

Szenario = Ausgangslage aus `game/scenarios.lua`, gestartet mit `tools/hoofy-test.sh`.
Selbsttest = Test in `game/tests/`, läuft im Szenario `selftest`.

### 0 Grundlagen

- [x] **0.1 Gerüst**: `main.lua`, `meta.json` (api 1, version 0.0.1), Szenen Titel/Welt wie Ausgebüxt,
  `lib/` aus Ausgebüxt übernommen. Titel → Welt mit START oder A.
  Prüfung: `make test` grün, Screenshot zeigt die Welt (nicht den Titel).
  *Erledigt:* Szenen `game/title.lua`, `game/world.lua`, `lib/` und `sprites.txt` aus Ausgebüxt,
  Platzhalter-Karte `game/maps.lua` (ersetzt A1; `lib/tilemap.lua` hat noch Tabellen je Kachel).
- [x] **0.2 Test-Werkzeug**: `game/scenarios.lua`, Szenario `selftest`, `tools/hoofy-test.sh` (siehe LOOP.md).
  Prüfung: `tools/hoofy-test.sh selftest` loggt `SELFTEST OK`; ein absichtlich falscher Test
  lässt es mit Status 1 enden (danach wieder entfernen).
  *Erledigt:* beides geprüft. Szenario = Funktion in `game/scenarios.lua`, Testmodule in
  `game/tests/list.lua` eintragen, Prüfhelfer `game/tests/check.lua`, `SCENARIO_OPTS='only = "util"'`.
- [x] **0.3 Katalog-Generator**: `tools/hoofy_katalog.py` liest die Tabellen aus KATALOG.md und
  schreibt `games/hoofy/data/*.lua` (je Abschnitt ein Modul), läuft bei `make test/shot/run` mit.
  Prüfung: Selbsttest: 12 Rassen, Mustang Tempo 40, Einhorn Grundwert 10000, 30 Farben in 5 Stufen,
  Farbmatrix für jede Rasse; Katalogwert ändern → nach `make test` im Spiel geändert.
  *Erledigt:* 15 Module (`data/zeit.lua` … `data/wirtschaft.lua`), Zugriff über `game/katalog.lua`
  (`K.rasse("mustang")`). Geprüft an einer Kopie (Mustang Tempo 41 → `data/rassen.lua` geändert),
  KATALOG.md selbst blieb unberührt. Werte werden per Muster aus dem Text gelesen: Wird eine Zeile
  umformuliert, bricht der Generator mit Abschnitt und Muster ab, dann das Muster anpassen.
  `make test` führt jetzt auch `tools/hoofy-test.sh selftest` aus.

### A Pferdeleben

- [x] **A1 Kartengenerator Heimattal**: 96×80 Kacheln aus Seed, Wiesen, Wald, Fluss mit Brücken,
  Wege, Hof-Grundstück, Dorf (E12), Palette „sattgrün“. Technik nach LOOP.md.
  Prüfung: Szenario `karte_ganz` zeichnet die Karte verkleinert (1 Kachel = 2 px) → Screenshot
  ansehen; Selbsttest: gleicher Seed = gleiche Karte, jeder begehbare Bereich vom Hof erreichbar
  (Flutfüllung); Speicher geloggt.
  *Erledigt:* `game/mapgen.lua`, neue `lib/tilemap.lua` (Ebenen als Strings je Zeile, Objekte in
  16×16-Blöcken, höchstens 12 Blöcke mit Zeichenteilen), `lib/rng.lua`. Szenario `karte_ganz`
  (`SCENARIO_OPTS='seed = 2'`), Seeds 1–5 angesehen. Selbsttest 5 Seeds erreichbar.
  Speicher: Karte 198 KB, Lua gesamt 482 KB. Entscheidungen E17–E21.
- [x] **A2 Spieler und Kamera**: Figur (Sprites, 4 Richtungen, Laufanimation), rennen mit B,
  Kollision, Kamera folgt, Tiefensortierung.
  Prüfung: Shot-Sheet eines Laufs quer über Wiese, Brücke, am Wald entlang.
  *Erledigt:* Figur aus Ausgebüxt, dazu Staub beim Rennen, Umriss hinter Bäumen (E22), Waldkachel
  als runde Kronen. Szenario `welt` mit `SCENARIO_OPTS='ort = "bruecke"'` (oder `cx = …, cy = …`).
  Selbsttest: über die Brücke ja, ins Wasser und in den Wald nein.
- [x] **A3 Pferdegrafik**: 4 Körperformen (Pony, Warmblut, Kaltblut, Einhorn) × 4 Richtungen ×
  stehen/gehen/galopp, alle ~30 Farben per `recolor`, Muster als Overlay, Nachtvarianten (E14).
  Vorlage: Pferde aus Ausgebüxt/Hufhüpfer.
  Prüfung: Szenario `galerie` zeigt alle Rassen und je 3 Farben, Shot-Sheet mit Animation.
  *Erledigt:* `game/horse_gfx.lua` (`G.draw(farbe, körper, pose, x, y, flip)`), 23 Grundfarben +
  6 Muster (E23), Körper abgeleitet (E24), Galopp von Hand. Nachtvarianten gestrichen (E14 geändert).
  sprites.png jetzt 256×2498 (≈ 1,8 MB auf der Konsole), sprites.lua ≈ 150 KB Lua-Speicher:
  auf der Konsole Ladezeit und Speicher prüfen.
- [x] **A4 Pferdemodell**: Gen/Training/Max-Potenzial, Zustände, Charakter, Geschlecht, sichtbare
  und versteckte Farbe, Name; Wildpferd-Erzeugung nach KATALOG §2–5 (Gebiet → Rasse → Farbe).
  Prüfung: Selbsttest mit 10 000 Wildpferden: Mittelwert/σ der Gen-Stats ≈ Katalog,
  Farbstufen ≈ 40/30/18/9/3 % (±2), Max-Potenzial nie über 100, Ausdauer 50–100.
  *Erledigt:* `game/horse_model.lua` (`H.wild{gebiet, rasse, rng}`, `H.stat`), Selbsttest `pferd`:
  Haflinger Mittel/σ passen, Shetlandpony 40,7/30,1/17,3/9,0/2,9 %. Entscheidungen E25–E27.
- [x] **A5 Wildpferde in der Welt**: 4 gleichzeitig, grasen/wandern/fliehen, Wechsel alle 3 Tage.
  Prüfung: Shot-Sheet; Selbsttest Wechsel nach 3 Tagen (1–2 neue).
  *Erledigt:* `game/wild.lua` (`Wild:new_day(tag)` ruft A12 beim Tageswechsel auf), Szenario
  `wildpferde`. Fliehen bei < 72 px, weit entfernte Pferde nur alle 30 Frames. Wechsel nur
  getestet, noch nicht an einen Tageszähler gehängt (kommt mit A12).
- [x] **A6 Sprechblasen**: Emoji-Sprites, Vorrang und Schwellen (E10, E11), Charakter-Blasen.
  Prüfung: Szenario `blasen` mit je einem Pferd pro Zustand, Screenshot.
  *Erledigt:* `game/bubbles.lua` (`B.choose(pferd, frame)`), 5 neue Symbole (Nase, Dreck, Mond,
  Glitzer, Apfel), Wildpferde zeigen Angst beim Fliehen. Charakter-Blase alle 12 s für 2 s.
- [ ] **A7 Zähmen**: Minispiel nach E16, Schwierigkeit nach Bindung.
  Prüfung: `INPUT`-Drehbuch, das bei SEED 1 zähmt; eines, das beim Hinschauen läuft und scheitert.
- [ ] **A8 Leine und Folgen**: Führen zu Fuß und reitend, Ausreißen nach KATALOG §2 Leine,
  Pferd ab Bindung 70 folgt ohne Leine, ab 90 auf Pfiff.
  Prüfung: Selbsttest Ausreiß-Rate über viele Würfe ≈ 9 % gehend / 27 % reitend bei Bindung 10.
- [ ] **A9 Reiten**: Auf-/Absitzen (E2, E3), Schritt/Galopp, Springen nach Stärke,
  Energieverbrauch nach Katalog, Sattel-Bonus, verweigern bei Bindung < 20.
  Prüfung: Shot-Sheet Ritt mit Sprung über Busch; Selbsttest Energie.
- [ ] **A10 Pflege und Training**: Aktionsmenü (E2), Streicheln, Füttern, Striegeln, Werte
  nach Katalog, Trainingsformel mit Bonus, Charakter-Effekte (KATALOG §5).
  Prüfung: Selbsttests für Trainingsformel, Futterwirkung, Bindungsregeln; Screenshot Menü.
- [ ] **A11 Hof**: Start mit Wohnwagen, Stall S, Weide mit Tor, Bürste (KATALOG §15);
  Pferde in Stall/Weide/frei stellen, Plätze begrenzt, Verluste nach KATALOG §2 Unterbringung.
  Prüfung: Szenario `hof_start`, Screenshot; Selbsttest Verluste pro Tag.
- [ ] **A12 Tag und Nacht**: 5 min pro Tag (3 hell, 2 dunkel), Nachtdarstellung (E14),
  Schlafen im Wohnwagen, Tageswechsel wendet alle Tagesregeln an (Hunger, Gewicht, Sauberkeit,
  Energie-Reset, Fohlenalter …).
  Prüfung: Shot-Sheet Abend → Nacht; Selbsttest Tageswechsel mit Beispielpferd.
- [ ] **A13 Menüs**: HUD (E9), Pausenmenü (E5), Pferdeliste, Pferde-Info (Balken mit Gen,
  Training, Max-Potenzial), Umbenennen mit Bildschirmtastatur, Inventar.
  Prüfung: Screenshot jedes Bildschirms.
- [ ] **A14 Speichern**: beim Schlafen, Gebietswechsel, `_quit`; Weiter-Eintrag im Titel.
  Prüfung: Selbsttest speichern → laden ergibt gleichen Zustand; Größe des Spielstands mit
  24 Pferden geloggt.
- [ ] **A15 Karte**: nur Erkundetes, Spieler mit Blickrichtung, Pferde, Hof (E6).
  Prüfung: Screenshot nach einem Erkundungsritt.
- [ ] **A16 Töne**: Hufe, Wiehern, Menü-Klicks, ruhige Melodie tags/nachts.
  Prüfung: WAV-Ausgabe erzeugt, Protokoll nennt, was zu hören ist.
- [ ] **A-Ende**: Cover, README-Tabelle, version 0.1.0, Konsolen-Checkliste, Push.

### B Wirtschaft und Zucht

- [ ] **B1 Geld und Laden**: Startgeld 300, Laden im Dorf (Futter, Bürste, Sättel, Schmuck,
  Satteltaschen, Samen), Hausinventar, Bauelemente zum Kaufpreis zurück.
  Prüfung: Szenario `laden`, Screenshot; Selbsttest Kauf/Verkauf.
- [ ] **B2 Pferdewert und Markt**: Formel KATALOG §6, Pferdemarkt (kaufen × 1,3).
  Prüfung: Selbsttest Beispielwerte.
- [ ] **B3 Käufer**: täglich ein Käufer am Hof, 4 Typen mit Formeln, Folgen und mehreren
  Sprüchen je Pferdetyp.
  Prüfung: Selbsttest Preise und Folgen; Screenshot Dialog.
- [ ] **B4 Bestellungen**: alle 3 Tage, Frist 5–10 Tage, Bonus.
  Prüfung: Selbsttest Erzeugen/Erfüllen/Verfallen.
- [ ] **B5 Jobs**: Jobbrett im Dorf, KATALOG §12, ein Job je Pferd und Tag.
  Prüfung: Selbsttest Lohn/Training/Energie; Screenshot.
- [ ] **B6 Zucht**: Hengst + Stute im Stall, Trächtigkeit, Pause, Fohlen wächst in 4 Tagen,
  Gen-Vererbung, Farbvererbung mit Mutation, Rasse 50:50, Premiumfutter für Fohlen.
  Prüfung: Selbsttest Farbanteile 35/15/35/15 (±2) über viele Fohlen, Gen-Stats ≈ Elternmittel.
- [ ] **B7 Stammbaum und Inzucht**: Stammbaum-Bildschirm (3 Generationen), Inzucht-Malus.
  Prüfung: Selbsttest Malus je Verwandtschaftsgrad; Screenshot.
- [ ] **B8 Wirtschaft prüfen**: Simulation einer einfachen Spielweise über 20 Tage, Vergleich
  mit KATALOG §15 Phase 1–2. Abweichungen nur in ENTSCHEIDUNGEN.md unter „Balance“ melden.
  Prüfung: Protokoll mit Tagen bis Fahrrad und Mofa.
- [ ] **B-Ende**: Cover, version 0.2.0, Konsolen-Checkliste, Push.

### C Hof bauen

- [ ] **C1 Baumodus**: Cursor (E8), Kategorien, Kosten, Abreißen mit Erstattung, Kollision,
  nur auf dem Grundstück.
  Prüfung: `INPUT`-Drehbuch baut Bank und Weg, Screenshot.
- [ ] **C2 Zäune und Weiden**: Zaunelemente, Tor, geschlossene Weide per Flutfüllung erkennen,
  mehrere Weiden, Plätze nach Fläche.
  Prüfung: Selbsttest offene/geschlossene Weide; Screenshot.
- [ ] **C3 Gebäude**: Ställe S–XL, Häuschen/Villa, Schuppen/Garage/Hangar.
  Prüfung: Screenshot aller Gebäude; Selbsttest Stallplätze.
- [ ] **C4 Hof-Schönheit**: Summe, Bindungsbonus ab 50/150/400.
  Prüfung: Selbsttest.
- [ ] **C5 Anbau**: Beete/Felder, Samen, Wachstum, Ernte ins Inventar (KATALOG §7).
  Prüfung: Selbsttest über Tage; Shot-Sheet Wachstum.
- [ ] **C6 Göpel-Generator**: 40 je Pferd und Tag, Bedingungen.
  Prüfung: Selbsttest.
- [ ] **C7 Land kaufen**: 10×10-Stücke, steigender Preis, bis zum ganzen Startgebiet.
  Prüfung: Selbsttest Preise; Screenshot Grundstücksgrenze.
- [ ] **C-Ende**: Cover, version 0.3.0, Konsolen-Checkliste, Push.

### D Welt

- [ ] **D1 Fahrzeuge**: Zugfahrzeuge und Anhänger kaufen, Garage nötig, Reisemenü am Fahrzeug,
  Fahrtkosten, Pferde im Anhänger mitnehmen.
  Prüfung: Szenario `reise`, Screenshots Menü und Ankunft.
- [ ] **D2 Gebiete 2–6**: Generator mit Palette, Größe, Wildpferden und Rassen je Gebiet
  (KATALOG §10), frühere Rassen seltener.
  Prüfung: Szenario `karte_ganz` für jedes Gebiet; Speicher beim größten Gebiet geloggt.
- [ ] **D3 Schätze**: 15–30 je Gebiet, Aufspüren nach KATALOG §11 (E4), Satteltaschen →
  Fahrzeug → Hausinventar, Aufspürung +1 je Fund.
  Prüfung: Selbsttest Radius/Chance; `INPUT`-Drehbuch findet einen Schatz.
- [ ] **D4 Wetter**: Regen (Sprites/Linien), Sauberkeit −15 draußen.
  Prüfung: Shot-Sheet; Selbsttest.
- [ ] **D5 Sattellampe und Nachtsicht** (E14).
  Prüfung: Screenshot nachts mit und ohne Lampe.
- [ ] **D-Ende**: Cover, version 0.4.0, Konsolen-Checkliste, Push.

### E Turniere und Chaos

- [ ] **E1 Turniere**: Turnierplatz, 6 Klassen nach Fahrzeug, Startgebühr, Chancen vorab,
  Rotation alle 3 Tage, Wettbewerb nach Teilnahme weg; Schönheitswettbewerb berechnet.
  Prüfung: Selbsttest Wertung; Screenshot.
- [ ] **E2 Minispiel Springreiten**: Parcours, Stärke → Sprunghöhe, Ausdauer → Leistungsabfall.
  Prüfung: `INPUT`-Drehbuch, Shot-Sheet.
- [ ] **E3 Minispiel Pferderennen**: Tempo, Ausdauer, Gegner.
  Prüfung: `INPUT`-Drehbuch, Shot-Sheet.
- [ ] **E4 Reformen**: Zeitung alle 4 Tage, alle Reformen aus KATALOG §14, Hunde/Wölfe/Krokodile
  nachts (Krokodile auch tags), zerstören Deko, starke Pferde wehren ab.
  Prüfung: Selbsttest Reform-Wirkungen; Screenshot Zeitung und Hundenacht.
- [ ] **E5 Sammelalbum**: jede entdeckte Kombination Rasse × Farbe.
  Prüfung: Screenshot.
- [ ] **E6 Tauschcode**: Pferd → Code (Vorschlag Katalog: 16 Zeichen A–Z, 2–9), Code → Pferd,
  Prüfsumme gegen Tippfehler, Pferd danach weg.
  Prüfung: Selbsttest Hin- und Rückweg für 1 000 Zufallspferde, falscher Code abgelehnt.
- [ ] **E-Ende**: Cover, version 0.5.0, Konsolen-Checkliste, Abschluss nach LOOP.md, Push.
