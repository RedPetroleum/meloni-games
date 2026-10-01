# Hoofy – Bauplan

Regeln: [LOOP.md](LOOP.md). Die Phasen geben nur die Reihenfolge vor, der Loop hält an keiner an.

## Rückmeldungen
Hier schreibt der Mensch, was nach dem Konsolentest anders sein soll. Der Loop erledigt das vor
der nächsten Aufgabe und hakt es ab.

- [x] Menüs 2D mit Kacheln und Icons, hübsch und einfacher zu bedienen. (0.5.1, E63)
- [x] Nachteinbruch graduell: am Abend immer dunkler, bis man nachts schwer sieht. (0.5.1, E63)
- [x] Raster hässlich: echte Transparenz (Engine `shade`, API 2). (0.5.2, E64)
- [x] Beim Fortsetzen stehen Weidepferde außerhalb an der Leine. (0.5.2, E64)
- [x] Meldung am Haus passt nicht in den Kasten; Pflege ohne „Bindung +1“, Pferd zeigt Emojis. (0.5.2, E64)
- [x] Auf dem Grundstück „Dein Hof“ statt „Heimattal“. (0.5.2, E64)
- [x] Funktionen kommen erst später im Spielverlauf dazu, um nicht zu überfordern: Käufer/Sammler erscheinen erst später, Zeitung etc. (0.5.3, E65: Kunden Tag 4, Käufer 5, Turnier 7, Sammlerin/Tauschen 9, Zeitung 10)
- [x] Hunde kommen viel zu früh im Spielverlauf (0.5.3, E65: frühestens Tag 16)
- [x] mache Tage (und proportional Nächte) etwas länger, ca. 25 % (0.5.3, E65: 6:15 min statt 5 min)
- [x] Man kann eine Lampe kaufen, so eine die man oben festhält. wenn man die einmal gekauft hat, wird die automatisch getragen bei nacht. Dann sieht es so aus, wie gerade, dass um einen herum alles etwas heller ist. Wenn man die nicht hat, dann ist alles gleichmäßig dunkel. (0.5.3, E65: Laterne 80 G im Laden, Zubehör)
- [x] man kann auch schon vor Nachteinbruch schlafen. (0.5.3, E65: ab 2 min vor der Nacht)
- [x] Sammler/Händler stehen nicht so nah am Hof, sondern irgendwo im Dorf. (0.5.3, E65: vor dem Wohnhaus)
- [x] wenn man nach unten rennt, soll der partikeleffekt nicht über dem menschen sein, sondern dahinter. (0.5.3, E65: Staub am Boden)
- [x] Die "Bäume" am Gebietsrand sehen unrealistsich aus. mache das vernünftig. (0.5.3, E65: Wald als Blätterdach, 4 Varianten)
- [x] wenn man hinter objekten ist, soll man nicht so xray mäßig aussehen. das nervt. funktion komplett weg. (0.5.3, E65: entfernt)
- [x] Wenn wilde pferde wegrennen sind die zu dumm, weil die konstant in eine richtung laufen, und dann an wänden etc. hängen bleiben. mache das smarter. (0.5.3, E65: weichen Hindernissen aus)
- [x] Pferde sollen nicht durch das weiden tor abhauen können. (0.5.3, E65: allein nicht, mit dir schon)
- [x] man kann immer nur max. 1 Pferd an einer Leine haben. (0.5.3, E65: frei folgende zählen nicht)
- [x] im Baumodus kleines dezentes raster über 2x2. (0.5.3, E65: Punkte an den Kachelecken)
- [x] das Baumenü ist unübersichtlich und verbuggt. auch die steuerung davon vermutlich. (0.5.3, E65: START öffnet Kachel-Auswahl)
- [x] Laden, Pferdemarkt usw. sollen nicht so fett da stehen sondern dezenter und nur wenn man davor steht. (0.5.4, E66: Schrift mit Schatten, nur in der Nähe)
- [x] Pferde Menu: "Wohin" -> "Ort" und Haus Grafik überarbeiten, diese hat einen Knick. (0.5.4, E66)
- [x] im Bauten Menu soll der Name nicht mehr in jeder Kachel stehen. Ganz unten steht der eh, wenn man das feld selektiert. (0.5.4, E66: in allen Bauteil-Menüs nur Bild und Preis)
- [x] Das Raster im Baumodus soll doppelt so grob sein (0.5.4, E66: Punkte alle 2 Kacheln)
- [x] bei der Grundstückerweiterung soll man nicht nach Himmelsrichtung pauschal entscheiden, sondern ein anliegendes Feld auswählen können. (0.5.4, E66: Felder 10×10, Cursor springt feldweise)
- [x] Die Lampe soll eher wie eine Laterne aussehen, also ähnlich hoch, aber dann so trichterförmig nach unten geöffnet (0.5.4, E66)
- [x] Bei der Pferde übersicht soll nicht mehr der Ort stehen und nicht "B" (wofür auch immer das steht?) und nicht der zahlenwert für die Stärke. (0.5.4, E66: „B 73“ war die Bindung, beides weg)
- [x] wenn man ein neues Pferd sieht, soll es nicht so schnell ins album eingetragen werden. erst, wenn man es gezämt hat. (0.5.4, E66: nur eigene Pferde)
- [x] beim Stammbaum: unbaknnt ersetzen durch ?. Infos unten weglassen (0.5.4, E66)
- [x] Karte: Schrift Hof und Dorf und Pfeil: du Gelb: Pferde weglassen. (0.5.4, E66)
- [x] Karte nicht mehr über select aufrufbar machen (0.5.4, E66: nur Pausenmenü)
- [x] Musik/Töne: tiefere Töne weglassen. diese scheppern auf billiger hardware. musik etwas schneller. (0.5.5, E67: nichts unter 440 Hz, Musik eine Oktave höher, ~17 % schneller)
- [x] Bug beheben: wenn man das spiel speichert und dann schließt und wieder öffnet sind die Pferde plätzlich alle außerhalb der weide! diese sollten da aber noch bleiben. (0.5.5, E67: lose Pferde merken sich ihren Platz)
- [x] Sprechblasen und emoji größer und deutlicher, sind aktuell zu schwer zu sehen/lesen/versehen. (0.5.5, E67: 21 × 18 statt 13 × 13, Symbole mit Umriss)
- [x] Hunde (und vermutlich auch andere Gegner) haben keine kollisionen und ziehen einfach über alles drüber. fixen. (0.5.5, E67: echte Figuren mit Fußkasten, auch Wölfe/Krokodile)
- [x] Die tragbare Laterne soll von der Position bei der rechten hand sein, so als würde man die tragen. am Tag ausblenden. (0.5.5, E67: hängt an der rechten Hand, erst ab dem Lichtkreis)
- [x] Häuser soll man auch abreißen können, wenn man ein weiteres hat, das gleiche gilt für garagen, ställe (0.5.7, E69)
- [x] Titelbildschirm: Pferdezüchter im Jahr 2040 kann weg. (0.5.7, E69)
- [x] Pferde sollen nicht sofort nach dem Zähmen reitbar sein. Dafür braucht es höhere Bindung, ein paar Mal füttern, sauber machen und streicheln sollte aber reichen. Ein frisch gezähmtes Pferd an der Leine zu rennen ist auch riskant und kann häufiger dazu führen, dass es sich losreißt. (0.5.8, E71: +6 Bindung seit dem Zähmen, Ausreißen beim Rennen ×3)
- [x] Beim Laden, wenn man ein Fahrzeug kaufen will, was nicht geht, weil man die Unterbringung nicht hat, soll nicht generisch „dafür fehlt dir die Garage (Schuppen/Garage)“ stehen, sondern konkret, was dafür fehlt. (0.5.8, E72: „Für das Mofa fehlt dir ein Schuppen.“)
- [x] Bei den Fahrzeugen soll in der Beschreibung nicht „erreicht Gebiet 2, kostet so und so viel Sprit“ stehen, sondern eher eine witzige Kurzbeschreibung, aus der das in etwa hervorgeht. (0.5.8, E72)
- [x] In anderen Gebieten: Pferd zum Anhänger führen und A drücken lädt es ein; zurück zu Hause steht es neben dem Anhänger. So viele Pferde, wie der Anhänger Plätze hat. Im Pferdemenü bei Ort ein eigenes Pferd vom Hof in den Anhänger laden, um es mitzunehmen. (0.5.9, E73)
- [x] Absturz farm.lua:312 am Fahrzeug beheben. (0.5.9, E73: Ort im Pferdemenü unterwegs)
- [x] In anderen Gebieten gibt es kein Dorf. (0.5.9, E73)
- [x] Neues Spiel trotz Spielstand: ein zweites Mal nachfragen und die Folgen erklären. (0.5.9, E74)
- [x] Mehrere Fahrzeuge in einer Garage/einem Schuppen: dazwischen wählen; Fahrzeugmenü überarbeiten wie die Pferde-Info. (0.5.9, E74)
- [x] Kleine Blumen in anderen Gebieten umfärben. (0.5.9, E74)

