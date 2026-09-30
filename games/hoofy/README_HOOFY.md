# Hoofy 🐎 
## Ideen / Konzept / Funktionen

### Kernelemente des Gameplays
- Pferde finden
- Pferde pflegen (trainieren, füttern...)
- Pferde züchten
- Geld verdienen (Pferde verkaufen, Turniere, Maschinen)
- Baumodus

### Pferde Funktionen 

- [ ] Pferde finden 
- [ ] Pferde zähmen
- [ ] Pferde füttern 
- [ ] Pferde striegeln
- [ ] Pferde trainieren 
- [ ] Pferde schmücken
- [ ] Pferde züchten (mit vererbbaren Eigenschaften)
- [ ] Pferde verkaufen 🥲 

### Pferde Stats 
Die Eigenschaften setzen sich zusammen aus Gen-stats und Trainings-Stats. Zusammen ergeben sie die gesamt-Stats, welche entscheidend sind, wie sich das Pferd verhält. Die maximalwerte sind max.-potential-stats. Das heißt es kann nicht unbegrenzt trainiert werden. Für die Vererbung sind nur die Gen-stats relevant. 
Wilde Pferde haben noch keinen Trainingsfortschritt. 
Jede Rasse besitzt Basis-Stats. Die Gen-Stats eines Pferdes basieren hierauf, weichen aber durch eine statistische Funktion mit Zufall von diesem Basiswert ab, das gleiche gilt für die max-potential-stats. 
Beispiel: Pferde der Rasse Mustang haben einen Basis-wert für Geschwindigkeit von 30. Man findet einenwilden Mustang mit der Gen-Geschwindkeit = Gesamt-geschwindigkeit von 40 mit max potial bis 60. Man kann ihn also zämen und dann trainieren bis 60. Wenn man mit ihm züchtet sind aber nur die 40 relavant für das Nachkommen. Nachkommen erben die Stats der Eltern, allerdings auch mit statistischer Abweichung. 


- [ ] Geschwindigkeit (0...100)
- [ ] Stärke (0...100) (beeinflusst Sprunghöhe, Fähigkeit Sachen zu ziehen und zu zertreten, sich gegen Feinde zu wehren)
- [ ] Laune/Zuneigung (0...100) (niedrig = zickig. Je höher, desto einfacher lässt es sich führen, reiten etc. bei sehr hohem Wert kommt es sogar auf Kommando angelaufen)
- [ ] Aufspürung (wie gut es Schätze aufspüren kann)
- [ ] Sauberkeit (0...100)
- [ ] Hunger (0...100) (Überfütterung erhöht Gewicht und Sorgt für Trainingsrückgang bei Stärke/geschwindigkeit. Längere Zeit Hunger verringert Laune-Stat. aktueller Hunger verhält sich ähnlich wie etwas schlechtere Laune)
- [ ] Gewicht (0...100) 50 = ideal
- [ ] Energie (0...100). begrenzt Training, resettet sich am neuen Tag.
- [ ] Alter (Unterscheidung: Fohlen/Pferd. Wenn Fohlen, dann als Slider wie weit bis ausgewachsen. Bei ausgewachsen keine weitere Alterung)
- [ ] Farbe (ca. 30, unterschiedliche Seltenheit)
- [ ] Rasse (ca. 10, unterschiedliche Seltenheit)
- [ ] Geschlecht (m/w) 
- [ ] Charakterzug: (verfressen, schreckhaft, faul, eitel oder Nachteule). Nicht veränderbar, hat hauptsächlich Auswirkungen auf die Emoji


### Pferde Eigenschaften
- [ ] Soll sprechen können in Form von Emojis
- [ ] Sollen coole Sachen aufspüren können (Blumen, Schätze, etc)
- [ ] Können ausrüstung besitzen (Sattel mit Gepäcktaschen, Lampen)
- [ ] Stammbaum anzeigbar

