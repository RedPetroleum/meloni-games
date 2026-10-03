# Hoofy – Katalog
Konkrete Werte zu [README_HOOFY.md](README_HOOFY.md). 

## 1. Zeit

| Wert | Vorschlag |
|---|---|
| 1 Spieltag | 5 min echt (3 min Tag, 2 min Nacht) |
| Schlafen im Haus | überspringt die Nacht |
| Energie | = Ausdauer (50–100), Reset beim Aufwachen |
| Fohlen → ausgewachsen | 4 Tage |
| Trächtigkeit | 2 Tage, danach 3 Tage Pause für die Stute |
| Wildpferde wechseln | alle 3 Tage 1–2 pro Gebiet |
| Speichern | beim Schlafen, Gebietswechsel und Beenden |

## 2. Stats

### Gen, Training, Potenzial
Gilt für **Geschwindigkeit, Stärke, Aufspürung, Ausdauer**. Alle anderen Werte sind Zustände ohne Gene.

| Wert | Formel |
|---|---|
| Gen-Stat (Wildpferd) | Rassen-Basis ± Zufall (Normalverteilung, σ = 8), 1–100 (Ausdauer 50–100) |
| Max-Potenzial | Gen-Stat + Rassen-Spanne ± Zufall (σ = 5), höchstens 100 |
| Gen-Stat (Fohlen) | Mittel der Eltern ± Zufall (σ = 6), dann Inzucht-Malus |
| Trainingszuwachs | Basis × Trainingstempo 3 × Bonus aus Sauberkeit und Bindung (bis ×1,5), gleichmäßig bis zum Max-Potenzial (Bindung zählt nicht dazu) |
| Trainingsgrenze | je Stat und Tag bis 10 voll, darüber ein Drittel, höchstens 15 (Drachenfrucht: Grenzen doppelt) |

Ausdauer wird durch lange Ritte und Jobs trainiert und legt die tägliche Energie fest.

### Zustände

| Wert | Start | Pro Tag | Wirkung |
|---|---|---|---|
| Bindung | Rasse ± Charakter | +2 Streicheln (zweites Mal am Tag +1), +1 je Fütterung (egal welches Futter, höchstens +5 am Tag), +1 je Striegeln, solange Sauberkeit unter 100, +1 je Min. Reiten; −3 bei Hunger > 70, −2 bei Sauberkeit < 30 | < 20 zickig (verweigert Reiten zu 50 %), ≥ 40 reitbar, ≥ 100 folgt ohne Leine, ≥ 90 kommt auf Pfiff |
| Hunger | 30 | +25 (verfressen +35) | > 70: Bindung sinkt; < 10 über 2 Tage: überfüttert |
| Gewicht | 50 | überfüttert +3, Hunger > 70 −3 | Abweichung > 15 von 50 senkt Tempo und Stärke um 1 % je Punkt darüber |
| Sauberkeit | 60 | Stall −5, Weide −10, frei −20, Regen −15 | < 30: Bindung sinkt |
| Energie | = Ausdauer | Reset auf Ausdauer | Reiten 1 je 10 s, Sprung 5, Job 30 |

### Unterbringung

| Ort | Verlust Trainings-Stats pro Tag | Sauberkeit |
|---|---|---|
| Stall | 0 | −5 |
| Weide | 2 × (1 − Stärke/100) | −10 |
| Frei | 2 × (1 − Stärke/100), nur ab Stärke 60 und Bindung 70 | −20 |

### Leine
Ausreiß-Chance je 10 s: (100 − Bindung) / 10 %. Sprinten ×2, Reiten ×3.
Beispiel: frisch gezähmt, Bindung 10 → gehend 9 %, reitend 27 % je 10 s.

## 3. Rassen
Vier Körperformen (Pony, Warmblut, Kaltblut, Einhorn), Farben per Recolor. Jedes Gebiet bringt neue Rassen, die Werte steigen mit dem Gebiet.

