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