## Auf der Konsole testen
Checklisten des Loops für jede fertige Phase.

**Version 0.5.5** – Rückmeldungen, siehe E67 (gleiche Firmware wie 0.5.3)
- [ ] Pferde in die Weide führen, Leine lösen (ohne „Ort“), speichern, beenden, Weiter: stehen sie noch drin?
- [ ] Töne und Musik: scheppert noch etwas? Tempo passend? Sprechblasen gut zu erkennen?
- [ ] Hundenacht: laufen die Hunde um Zäune und Gebäude herum? Laterne nachts an der Hand, tagsüber weg?

**Version 0.5.4** – Rückmeldungen, siehe E66 (gleiche Firmware wie 0.5.3)
- [ ] Baumodus → Land: Cursor springt feldweise, grün = kaufbar, A kauft. Verständlich?
- [ ] Dorf: Namen nur, wenn man davor steht. Laterne nachts als Trichter. Album füllt sich erst beim Zähmen.

**Version 0.5.2** – Rückmeldungen, siehe E64. **Braucht neue Firmware (Meloni API 2).**
- [ ] Erst Firmware mit der neuen Engine flashen, sonst überspringt „Update games“ Hoofy.
- [ ] Abend und Nacht: weich dunkler, nachts heller Bereich um dich. Läuft es flüssig?
- [ ] Spielstand fortsetzen: stehen die Weidepferde auf ihrer Weide?
- [ ] Streicheln/Füttern/Striegeln: Herz bzw. Glitzer über dem Pferd, keine Zahlen.

