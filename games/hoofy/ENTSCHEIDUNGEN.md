# Hoofy – Entscheidungen zum Überprüfen

Alles, was nicht in README_HOOFY.md oder KATALOG.md steht und trotzdem festgelegt werden musste.
Alles hier ist vorläufig: Der Loop darf Einträge ändern, wenn sich beim Bauen etwas Besseres
zeigt, und vermerkt dann `geändert: alt → neu, weil …`.
Mensch: ändern oder streichen gilt ab dem nächsten Durchlauf. **✔** vor einem Eintrag = bestätigt,
den ändert der Loop nicht mehr.
Format: **E-Nummer** (Aufgabe) Entscheidung.

## Bedienung

- **E1** Steuerkreuz: gehen bzw. reiten. **B halten**: rennen, reitend Galopp (verbraucht Energie).
- **E2** **A** = Aktion mit dem, was vor einem steht: Pferd, Tür, Händler, Fahrzeug, Beet, Truhe.
  Zu Fuß an einem eigenen Pferd öffnet A ein kleines Aktionsmenü neben dem Pferd:
  Streicheln, Füttern, Striegeln, Anleinen/Leine lösen, Aufsitzen, Info.
- **E3** Reitend: **A** springt (Höhe nach Stärke), vor einem Tor/einer Tür öffnet A es.
  **A lange halten** (½ s): Menü Absitzen, Pferd frei gehen lassen, Info.
- **E4** Schatz: Zeigt das Pferd 👃, einfach das Steuerkreuz loslassen. Nach 1 s ohne Eingabe
  läuft es selbst zum Schatz (so wie im README: „frei gehen lassen“). Jede Richtungstaste bricht ab.
- **E5** **START**: Pausenmenü mit Pferde, Inventar, Karte, Bauen (nur auf dem Grundstück),
  Album, Speichern.
- **E6** **SELECT** allein (beim Loslassen, wenn dabei keine andere Taste gedrückt wurde): Karte.
  So kollidiert es nicht mit SELECT+START / SELECT+A.
  geändert (Rückmeldung 0.5.4): SELECT ist frei, die Karte gibt es nur noch über das Pausenmenü.
- **E7** In allen Menüs: Steuerkreuz wählen, A bestätigen, B zurück. Namen und Tauschcodes über
  eine Bildschirmtastatur.
- **E8** Baumodus: Cursor im Kachelraster, A setzen, B zurück, LEFT/RIGHT bei gehaltenem B
  wechselt die Kategorie. Setzen an ungültiger Stelle: Cursor rot.

## Bildschirm und Welt

- **E9** HUD oben als schmale Leiste: Tag, Uhr als Sonne/Mond, Geld. Unten nur beim Reiten:
  Energie des Pferdes. Sonst frei.
- **E10** Emojis als Sprechblasen über dem Kopf wie in Ausgebüxt, als Sprites (der Font kann
  keine Emojis). Ein Pferd zeigt höchstens eine Blase gleichzeitig, wichtigste zuerst:
  👃 Schatz > 😱 Angst > Hunger > schmutzig > müde > Charakter-Blase (gelegentlich) > ❤ bei Bindung ≥ 70 nach Streicheln.
- **E11** Schwellen für Blasen: Hunger > 60, Sauberkeit < 40, Energie < 15.
- **E12** Heimattal: Hof in der Mitte des Tals, Dorf mit Laden, Pferdemarkt, Turnierplatz und
  Jobbrett etwa einen Bildschirm entfernt, über einen Weg verbunden. In fremden Gebieten steht
  das Fahrzeug am Rand, dort beginnt und endet der Ausflug.
- **E13** Läden, Markt, Turniere und Jobs sind Menübildschirme, die man per A an der Tür bzw.
  am Stand öffnet. Keine begehbaren Innenräume.
- **E14** Nacht: dunklere Bodenfarben und dunkle Sprite-Varianten. Die Sicht ist ein Kreis um
  den Spieler (außen schwarz, gezeichnet mit ein paar Dutzend `rectfill`-Streifen), die
  Sattellampe vergrößert ihn.
  geändert (A3): dunkle Sprite-Varianten → keine für Pferde, im Sichtkreis sind sie normal hell,
  weil 23 Farben × 4 Körper × 9 Posen doppelt so viel Bildspeicher bräuchten (heute schon 1,8 MB).
  Dunkle Bodenkacheln bleiben.
  geändert (A12): dunkle Bodenkacheln → keine, Bilder lassen sich nicht einfärben; Nacht = schwarz
  außerhalb eines Sichtkreises (Radius 70 px, ≈ 91 rectfill je Frame), Dämmerung 15 s und Sonnenaufgang
  10 s als weicher Übergang.

- **E17** (A1) Start-Grundstück: 20×20 Kacheln (2×2 Landstücke aus KATALOG §9) in der Mitte des
  Heimattals, auf dem 10er-Raster der Landstücke.
- **E18** (A1) Welt-Seed: Jedes neue Spiel würfelt einen Seed und speichert ihn (kommt mit A14);
  bis dahin fest Seed 1. Gebiet n nutzt Seed + n × 1000.
- **E19** (A1) Wald: dichtes Blätterdach als feste Bodenkachel, Bäume nur am Waldrand (etwa jede
  Randkachel). Ein Baum pro Waldkachel wäre auf der Konsole zu langsam.
- **E20** (A1) Dorf aus einer festen Vorlage (26×15 Kacheln: Laden, Wohnhaus, Marktstand mit
  Koppel, Jobbrett, Turnierplatz mit Hindernissen), 8 Kacheln neben dem Hof. Der Fluss fließt auf
  der anderen Seite von Nord nach Süd. Wege: Hof → Dorf, Hof → Nord-, Süd- und Flussrand.
- **E21** (A1) Laden, Pferdemarkt, Jobbrett und Turnierplatz tragen ein Namensschild (Text über
  dem Gebäude), damit man sie ohne Innenräume findet.
- **E22** (A2) Steht die Figur hinter Bäumen oder einem Haus, erscheint sie als Umriss (weiß,
  dunkel gefüllt) über allem. Rennen (B) wirbelt kleine Staubwölkchen auf.

- **E23** (A3) Fellfarben: RGB-Werte selbst gewählt (`recolor` in sprites.txt). Musterfarben sind
  Grundfarbe + Overlay: Braun-/Rapp-/Fuchsschecke = Brauner/Rappe/Fuchs + weiße Flecken,
  Tigerschecke = Schimmel + dunkle Tupfen, Apfelschimmel = Grauschimmel + helle Äpfel,
  Fliegenschimmel = Schimmel + Sprenkel, Zebra = Schimmel + Streifen, Regenbogen = weiß mit
  Regenbogen-Streifen und rosa Mähne.
- **E24** (A3) Pony, Kaltblut und Einhorn werden aus dem Warmblut abgeleitet (`tools/hoofy_pferde.py`:
  Pony kürzer, Kaltblut größer mit weißem Behang, Einhorn mit Horn). Jede Pose lässt sich von Hand
  neu zeichnen, die Hand-Version gewinnt. Galopp gibt es nur von der Seite, nach oben/unten laufen
  die Schritt-Posen schneller.

## Werte
- **E49** (C5) Anbau: Baumodus → „Anbau“ (Beet/Feld, 20 je Kachel; beides derselbe Boden) und „Pflanzen“ (zeigt die
  gekauften Samen). **Ein Samen schaltet die Pflanze frei, danach beliebig viele Pflanzungen** (KATALOG: „Samen einmal
  kaufen: Pflanze trägt danach unbegrenzt“). Pflanzen kosten nichts, brauchen ein Beet auf allen Kacheln (Apfelbaum 2×2).
  Wachstum in Tagen nach „reif nach / dann alle“, drei Bilder (Keimling, wächst, reif); geerntet wird per A neben der
  reifen Pflanze, der Ertrag landet sofort im Vorrat (Hausinventar, Gras → Heu). Pflanzen blockieren nicht. Ernte als
  Futter im Füttern-Menü: Wirkung nach KATALOG §7, Minze bei eitel doppelt, Drachenfrucht Training ×2 für den Tag nach
  dem Füttern, goldene Karotte wie Premiumfutter (gemeinsam bis +10). Sonnenblumen zählen +2 Schönheit. Abreißen entfernt
  erst die Pflanze (kein Geld, Samen bleibt), dann das Beet (20 zurück).
- **E48** (C4) Hof-Schönheit: Summe der Deko-Punkte aller gebauten Dinge und Gebäude (Wege/Böden 0,5 je Kachel),
  ab 50 / 150 / 400 Punkten bekommen **alle** Pferde (auch an der Leine, auf der Weide …) jeden Tageswechsel +1 / +2 / +3
  Bindung, zusätzlich zum Stallbonus (E47). Anzeige im Baumodus unten rechts („Schönheit 48/50 (Bindung +0)“).
  Schmuck am Pferd zählt nicht zum Hof.
