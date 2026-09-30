# Hoofy 🐎
Ideen, Konzept, Funktionen

## 1. Überblick

### Kernelemente
- Pferde finden
- Pferde pflegen (trainieren, füttern …)
- Pferde züchten
- Geld verdienen (Pferde verkaufen, Turniere, Maschinen)
- Baumodus

### Story
Wir schreiben 2040. Aus dem KI-Boom wurde eine Wirtschaftskrise, weil viele Autohersteller pleitegegangen sind. Die Folge: Fahrzeuge sind sehr teuer geworden, dafür sind Pferde als Fortbewegungsmittel wieder interessant. Gut für dich, denn du bist Pferdezüchter.
Auch Benzin und Strom sind teuer, deshalb kann man z. B. einen pferdebetriebenen Stromgenerator bauen.
Die Bevölkerung ist sehr unzufrieden und hat deshalb eine radikale Regierung gewählt. Leider hat sich diese als inkompetent herausgestellt. Einige Reformen sind gut, andere eher verrückt. Sie beeinflussen das Spiel (siehe Regierungsreformen).

### Rahmen und Stil
* Für open-086 (ESP32-S3, retro-go)
* Nur privat – Lizenzprobleme ignorieren
* Keine FSK-Beschränkung 😈
* Stil: eher quatschig, lustig, aber auch beruhigend
* Grafik: 3/4 Perspektive mit Sprites, wie Ausgebüxt.

## 2. Das Pferd

### Werte
Jeder Wert setzt sich aus Gen-Stat und Trainings-Stat zusammen. Die Summe (Gesamt-Stat) bestimmt, wie sich das Pferd verhält. Nach oben begrenzt ist sie durch das Max-Potenzial, unbegrenzt trainieren geht also nicht. Vererbt werden nur die Gen-Stats. Wilde Pferde haben noch keinen Trainingsfortschritt.
Jede Rasse hat Basis-Stats. Gen-Stats und Max-Potenzial eines Pferdes weichen davon zufällig (statistisch verteilt) ab.
Beispiel: Mustangs haben eine Basis-Geschwindigkeit von 30. Man findet einen wilden Mustang mit Gen-Geschwindigkeit 40 (= Gesamt-Geschwindigkeit, da untrainiert) und Max-Potenzial 60. Gezähmt lässt er sich bis 60 trainieren, für Nachkommen zählen aber nur die 40.

- [ ] Geschwindigkeit (0–100)
- [ ] Stärke (0–100): Sprunghöhe, Ziehen und Zertreten von Sachen, Abwehr von Feinden
- [ ] Laune/Zuneigung (0–100): niedrig = zickig. Je höher, desto leichter lässt es sich führen, reiten usw. Bei sehr hohem Wert kommt es sogar auf Kommando angelaufen.
- [ ] Aufspürung (0-100): wie gut es Schätze aufspürt
- [ ] Sauberkeit (0–100)
- [ ] Hunger (0–100): Überfütterung erhöht das Gewicht und senkt trainierte Stärke/Geschwindigkeit. Längerer Hunger senkt die Laune, akuter Hunger wirkt wie etwas schlechtere Laune.
- [ ] Gewicht (0–100), 50 = ideal
- [ ] Energie (0–100): begrenzt das Training, wird jeden Tag zurückgesetzt

### Merkmale
- [ ] Alter: Fohlen oder Pferd. Beim Fohlen zeigt ein Balken, wie weit es bis ausgewachsen ist. Ausgewachsene Pferde altern nicht mehr.
- [ ] Rasse (ca. 10, unterschiedlich selten)
- [ ] Farbe (ca. 30, unterschiedlich selten)
- [ ] Geschlecht (m/w)
- [ ] Charakterzug (verfressen, schreckhaft, faul, eitel oder Nachteule): unveränderlich, wirkt sich hauptsächlich auf die Emojis aus
- [ ] Name. Kann vergeben und verändert werden

### Fähigkeiten
- [ ] Sprechen in Form von Emojis
- [ ] Können Sachen aufspüren (Blumen, Samen Schätze usw.)
- [ ] Können Ausrüstung tragen (Sattel mit Gepäcktaschen, Lampen)
- [ ] Stammbaum anzeigbar