**Version 0.5.1** – Rückmeldungen, siehe E63
- [ ] Pausenmenü, Pferdemenü, Füttern, Unterbringen als Kacheln: mit dem Steuerkreuz gut zu treffen? Icons erkennbar?
- [ ] Abend: wird es gleichmäßig dunkler? Nachts: Sichtbereich um den Spieler, mit Sattellampe größer. Ruckelt es nachts (≈ 180 Sprites je Frame)?

**Phase E (Version 0.5.0)** – Turniere und Chaos, siehe E57–E62
- [ ] Turnierplatz im Dorf (A): Klasse, Wettbewerb, Pferd mit Chancen. Wettbewerb nach Teilnahme weg, neue Runde alle 3 Tage.
- [ ] Springreiten (A springt) und Rennen (A halten = Spurt): Fühlt sich das Steuern fair an, stimmt der Schwierigkeitsgrad?
- [ ] Pause → Zeitung: neue Reform alle 4 Tage; Hunde nachts, Pferdesteuer, Hafersteuer, Stromsubvention wirken. Wehren starke Pferde auf der Weide ab, zerstören Tiere sonst Deko?
- [ ] Pause → Album: neue Kombinationen kommen beim Anschauen und Zähmen dazu.
- [ ] Pause → Tauschen: Pferd als Code abgeben, mit dem Code auf einem zweiten Gerät/Spielstand einlösen. Ist die Eingabe der 28 Zeichen auf der Tastatur zumutbar?

**Phase D (Version 0.4.0)** – Welt, siehe E52–E56
- [ ] Laden → Fahrzeuge: Zugfahrzeug nur mit passendem Gebäude (Schuppen/Garage/Hangar), Anhänger frei kaufbar.
- [ ] A vor der Schuppen-/Garagentür: Reisemenü; Fahrtkosten, Pferde an der Leine (höchstens Anhängerplätze) fahren mit.
- [ ] Gebiete 2–6: andere Farben, Rassen, mehr Wildpferde; Fahrzeug steht am Ankunftspunkt, A dort = Rückreise. Ladezeit/Ruckeln im größten Gebiet (Canyon)?
- [ ] 👃 über dem Pferd beim Reiten: Steuerkreuz loslassen, es läuft zum Schatz. Satteltaschen nötig außerhalb des Heimattals.
- [ ] Regen (jeder 4. Tag): Striche, „Regen“ oben, schmutzigere Pferde auf der Weide. Nachts mit Sattellampe größerer Sichtkreis.
- [ ] Speichern unterwegs: danach steht man wieder zu Hause, Funde verkauft.

**Phase C (Version 0.3.0)** – Hofbau, Bedienung E8, E32–E51
- [ ] START → Bauen (oder am Hof): Cursor mit Steuerkreuz, B halten + Pfeile wählt Kategorie/Bauteil, A baut. Nachvollziehbar?
- [ ] Zäune/Tore schließen eine Weide (grüne Punkte, „Weide n Plätze“); Pferd auf die Weide, Umbau setzt Pferde um.
- [ ] Gebäude (Ställe S–XL, Häuschen, Villa, Schuppen, Garage, Hangar): Stalltür/Bett wirken auch bei neuen Bauten.
- [ ] Schönheit-Anzeige unten rechts; Bindungsbonus nach dem Schlafen.
- [ ] Anbau: Beet bauen, Samen aus dem Laden pflanzen, nach Tagen A zum Ernten, Ernte im Füttern-Menü.
- [ ] Göpel-Generator bauen: am nächsten Tag Geld bei starken, ausgeruhten Pferden auf dem Hof?
- [ ] Land kaufen (Kategorie „Land“): Preise 500 + 250 je Stück, Karte/Grundstücksrahmen wächst. Ruckelt der Baumodus?