- **E47** (C3) Gebäude: im Baumodus unter „Bauten“ (Stall S–XL, Häuschen, Villa, Schuppen, Garage, Hangar), Grundflächen
  in Kacheln: S 4×3, M 6×3, L 8×4, XL 10×4, Häuschen 3×2, Villa 5×3, Schuppen 3×2, Garage 4×3, Hangar 6×4. Stallplätze
  addieren sich über alle Ställe; jeder Stall hat eine Tür (Mitte der Unterkante) für das Stallmenü. **Stall-Bindung:**
  der beste Stall gibt allen Pferden im Stall pro Tag +1/+2/+3/+4 Bindung (KATALOG §9 sagt „pro Tag“ ohne zu
  sagen, für wen: hier nicht summiert). Schlafen geht an Wohnwagen, Häuschen und Villa. Schuppen, Garage und Hangar
  merken sich, welche Fahrzeuge der Hof unterstellen kann (`Farm.garaged`, gebraucht ab D1). Weil große
  Sprites den Bildspeicher wachsen lassen, ist die Sprite-Tabelle jetzt 256×2741 (≈ 2,1 MB auf der Konsole).
- **E46** (C2) Weiden: Eine Weide ist eine zusammenhängende Fläche freier Kacheln auf dem Grundstück, die
  ringsum von Zaun, Gebäuden oder anderen Bauten begrenzt ist und an ein Tor grenzt (Flutfüllung). Plätze:
  ein Platz je 10 Kacheln (Bänke, Büsche usw. zählen nicht zur Fläche). Mehrere Weiden gehen; ein Pferd
  merkt sich seine Weide (`weide_id`). Nach jedem Umbau werden die Weiden neu berechnet: Pferde bleiben auf
  ihrer Weide, ziehen auf eine andere mit Platz um oder kommen an die Leine (Meldung). Im Baumodus sind
  Weiden mit gelben Punkten und „Weide N Plätze“ markiert. Zäunt man das ganze Grundstück samt Tor ein,
  wird der Hof selbst zur großen Weide.
- **E45** (C1) Baumodus: Pausenmenü → Bauen (nur wenn der Spieler auf dem Grundstück steht). Cursor im
  Kachelraster (Steuerkreuz), A baut bzw. reißt ab, **B gehalten + Links/Rechts** wählt die Art (Deko, Wege,
  Zaun, Abreißen), **B gehalten + Hoch/Runter** das Bauteil, B allein schließt. Cursor gelb = möglich, rot =
  nicht möglich (belegt, im Weg, zu wenig Geld, nicht auf Gras, du stehst drauf). Startbauten (Wohnwagen,
  Stall S, Weide) lassen sich nicht abreißen (geändert: Wohnwagen und Stall S jetzt doch, siehe E69). Abreißen erstattet den vollen Kaufpreis. Wege und Böden
  verändern nur den Boden (Abreißen stellt das Gras wieder her). Ställe, Gebäude und Beete kommen mit C3 und C5;
  Weide-Erkennung und Plätze aus Zäunen mit C2. Gebaut wird im Hof (`farm.items`), nicht als Kartenänderung.
- **E44** (B7) Stammbaum und Inzucht: In der Pferde-Info zeigt Rechts den Stammbaum (Pferd, Eltern,
  Großeltern, Urgroßeltern; Vater oben, Mutter unten). Mehr speichert ein Pferd nicht (917 Bytes
  Ahnen bei 3 Ebenen). Verwandtschaft nach dem Katalog: Eltern/Kind und Vollgeschwister −15 %,
  Halbgeschwister und Großeltern/Enkel −8 %, Cousins −3 % auf die Gen-Stats des Fohlens. Onkel und
  Nichten zählen nicht (steht nicht im Katalog). Bei der Stutenwahl steht die Verwandtschaft samt
  Malus hinter dem Namen, nach der Paarung in der Meldung. Wildfänge haben keine Ahnen.
- **E43** (B6) Zucht: An der Stalltür → „Zucht starten“ → Hengst, dann Stute wählen (beide ausgewachsen
  und im Stall, Stute nicht trächtig/in Pause). Nach 2 Tagen kommt das Fohlen (beim Tageswechsel),
  folgt an der Leine; die Stute hat 3 Tage Pause. Gen-Stats: Mittel der Eltern ± σ 6, Potenzial wie
  bei Wildpferden aus der Rasse des Fohlens. Farbe: die mutierte (1 %) Farbe ist die gezeigte, nicht
  die versteckte. Der Vater wird bei der Paarung festgehalten (wird er verkauft, erbt das Fohlen trotzdem).
  Jedes Pferd bekommt eine Kennung (`id`) und eine Kurzform der Ahnen (`ahnen`, 3 Ebenen) für B7.
  Das Fohlen bekommt einen Zufallsnamen und einen zufälligen Charakter.
- **E42** (B5) Jobs: A am Jobbrett → Job wählen → Pferd wählen (Voraussetzung, Energie und „schon
  gearbeitet“ stehen dabei). Der Job läuft sofort ab (kein Minispiel, keine Wegzeit): Lohn nach
  Katalog mit den Gesamtwerten, Energie ab, Training Basis × Formel.
  währenddessen nicht nötig sein. Ein Job pro Pferd und Tag (`job_tag`).
- **E41** (B4) Bestellungen: Tag 1, 4, 7 … gibt jemand eine auf (Kunde, Farbe aus einer erreichbaren Rasse
  (häufig bis selten), Geschlecht, ein Stat mit Mindestwert 40–60 (Ausdauer 60–80), plus 5 je
  weiteres Gebiet), Frist 5–10 Tage, verfällt danach. Geliefert wird im Pausenmenü → Bestellungen →
  Pferd wählen (nur passende zahlen): Wert × 1,5, das Pferd geht weg, keine Folgen für die übrigen
  (der Katalog nennt keine). Gesamtwerte inklusive Training zählen. Mitteilung beim Tageswechsel.
- **E40** (B3) Käufer: Ab Tagesbeginn steht der Käufer des Tages am Hoftor (Figur in Käuferfarben mit ❗,
  tagsüber, weg nach einem Verkauf oder bei Einbruch der Nacht). A daneben öffnet die Liste deiner
  Pferde mit dem Preis, den er zahlt, einem Spruch zum markierten Pferd und den Folgen. Pro Besuch ein
  Verkauf. Der Spruch ist pro Pferd und Tag fest und hängt von Käufer und Pferd ab (Sauberkeit, Farbe,
  Fohlen, Geschlecht, Bindung, Tempo/Stärke, Gewicht). Die Bestellung kommt mit B4.
- **E39** (B2) Pferdemarkt: 4 Pferde zum Kauf, alle 3 Tage neue (aus Seed und Zyklus, bleibt nach dem
  Laden gleich und wird mit dem Spielstand gespeichert). Rassen aus allen erreichbaren Gebieten
  (Gebiet gleichverteilt), Preis = Wert × 1,3. Gekaufte Pferde folgen sofort an der Leine. Mehr
  als 24 eigene Pferde gehen nicht (Vorschlag aus den offenen Fragen). Der Markt kauft nichts:
  verkauft wird an Käufer (B3). Wert wird auch in der Pferde-Info gezeigt.
- **E38** (B1) Laden: A an der Ladentür öffnet einen Bildschirm mit Reitern Futter, Sättel,
  Zubehör, Schmuck, Samen (nur Samen der erreichbaren Gebiete). Gekauft wird 1 Stück je A. Einmalige
  Waren (Bürste, Samen) sind danach ausgegraut. Ausrüstung: im Pferdemenü „Ausrüsten“: ein Sattel,
  Taschen nur mit Sattel (gehen mit ihm ab), Lampe und je ein Stück Schmuck. Bauelemente gibt es erst
  im Baumodus (C1), die Rückgabe zum Kaufpreis ist schon da (`Economy.refund_building`).
  Pferdemarkt, Käufer und Wert kommen mit B2/B3.
- **E37** (A16) Töne: Menü-Klicks (Bewegen, Bestätigen, Zurück, Tastatur), Hufschlag beim Reiten
  (Schritt alle 15 Frames leise, Galopp alle 8 Frames lauter), Wiehern beim Fliehen und
  Ausreißen, Warnton bei ❗, Jingles beim Zähmen, Streicheln, Dämmerung und Morgen, Sprung und
  Landung, Fressen, Striegeln, Reißen der Leine. Hintergrundmusik: tagsüber eine ruhige Dreieck-
  Melodie (96 bpm), nachts eine langsame Sinus-Melodie mit Pausen (56 bpm), beide leise.
- **E36** (A15) Karte: Zellen zu 4×4 Kacheln gelten als erkundet, sobald ein Stück davon im Bild
  war (nachts im Sichtkreis). 1 Kachel = 2 Pixel, unerkundet dunkel. Hof-Grundstück und Dorf mit
  Namen, sobald ihre Mitte erkundet ist; Pferde gelbe Punkte, Spieler roter Punkt mit Pfeil.
  Öffnen: SELECT antippen oder Pausenmenü; B, A oder SELECT schließt. Die Erkundung wird mit
  dem Spielstand gespeichert (480 Zeichen).
