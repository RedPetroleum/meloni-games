-- Benannte Ausgangslagen zum Testen: Ein Spielstand {scenario = "name", …} startet das Spiel
-- direkt dort (tools/hoofy-test.sh schreibt so einen Spielstand und startet den Runner).
--
-- Ein Szenario ist eine Funktion(save) und gibt die Szene zurück, mit der es weitergeht
-- (Name und Argument wie in main.lua), z. B. "world".
local Scenarios = {}

-- Alle Selbsttests aus game/tests/ (Liste in game/tests/list.lua). save.only = "modul": nur dieses,
-- save.list = "game.tests.andere_liste": andere Liste (z. B. für eine einmalige Messung).
-- Loggt "SELFTEST OK <n>" oder wirft beim ersten Fehler (Runner endet mit Status 1).
function Scenarios.selftest(save)
  local modules = require(save.list or "game.tests.list")
  local n = 0
  for _, name in ipairs(modules) do
    if not save.only or save.only == name then
      local tests = require("game.tests." .. name)
      for _, t in ipairs(tests) do
        local ok, err = pcall(t[2])
        if not ok then error("SELFTEST FEHLER " .. name .. ": " .. t[1] .. ": " .. tostring(err), 0) end
        n = n + 1
      end
    end
  end
  log("SELFTEST OK " .. n)
  return "title"
end

-- Welt. save.ort = Ort aus area.places (start, hoftor, bruecke, laden …) oder save.cx, save.cy.
function Scenarios.welt(save)
  if save.ort or save.cx then return "world", {ort = save.ort, cx = save.cx, cy = save.cy} end
  return "world"
end

-- Ganzes Gebiet verkleinert (1 Kachel = 2 px). save.gebiet (Standard 1), save.seed.
function Scenarios.karte_ganz(save)
  return "overview", {nr = save.gebiet or 1, seed = save.seed}
end

-- Wildpferde im Sichtfeld: Start am Hof, save.cx/cy überschreiben. Pferde stehen dann nah am Spieler.
function Scenarios.wildpferde(save)
  return "world", {ort = "start", wild_nah = true}
end

-- Tageszeit: save.zeit = Frame im Tag (0–22500, ab 13500 ist es dunkel), save.tag = Tagesnummer.
function Scenarios.abend(save)
  return "world", {ort = "start", zeit = save.zeit or 12250, tag = save.tag, laterne = save.laterne}
end

-- Bildschirme: save.screen = pause, horses, info, keyboard, inventar, map (Pferde wie in hof_start).
function Scenarios.menues(save)
  return "world", {ort = "start", hof = true, screen = save.screen or "pause"}
end

-- Laden: am Ladeneingang, save.geld setzt das Geld. save.screen = "laden" öffnet ihn gleich.
function Scenarios.laden(save)
  return "world", {ort = "laden", screen = "laden", hof = true, geld = save.geld or 300}
end

-- Baumodus: am Hof, save.geld setzt das Geld. Start im Baumodus, Drehbuch per INPUT (A setzt, B + Tasten wählt).
function Scenarios.bauen(save)
  return "world", {ort = "start", screen = "bauen", geld = save.geld or 500, hof = save.hof}
end

-- Weiden: zweite Weide mit Tor und eine geschlossene Koppel ohne Tor (zählt nicht), Baumodus offen.
function Scenarios.weiden()
  return "world", {ort = "start", screen = "weiden", weiden = true}
end

-- Anbau: Beete und alle Pflanzen am Tag 1 gepflanzt, save.tage Tage später. Kamera auf dem Beet.
function Scenarios.anbau(save)
  return "world", {ort = "start", anbau = true, tage = save.tage or 0}
end

-- Gebäude: alle Gebäude auf dem Grundstück. save.cx, save.cy: Startkachel der Kamera.
-- Reise (D1): am Schuppen mit Mofa und zwei Pferden; Drehbuch: A, A lädt beide ein, A öffnet das Reisemenü, A fährt.
function Scenarios.reise(save)
  return "world", {fahrt = true}
end