| Rasse | Körper | ab Gebiet | Tempo | Stärke | Spür | Ausdauer | Bindung Start | Spanne | Grundwert |
|---|---|---|---|---|---|---|---|---|---|
| Shetlandpony | Pony | 1 | 15 | 35 | 45 | 70 | 30 | +20 | 200 |
| Haflinger | Pony | 1 | 30 | 40 | 35 | 75 | 35 | +25 | 250 |
| Noriker | Kaltblut | 1 | 20 | 55 | 25 | 70 | 35 | +25 | 275 |
| Mustang | Warmblut | 2 | 40 | 35 | 40 | 85 | 10 | +30 | 400 |
| Schwarzwälder Fuchs | Kaltblut | 2 | 30 | 60 | 30 | 75 | 30 | +30 | 500 |
| Quarter Horse | Warmblut | 3 | 55 | 40 | 30 | 65 | 25 | +30 | 800 |
| Friese | Warmblut | 3 | 45 | 50 | 30 | 70 | 25 | +35 | 1 200 |
| Fjordpferd | Pony | 3 | 40 | 50 | 45 | 85 | 40 | +30 | 1 000 |
| Andalusier | Warmblut | 4 | 60 | 45 | 35 | 75 | 35 | +40 | 2 500 |
| Achal-Tekkiner | Warmblut | 4 | 65 | 40 | 40 | 90 | 15 | +40 | 3 000 |
| Araber | Warmblut | 5 | 75 | 35 | 50 | 95 | 15 | +40 | 5 000 |
| Einhorn | Einhorn | 6 | 80 | 50 | 70 | 90 | 10 | +45 | 10 000 |

Spanne: so weit lässt sich ein Pferd über seine Gen-Stats hinaus trainieren (Max-Potenzial = Gen-Stat + Spanne ± σ 5, gilt für alle vier Gen-Werte).

## 4. Farben
Fell- und Mähnenfarbe per Recolor, Muster (Schecke, Tupfen, Streifen) als Overlay.

| Stufe | Anteil (Gebiet 1) | Wertfaktor | Farben |
|---|---|---|---|
| häufig | 40 % | ×1 | Brauner, Fuchs, Dunkelbrauner, Hellfuchs, Rappe, Grauschimmel |
| gewöhnlich | 30 % | ×1,2 | Falbe, Isabell, Schimmel, Dunkelfuchs, Mausfalbe, Rotschimmel, Braunschecke |
| selten | 18 % | ×1,5 | Palomino, Rappschecke, Fuchsschecke, Apfelschimmel, Fliegenschimmel, Silberrappe, Windfarben |
| sehr selten | 9 % | ×2 | Tigerschecke, Cremello, Perlino, Champagner, Rosa, Mintgrün |
| legendär | 3 % | ×3 | Gold, Regenbogen, Lila, Zebra |

Pro Gebietsstufe verschieben sich 3 Prozentpunkte von „häufig“ zu den seltenen Stufen.

### Farben je Rasse
Gilt nur für Wildpferde, gezüchtet ist jede Kombination möglich. Gewürfelt wird nach den Stufenanteilen oben; hat eine Rasse in einer Stufe keine Farbe, verteilt sich deren Anteil auf die übrigen Stufen.