- **E35** (A14) Speichern: beim Schlafen, über „Speichern“ im Pausenmenü und beim Beenden über das
  Konsolenmenü (auch mitten im Ritt). Nicht gespeichert werden Wildpferde (sie werden beim Laden
  frisch aus dem Seed gewürfelt), Sprechblasen und Uhrzeit-Feinheiten. Titel: „Weiter“ (Standard,
  wenn es einen Spielstand gibt) und „Neues Spiel“; Neues Spiel überschreibt den Stand erst beim
  nächsten Speichern. Test-Szenarien speichern nie. Größe mit 24 Pferden: 10 KB.
- **E34** (A13) Bildschirme: START öffnet das Pausenmenü (Weiter, Pferde, Inventar; Karte, Bauen,
  Album, Speichern stehen ausgegraut da, bis es sie gibt). Die Welt steht still, solange ein
  Bildschirm offen ist. Pferdeliste → Info (Balken: Gen gold, Training grün, Max-Potenzial als
  roter Strich; Zustände darunter) → A benennt um. Tastatur: 6 Reihen Buchstaben samt Umlauten, dazu
  LÖSCHEN und FERTIG; B löscht das letzte Zeichen (bei leerem Text: zurück). Höchstens 12 Zeichen.
- **E33** (A12) Tag: Start am Morgen, 10 800 Frames hell, dann 7 200 dunkel. Schlafen: nur nachts
  (A an der Wohnwagentür), überspringt den Rest der Nacht, sonst „Noch nicht müde“. Pause und Menüs
  halten die Uhr an. Reihenfolge des Tageswechsels: Bindung (aus gestrigen Zuständen), Gewicht,
  Unterbringung, Hunger +25, Energie zurück, Fohlenalter +¼. Nachteulen: +20 Energie bei Einbruch
  der Nacht (darf über die Ausdauer gehen), morgens Ausdauer −10. HUD: Tag, Sonne/Mond mit Fortschritt,
  Geld (Startgeld 300, Ausgeben kommt mit B1). Speichern beim Schlafen kommt mit A14.
- **E32** (A11) Hof: Grundstück 20×20 (E17). Wohnwagen und Stall S im Norden, Weide (Zaunring
  10×7 mit Tor oben, Innenfläche 8×5) im Süden, Start im Hof dazwischen. Plätze: Stall nach
  KATALOG §9, Weide 1 je 10 Innenkacheln (= 4), frei auf dem Grundstück 1 je 50 Kacheln (= 8).
  Pferde im Stall sind unsichtbar (A an der Stalltür holt sie heraus); Weide und frei: sie laufen
  nur innerhalb der Fläche herum. „Unterbringen“ im Pferdemenü, Anleinen löst die Unterbringung.
  Die Tagesverluste (`Farm.daily`) ruft A12 beim Tageswechsel auf.
- **E31** (A10) Pflege und Training: Aktionsmenü per A neben einem eigenen Pferd (Streicheln,
  Füttern, Striegeln, Leine lösen/Anleinen, Aufsitzen, Info). Aufsitzen geht nur noch über das
  Menü (ersetzt „A neben dem Pferd sitzt auf“ aus E30). Startvorrat: 3 Heu, 2 Karotten, Bürste
  (der Katalog nennt nur die Bürste; Futter wird ab B1 gekauft). Streicheln +2 Bindung nur einmal
  am Tag (`gestreichelt`, A12 setzt es zurück). Trainingsbonus = 1 + 0,25 × Sauberkeit/100 +
  0,25 × Bindung/100, bis ×1,5; eitel zählt die Sauberkeit doppelt. Training beim Reiten: Galopp
  Tempo +1 je Minute, Reiten Ausdauer +0,5 je Minute, Sprung Stärke +0,2 (jeweils × Formel).
  „Reiten senkt das Gewicht etwas“ kommt mit A12 zusammen mit den Tagesregeln. Info zeigt
  vorerst nur eine Zeile, der Bildschirm kommt mit A13.
- **E30** (A9) Reiten: A neben einem geführten oder folgenden Pferd (≤ 30 px) steigt auf. Bindung
  < 20: 50 % Verweigern; 20–39 wird nicht eingeschränkt (Katalog sagt nur „≥ 40 reitbar“). Tempo:
  Schritt 1,3 + 0,6 × T/100, Galopp (B) 2,0 + 1,4 × T/100 Pixel je Frame, T = Tempo + Sattel.
  Energie: Reiten 1 je 10 s, Galopp doppelt, Sprung 5; bei 0 nur noch langsamer Schritt, kein
  Sprung. Sprunghöhe 6 + 0,3 × Stärke Pixel; Hindernishöhen: Busch 12, Hürde 14, Stein 16,
  Zaun 18, Bäume und Häuser nie. **A antippen = springen (beim Loslassen), A halten (½ s) =
  absteigen** direkt, das Menü aus E3 kommt mit A13. Energie-Balken unten links.
- **E29** (A8) Leine: Ein frisch gezähmtes Pferd ist sofort angeleint (Seil von der Hand zum Kopf),
  ab Bindung 70 folgt es frei ohne Seil und reißt nie aus. Bis zu 4 Pferde gleichzeitig
  (Karawane, je 20 px Abstand mehr). Ausreißen: einmal pro Sekunde gewürfelt, so dass die Chance je
  10 s dem Katalog entspricht. Ein ausgerissenes Pferd bleibt lose in der Nähe stehen, A daneben
  leint es wieder an. **Pfiff** (Bindung ≥ 90): A eine halbe Sekunde halten, ohne dass ein Pferd
  in Reichweite ist; lose Pferde kommen und folgen. (Reitend gilt A lange halten = Menü, E3.)
- **E28** (A7) Zähmen, Feinheiten zu E16: Zone 110 px um das Pferd. Wegschauen = Grasen-Pose, 🡒
  Hinschauen = Seitenpose mit Blick zum Spieler. Wegschauzeit (2–4 s) × (0,5 + Bindung/200). Wer
  weiter als 140 px weggeht, beendet den Ablauf. Nach der Flucht 4 s Ruhe. Gezähmt bei höchstens
  26 px Abstand und A, auch beim Hinschauen. Das gezähmte Pferd bleibt stehen (Leine kommt mit A8)
  und landet in `ctx.herd`; ein neues Wildpferd kommt erst beim nächsten Wechsel (alle 3 Tage).
- **E25** (A4) Wildpferd-Rasse: Rassen des aktuellen Gebiets zählen dreifach, Rassen früherer
  Gebiete einfach („kommen weiter vor, nur seltener“).
- **E26** (A4) „3 Prozentpunkte je Gebietsstufe von häufig zu den seltenen Stufen“: verteilt im
  Verhältnis der Anteile (Gebiet 4: häufig 31 %, legendär 3,45 %). Fehlt einer Rasse eine Stufe,
  verteilt sich deren Anteil ebenso anteilig. Versteckte Farbe: Stufe nach denselben Anteilen,
  aber nur gleich selten oder seltener.
- **E27** (A4) Wildpferde bekommen einen Namen aus einer Liste quatschiger Namen (Keks, Günther,
  Apfelstrudel, Tante Erna …), für Stuten und Hengste gemischt. Charakterzug gleich verteilt.

- **E15** Bindung-Startwert: Rassenwert ± 5 zufällig; schreckhaft −10, faul +5, verfressen +5,
  eitel 0, Nachteule 0.
- **E16** Zähmen: Das Wildpferd schaut 2–4 s weg, dann 1–2 s zu dir (vorher 0,3 s Warnblase ❗).
  Bewegst du dich, während es schaut, flieht es ein Stück. Je niedriger die Bindung, desto
  kürzer das Wegschauen. Nah genug + A = gezähmt, es kommt an die Leine.

## Balance

(Befunde aus Simulationen; Katalogwerte ändert nur der Mensch.)
- **(B3)** Schlachter: 5 × Gewicht² / 50 + Grundwert × 0,3 zahlt bei Gewicht 50 immer 250 + 30 % vom
  Grundwert, also oft mehr als der Wert des Pferds (Haflinger: Wert 330, Schlachter 340; Shetlandpony
  Wert 126, Schlachter 295). Damit ist der Schlachter für billige Pferde der beste Käufer und die Folge
  (−10 Bindung für alle) der einzige Preis. Vorschlag: Gewicht-Term durch einen Faktor auf den Wert ersetzen.
- **(B8)** Simulation `game/sim.lua` (12 Seeds, 60 Tage; alle 2 Tage ein gezähmtes Wildpferd, zwei Pferde
  arbeiten täglich im besten Job, überzählige gehen an den Käufer des Tages, Heu bei Hunger, Bestellungen
  geliefert; ohne Turniere, Anbau, Funde, Reformen). Tage bis zum Ziel gegen KATALOG §15:
  Fahrrad (400) 4,2 · Phase 1 (900) 7,5 (Katalog: 8) · Mofa (2 000) 11,8 · Phase 2 (3 700) 18,1 (Katalog: 19).
  Die Werte passen also zur Beispielrechnung. Einnahmen netto im Mittel 277 G/Tag: Verkäufe 178, Jobs 101,
  Bestellungen 7, Futter −8. Auffällig: Der Verkauf überzähliger Wildpferde trägt fast zwei Drittel, Jobs
  allein wären nur ~100 G/Tag (Katalog nimmt für Phase 1 ~80 an). Mit Turnieren kämen noch etwas dazu;
  Phase 1 ginge dann schneller als 8 Tage. Futterkosten 8 G/Tag liegen unter den 11 des Katalogs, weil die
  Steuer (E4) fehlt und Hafer/Premium nicht gekauft werden. Zahlen nicht geändert.