**Phase B (Version 0.2.0)** – Wirtschaft und Zucht
- [ ] Im Dorf: Laden (Futter, Sättel, Zubehör, Schmuck, Samen), Pferdemarkt (4 Pferde, Preise), Jobbrett. A an Tür bzw. Stand.
- [ ] Am Hoftor steht tagsüber ein Käufer mit ❗: A, Pferd markieren, Preis und Spruch ansehen, verkaufen. Stimmen die Folgen (Bindung der übrigen)?
- [ ] START → Bestellungen: alle 3 Tage eine neue; passendes Pferd liefern.
- [ ] Zucht: Stalltür → „Zucht starten“ (Hengst + Stute im Stall), nach 2 Tagen Fohlen, Info → Rechts: Stammbaum.
- [ ] Ausrüsten im Pferdemenü (Sattel, Taschen, Lampe, Schmuck), Reiten mit Sattel schneller?
- [ ] Wie lange bis zum ersten Gewinn? Fühlt sich das Tempo (Fahrrad nach ~1 Stunde) richtig an?
- [ ] Ruckelt der Hof mit mehreren Pferden? Läuft die Stalltür-Bedienung nachvollziehbar?

**Phase A (Version 0.1.0)** – Bedienung siehe ENTSCHEIDUNGEN.md E1–E3, E5, E6, E29–E31
- [ ] Hoofy 0.1.0 erscheint nach „Update games“, Cover zeigt den Hof.
- [ ] Titel → START: neues Spiel. Laufen (B rennt), Dorf im Osten/Westen besuchen, Namen über den Gebäuden.
- [ ] Wildpferd anschleichen: stehen bleiben, solange es hinschaut (❗ warnt). A in der Nähe zähmt.
- [ ] A neben dem eigenen Pferd: Menü. Füttern, Streicheln, Striegeln, Aufsitzen, Unterbringen.
- [ ] Reiten: B galoppiert, A antippen springt (Busch, Zaun), A halten steigt ab. Energie-Balken unten links.
- [ ] Nachts: Sichtkreis; am Wohnwagen A = schlafen und speichern. START → Speichern, SELECT → Karte.
- [ ] Neu starten: Titel zeigt „Weiter“, alles ist da (Pferde, Hof, Karte, Geld).
- [ ] Ruckelt es beim Scrollen/Reiten? Ladezeit des Spiels (Sprites ≈ 1,8 MB)? Nachtkreis flüssig?
- [ ] Tastenbelegung okay? Was fehlt oder nervt, unter „Rückmeldungen“ oben eintragen.

**Phase 0 (Version 0.0.1)**
- [ ] Hoofy erscheint nach „Update games“ im Meloni-Tab, mit Cover.
- [ ] Titel → START oder A → Welt; herumlaufen, B hält zum Rennen, START pausiert.
- [ ] Ruckelt das Scrollen? (Die Karte ist noch ein Platzhalter aus Ausgebüxt.)

## Stand
**Alle Aufgaben sind erledigt, keine ist blockiert.** Hoofy 0.5.0 enthält Phase 0 und A–E:
- Phase 0/A (0.0.1/0.1.0): Gerüst, Test-Werkzeug, Katalog-Generator, Karte, Spieler, Pferdegrafik, Pferdemodell, Wildpferde, Zähmen, Leine, Reiten, Pflege, Hof, Tag/Nacht, Menüs, Speichern, Karte, Töne.
- Phase B (0.2.0): Laden, Markt, Käufer, Bestellungen, Jobs, Zucht, Stammbaum, Inzucht, Wirtschaftscheck.
- Phase C (0.3.0): Baumodus, Weiden, Gebäude, Schönheit, Anbau, Göpel-Generator, Land kaufen.
- Phase D (0.4.0): Fahrzeuge und Reisen, Gebiete 2–6, Schätze, Regen, Sattellampe.
- Phase E (0.5.0): Turniere mit zwei Minispielen, Reformen mit Zeitung, Sammelalbum, Tauschcode.

**Zuerst ansehen (ENTSCHEIDUNGEN.md):**
1. „Balance“: Schlachter zahlt oft mehr als ein Pferd wert ist; Verkäufe tragen zwei Drittel des Einkommens; Turnier- und Reformzahlen (E57, E59, E60) sind ungetestet auf der Konsole.
2. E62 Tauschcode: 28 statt 16 Zeichen (Alphabet 32 Zeichen), Name/Stammbaum/Ausrüstung nicht im Code. Ist das so gewollt?
3. E52/E54: Reisen und Schätze – Garage-Pflicht für Fahrzeuge, Satteltaschen nötig außerhalb des Heimattals, Fund-Verkauf beim Heimkommen. Passt der Ablauf?
4. E60: Tierangriffe sind abstrakt (beim Tageswechsel gewürfelt, Tiere nur als Bild), ein starkes Pferd auf der Weide löst alles.
5. E51: Land wächst als Streifen (Rechteck), nicht in Einzelstücken.
6. Technik auf der Konsole prüfen: Sprite-Bild über 2,1 MB (Ladezeit, Speicher), größtes Gebiet Canyon (128×112), Ruckeln im Baumodus, Nachtkreis, Regen mit vielen Pferden.