| Rasse | häufig | gewöhnlich | selten | sehr selten | legendär |
|---|---|---|---|---|---|
| Shetlandpony | Brauner, Fuchs, Dunkelbrauner, Rappe, Grauschimmel | Isabell, Schimmel, Rotschimmel, Braunschecke | Palomino, Rappschecke, Fuchsschecke, Silberrappe, Windfarben | Cremello, Rosa | Regenbogen |
| Haflinger | Fuchs, Hellfuchs | Dunkelfuchs | – | Champagner | Gold |
| Noriker | Brauner, Dunkelbrauner, Fuchs, Rappe | Schimmel, Rotschimmel, Braunschecke | Rappschecke, Apfelschimmel | Tigerschecke | Zebra |
| Mustang | Brauner, Fuchs, Dunkelbrauner, Rappe, Grauschimmel | Falbe, Isabell, Mausfalbe, Rotschimmel, Braunschecke | Palomino, Rappschecke, Fuchsschecke | Tigerschecke, Cremello, Perlino | Zebra |
| Schwarzwälder Fuchs | Fuchs, Hellfuchs | Dunkelfuchs | Windfarben | Champagner | Gold |
| Quarter Horse | Brauner, Fuchs, Dunkelbrauner, Rappe, Grauschimmel | Falbe, Isabell, Mausfalbe, Dunkelfuchs, Rotschimmel | Palomino | Cremello, Perlino, Champagner | Gold |
| Friese | Rappe | – | – | Mintgrün | Lila |
| Fjordpferd | – | Falbe, Mausfalbe | – | Cremello | Zebra |
| Andalusier | Brauner, Rappe, Grauschimmel | Schimmel, Isabell | Palomino, Apfelschimmel | Cremello, Perlino | Gold |
| Achal-Tekkiner | Brauner, Fuchs, Rappe, Grauschimmel | Falbe, Isabell, Dunkelfuchs | Palomino | Cremello, Perlino, Champagner | Gold |
| Araber | Brauner, Fuchs, Rappe, Grauschimmel | Schimmel, Dunkelfuchs, Rotschimmel | Fliegenschimmel, Apfelschimmel | Rosa | Gold |
| Einhorn | – | Schimmel | Apfelschimmel | Cremello, Perlino, Rosa, Mintgrün | Gold, Regenbogen, Lila |

**Rasse des Fohlens:** 50 % Vater, 50 % Mutter.
**Farbe:** Jedes Pferd hat eine sichtbare und eine versteckte Farbe (in der Pferde-Info angezeigt). Das Fohlen bekommt:

| Farbe | Chance |
|---|---|
| sichtbare vom Vater | 35 % |
| versteckte vom Vater | 15 % |
| sichtbare von der Mutter | 35 % |
| versteckte von der Mutter | 15 % |

Umsetzung: Von jedem Elternteil wird eine Farbe gezogen (70 % sichtbar, 30 % versteckt), eine davon zeigt das Fohlen (50:50), die andere trägt es versteckt. 1 % Mutation zu einer Farbe der nächsten Stufe.
**Wildpferd:** sichtbare Farbe nach Matrix, versteckte zufällig aus der Matrix, gleich selten oder seltener.
**Inzucht:** Eltern/Geschwister −15 % Gen-Stats, Halbgeschwister/Großeltern −8 %, Cousins −3 %.

## 5. Charakterzüge
Hauptsächlich Emojis, dazu je ein kleiner Effekt.

| Zug | Emoji-Thema | Effekt |
|---|---|---|
| verfressen | 🥕🍎 | Hunger +35 statt +25 pro Tag |
| schreckhaft | 😱 | Ausreiß-Chance ×1,5, flieht vor Tieren |
| faul | 😴 | Trainingszuwachs −20 % |
| eitel | 💅✨ | Sauberkeit wirkt doppelt auf Bindung |
| Nachteule | 🦉🌙 | nachts +20 Energie, morgens −10 |

## 6. Pferdewert
**Leistung L** = (((Tempo/100)^1,5 + (Stärke/100)^1,5 + (Spür/100)^1,5 + (Ausdauer/100)^1,5 + 0,5 × (Bindung/100)^1,5) / 4,5)^(1/1,5)
**Leistungsfaktor** = max(0,3; 1 + 1,66 × (L / L_Rasse − 1)), L_Rasse = L eines wilden Durchschnittspferds der Rasse (Stats und Bindung wie in §3). Gut und voll trainiert ≈ 3 × schlecht und untrainiert.
**Stammbaum** = +5 % je bekanntem Elternteil, +3 % je Großelternteil, +2 % je Urgroßelternteil (höchstens +38 %)
**Wert** = Grundwert × Farbfaktor × Leistungsfaktor × Alter (Fohlen ×0,6) × (1 + Stammbaum)
Kaufen beim Händler: Wert × 1,5.

