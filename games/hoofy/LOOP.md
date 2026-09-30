# Hoofy – Regeln für den Bau-Loop

Diese Datei ist die Anleitung für Claude, wenn Hoofy im Loop gebaut wird. Start:
`/loop Lies games/hoofy/LOOP.md und arbeite nach den Regeln dort.`

## Dateien

| Datei | Inhalt | Wer schreibt |
|---|---|---|
| [README_HOOFY.md](README_HOOFY.md), [KATALOG.md](KATALOG.md) | Konzept und Werte, die Vorgabe | nur der Mensch |
| [PLAN.md](PLAN.md) | Rückmeldungen, Aufgaben mit Prüfung, Stand | Mensch: Rückmeldungen; Loop: Häkchen, Notizen |
| [ENTSCHEIDUNGEN.md](ENTSCHEIDUNGEN.md) | alles, was der Loop selbst festgelegt hat, zum Überprüfen | Loop (Mensch streicht/ändert) |
| [PROTOKOLL.md](PROTOKOLL.md) | eine Zeile pro Durchlauf, nur anhängen | Loop |

## Ein Durchlauf

1. **Stand lesen:** PLAN.md (zuerst „Rückmeldungen“), die letzten 20 Zeilen von PROTOKOLL.md,
   `git status`, `git log --oneline -5`. Liegt ein halb fertiger Stand herum (Protokoll „begonnen“
   ohne „fertig“, uncommittete eigene Änderungen), zuerst diesen zu Ende bringen oder verwerfen.
2. **Aufgabe wählen:** Offene Rückmeldungen des Menschen gehen vor. Sonst die erste Aufgabe
   `- [ ]` in PLAN.md, die nicht `BLOCKIERT` ist. Ins Protokoll: `begonnen`.
3. **Umsetzen:** KATALOG.md ist die Quelle für alle Zahlen, README_HOOFY.md für das Verhalten.
   Fehlt etwas: selbst sinnvoll entscheiden, **nicht warten**, und die Entscheidung in
   ENTSCHEIDUNGEN.md eintragen (Nummer, ein Satz, betroffene Aufgabe). Entscheidungen, die schon
   dort stehen, gelten; hat der Mensch eine geändert, gilt seine Fassung.
4. **Prüfen:** die Prüfung aus der Aufgabe **und** `make test` (alle Spiele). Screenshots ansehen,
   nicht nur den Exit-Status. Bei Grafik die Shot-Sheet-Übersicht (`SHOTS=…`) nutzen.
5. **Festhalten:** Häkchen in PLAN.md mit einer kurzen Notiz, Zeile in PROTOKOLL.md
   (`JJJJ-MM-TT HH:MM | Aufgabe | fertig/blockiert | Prüfung | Commit`), dann committen.
   Nur die eigenen Dateien stagen (`git add games/hoofy tools/…`), nie `git add -A`: Der Mensch
   arbeitet eventuell gleichzeitig an README/KATALOG, und `archive/` gehört nicht dazu.
6. **Weiter:** nächster Durchlauf nach kurzer Pause (ScheduleWakeup 60 s). Sind alle Aufgaben
   erledigt oder blockiert: Abschluss schreiben (siehe unten), Loop beenden.

Jeder Durchlauf muss für sich stehen: Alles, was man zum Weitermachen wissen muss, steht in den
Dateien und im Git-Log, nicht im Gesprächsverlauf. Unterbrechungen (Limit, Absturz, Neustart)
kosten dann höchstens die angefangene Aufgabe.

## Harte Regeln

- **Keine Engine-Änderungen** (`engine/`, `runner/`, `web/`). Geht etwas ohne nicht: Aufgabe
  `BLOCKIERT: braucht Engine: …`, Workaround-Idee in ENTSCHEIDUNGEN.md, weiter mit der nächsten.
- **README_HOOFY.md und KATALOG.md nicht ändern.** Widersprüche oder fehlende Werte gehören in
  ENTSCHEIDUNGEN.md. Zahlen aus dem Katalog nicht „verbessern“, auch wenn die Balance falsch wirkt:
  Befund in ENTSCHEIDUNGEN.md unter „Balance“.
