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

## Werte

- **E15** Bindung-Startwert: Rassenwert ± 5 zufällig; schreckhaft −10, faul +5, verfressen +5,
  eitel 0, Nachteule 0.
- **E16** Zähmen: Das Wildpferd schaut 2–4 s weg, dann 1–2 s zu dir (vorher 0,3 s Warnblase ❗).
  Bewegst du dich, während es schaut, flieht es ein Stück. Je niedriger die Bindung, desto
  kürzer das Wegschauen. Nah genug + A = gezähmt, es kommt an die Leine.

## Balance

(Befunde aus Simulationen; Katalogwerte ändert nur der Mensch.)