**Bekannte Lücken:** Käufer/Jobs/Markt gibt es nur im Heimattal; Gebiete 2–6 haben keine Dörfer-Besonderheiten; Tauschcodes lassen sich ohne Server nicht vor Mehrfachnutzung schützen; keine Musik- oder Soundprüfung für Phase C–E (nur kurze Klicks aus Phase A).

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
- [x] **A7 Zähmen**: Minispiel nach E16, Schwierigkeit nach Bindung.
  Prüfung: `INPUT`-Drehbuch, das bei SEED 1 zähmt; eines, das beim Hinschauen läuft und scheitert.
  *Erledigt:* Szenario `zaehmen` (Haflinger 140 px rechts, Übergänge im Log). Zähmt:
  `--seed 1 --input "5-100:RIGHT,101:A"` (Frame 101 „Momo gezähmt“). Scheitert:
  `--input "5-50:RIGHT,51-70:UP,71-110:DOWN,111-150:UP,151-190:DOWN,191-230:UP"` (Frame 169 flee).
  Entscheidung E28.
- [x] **A8 Leine und Folgen**: Führen zu Fuß und reitend, Ausreißen nach KATALOG §2 Leine,
  Pferd ab Bindung 70 folgt ohne Leine, ab 90 auf Pfiff.
  Prüfung: Selbsttest Ausreiß-Rate über viele Würfe ≈ 9 % gehend / 27 % reitend bei Bindung 10.
  *Erledigt:* `game/leash.lua`, Verhalten in `game/wild.lua` (`led/follow/free/escape`), Seil in
  `game/world.lua`. Rate über 20 000 Fenster: 9,1 % / 26,6 %. „Reitend“ wirkt, sobald A9 `player.riding`
  setzt. Entscheidung E29.
- [x] **A9 Reiten**: Auf-/Absitzen (E2, E3), Schritt/Galopp, Springen nach Stärke,
  Energieverbrauch nach Katalog, Sattel-Bonus, verweigern bei Bindung < 20.
  Prüfung: Shot-Sheet Ritt mit Sprung über Busch; Selbsttest Energie.
  *Erledigt:* `game/ride.lua`, Reiter wird mit dem Pferd gezeichnet, `Map:blocked(…, clear)` mit
  Hindernishöhen. Szenario `ritt` (`--input "5:A,20-110:RIGHT+B,40:A"` springt über die Büsche,
  `SCENARIO_OPTS='staerke = 10'` schafft es nicht). Entscheidung E30.
- [x] **A10 Pflege und Training**: Aktionsmenü (E2), Streicheln, Füttern, Striegeln, Werte
  nach Katalog, Trainingsformel mit Bonus, Charakter-Effekte (KATALOG §5).
  Prüfung: Selbsttests für Trainingsformel, Futterwirkung, Bindungsregeln; Screenshot Menü.
  *Erledigt:* `game/care.lua` (Regeln), `game/menu.lua` (Auswahlmenü), Menü in `game/world.lua`,
  Training beim Reiten. Screenshot: Szenario `ritt` mit `--input "10:A,20:DOWN,30:A"`. E31.
- [x] **A11 Hof**: Start mit Wohnwagen, Stall S, Weide mit Tor, Bürste (KATALOG §15);
  Pferde in Stall/Weide/frei stellen, Plätze begrenzt, Verluste nach KATALOG §2 Unterbringung.
  Prüfung: Szenario `hof_start`, Screenshot; Selbsttest Verluste pro Tag.
  *Erledigt:* `game/farm.lua`, Sprites Wohnwagen und Tor, Unterbringen/Stalltür in `game/world.lua`.
  Screenshot `hof_start` (Wohnwagen, Stall, Weide mit Pferd, Pferd an der Leine). Entscheidung E32.
- [x] **A12 Tag und Nacht**: 5 min pro Tag (3 hell, 2 dunkel), Nachtdarstellung (E14),
  Schlafen im Wohnwagen, Tageswechsel wendet alle Tagesregeln an (Hunger, Gewicht, Sauberkeit,
  Energie-Reset, Fohlenalter …).
  Prüfung: Shot-Sheet Abend → Nacht; Selbsttest Tageswechsel mit Beispielpferd.
  *Erledigt:* `game/clock.lua`, `game/days.lua`, Nachtkreis `Stage.draw_night`, Schlafen am Wohnwagen.
  Szenario `abend` (`zeit = 11000` + Drehbuch zum Wohnwagen schläft). Wildpferdwechsel ist jetzt an
  den Tageszähler gehängt. E14 geändert, E33.