## 3. Mit Pferden spielen

### Pferde bekommen
- [ ] Finden: Wildpferde in den Gebieten; je besser das Fahrzeug, desto weiter entfernte Gebiete (siehe Gebiete, Fahrzeuge). 
- [ ] Zähmen, als Minispiel: anschleichen, solange das Pferd wegschaut, stehen bleiben, wenn es guckt. Wie schwer das ist, hängt von der Laune des Wildpferds ab.
- [ ] Kaufen: Welche Pferde man kaufen kann, hängt von der Fahrzeugklasse ab.

### Pflegen und trainieren
- [ ] Füttern: beeinflusst den Hunger, über längere Zeit auch das Gewicht
- [ ] Striegeln: erhöht die Sauberkeit
- [ ] Streicheln, Füttern, Reiten (eigentlich alles): erhöht die Laune
- [ ] Reiten und Springen: erhöht Geschwindigkeit und Stärke, das Gewicht nimmt etwas ab
- [ ] Schmücken
- [ ] Aufspürung verbessert sich mit jedem Fund
- [ ] Jobs: Kutschtaxi, Postritt oder Pflügen bringen wenig, aber sicheres Geld und trainieren nebenbei Stärke oder Geschwindigkeit

Zusammenhänge: Sauberkeit und Laune beschleunigen den Trainingsfortschritt. Das Gewicht beeinflusst Geschwindigkeit und Stärke.

### Unterbringung
- Stall: Trainings-Stats bleiben erhalten.
- Weide: Trainings-Stats sinken, je stärker das Pferd, desto weniger.
- Frei auf dem Grundstück: nur für sehr starke Pferde mit hoher Laune; sie verteidigen das Grundstück gegen Tiere.

Weide und freie Haltung verringern die Sauberkeit. Die Plätze sind begrenzt: im Stall durch den gebauten Stall, auf Weide und Grundstück durch deren Größe.

### Züchten
- [ ] Erfordert einen ausgewachsenen Hengst und eine ausgewachsene Stute.
- [ ] Vererbt werden die Gen-Stats der Eltern, mit statistischer Abweichung.
- [ ] Premiumfutter für ein Fohlen kann sein Max-Potenzial etwas erhöhen.
- [ ] Farbgenetik mit versteckten Genen: Jedes Pferd trägt zwei Farbgene, sichtbar ist nur das dominante. So lassen sich seltene Farben gezielt züchten, und der Stammbaum wird zum Werkzeug.
- [ ] Inzucht-Malus: Nachkommen naher Verwandter bekommen schlechtere Gen-Stats. Ein zweiter Grund, in den Stammbaum zu schauen und neue Wildpferde zu holen.

## 4. Geld
Geld ist entscheidend für den Fortschritt, weil man damit Fahrzeuge kauft. Gute Entscheidungen, Glück, Turniererfolge und Spielzeit bringen Geld.

### Einnahmen
- Pferde verkaufen 🥲 (siehe Käufer)
- Turniere
- Jobs mit Pferden (siehe Pflegen und trainieren)
- Maschinen (siehe Hof)
- Bauelemente lassen sich zum Kaufpreis wieder verkaufen

### Ausgaben
- [ ] (Premium-)Futter
- [ ] Samen für Futterpflanzen
- [ ] Bauelemente
- [ ] Pferde
- [ ] Pferde-Verbesserungen (mehr Gepäck)
- [ ] Pferdeanhänger und Fahrzeuge
- [ ] Steuern (siehe Regierungsreformen)

### Käufer
Leute, die angebotene Pferde kaufen, wenn sie wollen. Sie haben mehrere Sprüche, passend zum angebotenen Pferd. Jeder Käufer gewichtet die Stats anders.