## E50 Göpel-Generator (C6)
- Je Generator läuft ein Pferd; Bedingungen (vor dem Tageswechsel geprüft): Pferd ist auf dem Hof (Stall/Weide/frei), kein Fohlen, Stärke ≥ 40, Energie ≥ 40. Die stärksten Pferde laufen zuerst. 40 Geld je Pferd, Gutschrift beim Tageswechsel, kein Energieabzug (Energie wird morgens ohnehin zurückgesetzt). `ctx.goepel_mult` (Standard 1) ist der Haken für die Reform „Stromsubvention“ (E4). Bild: einfaches Tretrad, 2×2 Kacheln, unter „Bauten“.

## E51 Land kaufen (C7)
- Das Grundstück ist ein Rechteck (Start 20×20) und wächst im Baumodus unter „Land“ um einen Streifen von 10 Kacheln nach Nord/Ost/Süd/West. Ein Streifen besteht aus 2–n Stücken à 10×10; jedes Stück kostet 500 + 250 × (schon gekaufte Stücke), der Streifen die Summe. Ende am Kartenrand („Kartenrand“). Rechteck statt Einzelstücken, weil Bau, Weiden und Freilauf das Grundstück als Rechteck nutzen. Der Startpunkt bleibt (`farm.home`). Land (auch Wald/Fluss) ist nur Fläche: gebaut wird wie bisher nur auf freien Kacheln.

## E52 Fahrzeuge und Reisen (D1)
- Laden-Reiter „Fahrzeuge“: Zugfahrzeuge (Fahrrad bis Flugzeug) und Anhänger 1–4, je einmal. Ein Zugfahrzeug lässt sich nur kaufen, wenn der Hof das passende Gebäude hat (Schuppen: Fahrrad/Mofa, Garage: Kleinwagen/SUV, Hangar: Flugzeug); Anhänger brauchen nichts. Das beste Fahrzeug bestimmt `max_gebiet`; ohne Fahrzeug 1.
- Reisemenü: A vor der Tür des Gebäudes, das das Fahrzeug unterstellt (zu Hause), bzw. am Fahrzeug am Ankunftspunkt (unterwegs; dort wird es gezeichnet). Das Fahrzeug hat Vorrang vor dem Pferdemenü. Kosten = Fahrtkosten × Abstand der Gebietsnummern. Mit: alle Pferde an der Leine, höchstens so viele wie Anhängerplätze (ohne Anhänger keins); nicht beim Reiten. Die übrigen bleiben im Stall/auf der Weide (nur Daten, keine Figuren).
- Unterwegs: Tage laufen weiter, der Hof pausiert (Pflanzen holen beim nächsten Tag auf, Göpel/Stall-/Schönheitsbonus laufen über `ctx.hof`). Bauen, Stall, Bett, Unterbringen gehen nur auf dem Hof. Speichern unterwegs speichert den Hof-Stand zu Hause (Fahrzeug fährt heim, Mitgenommene stehen an der Leine). Erkundung fremder Gebiete wird nicht gespeichert. Gebiete 2–6 sind bis D2 noch generisch (Größe/Wild aus dem Katalog), die Käufer erscheinen nur zu Hause.

## E53 Gebiete 2–6 (D2)
- Der Generator hatte Größe, Wildpferdezahl und Rassenauswahl (neue Rassen dreifach gewichtet, frühere seltener) schon aus dem Katalog; neu ist nur die Palette: Wiese und Schatten je Gebiet (`Tiles.PALETTES`, gesetzt in `Stage.build` und der Übersicht). Wald, Wasser und Deko behalten ihre Farben. Karte, Speicher je Gebiet geloggt (Karte ≈ 120 KB im Heimattal bis 232 KB im Canyon, 128×112): unkritisch.

## E54 Schätze (D3)
- 15–30 Schätze je Gebiet aus dem Seed, auf freier Wiese, nicht auf dem Hof (+2 Rand), im Dorf oder am Start; mindestens 4 Kacheln auseinander. Fundart gewichtet nach Häufigkeit (40/25/6/2/1); seltene Funde zählen × Gebietsnummer, die Truhe gibt es ab Gebiet 3. Gefundene bleiben weg (`ctx.gefunden[gebiet]`, wird gespeichert).
- Suchen dürfen das geritten Pferd und freie Folger (nicht am Seil), einmal je Sekunde mit Chance Aufspürung/2 % im Radius 2 + Aufspürung/10 Kacheln. Nach 60 Frames ohne Steuerkreuz läuft es hin (Reiter: das Pferd trägt den Spieler; Hindernis: seitlich ausweichen, nach 15 s Aufgeben und 1 min Pause für diesen Schatz).
- Funde: im Heimattal sofort im Haus (Münzbeutel/Hufeisen/Antiquität/Truhe/Blume = Wert in Geld; Samen schalten die Pflanze frei, doppelte zählen halben Samenpreis). In fremden Gebieten braucht das Pferd Satteltaschen mit freiem Platz (sonst spürt es nichts auf); am Fahrzeug werden die Taschen automatisch ins Fahrzeuglager (unbegrenzt) geladen; Heimfahrt oder Speichern unterwegs bringt alles ins Haus und verkauft es. Aufspürung steigt je Fund mit der Trainingsformel (Basis 1).

## E55 Wetter (D4)
- Regen gibt es nur als Tageswetter: aus Seed und Tagesnummer, etwa jeder vierte Tag (`Wetter.CHANCE` 0,25), nur tagsüber gezeichnet (Striche, „Regen“ im Kopf). Wirkung beim Tageswechsel für den Vortag: Pferde auf Weide und frei verlieren 15 Sauberkeit (KATALOG), im Stall nicht; Meldung „Es hat geregnet: n Pferd(e) draußen sind schmutzig“. Kein Gewitter, keine Wirkung auf Tempo oder Zähmen. Gilt in allen Gebieten gleich (der Hof wird ohnehin nur beim Tageswechsel bewertet).

## E56 Sattellampe (D5)
- Die Lampe leuchtet nur, wenn man auf dem Pferd sitzt, das sie trägt; der Sichtkreis nachts wächst von 70 auf 126 Pixel (× 1,8, schon in `Clock:sight`), auch für die Erkundung der Karte. Zu Fuß oder am Seil bleibt es bei 70. Dunkle Pferde-Sprites gibt es weiter nicht (E14, geändert A3).

## E57 Turniere (E1)
- Turnierplatz = das Dorf-Feld „Turnierplatz“ (A in der Nähe). Klasse → Wettbewerb → Pferd; je Pferd werden Sieg- und Podest-Chance vorab gezeigt (200 Probeläufe). Klassen nach bestem Fahrzeug (Dorf immer). Runde = (Tag−1) ÷ 3; verbrauchte Wettbewerbe stehen in `ctx.turnier` (gespeichert).
- Wertung wie Katalog: Fach × (0,5 + Bindung/200). Fach: Schönheit = 0,4 Seltenheit (Farbstufe 60 % + Rassen-Gebiet 40 %) + 0,3 Sauberkeit + 0,3 Schmuck-Schönheit (max 100); Springreiten (Stärke+Ausdauer)/2; Rennen (Tempo+Ausdauer)/2 (effektive Werte). Fünf Gegner, Stärke Mittel 10 + 10 × Klasse (±12, aus Seed und Runde). Tagesform ± 10 % für alle, Platz → Preis 1./2./3.; Fohlen dürfen nicht.
- Balance-Hinweis: Dorf-Gegner (Mittel 20) sind für ein frisch gezähmtes Pferd schlagbar, International (Mittel 70) braucht trainierte Spitzenpferde. Springreiten/Rennen werden in E2/E3 durch Minispiele ersetzt (`punkte`), bis dahin gerechnet.

## E58 Springreiten-Minispiel (E2)
- Seitenansicht: das Pferd galoppiert von selbst (2,2 px/Frame), A springt (30 Frames Bogen), 10 Stangen von 8 bis 30 px, Abstand 105 px, ≈ 14 s. Sprunghöhe wie beim Reiten (6 + 0,3 × effektive Stärke), schwindet mit dem Fortschritt um bis zu die Hälfte × (1 − Ausdauer/100). Zu niedrig an der Stange = Fehler, 24 Frames Stolpern. Punkte = saubere Stangen in % × (0,5 + Bindung/200) und ersetzen die gerechnete Wertung im Turnier. Die Startgebühr wird vorher auf Deckung geprüft, abgezogen nach dem Lauf; kein Abbruch mit B (sonst würde man Gebühr sparen).
- Die Chancen-Anzeige vor dem Start rechnet weiter mit Stärke/Ausdauer (Schätzung); die Leistung im Minispiel kann davon abweichen. Zu Fuß keine Sättel nötig.