- [x] **A13 Menüs**: HUD (E9), Pausenmenü (E5), Pferdeliste, Pferde-Info (Balken mit Gen,
  Training, Max-Potenzial), Umbenennen mit Bildschirmtastatur, Inventar.
  Prüfung: Screenshot jedes Bildschirms.
  *Erledigt:* `game/screens.lua` (Stapel in `game/world.lua`). Szenario `menues` mit
  `SCENARIO_OPTS='screen = "pause"'` (auch `horses`, `info`, `keyboard`, `inventar`). E34.
- [x] **A14 Speichern**: beim Schlafen, Gebietswechsel, `_quit`; Weiter-Eintrag im Titel.
  Prüfung: Selbsttest speichern → laden ergibt gleichen Zustand; Größe des Spielstands mit
  24 Pferden geloggt.
  *Erledigt:* `game/save.lua`, Laden in `game/world.lua`, Titel mit Weiter/Neues Spiel, `_quit`.
  Selbsttest Rundlauf; 24 Pferde = 10 388 Bytes. Von Hand: Neues Spiel → Pause → Speichern →
  Neustart lädt („Weiter“). E35.
- [x] **A15 Karte**: nur Erkundetes, Spieler mit Blickrichtung, Pferde, Hof (E6).
  Prüfung: Screenshot nach einem Erkundungsritt.
  *Erledigt:* `game/explore.lua`, `Screens.map`, SELECT-Antippen in `game/world.lua`. Screenshot:
  Szenario `ritt` mit `screen = "none"`, Aufsitzen per Menü, Ritt, SELECT (19 % erkundet). E36.
- [x] **A16 Töne**: Hufe, Wiehern, Menü-Klicks, ruhige Melodie tags/nachts.
  Prüfung: WAV-Ausgabe erzeugt, Protokoll nennt, was zu hören ist.
  *Erledigt:* `game/sfx.lua` (E37), Hooks in Menü, Reiten, Wildpferden, Pflege, Tageszeit.
  WAVs `runner/build/meloni-run --headless --frames 420 --wav out.wav games/hoofy` (mit `--save` auf
  eine Datei `return {scenario = "ritt", screen = "none"}`). Geprüft mit Lautstärke je 50 ms.
- [x] **A-Ende**: Cover, README-Tabelle, version 0.1.0, Konsolen-Checkliste, Push.

### B Wirtschaft und Zucht

- [x] **B1 Geld und Laden**: Startgeld 300, Laden im Dorf (Futter, Bürste, Sättel, Schmuck,
  Satteltaschen, Samen), Hausinventar, Bauelemente zum Kaufpreis zurück.
  Prüfung: Szenario `laden`, Screenshot; Selbsttest Kauf/Verkauf.
  *Erledigt:* `game/economy.lua`, Ladenbildschirm, Ausrüsten im Pferdemenü, Inventar nach Kategorien.
  Szenario `laden` (`SCENARIO_OPTS='geld = 120'`). E38.
- [x] **B2 Pferdewert und Markt**: Formel KATALOG §6, Pferdemarkt (kaufen × 1,3).
  Prüfung: Selbsttest Beispielwerte.
  *Erledigt:* `game/value.lua`, `game/market.lua`, Marktbildschirm am Stand. Szenario `markt`.
  Beispiel Shetlandpony/Brauner (15/35/45/70): Wert 126, Kauf 163. E39.
- [x] **B3 Käufer**: täglich ein Käufer am Hof, 4 Typen mit Formeln, Folgen und mehreren
  Sprüchen je Pferdetyp.
  Prüfung: Selbsttest Preise und Folgen; Screenshot Dialog.
  *Erledigt:* `game/buyers.lua`, Käuferfiguren (Recolor der Spielfigur), Dialog `Screens.buyer`.
  Szenario `kaeufer` (`SCENARIO_OPTS='kaeufer = "zuechter"'`), 4 Screenshots. E40, Balance-Befund zum Schlachter.
- [x] **B4 Bestellungen**: alle 3 Tage, Frist 5–10 Tage, Bonus.
  Prüfung: Selbsttest Erzeugen/Erfüllen/Verfallen.
  *Erledigt:* `game/orders.lua`, Bildschirme im Pausenmenü, Mitteilung beim Tageswechsel. Szenario
  `bestellung` (Screenshot). E41.