- [ ] Reiche Sammlerin: zahlt besonders viel für seltene Farben und Rassen, verlangt hohe Sauberkeit
- [ ] Netter Reithof: zahlt eher wenig, aber mehr für gute Laune. Ein Verkauf verbessert die Laune der übrigen Pferde.
- [ ] Züchter: zahlt besonders viel für Hengste und hohe Geschwindigkeit/Stärke. Ein Verkauf verschlechtert die Laune der übrigen Pferde.
- [ ] Schlachter: zahlt insgesamt gut, besonders viel für hohes Gewicht
- [ ] Bestellungen: Käufer geben Aufträge wie „braune Stute, Geschwindigkeit über 50, bis Tag 20“ und zahlen dafür einen Bonus

### Turniere
Ab und zu gibt es Turniere in verschiedenen Klassen. Es gibt eine Startgebühr, die Gewinnchancen sind vorab sichtbar. Je höher die Fahrzeugklasse, desto lukrativer und schwieriger die Turniere. Für alle ist hohe Laune wichtig, dazu je nach Turnier:

- [ ] Schönheitswettbewerb: Seltenheit von Farbe und Rasse, Sauberkeit
- [ ] Springreiten (Minispiel): Stärke
- [ ] Pferderennen (Minispiel): Geschwindigkeit

## 5. Hof (Baumodus)
Schönes Haus, Stall, Deko usw. erhöhen die Laune und teilweise die Trainingsgeschwindigkeit.

- [ ] Grundstück: Man startet klein und kann Land dazukaufen
- [ ] Haus (verschiedene): nur dekorativ, zum Schlafen/Überspringen der Nacht
- [ ] Stall (verschiedene): bestimmt die Zahl der Stallplätze
- [ ] Weide: frei mit Zaunelementen baubar, braucht ein Tor. Mehrere Weiden sind möglich.
- [ ] Deko (Lampen, Bänke, Brunnen, Wege, Teich, Böden)
- [ ] Maschinen, die Geld bringen, z. B. ein pferdebetriebener Stromgenerator
- [ ] Pflanzen/Getreide als Futter

## 6. Fahrzeuge (Fortschritt)
Man kauft einen Pferdeanhänger. Entscheidend ist das Zugfahrzeug: anfangs Fahrrad, dann Mofa usw. bis zum edlen SUV und am Ende das Flugzeug. Je besser das Fahrzeug, desto weiter entfernte Gebiete kann man besuchen, um seltenere Pferde zu finden oder an exklusiveren Turnieren teilzunehmen.

## 7. Welt
- [ ] Tag/Nacht-Rhythmus
- [ ] Wetter: kann die Sauberkeit von Pferden beeinflussen, die draußen stehen

### Gebiete
- [ ] Sehr groß, mit Natur, Wiesen, Bäumen, Flüssen, Brücken, Häusern usw.
- [ ] Jedes Gebiet hat eine eigene Farbpalette für Boden und Bäume
- [ ] Enthalten wilde Pferde und Schätze zum Aufspüren
- [ ] Das Startgebiet ist ohne Fahrzeug erreichbar, weitere Gebiete erfordern eine höhere Fahrzeugklasse
- [ ] Das Grundstück liegt im Startgebiet und lässt sich auf das ganze Startgebiet erweitern

### Regierungsreformen
Ereignissystem: Alle paar Tage verkündet eine Zeitung eine Reform, die für einige Tage die Regeln ändert.
- [ ] Gefährliche Tiere werden freigelassen: erst Hunde, dann Wölfe, dann Krokodile. Starke Pferde können sich wehren, die anderen sollten in den Stall. Die Tiere können auch Deko zerstören.
- [ ] Pferdesteuer (pro Tag), variiert im Spielverlauf
- [ ] Hafersteuer: Futter wird teurer
- [ ] Stromsubvention: Der Generator bringt doppelt so viel

## 8. Extras
- [ ] Sammelalbum: Jede entdeckte Kombination aus Farbe und Rasse wird eingetragen
- [ ] Pferde mit echten Spielern tauschen, ohne Server/Internet: Wer ein Pferd weggibt, bekommt einen einzigartigen Code mit allen Eigenschaften des Pferdes, danach ist das Pferd weg. Ein anderer Spieler gibt den Code ein und erhält das Pferd.
