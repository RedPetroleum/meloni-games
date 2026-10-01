# Hoofy 🐎
Ideen, Konzept, Funktionen. Konkrete Werte: [KATALOG.md](KATALOG.md)

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
* Grafik: 3/4-Perspektive mit Sprites, wie Ausgebüxt
* Technik: Gebiete aus festem Zufalls-Seed erzeugen, nur Änderungen speichern. Erst ein kleines Gebiet, später größer.

## 2. Das Pferd

### Werte
Jeder Wert setzt sich aus Gen-Stat und Trainings-Stat zusammen. Die Summe (Gesamt-Stat) bestimmt, wie sich das Pferd verhält. Nach oben begrenzt ist sie durch das Max-Potenzial, unbegrenzt trainieren geht also nicht. Vererbt werden nur die Gen-Stats. Wilde Pferde haben noch keinen Trainingsfortschritt.
Jede Rasse hat Basis-Stats. Gen-Stats und Max-Potenzial eines Pferdes weichen davon zufällig (statistisch verteilt) ab.
Beispiel: Mustangs haben eine Basis-Geschwindigkeit von 30. Man findet einen wilden Mustang mit Gen-Geschwindigkeit 40 (= Gesamt-Geschwindigkeit, da untrainiert) und Max-Potenzial 60. Gezähmt lässt er sich bis 60 trainieren, für Nachkommen zählen aber nur die 40.

- [ ] Geschwindigkeit (0–100)
- [ ] Stärke (0–100): Sprunghöhe, Ziehen und Zertreten von Sachen, Abwehr von Feinden
- [ ] Bindung (0–100): niedrig = zickig. Je höher, desto leichter lässt es sich führen, reiten usw. Bei sehr hohem Wert folgt es ohne Leine und kommt auf Kommando.
- [ ] Aufspürung (0–100): wie gut es Schätze aufspürt
- [ ] Ausdauer (50–100): legt die tägliche Energie fest, zählt bei Turnieren und für den Züchter
- [ ] Sauberkeit (0–100)
- [ ] Hunger (0–100): Überfütterung erhöht das Gewicht und senkt trainierte Stärke/Geschwindigkeit. Längerer Hunger senkt die Bindung, akuter Hunger wirkt wie etwas schlechtere Bindung.
- [ ] Gewicht (0–100), 50 = ideal
- [ ] Energie (0 bis Ausdauer): begrenzt das Training, wird jeden Tag auf die Ausdauer zurückgesetzt

### Merkmale
- [ ] Alter: Fohlen oder Pferd. Beim Fohlen zeigt ein Balken, wie weit es bis ausgewachsen ist. Ausgewachsene Pferde altern nicht mehr.
- [ ] Rasse (12, unterschiedlich selten)
- [ ] Farbe (ca. 30, unterschiedlich selten, je Rasse nur bestimmte)
- [ ] Geschlecht (m/w)
- [ ] Charakterzug (verfressen, schreckhaft, faul, eitel oder Nachteule): unveränderlich, wirkt sich hauptsächlich auf die Emojis aus
- [ ] Name: frei vergeb- und änderbar

### Fähigkeiten
- [ ] Sprechen in Form von Emojis (Signalisieren Hunger, mangelnde Sauberkeit, Charakterzug, etc.)
- [ ] Können Sachen aufspüren (Blumen, Samen, Schätze usw.): In der Nähe eines versteckten Schatzes erscheint ein Emoji. Lässt man das Pferd frei gehen, läuft es hin. Je höher die Aufspürung, desto öfter und aus größerem Abstand.
- [ ] Können Ausrüstung tragen (Sattel, Satteltaschen, Lampen)
- [ ] Sättel: verschiedene, erhöhen die Geschwindigkeit. Reiten geht auch ohne.
- [ ] Stammbaum anzeigbar

## 3. Mit Pferden spielen

### Pferde bekommen
- [ ] Finden: Wildpferde in den Gebieten; je besser das Fahrzeug, desto weiter entfernte Gebiete (siehe Gebiete, Fahrzeuge)
- [ ] Zähmen, als Minispiel: anschleichen, solange das Pferd wegschaut, stehen bleiben, wenn es guckt. Wie schwer das ist, hängt von der Bindung des Wildpferds ab.
- [ ] Heimbringen: aus fremden Gebieten zum Fahrzeug, im Startgebiet auf die Weide oder in den Stall
- [ ] Leine: Frisch gezähmte Pferde werden an der Leine geführt (zu Fuß oder reitend). Wegen geringer Bindung reißen sie ab und zu aus, eher beim Sprinten oder Reiten.
- [ ] Zu Fuß kann zusätzlich ein Pferd mit hoher Bindung ohne Leine folgen
- [ ] Kaufen: Welche Pferde man kaufen kann, hängt von der Fahrzeugklasse ab.