### Pferde trainieren/pflegen
So können die Trainings-stats erhöht werden:
- [ ] Sauberkeit und Laune erhöhen Trainingsfortschritt
- [ ] Streicheln, füttern, reiten (eigentlich alles) erhöht Laune
- [ ] Striegeln erhöht Sauberkeit
- [ ] Reiten und Springen erhöhen Stärke, Gewicht nimmt etwas ab
- [ ] füttern beeinflusst Hunger. 
- [ ] Hunger-Tendenz kann über längeren Zeitraum Gewicht beeinflussen
- [ ] Gewicht beeinflusst Geschwindigkeit und Stärke 
- [ ] Aufspürung wird verbessert, wenn Sachen aufgespürt werden
- [ ] Jobs mit Pferden: Kutschtaxi, Postritt oder Pflügen bringen kleines, sicheres Geld und trainieren nebenbei Stärke oder Geschwindigkeit. 

### Pferde zähmen
Mini-Spiel:
anschleichen, solange das Pferd wegschaut, und stehen bleiben, wenn es guckt. Wie schwer es ist, hängt von der Laune des Wildpferds ab. 


### Pferde Züchten
- Erfordert ausgewachsenes Männchen und Weibchen. S
- Stats sind vererbbar auf Grundlage der Gen-stats aber mit statischen Abweichungen. 
- Einem Fohlen Premiumfutter zu geben kann das max-potential etwas erhöhen. 
- Farbgenetik mit versteckten Genen: Jedes Pferd trägt zwei Farbgene, sichtbar ist nur das dominante. Seltene Farben lassen sich dann gezielt erzüchten, und der Stammbaum wird zum Werkzeug.
- inzucht-Malus: Nachkommen naher Verwandter bekommen schlechtere Gen-Stats. Das ist ein zweiter Grund, in den Stammbaum zu schauen und neue Wildpferde zu holen.


### Geld
- [ ] (Premium-)futter kaufen 
- [ ] Samen für Pflanzen für Futter
- [ ] Bauelemente kaufen 
- [ ] Pferde kaufen 
- [ ] Pferd-Verbesserungen kaufen (mehr Gepäck)
- [ ] Pferde Transporter kaufen (um weiter entfernt nach besseren Pferden zu 
suchen) 
- [ ] Bauelemente können für den Kaufpreis verkauft werden. 

### Händler/Käufer
Leute, die Pferde kaufen können, wenn sie wollen. Sie besitzen mehrere Sätze, die zum angebotenen Pferd passen. Jeder Käufer legt auf verschiedene Stats unterschiedlich Wert. 

- [ ] Reiche Sammlerin: Bezahlt besonders viel für seltene Farben und Rassen, hohe Sauberkeit erforderlich.
- [ ] Netter Reithof: Bezahlt tendenziell wenig aber mehr für gute Laune. Ein Verkauf verbessert die Laune bei den übrigen Pferden
- [ ] Züchter: Bezahlt besonders viel für Männer und hohe Geschwindigkeit/Stärke. Ein Verkauf verschlechtert die Laune bei den übrigen Pferden
- [ ] Schlachter: Bazhlt insgesamt gut, besonders viel für hohes Gewicht.
- [ ] Bestellungen: Käufer geben Aufträge wie „braune Stute, Geschwindigkeit über 50, bis Tag 20" und zahlen dafür einen Bonus. 

### Pferde Kaufen
man kann je nach Fahrzeugklasse auch Pferde kaufen.

### Unterbringung der Pferde
Möglichkeiten:
- Stall
- Weide
- Frei auf dem Grundstück

Stall schont die Trainings-stats.
Weide verringert Trainingsstats in Abhängigkeit der Stärke. je stärker desto geringer der Abzug. wenn sie sehr stark sind und hohe Laune haben  können sie auch frei auf dem Grundstück bleiben und gegen tiere verteidigen.

Der Platz aller 3 Möglichkeiten ist begrenzt durch die auswahl des Stalles und die Größe von Weide und freiem Grundstück.

Weide und frei verringern Sauberkeit.

### Bauelemente 
als Building System um Stall und Weide etc. auszubauen. Es gibt verschiedene Wohnhäuser und Ställe. Schönes Haus, Stall, Deko-Elemente usw. erhöhen Laune und teilweise Trainingsgeschwindigkeit. 