## E59 Pferderennen-Minispiel (E3)
- Seitenansicht, 6 Bahnen (eigenes Pferd unten, 5 Gegner), 900 px. A halten = Spurt mit Höchstgeschwindigkeit 1,3 + 2,1 × Tempo × (0,5 + Bindung/200) / 100 px pro Frame; Vorrat 120 + 3 × Ausdauer Frames, danach lahmt es (55 %); ohne A trabt es (70 %) und erholt sich (0,5 pro Frame). Gegner laufen gleichmäßig mit ihrer Turnierstärke ± 10 % Tagesform. Der Platz im Rennen ist der Platz im Turnier (`platz_fix`), die Punkte (Durchschnittstempo als 0–100) stehen im Ergebnis.
- Balance-Hinweis: Wilde Pferde (Tempo ≈ 30–50) kommen im Dorf-Rennen mit klugem Spurt oft aufs Podest, in höheren Klassen brauchen sie Training. Das Ergebnis ist deterministisch bis auf die Eingabe; die Chancenanzeige vorher bleibt eine Schätzung.

## E60 Reformen (E4)
- Zeitung: alle 4 Tage (Tag 4, 8, …) eine neue Reform, Dauer 3–5 Tage, aus dem Seed; Wölfe/Krokodile erst 4 Tage nach dem ersten Besuch von Gebiet 3/5. Bis zu drei Reformen können sich überlappen, dieselbe läuft nicht doppelt. Pause-Menü „Zeitung“ zeigt aktive Reformen mit Ablauftag und die nächste Ausgabe; am Morgen meldet die Welt Neue Reform, Angriff oder Steuer.
- Wirkung: Hafersteuer +50 % auf Futter (Laden); Stromsubvention Göpel ×2 (`Reformen.faktor_strom`); Pferdesteuer = (Tag−1)÷6 pro Pferd und Tag, höchstens 10, nie mehr als das Geld.
- Tiere (Hunde nachts, Wölfe nachts, Krokodile auch tags): Angriff wird abstrakt beim Tageswechsel gewürfelt, nicht gespielt. Gibt es ein Pferd auf Weide oder frei mit Stärke ≥ 40/60/80, wird abgewehrt (und trainiert Stärke +0,2). Sonst: 2 Tiere (Krokodile 4) zerstören je 2 Deko-Stücke (Bank, Lampe, Büsche, Brunnen …, ohne Geld zurück), Pferde draußen verlieren 5 Bindung. Pferde im Stall sind sicher, auch starke wehren von dort nicht ab. Auf dem Bildschirm laufen die Tiere nur als Bild um den Hof (vier Sprites, keine Kollision, keine Eingriffsmöglichkeit).
- Balance-Hinweis (E4): Deko-Verlust ist spürbar, aber ein starkes Pferd auf der Weide löst es komplett; ob das zu einfach ist, zeigt der Konsolentest.

## E61 Sammelalbum (E5)
- Eingetragen wird die Kombination Rasse × sichtbare Farbe, sobald ein Pferd davon im Bild ist (Wildpferde in der Kamera, alle 30 Frames geprüft) oder dir gehört (Zähmen, Kauf, Zucht). Die verborgene Zweitfarbe zählt nicht. Mögliche Kombinationen = Farben-Matrix je Rasse (120 insgesamt); neue Einträge melden „Album: n neu eingetragen“.
- Pause-Menü „Album“: eine Seite je Rasse (Links/Rechts), 5 Felder je Reihe in Seltenheitsreihenfolge, Unentdecktes als „?“, Cursor mit Hoch/Runter zeigt den Farbnamen. Gespeichert in `ctx.album`. Kein Gebietsbezug und keine Belohnung für Vollständigkeit (noch).

## E62 Tauschcode (E6)
- Code: 28 Zeichen (in 4er-Gruppen mit Strich angezeigt), Alphabet 32 Zeichen = A–Z ohne I und O plus 2–9 (5 Bit je Zeichen; ohne I/O/0/1, weil verwechselbar). Länge geändert gegenüber dem Katalog-Vorschlag (16), weil ein Pferd mit allen Werten ≈ 130 Bit braucht: Rasse 4, Geschlecht 1, Charakter 3, zwei Farben 10, Gen/Training/Potenzial 4 × 3 × 7 Bit, Bindung 7, Alter 4 Bit (Fohlen ≈ 1/15-Schritte), Kennung 16, Prüfsumme 10. Training und Werte werden auf ganze Zahlen gerundet.
- Nicht im Code: Name (aus der Kennung gewählt, umbenennbar), Stammbaum, Ausrüstung (kommt beim Abgeben zurück in den Vorrat), Tageszustand (Hunger/Sauberkeit/Gewicht/Energie starten frisch). Ein verfälschter Zeichen ergibt nie ein anderes Pferd (Test über alle Positionen), Tippfehler melden „Prüfsumme“. Der Code kann ohne Server nicht vor Mehrfachnutzung durch mehrere Spieler schützen; auf demselben Hof ist jeder Code einmal einlösbar (`ctx.getauscht`, gespeichert).
- Bedienung: Pause → Tauschen: „Pferd abgeben“ (Pferd wählen, Rückfrage, Code groß anzeigen, Pferd ist weg), „Code eingeben“ (Tastatur mit den 32 Zeichen). Kein Abgeben beim Reiten.

## E63 Kachelmenüs und Abenddämmerung (Rückmeldung nach 0.5.0)
- geändert (E5, E7, Rückmeldung): Menüs mit Bildern sind ein Kachelraster statt einer Liste: Pausenmenü (5 × 2),
  Pferdemenü (4 × 2), Füttern (mit Vorrat als Zahl in der Ecke), Unterbringen (mit Plätzen) und Stalltür. Steuerkreuz in
  alle vier Richtungen (umlaufend), unter jedem Bild ein Kurzname, darunter der volle Name der gewählten Kachel.
  Ausgegraute Kacheln lassen sich anwählen, A tut dort nichts. Listen ohne Bilder (Ausrüstung, Hengst/Stute) bleiben Listen.
  Icons 12 × 12 in `sprites.txt` (`ico_…`), doppelt groß gezeichnet. Meldungen erscheinen bei offenem Menü oben.
- geändert (E14, Rückmeldung): Statt des harten Sichtkreises legt sich ein Dither-Schleier (Bayer 4 × 4, 14 Stufen,
  Farbe Nachtblau) über die Welt. Ab 60 s vor der Nacht wird es gleichmäßig dunkler (Nachtbeginn 55 %), 30 s später
  ist es ganz dunkel (14/16), die letzten 30 s der Nacht und nach dem Aufwachen wieder heller. Erst mit der Nacht
  bleibt um den Spieler ein hellerer Bereich (weich bis 112 px, Sattellampe × 1,8). Zeichenaufwand: Abend 75,
  tiefe Nacht ≈ 180 Sprite-Aufrufe je Frame (gleiche Stufen als 64-px-Streifen). Auf der Konsole prüfen, ob das flüssig läuft.

## E64 Nacht mit echter Transparenz, Emoji-Reaktionen, Laden (Rückmeldung nach 0.5.1)
- geändert (E63, Rückmeldung „Raster hässlich“): neue Engine-Funktion `shade(c, a, [x, y, r0, r1, a0])` (API 2, mit dem
  Menschen abgesprochen). Der Abend mischt die Welt stufenlos mit Nachtblau (bis 86 % deckend); ab 45 % Dunkelheit
  hält der Sichtbereich um den Spieler die Helligkeit fest (weicher Rand 40–112 px, Sattellampe × 1,8). Raster-Sprites
  entfernt. Ausgegraute Kacheln nutzen ebenfalls `shade`. Hoofy braucht damit `"api": 2` und neue Firmware.
- Pflege ohne Zahlen (Rückmeldung): Streicheln und Füttern zeigen ein Herz über dem Pferd (Füttern ohne Bindungsgewinn:
  Apfel; schon gestreichelt: Zzz), Striegeln Glitzer, Reiten verweigert: Gewitterwolke. Info öffnet den Info-Bildschirm.
  Meldungen werden umgebrochen, der Kasten wächst mit. Auf dem Grundstück steht oben „Dein Hof“.
- Laden (Rückmeldung „Pferde von der Weide an der Leine“): Beim Laden wird die gespeicherte Unterbringung ohne neue Platz-
  oder Bindungsprüfung wiederhergestellt (Weide: die gespeicherte zuerst); an die Leine nur, wenn es gar keine Weide mehr
  gibt. Außerdem zeigte `ctx.hof` nach „Weiter“ auf eine zweite, nicht angewandte Kopie des Hofs (Reisen nahm sie mit):
  jetzt der Hof der Karte. Die genaue Ursache auf der Konsole ließ sich am Rechner nicht nachstellen.


## E65 Spielverlauf, Licht, Leine, Baumodus (Rückmeldung nach 0.5.2)
- Freischalten nach Spieltag (`game/fortschritt.lua`, Werte vom Loop gewählt): Bestellungen ab Tag 4, Käufer im Dorf ab Tag 5
  (Sammlerin ab Tag 9), Turnierplatz ab Tag 7, Tauschen ab Tag 9, Zeitung/Reformen ab Tag 10, Hunde frühestens ab Tag 16.
  Noch nicht freie Einträge fehlen im Pausenmenü ganz; am Morgen des Freischalttags kommt eine Meldung „Neu: …“.