### Pflegen und trainieren
- [ ] Füttern: beeinflusst den Hunger, über längere Zeit auch das Gewicht
- [ ] Striegeln: erhöht die Sauberkeit
- [ ] Streicheln, Füttern, Reiten (eigentlich alles): erhöht die Bindung
- [ ] Reiten und Springen: erhöht Geschwindigkeit und Stärke, das Gewicht nimmt etwas ab
- [ ] Schmücken
- [ ] Aufspürung verbessert sich mit jedem Fund
- [ ] Jobs: Kutschtaxi, Postritt oder Pflügen bringen wenig, aber sicheres Geld und trainieren nebenbei Stärke oder Geschwindigkeit

Zusammenhänge: Sauberkeit und Bindung beschleunigen den Trainingsfortschritt. Das Gewicht beeinflusst Geschwindigkeit und Stärke.

### Unterbringung
- Stall: Trainings-Stats bleiben erhalten.
- Weide: Trainings-Stats sinken, je stärker das Pferd, desto weniger.
- Frei auf dem Grundstück: nur für sehr starke Pferde mit hoher Bindung; sie verteidigen das Grundstück gegen Tiere.

Weide und freie Haltung verringern die Sauberkeit. Die Plätze sind begrenzt: im Stall durch den gebauten Stall, auf Weide und Grundstück durch deren Größe.

### Züchten
- [ ] Erfordert einen ausgewachsenen Hengst und eine ausgewachsene Stute.
- [ ] Vererbt werden die Gen-Stats der Eltern, mit statistischer Abweichung.
- [ ] Premiumfutter für ein Fohlen kann sein Max-Potenzial etwas erhöhen.
- [ ] Farbgenetik: Jedes Pferd hat eine sichtbare und eine versteckte Farbe. Das Fohlen bekommt eine der vier Farben der Eltern, die sichtbaren öfter. So lassen sich seltene Farben gezielt züchten.
- [ ] Rassen mischen: Das Fohlen hat die Rasse von Vater oder Mutter (50:50). Jede Kombination aus Rasse und Farbe ist züchtbar, auch wenn sie in der Wildnis nicht vorkommt.
- [ ] Inzucht-Malus: Nachkommen naher Verwandter bekommen schlechtere Gen-Stats. Ein zweiter Grund, in den Stammbaum zu schauen und neue Wildpferde zu holen.

## 4. Geld
Geld ist entscheidend für den Fortschritt, weil man damit Fahrzeuge kauft. Gute Entscheidungen, Glück, Turniererfolge und Spielzeit bringen Geld.

### Einnahmen
- Pferde verkaufen 🥲 (siehe Käufer)
- Turniere
- Jobs mit Pferden (siehe Pflegen und trainieren)
- Maschinen (siehe Hof)
- Bauelemente lassen sich zum halben Kaufpreis wieder verkaufen

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
- [ ] Netter Reithof: zahlt eher wenig, aber mehr für hohe Bindung. Ein Verkauf verbessert die Bindung der übrigen Pferde.
- [ ] Züchter: zahlt besonders viel für Hengste und hohe Geschwindigkeit/Stärke. Ein Verkauf verschlechtert die Bindung der übrigen Pferde.
- [ ] Schlachter: zahlt insgesamt gut, besonders viel für hohes Gewicht
- [ ] Bestellungen: Käufer geben Aufträge wie „braune Stute, Geschwindigkeit über 50, bis Tag 20“ und zahlen dafür einen Bonus

### Turniere
Es gibt Turniere in verschiedenen Wettbewerben. Es gibt eine Startgebühr, die Gewinnchancen sind vorab sichtbar. Alle paar Tage verändern sich die Turniere (Teilnehmer, Chancen). Man kann jederzeit an einem Turnier teilnehmen, danach ist dieser Wettbewerb bis zur nächsten Runde weg, die anderen bleiben offen. Je höher die Fahrzeugklasse, desto lukrativer und schwieriger die Turniere. Für alle ist hohe Bindung wichtig, dazu je nach Wettbewerb:

- [ ] Schönheitswettbewerb: Seltenheit von Farbe und Rasse, Sauberkeit
- [ ] Springreiten (Minispiel): Stärke, Ausdauer
- [ ] Pferderennen (Minispiel): Geschwindigkeit, Ausdauer