- [ ] Grundstück: Man startet mit einem kleinen Grundstück, kann aber Land dazu kaufen
- [ ] Haus: Nur Dekorativ, zum Schlafen des Spielers/Überspringen der Nacht
- [ ] Stall: Bestimmt Stallplätze 
- [ ] Weide: frei baubar mit Zaunelementen. Benötigt ein Tor. Man kann mehrere Weiden haben. 
- [ ] Diverse dekorative Elemente (Lampen, Bänke, Brunnen, Weg, Teich, Böden)
- [ ] Maschinen, die Geld generieren, wie z.B. ein Pferde betriebener Stromgenerator
- [ ] Pflanzen/Getreide: Für Futter

### Turniere
Ab und zu gibt es Turniere in verschiedenen Klassen, in denen Geld gewonnen werden kann. Es gibt Beitrittsgebür und direkt zu sehende Gewinnchancen. Je höher die Fahrzeugklasse, desto lukrativere und schwierigere Turniere gibt es.
Für alle Tuniere ist eine hohe Laune wichtig aber es gibt je nach Turnier unterschiedliche weitere entscheidene Stats:

- [ ] Schönheitswettbewerb (hier zählt vor allem seltenheit von Farbe und auch Rasse und Sauberkeit)
- [ ] Spring-reiten: Tatsächliches Mini-Game. Hier zählt die Stärke 
- [ ] Pferde-rennen: Mini-game. Hohe Geschwindigkeit


### Pferdetransporter
Man kann einen Pferde Anhänger kaufen. Wichtig für den Fortschritt ist das Zugkraftfahrzeug. Am Anfang Fahrrad, dann Mofa usw. bis zum edlen SUV und am Ende Flugzeug. Je besser das Fahrzeug desto weiter entfernte Gebiete kann man besuchen um seltenere Pferde zu finden oder an exklusiveren Turnieren teilzunehmen.  

### Regierungsreformen
Ereignissystem:
- [ ] gefährliche Tiere werden freigelassen: Zuerst Hunde, dann Wölfe, dann Krokodile. Starke Pferde können gegen diese Verteidigen, oder Pferde sollten in den Stall. Tiere können auch dekorative Elemente zerstören.
- [ ] Pferde Steuer (pro Tag) variiert im Spielverlauf
- [ ] Alle paar Tage verkündet eine Zeitung eine Reform, die für einige Tage die Regeln ändert. 
- [ ] Hafersteuer: Futter wird teurer.
- [ ] Stromsubvention: Der Generator bringt doppelt so viel.

### Allgemeines 

* Nur privat - Lizenzprobleme ignorieren 
* Keine FSK Beschränkung 😈
* Für Open-086 (ESP32 S3, Retro-Go)
* Pferde mit echten Spielern tauschen: Wenn man ein Pferd weggibt, wird ein einzigartiger Code für das Pferd mit allen Eigenschaften generiert, danach ist das Pferd weg. Ein anderer Spieler kann diesen Code eingeben und erhält dann dieses Pferd. Ohne Server/internet.
* Einfache Grafik?
* Realismus: 3/10??
* Stil: eher quatschig, lustig, aber auch beruhigend
* Turniere?
* richtige Story??
* NPCs ja/nein?
* Geld: Gute Entscheidungen, Glück, Erfolg in Turnieren und Spielzeit erhöhen Geld. Geld ist entscheidend für den Spielfortschritt, da hierdurch Fahrzeuge erworben werden können.
* Tag/Nacht Rhythmus.
* Wetter: Kann Sauberkeit beeinflussen, bei Pferden die draußen stehen.
* Sammelalbum: Jede entdeckte Kombination aus Farbe und Rasse wird eingetragen

### Story/Background

Story: wir haben 2040. aus dem KI Boom wurde eine Wirtschaftskriese, weil viele Autombilhersteller pleite gegangen sind. Die Folge: Fahrzeuge sind sehr teuer geworden, aber dafür werden Pferde als Fortbewegungsmittel wieder interessant. Gut für dich, denn du bist ein Pferdezüchter.
Auch Benzin und Strom sind teuer, deswegen kann man z.B. einen Stromgenerator bauen, der durch Pferde angetrieben ist.
Die Bevölkerung ist sehr unzufrieden und hat deswegen eine radikale Regierung gewählt. Leider hat sich diese als nicht kompetent herausgestellt. Einige Reformen sind gut, andere eher verrückt. Diese könnten das Spiel beeinflussen, wie z.B. das auf einmal Wölfe frei herumlaufen.