- Tag und Nacht × 1,25 (`Clock.LONGER`): 6:15 min, davon 3:45 hell. Der Katalog (5 min) bleibt unverändert; Abend-
  und Morgenübergänge behalten ihre Länge. Schlafen geht ab 2 min vor der Nacht.
- Laterne (nicht im Katalog): 80 G im Laden unter Zubehör, einmal kaufen, ab der Dämmerung hält die Figur sie hoch. Ohne
  Laterne und ohne Sattellampe ist die Nacht gleichmäßig dunkel (kein Sichtbereich), Erkundung nachts nur 60 % des Radius.
  Sattellampe beim Reiten bleibt × 1,8.
- Leine: höchstens 1 Pferd am Strick, frei folgende (Bindung ≥ 70) zählen nicht (zusammen weiter höchstens 4). Ist der Strick
  belegt, bleibt ein frisch gezähmtes oder abgesessenes Pferd lose stehen; aus dem Stall holen geht dann nicht.
- Weidetor: Pferde, die allein laufen (lose, auf der Weide, ausgerissen, wild), betreten keine Torkachel; an der Leine,
  folgend (auch nach Pfiff) und geritten geht es durch.
- Flucht (Wildpferde, ausgerissene Pferde): Richtung alle 12 Frames neu, weg vom Spieler, aber nur dorthin, wo die nächsten
  42 px frei sind (sonst schrittweise seitlich, zuerst zur zuletzt gewählten Seite).
- Käufer steht im Dorf vor dem Wohnhaus statt am Hoftor. Röntgen-Umriss hinter Objekten entfernt. Staub beim Rennen liegt
  am Boden (unter den Figuren). Waldboden: vier nahtlose Blätterdach-Kacheln statt runder Kugeln im Raster.
- geändert (E8): Baumodus: START öffnet die Auswahl als Kachelmenü (erst Art, dann Bauteil mit Bild und Preis), A baut,
  B schließt sofort (kein „B halten + Pfeile“ mehr). Leiste unten neu (Bauteil mit Bild, Meldung oder Schönheit, Tasten).
  Raster: 2 × 2 Pixel große helle Punkte an allen Kachelecken des Grundstücks. Behoben: Auswahl außerhalb der Liste, wenn
  die Samenliste beim Pflanzen kürzer wird; Meldung und Schönheit überlagerten sich.

## E66 Dorf, Baumodus, Land, Album (Rückmeldung nach 0.5.3)
- Ortsnamen im Dorf (Laden, Pferdemarkt, Jobbrett, Turnierplatz) ohne Kasten, helle Schrift mit dunklem Schatten, nur
  wenn der Spieler höchstens 34 px vom Ort entfernt ist. Auf den Karten bleiben die Punkte.
- Pferdemenü: Kachel „Unterbringen“ heißt „Ort“; Haus-Symbol symmetrisch mit Traufe neu gezeichnet. Pferdeliste nur
  noch Name und Rasse (ohne Ort und „B“ = Bindung). Stammbaum: „?“ statt „unbekannt“, ohne Hinweise unten.
- Baumodus: Bauteil-Menüs aller Arten nur mit Bild und Preis, Name unten (Art-Auswahl behält die Namen). Raster:
  Punkte nur noch an jeder zweiten Kachelecke.
- geändert (C7): Land kaufen feldweise statt streifenweise. Das Grundstück besteht aus 10×10-Feldern (Raster an
  Vielfachen von 10, `farm.parcels`), `farm.plot` ist nur noch das umschließende Rechteck. Kaufbar ist ein Feld, das an
  ein eigenes grenzt (nicht diagonal), ganz auf der Karte liegt und nicht ins Dorf ragt; Preis 500 G, jedes weitere
  +250 (wie bisher je Stück). In der Art „Land“ springt der Cursor feldweise bis ein Feld über das Grundstück hinaus,
  das Feld ist grün (kaufbar) oder rot getönt. Bauen, Weiden, freie Plätze (je 50 Kacheln der Felder), „Dein Hof“ und
  lose Hofpferde richten sich nach den Feldern. Alte Spielstände bekommen die Felder aus dem Rechteck.
- Laterne: Schirm wie ein Trichter, unten offen mit Licht, 7 × 9 Pixel.
- Album: nur eigene Pferde (gezähmt, gekauft, gezüchtet) werden eingetragen, Wildpferde im Bild nicht mehr.
- Karte (Nachtrag): ohne die Schrift „Hof“ und „Dorf“ und ohne die Legende unten; der Hof bleibt gelb umrandet. Nur
  noch über das Pausenmenü, nicht mehr mit SELECT (E6 geändert); A oder B schließt.

## E67 Töne, Laden loser Pferde, Sprechblasen (Rückmeldung nach 0.5.4)
- Laden: Ursache war wohl, dass die Pferde in die Weide geführt und dort losgelassen, aber nicht über „Ort → Weide“
  untergebracht waren (seit 0.5.3 kommen sie allein nicht mehr durchs Tor, sehen also aus wie auf der Weide). Gespeichert
  wurde nur die Unterbringung; ohne kamen beim Laden alle an die Leine, wegen höchstens 1 am Strick standen die übrigen
  lose neben dem Spieler. Jetzt merken sich lose Pferde beim Speichern und vor einer Reise ihren Platz (`lose = {x, y}`)
  und stehen nach dem Laden wieder dort. Lose Pferde werden dabei bewusst nicht automatisch zu Weidepferden.
- Töne: nichts unter A4 (440 Hz), Rauschen ab 400 Hz (Hufschlag, Schnauben, Landung, Fressen ×4 höher). Musik eine Oktave
  höher, Tag 96 → 112 bpm, Nacht 56 → 66 bpm, etwas leiser (höhere Töne klingen lauter).
- Sprechblasen 21 × 18 statt 13 × 13, Symbole 11 × 9 mit dunklem Umriss (Herz, Apfel rot; Blitz, Mond, Glitzer gelb mit
  Goldrand; Zzz blau). Die Spitze des Zipfels bleibt, wo sie war; der Ausruf des Käufers nutzt dieselbe Zeichnung.
- Freie Tiere (Hunde, Wölfe, Krokodile) sind jetzt Figuren in der Welt statt gemalter Bahnen: 4 Stück, Fußkasten wie
  Pferde (Krokodil breiter), laufen mit 0,7 px/Frame zu zufälligen freien Punkten auf dem eigenen Land und suchen ein
  neues Ziel, wenn sie hängen bleiben. Sie verlassen das Grundstück nicht, werden richtig nach Tiefe sortiert und
  verschwinden morgens. Schaden bleibt wie bisher abstrakt beim Tageswechsel.
- Laterne hängt an der rechten Hand der Figur (von vorn links im Bild, von hinten rechts, seitlich an der sichtbaren
  Hand), sichtbar erst ab Dunkelheit 0,45, also zusammen mit dem Lichtkreis; vorher (Tag, früher Abend) nicht.

## E68 Fahrzeug-Sprites und Gebietsfarben (Rückmeldung nach 0.5.5)
- Eigene Sprites für Fahrrad, Mofa, Kleinwagen (kompakt wie ein Golf), Luxus-SUV (schwarz, Chrom, getönte Scheiben)
  und Flugzeug sowie für die Anhänger mit 1–4 Plätzen (ein Fenster je Platz). Zu Hause steht das Zugfahrzeug in
  Schuppen/Garage/Hangar, nur der Anhänger parkt rechts neben der Tür; unterwegs steht das ganze Gespann rechts neben
  dem Ankunftspunkt. Nach Tiefe sortiert. Laden (Reiter Fahrzeuge) und Reisemenü zeigen das Bild.
- Gebiete nur per recolor: Wiese, Wald, Bäume, Büsche, Steine, Deko, Wege, Sand, Ufer- und Wegränder heißen `land_…`;
  jedes Gebiet hat eine recolor-Zeile in sprites.txt (birke, aue, steppe, canyon, nebel) und `Tiles.set_palette`
  schaltet die Namen um. Wasser, Brücken und Hofbauten bleiben gleich.

## E69 Häuser, Ställe, Garagen abreißen (Rückmeldung nach 0.5.6)
- Wohnwagen/Häuschen/Villa, Ställe und Schuppen/Garage/Hangar lassen sich abreißen, solange noch einer derselben
  Art steht; auch Wohnwagen und Stall S vom Start. Sonst rot mit „erst ein zweites Haus bauen“ usw.
- Eigene Ergänzungen: Startbauten bringen nichts zurück (waren geschenkt). Ein Stall nur, wenn die übrigen alle
  Stallpferde fassen („erst Pferde aus dem Stall holen“); eine Garage nur, wenn das eigene Fahrzeug in einer
  anderen unterkommt („Mofa braucht sie“).
- Titelbildschirm ohne „Pferdezüchter im Jahr 2040“.

## E70 Laden in Rot/Rosa, Bürste kaufen (Rückmeldung nach 0.5.7)
- Laden-Reiter als Icons (die Namen passten nicht mehr in eine Zeile), Name im Kopf: „Laden:“ rosa, Rubrik weiß.
  Ladenmenü in Rot, Dunkelrot, Rosa; Linie unter den Reitern in der Farbe des aktiven Reiters, der in sie übergeht.
  Fahrzeuge und Anhänger durch eine Linie getrennt. Das Ladengebäude im Dorf in denselben Farben.