- [x] **B5 Jobs**: Jobbrett im Dorf, KATALOG §12, ein Job je Pferd und Tag.
  Prüfung: Selbsttest Lohn/Training/Energie; Screenshot.
  *Erledigt:* `game/jobs.lua`, Jobbrett-Bildschirme, Szenario `jobbrett` (Jobliste, Pferdeauswahl).
  E42.
- [x] **B6 Zucht**: Hengst + Stute im Stall, Trächtigkeit, Pause, Fohlen wächst in 4 Tagen,
  Gen-Vererbung, Farbvererbung mit Mutation, Rasse 50:50, Premiumfutter für Fohlen.
  Prüfung: Selbsttest Farbanteile 35/15/35/15 (±2) über viele Fohlen, Gen-Stats ≈ Elternmittel.
  *Erledigt:* `game/breeding.lua`, Stalltür-Menü, Fohlen in `game/days.lua`. 20 000 Würfe: 34,6 /
  14,7 / 35,0 / 14,6 %, Mutation 1,0 %; Fohlen-Tempo Mittel 50,1 σ 6,0. E43.
- [x] **B7 Stammbaum und Inzucht**: Stammbaum-Bildschirm (3 Generationen), Inzucht-Malus.
  Prüfung: Selbsttest Malus je Verwandtschaftsgrad; Screenshot.
  *Erledigt:* `Breeding.verwandtschaft/inzucht_malus`, `Screens.stammbaum`, Szenario `stammbaum`
  (4 Generationen, Screenshot). Malus −15/−8/−3 %: Fohlen-Mittel 50 → 42,5 / 46 / 48,5. E44.
- [x] **B8 Wirtschaft prüfen**: Simulation einer einfachen Spielweise über 20 Tage, Vergleich
  mit KATALOG §15 Phase 1–2. Abweichungen nur in ENTSCHEIDUNGEN.md unter „Balance“ melden.
  Prüfung: Protokoll mit Tagen bis Fahrrad und Mofa.
  *Erledigt:* `game/sim.lua`, Selbsttest `wirtschaft` (loggt `WIRTSCHAFT …`). Fahrrad Tag 4,2, Phase 1
  Tag 7,5, Mofa Tag 11,8, Phase 2 Tag 18,1. Befund unter „Balance“ in ENTSCHEIDUNGEN.md.
- [x] **B-Ende**: Cover, version 0.2.0, Konsolen-Checkliste, Push.

### C Hof bauen

- [x] **C1 Baumodus**: Cursor (E8), Kategorien, Kosten, Abreißen mit Erstattung, Kollision,
  nur auf dem Grundstück.
  Prüfung: `INPUT`-Drehbuch baut Bank und Weg, Screenshot.
  *Erledigt:* `Farm.place/remove/can_place` (game/farm.lua), `Screens.build`, 10 neue Sprites (Deko,
  Cursor). Szenario `bauen`, Drehbuch `--input "5:RIGHT,9:RIGHT,13:A,17:DOWN,21:A,25-42:B,30:RIGHT,44:UP,46:UP,50:A,54:LEFT,58:A,62:LEFT,66:A,70:LEFT,74:A"`
  (2 Bänke, 4 Wegkacheln). E45.
- [x] **C2 Zäune und Weiden**: Zaunelemente, Tor, geschlossene Weide per Flutfüllung erkennen,
  mehrere Weiden, Plätze nach Fläche.
  Prüfung: Selbsttest offene/geschlossene Weide; Screenshot.
  *Erledigt:* `Farm.pastures` (Flutfüllung), `Wild:rehome`, Überlagerung im Baumodus. Szenario `weiden`
  (zweite Weide mit Tor und eine Koppel ohne Tor, Screenshot). E46.
- [x] **C3 Gebäude**: Ställe S–XL, Häuschen/Villa, Schuppen/Garage/Hangar.
  Prüfung: Screenshot aller Gebäude; Selbsttest Stallplätze.
  *Erledigt:* 7 neue Gebäude-Sprites, `Farm.all_buildings/stall_doors/bed_doors/garaged/stall_bonus`,
  Szenario `gebaeude` (Screenshot mit allen Gebäuden). E47. Sprite-Bild jetzt 2,1 MB: auf der Konsole
  Ladezeit und Speicher prüfen.
- [x] **C4 Hof-Schönheit**: Summe, Bindungsbonus ab 50/150/400.
  Prüfung: Selbsttest.
  *Erledigt:* `Farm.schoenheit_bonus`, Anzeige im Baumodus, Tageswechsel in `game/days.lua`. E48.
- [x] **C5 Anbau**: Beete/Felder, Samen, Wachstum, Ernte ins Inventar (KATALOG §7).
  Prüfung: Selbsttest über Tage; Shot-Sheet Wachstum.
  *Erledigt:* Pflanzen-Logik in `game/farm.lua` (`plant/harvest/grow`), 33 Pflanzensprites, Erntefutter in
  `game/care.lua`. Szenario `anbau` (`SCENARIO_OPTS='tage = 2'`): Screenshot zeigt Keimling → Wachstum → reif. E49.