| Käufer | Zahlt | Bedingung / Folge |
|---|---|---|
| Reiche Sammlerin | Wert (neutral) × (1 + (Farbfaktor − 1) × 0,15) × Laune 0,9–1,1 (einmal pro Tag gewürfelt) | Sauberkeit über 90, Farbe ab gewöhnlich |
| Netter Reithof | Wert × (0,6 + (Bindung − 70)/100) | Bindung über 70, Sauberkeit über 50, Hunger unter 30 |
| Züchter | Wert × (1 + Stammbaum %/100), Stute ×1,05, Hengst ×0,95 | Bindung über 50, Sauberkeit über 50 |
| Schlachter | Wert (neutral) × (1 + (Gewicht − 50)/20) × (0,9 + Stärke/400) | Gewicht über 50; übrige Pferde −20 Bindung |
| Bestellung | Wert × 1,5 | alle 3 Tage eine, Frist 5–10 Tage |

Wert (neutral): Wert mit der Start-Bindung der Rasse statt der eigenen Bindung. Tendenz: Reithof zahlt zu wenig, Züchter etwa den Wert, Sammlerin je nach Farbe zu wenig oder zu viel, Schlachter zu viel.
Pro Tag kommt ein zufälliger Käufer vorbei, der Pferdemarkt im Ort ist immer offen.

## 7. Futter und Anbau

### Kaufen

| Artikel | Preis | Wirkung |
|---|---|---|
| Heu | 5 | Hunger −30 |
| Hafer | 12 | Hunger −40, Energie +15 |
| Karotte | 3 | Bindung +3, Hunger −5 |
| Premiumfutter | 60 | Hunger −40; Fohlen: Max-Potenzial +2 (bis +10 insgesamt) |
| Bürste | 20 (einmalig) | Striegeln: Sauberkeit +40 |
| Hacke | 100 (einmalig) | Beete anlegen |

### Anbau
Samen kaufen (beliebig oft) oder finden: Jedes Pflanzen verbraucht einen Samen, die Pflanze trägt danach unbegrenzt. Beete kosten 0 je Kachel (Baumodus), anlegen braucht eine Hacke. Der Apfelbaum wächst ohne Beet auf Gras. Geerntetes kommt ins Hausinventar.

| Pflanze | Samen | ab Gebiet | Platz | reif nach / dann alle | Ertrag | Wirkung je Stück |
|---|---|---|---|---|---|---|
| Gras (Heu) | 10 | 1 | 1 Kachel | 3 / 3 Tage | 1 Heu | Hunger −30 |
| Karotte | 15 | 1 | 1 Kachel | 2 / 2 Tage | 1 | Hunger −5, Bindung +3 |
| Apfelbaum | 40 | 1 | 2×2 | 4 / 3 Tage | 3 | Hunger −8, Bindung +4 |
| Hafer | 25 | 2 | 1 Kachel | 3 / 3 Tage | 2 | Hunger −40, Energie +15 |
| Sonnenblume | 30 | 2 | 1 Kachel | 3 / 3 Tage | 1 (Kerne) | Hunger −10, Sauberkeit +10 (Fellglanz); Deko, Schönheit +2 |
| Minze | 30 | 3 | 1 Kachel | 2 / 2 Tage | 2 | Bindung +2 (eitel ×2) |
| Zuckerrübe | 40 | 3 | 1 Kachel | 4 / 4 Tage | 1 | Hunger −20, Energie +25 |
| Luzerne | 50 | 4 | 1 Kachel | 3 / 3 Tage | 2 | Hunger −35, Gewicht +2 (gegen Untergewicht) |
| Drachenfrucht | 300 | 5 | 1 Kachel | 6 / 5 Tage | 1 | Hunger −15, Training ×2 für einen Tag |
| Goldene Karotte | 1 500 | 6 | 1 Kachel | 7 / 7 Tage | 1 | Fohlen: Max-Potenzial +2 (wie Premiumfutter) |

## 8. Ausrüstung und Schmuck
Reiten geht auch ohne Sattel, dann ohne Tempo-Bonus und ohne Satteltaschen. Der Sattel-Bonus zählt über das Max-Potenzial hinaus.