- Bürste unter Zubehör statt Futter. Start ohne Bürste: „Striegeln“ im Pferdemenü ist ausgegraut, bis sie gekauft ist
  (alte Spielstände behalten ihre).
- Nach dem Absteigen (A halten) öffnet die Tastenwiederholung nicht mehr das Pferdemenü.

## E71 Frisch gezähmt (Rückmeldung nach 0.5.8)
- Beim Zähmen merkt sich das Pferd seine Bindung; reitbar erst bei +6 darüber (z. B. 3× Heu, Striegeln, Streicheln).
  Bis dahin schnaubt es beim Aufsitzen mit Gewitter-Blase und Hinweis; die Info zeigt „Frisch gezähmt: noch nicht reitbar“.
- Solange es frisch ist, reißt es an der Leine beim Sprinten oder Reiten ×3 so oft aus, im Gehen unverändert.
- Eigene Wahl: relativ zur Start-Bindung statt der Katalog-Schwelle „ab 40 reitbar“ (Mustang mit 10 bräuchte sonst
  30 Punkte). Gekaufte, gezüchtete und alte Pferde sind nie frisch.

## E72 Fahrzeuge im Laden (Rückmeldung nach 0.5.8)
- Fehlt die Unterbringung, nennt der Laden das Gebäude: „Für das Mofa fehlt dir ein Schuppen.“ (Garage, Hangar ebenso).
- Kurztexte statt Zahlen, Reichweite steckt im Zielgebiet, Sprit im Ton: Fahrrad „Strampeln statt tanken … Birkenwald,
  kostet nur Muskelkater“, Mofa „knattert bis in die Flussauen“, Kleinwagen „mit Heizung … bis in die Steppe“, SUV
  „groß, schwarz, durstig … Canyon“, Flugzeug „bis zur Nebelinsel … Tank teuer, Aussicht unbezahlbar“. Texte stehen in
  game/economy.lua (FAHRZEUG_TEXT), nicht im KATALOG.

## E73 Pferde im Anhänger, kein Dorf unterwegs (Rückmeldung nach 0.5.8)
- Pferde fahren nur im Anhänger mit (ein Platz je Pferd). Einladen: mit dem Pferd an der Leine zum Anhänger (oder
  Fahrzeug) und A, oder Pferdemenü → Ort → Anhänger (zu Hause von überall auf dem Hof, unterwegs auch). Bei der
  Ankunft stehen sie lose neben dem Anhänger.
- Eigene Ergänzungen: Pferde an der Leine steigen bei der Abfahrt von selbst ein, wenn Platz ist (wie bisher). Unterwegs
  hält ein eigenes Pferd, das nicht im Anhänger ist, die Abfahrt auf („Hilde ist nicht im Anhänger“), damit keins
  verloren geht; dafür gibt es unterwegs unter Ort „Freilassen“ (Kachel „Wildnis“), falls mehr gezähmt sind, als
  Plätze da sind. Im Reisemenü „Pferde ausladen“, solange welche drin sind (sonst kämen sie zu Hause nicht mehr heraus).
- Absturz behoben: Ort im Pferdemenü fragte unterwegs den Hof ab (farm.lua:312).
- Dorf (Laden, Markt, Jobbrett, Turnierplatz, Käufer) gibt es nur im Heimattal; fremde Gebiete sind Wildnis.

## E74 Neues Spiel, Fahrzeugwahl, Reisemenü, Blumen (Rückmeldung nach 0.5.9)
- Neues Spiel bei vorhandenem Spielstand fragt nach: nennt Tag, Pferde und Geld des alten Stands, „Nein, zurück“ ist
  vorgewählt, „Ja, alles löschen“ in Rot; B geht zurück.
- Fahrzeugwahl: im Reisemenü ← → zwischen den eigenen Fahrzeugen im selben Gebäude (Schuppen: Fahrrad/Mofa, Garage:
  Kleinwagen/SUV). Die Wahl merkt sich der Hof (hof.fahrzeug) und gilt für Reichweite, Spritkosten und den Platz des
  Anhängers. Eigene Ergänzung: A geht an jeder Fahrzeug-Tür, nicht nur an der des gewählten; dort ist dann das beste
  Fahrzeug dieses Gebäudes gewählt. Markt, Samen und Turnierklassen richten sich weiter nach dem besten im Besitz.
- Reisemenü wie die Pferde-Info: Fahrzeugname groß mit „< >“, Kasten mit Anhänger, Reichweite, Sprit und Bild des
  Gespanns, darunter „Wohin?“. Fehler behoben: Kopfzeile lief bei langen Namen in das Geld, und gehaltenes A vom
  Öffnen fuhr nach einer Viertelsekunde gleich los (A zählt jetzt erst nach dem Loslassen).
- Blüten der kleinen Blumen je Gebiet (eigene Wahl): Birkenwald hellblau/weiß, Flussauen blau/gelb (Vergissmeinnicht,
  Sumpfdotter), Steppe rot/lila (Mohn), Canyon gelb/weiß mit roter Mitte, Nebelinsel türkis/hellviolett.

## E75 Heimfahrt ohne Geld, Schuppendach, Reisemenü blau (Rückmeldung nach 0.5.9)
- Die Heimfahrt kostet höchstens das Geld, das noch da ist (auch 0 G), damit man unterwegs nie festsitzt. Fahrten in
  andere Gebiete brauchen weiter den vollen Preis.
- Schuppen ohne das graue Blechdach: flaches Holzdach mit kleinem Überstand.
- Reisemenü (Garage) in gedämpften Blautönen, wie der Laden mit eigener Palette (GARAGE in game/screens.lua); das Bild
  des Gespanns steht auf grauem Grund mit angedeuteter Straße statt auf Gras.
- `make run GAME=hoofy SCENARIO=reise` startet ein Szenario im Fenster.

## E76 Vorspann, Klick-Effekt (Rückmeldung nach 1.0.0)
- Vor jedem neuen Spiel ein kurzer Vorspann mit der Story (README §1) in vier Bildern über dem abgedunkelten Hof:
  Krise und „PLEITE“-Autos, teures Benzin und galoppierende Pferde, Zeitung „REFORM!“, Wohnwagen und Stall. Der Text
  baut sich auf; A zeigt ihn ganz bzw. blättert, START überspringt. Texte in game/intro.lua (eigene Formulierung).
- Kachel- und Listenmenüs lösen jetzt beim Loslassen von A aus (vorher beim Drücken). Solange A gedrückt ist, ist die
  Kachel hell umrandet und der Name unten weiß statt gold; wer mit gedrückter Taste weiterwählt, bricht ab.
- Vollbild-Menüs: In der Tastenleiste leuchtet der Teil der gedrückten Taste gold („A: kaufen“, „B: zurück“, „</>“).

## E77 Absturz beim Start auf der Konsole (Rückmeldung nach 1.1.0)
- Auf der Konsole startete 1.1.0 nicht (Neustart-Schleife). Ursache sehr wahrscheinlich der Speicher: sprites.png war
  256×2926 RGBA. lodepng hält beim Dekodieren zwei 3-MB-Puffer, die Engine danach 3 MB RGBA plus 2,25 MB Bild, alles
  zusammenhängend im 8-MB-PSRAM neben dem Lua-Heap. Seit 0.5.5 (2795 Zeilen, lief noch) ist das Blatt gewachsen.
- tools/sprites.py verteilt Sätze über 512 Zeilen auf mehrere Bilder (Hoofy: sechs, je höchstens 256×510); der 5.
  Eintrag eines Rechtecks ist sein Bild. Dauerhaft bleibt es bei 2,1 MB, beim Laden kommt nur noch ~1,5 MB dazu.
  Tilemap, Welt und Menü-Icons zeichnen mit `r[5]`. Selbsttest prüft die Größe des größten Bilds.

## E78 Schmuck, Stall von innen, Zähmen, Anbau, Jobs, Göpel, Zucht (Rückmeldung nach 1.2.1)
- Schmuck sichtbar: tools/hoofy_pferde.py erzeugt Overlays für alle Körper und Posen (Schleife pink in der Mähne,
  Blumenkranz um den Hals, Glitzerdecke lila mit Goldrand, Goldhufeisen), Lage in game/schmuck_pos.lua. Zu sehen in
  der Welt, in Info, Pferdeliste, Springreiten, Stall und Jobs. Szenario `schmuck` zeigt alles.
- Schmuck teurer (eigene Wahl, KATALOG §8 angepasst): Mähnenschleife 30 → 150, Blumenkranz 60 → 300,
  Glitzerdecke 250 → 1 200, Goldhufeisen 1 000 → 4 000.
- Stall von innen: A an der Stalltür öffnet die Ansicht (hat jetzt Vorrang vor dem Pferd an der Leine). S 2 Boxen,
  M 4 mit Fenstern, L 8 in zwei Reihen mit Steingasse, rot; XL 12 dunkles Holz mit Goldleiste und Lampen. Pferde
  verteilen sich der Reihe nach auf die Ställe. Pferd + A: Pferdemenü mit „Holen“ statt Leine, ohne Reiten, mit
  „Zucht“ (Partner wählen, Verwandtschaft steht dabei). Leere Box + A: das Pferd an der Leine einstellen. Das
  alte Stallmenü ist weg. Das Pferdemenü steckt jetzt in game/horse_menu.lua (Welt und Stall).