- [x] **C6 Göpel-Generator**: 40 je Pferd und Tag, Bedingungen. (E50; Selbsttest, 170 grün; Bild nicht im Shot geprüft)
  Prüfung: Selbsttest.
- [x] **C7 Land kaufen**: 10×10-Stücke, steigender Preis, bis zum ganzen Startgebiet. (E51; Selbsttest, 173 grün; Baumodus-Bild nicht im Shot geprüft)
  Prüfung: Selbsttest Preise; Screenshot Grundstücksgrenze.
- [x] **C-Ende**: Cover, version 0.3.0, Konsolen-Checkliste, Push.

### D Welt

- [x] **D1 Fahrzeuge** (E52; Shot-Sheet Menü + Ankunft Flussauen, SELFTEST 176): Zugfahrzeuge und Anhänger kaufen, Garage nötig, Reisemenü am Fahrzeug,
  Fahrtkosten, Pferde im Anhänger mitnehmen.
  Prüfung: Szenario `reise`, Screenshots Menü und Ankunft.
- [x] **D2 Gebiete 2–6** (E53; Übersicht aller 6 Gebiete, SELFTEST 178): Generator mit Palette, Größe, Wildpferden und Rassen je Gebiet
  (KATALOG §10), frühere Rassen seltener.
  Prüfung: Szenario `karte_ganz` für jedes Gebiet; Speicher beim größten Gebiet geloggt.
- [x] **D3 Schätze** (E54; Szenario `schatz`: Reiter findet „Samen: Minze“, SELFTEST 183): 15–30 je Gebiet, Aufspüren nach KATALOG §11 (E4), Satteltaschen →
  Fahrzeug → Hausinventar, Aufspürung +1 je Fund.
  Prüfung: Selbsttest Radius/Chance; `INPUT`-Drehbuch findet einen Schatz.
- [x] **D4 Wetter** (E55; Shot-Sheet Regen, SELFTEST 185): Regen (Sprites/Linien), Sauberkeit −15 draußen.
  Prüfung: Shot-Sheet; Selbsttest.
- [x] **D5 Sattellampe und Nachtsicht** (E14, E56; Szenario `nachtritt` mit/ohne Lampe verglichen)
  Prüfung: Screenshot nachts mit und ohne Lampe.
- [x] **D-Ende**: Cover, version 0.4.0, Konsolen-Checkliste, Push.

### E Turniere und Chaos

- [x] **E1 Turniere** (E57; Shot-Sheet Turnierplatz, SELFTEST 191): Turnierplatz, 6 Klassen nach Fahrzeug, Startgebühr, Chancen vorab,
  Rotation alle 3 Tage, Wettbewerb nach Teilnahme weg; Schönheitswettbewerb berechnet.
  Prüfung: Selbsttest Wertung; Screenshot.
- [x] **E2 Minispiel Springreiten** (E58; Drehbuch-Shot-Sheet, SELFTEST 196): Parcours, Stärke → Sprunghöhe, Ausdauer → Leistungsabfall.
  Prüfung: `INPUT`-Drehbuch, Shot-Sheet.
- [x] **E3 Minispiel Pferderennen** (E59; Drehbuch-Shot-Sheet, SELFTEST 201): Tempo, Ausdauer, Gegner.
  Prüfung: `INPUT`-Drehbuch, Shot-Sheet.
- [x] **E4 Reformen** (E60; Screenshots Hundenacht, Krokodile am Tag, Zeitung; SELFTEST 206): Zeitung alle 4 Tage, alle Reformen aus KATALOG §14, Hunde/Wölfe/Krokodile
  nachts (Krokodile auch tags), zerstören Deko, starke Pferde wehren ab.
  Prüfung: Selbsttest Reform-Wirkungen; Screenshot Zeitung und Hundenacht.
- [x] **E5 Sammelalbum** (E61; Screenshot Albumseite, SELFTEST 210): jede entdeckte Kombination Rasse × Farbe.
  Prüfung: Screenshot.
- [x] **E6 Tauschcode** (E62; 1 000 Pferde hin/zurück, Verfälschungen abgelehnt, SELFTEST 214): Pferd → Code (Vorschlag Katalog: 16 Zeichen A–Z, 2–9), Code → Pferd,
  Prüfsumme gegen Tippfehler, Pferd danach weg.
  Prüfung: Selbsttest Hin- und Rückweg für 1 000 Zufallspferde, falscher Code abgelehnt.
- [x] **E-Ende**: Cover, version 0.5.0, Konsolen-Checkliste, Abschluss nach LOOP.md, Push.