| Artikel | Preis | Wirkung |
|---|---|---|
| Einfacher Sattel | 150 | Tempo +5, Satteltaschen möglich |
| Sportsattel | 800 | Tempo +10 |
| Rennsattel | 3 000 | Tempo +15 |
| Goldsattel | 12 000 | Tempo +20, Schönheit +20 |
| Satteltaschen S / M / L | 100 / 400 / 1 200 | 1 / 2 / 4 Plätze für Fundstücke |
| Sattellampe | 150 | Sicht nachts |
| Mähnenschleife | 150 | Schönheit +5 |
| Blumenkranz | 300 | Schönheit +10 |
| Glitzerdecke | 1 200 | Schönheit +15 |
| Goldhufeisen | 4 000 | Schönheit +30 |

## 9. Bauelemente
Hof-Schönheit = Summe der Deko-Punkte. Ab 50 / 150 / 400 bekommen alle Pferde +1 / +2 / +3 Bindung pro Tag.
Abreißen bringt 100 % des Preises zurück.

| Element | Preis | Wirkung |
|---|---|---|
| Land (10×10 Kacheln) | 500, jedes weitere +250 | Grundstück erweitern |
| Wohnwagen | Start | schlafen |
| Häuschen / Villa | 1 000 / 8 000 | schlafen, Schönheit +20 / +100 |
| Stall S / M / L / XL | 300 / 900 / 2 500 / 6 000 | 2 / 4 / 8 / 12 Plätze, 1 / 2 / 3 / 4 Bindung pro Tag |
| Zaun (je Kachel) / Tor | 5 / 30 | Weide |
| Schuppen / Garage / Hangar | 300 / 3 000 / 15 000 | Fahrrad + Mofa / Kleinwagen + SUV / Flugzeug |
| Göpel-Generator | 1 500 | 40 Geld pro Tag und angeschirrtem Pferd (Stärke ≥ 40, 40 Energie) |
| Heuraufe | 600 | füttert jeden Morgen alle Pferde auf dem Hof mit Hunger über 40, Vorrat 20 Heu (selbst befüllen) |
| Kratzbürste | 400 | Sauberkeit +20 pro Tag für alle Pferde auf dem Hof |
| Stallburschenhütte | 2 500 | Stallbursche streichelt und striegelt jeden Morgen alle Pferde auf dem Hof (Bindung +2, Sauberkeit +40), Lohn 15 pro Tag |
| Beet (je Kachel) | 0 | Pflanzen anbauen (siehe Anbau), braucht eine Hacke |
| Bank / Lampe / Blumenkübel | 40 / 60 / 20 | Schönheit +3 / +4 / +2 |
| Weg / Boden (je Kachel) | 5 | Schönheit +0,5 |
| Brunnen / Teich / Statue | 400 / 600 / 1 500 | Schönheit +25 / +35 / +80 |
| Baum / Busch / Hecke / Stein | 20 / 5 / 10 / 5 | Schönheit +2 / +0,5 / +1 / +0 |

## 10. Fahrzeuge und Gebiete

| Zugfahrzeug | Preis | Gebiete bis | Fahrtkosten je Gebiet Entfernung |
|---|---|---|---|
| zu Fuß | – | 1 | – |
| Fahrrad | 500 | 2 | 0 |
| Mofa | 4 000 | 3 | 5 |
| Kleinwagen | 12 000 | 4 | 10 |
| SUV | 30 000 | 5 | 20 |
| Flugzeug | 70 000 | 6 | 50 |

| Anhänger | 1 Platz | 2 Plätze | 3 Plätze | 4 Plätze |
|---|---|---|---|---|
| Preis | 400 | 1 500 | 4 000 | 8 000 |

Das Fahrzeug fasst unbegrenzt viele Fundstücke.