## 5. Hof (Baumodus)
Schönes Haus, Stall, Deko usw. erhöhen die Bindung und teilweise die Trainingsgeschwindigkeit.

- [ ] Grundstück: Man startet klein und kann Land dazukaufen
- [ ] Haus (verschiedene): nur dekorativ, zum Schlafen/Überspringen der Nacht
- [ ] Stall (verschiedene): bestimmt die Zahl der Stallplätze
- [ ] Weide: frei mit Zaunelementen baubar, braucht ein Tor. Mehrere Weiden sind möglich.
- [ ] Garage: nötig für ein Fahrzeug
- [ ] Deko (Lampen, Bänke, Brunnen, Wege, Teich, Böden)
- [ ] Maschinen, die Geld bringen, z. B. ein pferdebetriebener Stromgenerator
- [ ] Beete, Felder und Obstbäume für Futter (siehe Futteranbau)

### Futteranbau
- [ ] Samen einmal kaufen oder finden: Die Pflanze trägt danach unbegrenzt
- [ ] Ertrag je Pflanze verschieden: Karotte 1, Apfelbaum 3 usw.
- [ ] Seltene Pflanzen mit besonderer Wirkung erst in weiter entfernten Gebieten
- [ ] Geerntetes kommt ins Hausinventar

## 6. Fahrzeuge (Fortschritt)
Bestehend aus Pferdeanhänger und Zugfahrzeug.
- [ ] Pferdeanhänger: 1–4 Plätze, unabhängig vom Zugfahrzeug aufrüstbar
- [ ] Zugfahrzeug ist entscheidend: anfangs Fahrrad, dann Mofa usw. bis zum edlen SUV und am Ende das Flugzeug. Je besser das Fahrzeug, desto weiter entfernte Gebiete kann man besuchen (teleportieren), um bessere Pferde zu finden oder an exklusiveren Turnieren teilzunehmen.
- [ ] Fahrtkosten: gering, je nach Entfernung und Fahrzeugstufe
- [ ] Fundstücke: Satteltaschen fassen 1–4, das Fahrzeug unbegrenzt. Ist das Fahrzeug zurück im Startgebiet oder das Pferd auf dem Grundstück, landen sie im Hausinventar.

## 7. Welt
- [ ] Tag/Nacht-Rhythmus
- [ ] Wetter: kann die Sauberkeit von Pferden beeinflussen, die draußen stehen

### Gebiete
- [ ] Sehr groß, mit Natur, Wiesen, Bäumen, Flüssen, Brücken, Häusern usw.
- [ ] Lassen sich zu Fuß oder (besser) reitend erkunden
- [ ] Jedes Gebiet hat eine eigene Farbpalette für Boden und Bäume
- [ ] Enthalten wilde Pferde und Schätze zum Aufspüren
- [ ] Je weiter entfernt, desto häufiger seltene Rassen und Farben, hohe Gen-Stats und gute Schätze
- [ ] Wildpferde wechseln nach einigen Tagen (alte verschwinden, neue kommen)
- [ ] Das Startgebiet ist ohne Fahrzeug erreichbar, weitere Gebiete erfordern eine höhere Fahrzeugklasse
- [ ] Das Grundstück liegt im Startgebiet und lässt sich auf das ganze Startgebiet erweitern

### Karte
- [ ] Zeigt das aktuelle Gebiet (nur Erkundetes)
- [ ] Zeigt Spieler mit Blickrichtung, gezähmte Pferde, Haus oder Fahrzeug
- [ ] Nur bei Bedarf aufrufbar, nicht dauerhaft sichtbar

### Regierungsreformen
Ereignissystem: Alle paar Tage verkündet eine Zeitung eine Reform, die für einige Tage die Regeln ändert.
- [ ] Gefährliche Tiere werden freigelassen: erst Hunde, dann Wölfe (ab Gebiet 3), dann Krokodile (ab Canyon). Starke Pferde können sich wehren, die anderen sollten in den Stall. Die Tiere können auch Deko zerstören.
- [ ] Pferdesteuer (pro Tag), variiert im Spielverlauf
- [ ] Hafersteuer: Futter wird teurer
- [ ] Stromsubvention: Der Generator bringt doppelt so viel

## 8. Extras
- [ ] Sammelalbum: Jede entdeckte Kombination aus Farbe und Rasse wird eingetragen
- [ ] Pferde mit echten Spielern tauschen, ohne Server/Internet: Wer ein Pferd weggibt, bekommt einen einzigartigen Code mit allen Eigenschaften des Pferdes, danach ist das Pferd weg. Ein anderer Spieler gibt den Code ein und erhält das Pferd.