- **Dreimal gescheitert = blockiert.** Nicht die ganze Nacht an einer Aufgabe hängen.
- **Nie mit rotem `make test` committen oder pushen.**
- Nur API aus [docs/API.md](../../docs/API.md). Grafik als Sprites in `sprites.txt` (AGENTS.md Punkt 6).
- Menü-Kombinationen SELECT+START und SELECT+A nicht belegen.

## Pushen

Ein Push auf `main` veröffentlicht Hoofy auf der Konsole. Gepusht wird:
- am Ende jeder Phase (0, A, B, C, D, E), vorher `version` in `meta.json` erhöhen
  (Phase A → 0.1.0, B → 0.2.0 …), Cover mit `make cover` erneuern, README-Tabelle pflegen;
- zusätzlich, wenn seit dem letzten Push 6 Aufgaben fertig sind, damit morgens immer ein
  aktueller Stand auf der Konsole landen kann.

Nach dem Push den Release-Lauf prüfen (AGENTS.md „Veröffentlichen“). Schlägt er fehl: beheben,
bevor es weitergeht. Im Protokoll vermerken, welche Version jetzt über „Update games“ kommt.

Nach einem Phasenende **nicht anhalten**, sondern mit der nächsten Phase weitermachen. Oben in
PLAN.md unter „Auf der Konsole testen“ eine kurze Checkliste für die fertige Phase ergänzen.

## Technik

- `lib/` aus Ausgebüxt nach `games/hoofy/lib/` kopieren und dort weiterentwickeln (Spiele können
  nicht ordnerübergreifend `require`n). Aufbau wie Ausgebüxt: `lib/` spielunabhängig, `game/` Hoofy.
- Karte: 1 Byte pro Kachel (Strings oder Byte-Tabellen je Zeile), Deko aus einem Hash der
  Koordinaten, Objekte in Blöcken zu 16×16 Kacheln. Keine Tabelle pro Kachel. Gespeichert werden
  nur Änderungen gegenüber dem Seed.
- Pro Frame nur sichtbare Kacheln und Objekte in der Nähe anfassen. Wildpferde, die weit weg sind,
  nur grob (selten) aktualisieren.
- Lua-Speicher regelmäßig loggen (`collectgarbage('count')`), Ziel: unter 2 MB. Größe des
  Spielstands (Länge der gespeicherten Tabelle) bei jedem Speichertest loggen.
- Kein Einfärben von Bildern in der API: Nacht über zusätzliche Sprite-Varianten (`recolor`) und
  dunkle Bodenfarben, nicht über Pixel-Schleifen.
- Werte aus KATALOG.md kommen über einen Generator (`tools/hoofy_katalog.py`, Aufgabe 0.3) ins
  Spiel, nicht abgetippt. Katalog ändert sich → Generator läuft bei `make test/shot/run` mit.

## Prüfen mit Szenarien

Der Spielstand ist eine Lua-Tabelle (`return {...}`), der Runner lädt ihn mit `--save`. Darauf
baut das Test-Werkzeug aus Aufgabe 0.2 auf:

- `game/scenarios.lua`: benannte Ausgangslagen („tag5_drei_pferde“, „leine“, „zucht“ …), die ein
  vollständiger Spielstand oder eine Funktion sind. Ein Spielstand `{scenario = "leine"}` startet
  das Spiel direkt dort.
- Szenario `selftest`: führt alle Tests aus `game/tests/*.lua` aus (Formeln, Verteilungen,
  Speichern/Laden), loggt `SELFTEST OK <n>` und wirft bei einem Fehler, dann endet der Runner mit
  Status 1.
- `tools/hoofy-test.sh <szenario> [runner-argumente]`: schreibt den Spielstand in eine temporäre
  Datei (der Runner überschreibt sie beim Speichern) und startet den Runner headless.

Jede Aufgabe mit Spiellogik bekommt Selbsttests; jede Aufgabe mit Bild bekommt ein Szenario und
einen Screenshot. Zufall über `SEED`, bei Verteilungen mehrere Seeds oder viele Würfe.

## Abschluss

Wenn alle Aufgaben erledigt oder blockiert sind: in PLAN.md unter „Stand“ zusammenfassen, was
fertig ist, was blockiert ist und welche Entscheidungen am dringendsten angesehen werden sollten.
Letzter Push, Release prüfen, Loop beenden.