| Gebiet | Palette | Größe (Kacheln) | Wildpferde gleichzeitig | Neue Rassen |
|---|---|---|---|---|
| 1 Heimattal | sattgrün | 96 × 80 | 4 | Shetlandpony, Haflinger, Noriker |
| 2 Birkenwald | dunkelgrün | 112 × 80 | 5 | Mustang, Schwarzwälder Fuchs |
| 3 Flussauen | blaugrün | 112 × 96 | 6 | Quarter Horse, Friese, Fjordpferd |
| 4 Steppe | gelb | 128 × 96 | 6 | Andalusier, Achal-Tekkiner |
| 5 Canyon | rot-orange | 128 × 112 | 7 | Araber |
| 6 Nebelinsel | violett | 112 × 96 | 5 | Einhorn |

Rassen früherer Gebiete kommen weiter vor, nur seltener. Gezähmte Wildpferde wachsen erst beim nächsten Wechsel nach (§1), auch nach Reisen und Laden.

Größe: Kachel 16 px, Gebiete aus Blöcken zu 16 × 16 Kacheln (Heimattal ≈ 25 Bildschirme, Ausgebüxt Level 2 ≈ 5). Einmal quer durchreiten ≈ 10–15 s. Etwa alle 1–2 Bildschirme etwas zu entdecken (Pferd, Schatz, Brücke, Haus …), also 15–30 Schätze und Orte je Gebiet. Flüsse, Wälder und Zäune lenken die Wege, damit es nicht geradeaus durchgeht. Die Technik-Probe prüft die Obergrenze (256 × 256).

## 11. Schätze
In jedem Gebiet sind Schätze versteckt. Kommt ein Pferd in die Nähe, kann es einen aufspüren: Über ihm erscheint ein Emoji 👃. Lässt man es dann frei gehen (nicht mehr steuern), läuft es zum Schatz, und man erhält ihn.

| Wert | Formel |
|---|---|
| Spür-Radius | 2 + Aufspürung / 10 Kacheln (Aufspürung 50 → 7 Kacheln) |
| Chance je Sekunde im Radius | Aufspürung / 2 % (Aufspürung 50 → 25 %) |
Fundstücke: Satteltaschen (1–4) → Fahrzeug (unbegrenzt) → Hausinventar, sobald das Fahrzeug im Startgebiet oder das Pferd auf dem Grundstück ist.

| Fund | Wert | Häufigkeit |
|---|---|---|
| Blume | 5 | sehr häufig |
| Samen (zufällig, auch seltene) | – | häufig |
| Münzbeutel | 30 | häufig |
| Goldhufeisen (verkaufbar) | 200 | selten |
| Antiquität | 500 | sehr selten |
| Schatztruhe | 1 500 | legendär, ab Gebiet 3 |

Aufspürung +1 je Fund (mit Trainingsformel).

## 12. Jobs

| Job | ab | Lohn | Training | Energie |
|---|---|---|---|---|
| Postritt | Bindung 40 | 25 + Tempo / 2 | Tempo +2, Ausdauer +1 | 30 |
| Kutschtaxi | Stärke 30 | 25 + Stärke / 2 | Stärke +2, Ausdauer +1 | 30 |
| Pflügen | Stärke 50 | 40 + Stärke / 3 | Stärke +3, Ausdauer +1 | 40 |

Je Pferd ein Job pro Tag, jeden Job gibt es einmal pro Tag.

## 13. Turniere
Teilnahme jederzeit. Jede Klasse hat die drei Wettbewerbe. Ein Wettbewerb, an dem man teilgenommen hat, ist weg (für alle Pferde), die anderen bleiben offen. Nach 3 Tagen gibt es neue, mit neuen Teilnehmern und Chancen. Wertung = Stat-Anteil × (0,5 + Bindung / 200). Gegner: Wertung 15 + 12 × Klasse ± 12 (Dorf = Klasse 1). Springreiten: Die höchste Stange ist 18 + 3 × Klasse hoch (Sprunghöhe 6 + 0,3 × Stärke), fürs Dorf reicht Stärke 50, International braucht 100.