- Zucht-Absturz: am Rechner nicht nachzustellen (Szenario `zucht` mit Hengst und Stute lief durch). Der Ablauf ist
  neu gebaut und mit Tests abgesichert; bitte auf der Konsole prüfen und melden, falls es wieder abstürzt.
  geändert (1.3.1): Ursache gefunden. Das Spiel hing in einer Endlosschleife: Breeding.ensure_id verglich die neue
  Kennung auch mit dem Pferd selbst. Gezähmte Pferde hatten keine Kennung, bis der Spielstand einmal geladen war; kam
  so ein Pferd zur Zucht, fand die Schleife immer einen „Treffer“. Jetzt zählt das Pferd selbst nicht, und gezähmte
  Pferde bekommen sofort eine Kennung. Selbsttest dazu in game/tests/zucht.lua.
- Info zeigt nur noch die sichtbare Farbe, die versteckte (rezessive) bleibt geheim (1.3.1).
- Fohlen kommt in den Stall. Kein Platz: das billigste Stallpferd (nie Mutter oder Fohlen) zieht auf die Weide; ist
  die voll, zieht dort das billigste aufs Grundstück (frei, auch wenn es sonst zu schwach dafür wäre); ist auch das
  voll, läuft das Pferd mit dem geringsten Wert fort (Meldung). Eigene Ergänzung: Wird unterwegs ein Fohlen geboren,
  steht es im Stall zu Hause, Platz gemacht wird bei der Heimkehr.
- Zähmen schwerer: Sprinten (oder Galopp) in der 110-px-Zone verscheucht das Pferd sofort. A muss man drücken, während
  es wegschaut (schaut es her, flieht es), dann stillstehend halten: 1,5 s + 1 Frame je fehlendem Bindungspunkt
  (Bindung 35 → 2,6 s), Balken über dem Pferd. Loslassen oder Gehen bricht ab.
- Losgerissen: Ein gezähmtes Pferd ist „neu“, bis es einmal auf deinem Grundstück stand (oder untergebracht wurde).
  Reißt es sich vorher los, ist es wieder wild (Bindung wie vor dem Zähmen, zählt wieder als Wildpferd). Danach reißt
  es wie bisher nur aus und bleibt deins.
- Apfelbaum wächst ohne Beet auf freiem Gras des Grundstücks (auch auf Beeten). Beete und Felder kosten nichts, man
  braucht aber einmal eine Hacke (100 G, Laden → Zubehör, eigene Wahl des Preises). KATALOG §7/§9 angepasst.
- Jobs als Minispiele (je etwa 20 s): Postritt (A wirft den Brief, wenn der Briefkasten im Rahmen ist; daneben zählt
  halb dagegen), Kutschtaxi (↑/↓ Spur wechseln, Fahrgäste einsammeln, Pfützen/Steinen ausweichen), Pflügen (A, wenn
  der pendelnde Zeiger im Grünen ist; Stärke macht das Grüne breiter, 18 Furchenstücke in 20 s). Lohn = 40 % sicher
  + 60 % nach Ergebnis. Energie geht wie im Katalog ab (30/30/40) und läuft oben im Bild sichtbar herunter.
- Göpel als Unterbringung: unter „Ort“ gibt es „Göpel“, ein Pferd je Generator (ausgewachsen, Stärke ≥ 40). Es läuft im
  Kreis um den Generator, mit Zugbalken. Geld bringen nur noch Pferde am Göpel (vorher zog automatisch das stärkste
  untergebrachte Pferd) – nach dem Update also ein Pferd an den Göpel stellen. Göpel mit Pferd lässt sich nicht
  abreißen. Regen trifft Göpel-Pferde wie Weidepferde.
- README_HOOFY.md beschreibt Jobs und Göpel noch wie vorher (nicht geändert, gehört dem Menschen).
- Neue Szenarien: `zucht` (geburt = true), `stall` (stall = "stall_xl" …), `goepel`, `jobspiel` (job = …), `schmuck`.

## E79 Feld, Namen, Verkauf, Beete, Futter (Rückmeldung nach 1.3.1)
- Feld gestrichen (war dasselbe wie das Beet). Alte Spielstände: Felder werden beim Laden zu Beeten, Pflanzen darauf
  bleiben (Selbsttest). KATALOG §7/§9 sagt nur noch „Beet“.
- Namen: Kein neues Pferd heißt wie eins, das es schon gab. Belegt wird ein Name, sobald das Pferd dir gehört (gezähmt,
  geboren, gekauft, getauscht, umbenannt); die Liste steht im Spielstand (`namen`). Eigene Wahl: Wild- und Marktpferde
  bekommen beim Erzeugen nur einen noch freien Namen und belegen ihn erst beim Zähmen/Kauf, sonst wären die Namen
  nach ein paar Reisen aufgebraucht. Nach den 57 Namen kommen zusammengesetzte (Sternentänzer, Windflocke …, 240
  Stück), danach „Blitz II“ usw. Ältere Spielstände: vergeben sind die Namen der eigenen Pferde und ihrer Vorfahren;
  Namen früher verkaufter Pferde kennt der Spielstand nicht.
- Verkaufen an Käufer und Liefern bei Bestellungen fragen nach („Nein, behalten“ vorgewählt) und nennen, was zurück in
  den Vorrat geht. Sattel, Taschen, Lampe und Schmuck bleiben bei dir (beim Tauschen war das schon so).
- Beete: Das leere Beet ist jetzt helle, gepflügte Erde ohne Grün (vorher das Möhrenbeet, sah bepflanzt aus). Unter
  jeder gesäten Pflanze liegt in allen Stufen ein dunkler, feuchter Erdhügel.
- Füttern: unten steht zum gewählten Futter „Heu: Hunger -30“ (die Anzahl steht weiter auf der Kachel).
- Leine: zwei Pferde am Strick statt einem (E65 geändert: 1 → 2, Wunsch des Menschen). Frei folgende zählen weiter
  nicht, zusammen höchstens 4. Jedes Pferd am Strick würfelt fürs Ausreißen für sich.

## E80 Lose Pferde in der Weide zählen (Rückmeldung nach 1.3.2)
- geändert (E67): Ein Pferd, das innerhalb einer Weide losgelassen wird, ist jetzt Weidepferd dieser Weide und zählt
  unter „Ort“, solange dort Platz ist (Meldung „… bleibt auf der Weide.“). Ist die Weide voll oder steht es draußen,
  bleibt es lose wie bisher. Beim Laden werden lose Pferde, die in einer Weide stehen, ebenso zu Weidepferden, auch in
  vorhandenen Spielständen.
- Apfelbaum (Rückmeldung nach 1.3.2): Nach der Ernte bleibt er groß, erst ohne Äpfel, ab halber Zeit bis zur nächsten
  Reife mit grünen Äpfeln (pflanze_apfelbaum_leer/_gruen, Farm.BAUM). Vorher fiel er auf den Setzling zurück. Schon
  geerntete Bäume in alten Spielständen erkennt das Laden am Abstand bis zur nächsten Reife (3 statt 4 Tage).
- Startweide abreißbar (Rückmeldung nach 1.3.2): Zaunring und Tor der Startweide waren fest im Hof (farm.weide) und
  ließen sich nicht abreißen. Beim Anwenden des Hofs werden sie einmalig zu normalen Bauteilen (zaun/tor, start = true),
  in neuen wie alten Spielständen. Abreißen bringt wie bei den Startbauten nichts zurück. Die Weide funktioniert gleich
  (4 Plätze, gleiche Kennung, Weidepferde bleiben).
- Schlachter: übrige Pferde −20 statt −10 Bindung (KATALOG §6). Die Wirtschafts-Simulation (game/sim.lua) lässt den
  Spieler seitdem nicht mehr an den Schlachter verkaufen; sonst brachen die Turniergelder ein (Phase 5: 242 statt
  ≤ 210 min). Mit dieser Annahme: Phasen 58–115 min, bis zum Flugzeug etwa 7,2 h.
- Baumodus: Die Welt steht dort schon still (Uhr, Pferde, Tiere; im Test bewegt sich zwischen Frame 10 und 400 nichts
  außer der Meldungszeile). Nichts geändert, Rückfrage an den Menschen, was sich noch bewegt.

## E81 Zähmen: das Pferd hört (Rückmeldung nach 1.3.4)
- Zu E16/E28: Ein verborgener Lärmpegel (0–1) steigt, solange du in der Zone (110 px) gehst oder reitest, nah am
  Pferd schneller (voll nach 1,7 s am Rand, knapp 1 s ganz nah), und sinkt im Stehen (voll → leer in 1,5 s). Ab 60 %
  ❗ mit Warnton, das ❗ bleibt bis unter 35 % (Hysterese). Voll = Flucht. Gilt in jedem Zustand außer der Flucht,
  zusätzlich zum Wegschauen/Hinschauen. Zahlen sind eigene Wahl (NOISE_* in game/wild.lua).