-- Gebiet: am Ankunftspunkt von Gebiet save.gebiet (Standard 2) mit Gespann aus save.fahrzeug und
-- Anhänger für save.anhaenger Pferde, z. B. SCENARIO_OPTS='gebiet = 5, fahrzeug = "suv", anhaenger = 4'.
-- save.pferde = n: so viele eigene Pferde dabei (eins an der Leine, die anderen folgen).
-- save.blick = true: statt am Ankunftspunkt an der Stelle mit dem meisten Wald, Wasser und Weg
-- (zum Ansehen der Gebietsfarben).
function Scenarios.gebiet(save)
  local nr = save.gebiet or 2
  local arg = {gebiet = nr, fahrzeug = save.fahrzeug or "suv", anhaenger = save.anhaenger or 2, pferde = save.pferde}
  if save.blick then
    local map = require("game.area").get(nr).map
    local best = -1
    for cy = 7, map.h - 8, 3 do
      for cx = 10, map.w - 11, 3 do
        local n = {}
        for y = cy - 7, cy + 6 do
          for x = cx - 10, cx + 9 do
            local c = map:code(x, y)
            n[c] = (n[c] or 0) + 1
          end
        end
        local score = math.min(n.F or 0, 60) + 2 * math.min(n["~"] or 0, 25) + 2 * math.min(n[":"] or 0, 20)
          + math.min(n["."] or 0, 80)
        if score > best then best, arg.cx, arg.cy = score, cx, cy end
      end
    end
  end
  return "world", arg
end

-- Schatzsuche (D3): Reiter nahe eines Schatzes, ohne Eingabe; Drehbuch nicht nötig (--shots 30,90,150,300).
function Scenarios.schatz(save)
  return "world", {schatz = true}
end

-- Regen (D4): am Hof mit Pferden auf Weide und im Stall; save.regen = false schaltet ihn ab.
function Scenarios.regen(save)
  return "world", {ort = "start", hof = true, regen = save.regen ~= false}
end

-- Nachtritt (D5): Reiter bei Nacht, save.lampe = true mit Sattellampe.
function Scenarios.nachtritt(save)
  return "world", {ort = "start", ritt = true, aufsitzen = true, lampe = save.lampe, zeit = 15600}
end

-- Turnierplatz (E1): am Turnierplatz mit Pferden und Fahrzeug nach save.fahrzeug (Standard: Fahrrad).
function Scenarios.turnier(save)
  return "world", {ort = "turnier", hof = true, geld = save.geld or 1000, screen = "turnier", fahrzeug = save.fahrzeug or "fahrrad"}
end

-- Springreiten-Minispiel (E2): Drehbuch per INPUT (A springt), save.staerke setzt die Stärke des Pferds.
function Scenarios.springreiten(save)
  return "world", {ort = "start", hof = true, screen = "springen", staerke = save.staerke}
end

-- Pferderennen-Minispiel (E3): A halten = Spurt (INPUT-Drehbuch), save.staerke ist hier ohne Wirkung.
function Scenarios.pferderennen(save)
  return "world", {ort = "start", hof = true, screen = "rennen"}
end

-- Reformen (E4): save.reform = Reform-id (aktiv ab jetzt), save.screen = "zeitung" öffnet die Zeitung;
-- Hundenacht: save.zeit = 15600 (nachts) mit hunde_frei.
function Scenarios.reform(save)
  return "world", {ort = "start", hof = true, reform = save.reform or "hunde_frei", zeit = save.zeit, screen = save.screen or "none"}
end

-- Album (E5): öffnet das Album; save.viele = true trägt vorher viele Kombinationen ein (Tests der Optik).
function Scenarios.album(save)
  return "world", {ort = "start", hof = true, screen = "album", album_voll = save.viele}
end

-- Tauschen (E6): öffnet den Tauschbildschirm mit drei Pferden.
function Scenarios.tausch(save)
  return "world", {ort = "start", hof = true, screen = "tausch"}
end

function Scenarios.gebaeude(save)
  return "world", {cx = save.cx, cy = save.cy, ort = (not save.cx) and "start" or nil, gebaeude = true}