| Klasse | braucht | Startgebühr | 1. / 2. / 3. Preis |
|---|---|---|---|
| Dorf | – | 10 | 50 / 25 / 10 |
| Kreis | Fahrrad | 40 | 200 / 100 / 50 |
| Bezirk | Mofa | 120 | 750 / 350 / 180 |
| Land | Kleinwagen | 400 | 2 500 / 1 200 / 600 |
| National | SUV | 1 200 | 7 500 / 3 500 / 1 800 |
| International | Flugzeug | 4 000 | 25 000 / 12 000 / 6 000 |

| Wettbewerb | zählt |
|---|---|
| Schönheitswettbewerb | Seltenheit Farbe + Rasse, Sauberkeit, Schmuck |
| Springreiten (Minispiel) | Stärke → Sprunghöhe, Ausdauer → Parcours ohne Leistungsabfall |
| Pferderennen (Minispiel) | Tempo → Höchstgeschwindigkeit, Ausdauer → wie lange sie hält |

## 14. Reformen
Alle 4 Tage eine neue Reform aus der Zeitung, Dauer 3–5 Tage.

| Reform | Wirkung |
|---|---|
| Hunde frei | nachts Hunde, zerstören Deko; Pferde mit Stärke ≥ 40 wehren sie ab |
| Wölfe frei (ab 4 Tage nach Erreichen von Gebiet 3) | wie Hunde, Stärke ≥ 60 |
| Krokodile frei (ab 4 Tage nach Erreichen von Gebiet 5, Canyon) | wie Hunde, Stärke ≥ 80, auch tagsüber |
| Pferdesteuer | 0–10 pro Pferd und Tag, steigt im Spielverlauf |
| Hafersteuer | Futter +50 % |
| Stromsubvention | Generator ×2 |

## 15. Wirtschaft: Beispielrechnung
1 Spieltag ≈ 4,5 min Spielzeit (6:15 min, die Nacht meist verschlafen, Menüs halten die Uhr an). Laufende Kosten pro Pferd und Tag: etwa 8 Futter + 3 Steuer = **11**, mit eigenem Anbau etwa **5**.
Startgeld **300**, Start mit Wohnwagen, Stall S und Weide, ohne Pferd, ohne Sattel und ohne Bürste (Laden).

| Phase | Ziel | Kosten | Einnahmen/Tag (netto) | Tage | Spielzeit |
|---|---|---|---|---|---|
| 1 | Fahrrad + Schuppen + Anhänger 1 | 1 200 (900 nach Startgeld) | ~150: Jobs, ab Tag 5 ein Wildpferd am Tag an den Käufer | 8 | 0:35 h |
| 2 | Mofa + Anhänger 2 + Stall M | 6 400 | ~560: Wildpferde aus dem Birkenwald, Kreis-Turniere | 12 | 0:55 h |
| 3 | Kleinwagen + Garage + Anhänger 3 | 19 000 | ~1 500: Pferde aus den Flussauen, Bezirk-Turniere | 14 | 1:05 h |
| 4 | SUV + Anhänger 4 | 38 000 | ~3 600: Steppenpferde, Land-Turniere | 11 | 0:50 h |
| 5 | Flugzeug + Hangar | 85 000 | ~7 900: Araber, National-Turniere | 12 | 0:55 h |
| | **Summe** | | | **57** | **~4,3 h** |

Gerechnet mit `game/sim.lua` (Zeilen „WIRTSCHAFT“ im Selbsttest): jeden Tag ein Wildpferd aus dem neuesten Gebiet, drei Pferde behalten, Turniere ohne Minispiel. Die Simulation spielt sehr effizient, echtes Spielen dauert deutlich länger (Heimattal vorher: Simulation 1 h, gespielt 3–4 h). Ziel: pro Gebiet 1–3 h gespielt.
Ausgaben für Sättel, Deko, Land und Anbau kommen dazu und verlängern das Spiel.

## Offene Fragen
- Spieldauer ~10 h bis zum Flugzeug: passend?
- Hat Bindung doch einen Gen-Anteil (zutrauliche Linien züchten)?
- Wie viele Pferde maximal gleichzeitig (Speicher, Übersicht)? Vorschlag: 24.
- Tauschcode: Länge und Zeichen (Vorschlag: 16 Zeichen A–Z, 2–9)