end

-- Stammbaum: ein Pferd mit drei Generationen bekannter Ahnen, Bildschirm offen.
function Scenarios.stammbaum()
  return "world", {ort = "start", stammbaum = true, screen = "stammbaum"}
end

-- Jobbrett: drei Pferde (Hof), Jobliste offen.
function Scenarios.jobbrett()
  return "world", {ort = "start", hof = true, screen = "jobs"}
end

-- Job-Minispiel (Rückmeldung 1.2.1): save.job = postritt, kutschtaxi oder pfluegen, mit dem ersten Hofpferd.
function Scenarios.jobspiel(save)
  return "world", {ort = "start", hof = true, screen = "jobspiel", job = save.job or "postritt"}
end

-- Bestellungen: drei Pferde (Hof), eine Bestellung passt auf das erste, Liste offen.
function Scenarios.bestellung()
  return "world", {ort = "start", hof = true, bestellung = true, screen = "bestellung"}
end

-- Käufer: drei Pferde (Hof), save.kaeufer = sammlerin, reithof, zuechter oder schlachter; Dialog offen.
function Scenarios.kaeufer(save)
  return "world", {ort = save.ort or "start", hof = true, kaeufer = save.kaeufer or "sammlerin", screen = save.screen or "kaeufer"}
end

-- Pferdemarkt: am Stand, save.geld setzt das Geld, save.gebiet das weiteste erreichbare Gebiet.
function Scenarios.markt(save)
  return "world", {ort = "markt", screen = "markt", hof = true, geld = save.geld or 600}
end

-- Hof: Startausstattung, drei eigene Pferde (Weide, Stall, Leine).
function Scenarios.hof_start()
  return "world", {ort = "start", hof = true}
end

-- Stall von innen: save.stall = stall_s, stall_m, stall_l oder stall_xl, fast voll belegt.
function Scenarios.stall(save)
  return "world", {stall = save.stall or "stall_l"}
end

-- Göpel: ein Pferd zieht den Generator am Hof (läuft im Kreis).
function Scenarios.goepel()
  return "world", {goepel = true}
end

-- Zucht: Hengst und Stute im Stall, Spieler vor der Stalltür. Drehbuch: A öffnet das Stallmenü.
-- save.geburt = true: die Stute ist trächtig, kurz vor dem nächsten Morgen (zeit 22400).
function Scenarios.zucht(save)
  return "world", {zucht = true, tag = save.tag, geburt = save.geburt, zeit = save.geburt and 22400 or save.zeit}
end

-- Reiten: zahmes Pferd mit Sattel neben dem Spieler, Büsche (save.hindernis = "o": Steine) 6 Kacheln
-- rechts. save.staerke setzt die Stärke, save.bindung die Bindung.
function Scenarios.ritt(save)
  return "world", {ort = "start", ritt = true, staerke = save.staerke, bindung = save.bindung, hindernis = save.hindernis}
end

-- Zähmen: ein Haflinger 140 px rechts vom Spieler am Hof (save.bindung, Standard 35). Übergänge im Log.
function Scenarios.zaehmen(save)
  return "world", {ort = "start", zaehmen = true, bindung = save.bindung}
end

-- Je ein Pferd pro Blasen-Zustand (E10). Charakter-Blasen erscheinen nur zeitweise: mehrere Shots.
function Scenarios.blasen()
  return "bubbles"
end

-- Schmuck (Rückmeldung 1.2.1): alle Körper in fünf Posen mit allem Schmuck.
function Scenarios.schmuck()
  return "gallery", {schmuck = true}
end

-- Alle Rassen mit je drei Farben, Posen laufen durch (Seite wechselt alle 4 s).
function Scenarios.galerie()
  return "gallery"
end

-- save: der geladene Spielstand mit save.scenario. Gibt Szene und Argument zurück.
function Scenarios.start(save)
  local f = Scenarios[save.scenario]
  if type(f) ~= "function" or save.scenario == "start" then
    error("unbekanntes Szenario " .. tostring(save.scenario), 0)
  end
  return f(save)
end

return Scenarios
