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

-- Tageszeit: save.zeit = Frame im Tag (0–18000, ab 10800 ist es dunkel), save.tag = Tagesnummer.
function Scenarios.abend(save)
  return "world", {ort = "start", zeit = save.zeit or 9800, tag = save.tag}
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
  return "world", {ort = "start", screen = "bauen", geld = save.geld or 500}
end

-- Weiden: zweite Weide mit Tor und eine geschlossene Koppel ohne Tor (zählt nicht), Baumodus offen.
function Scenarios.weiden()
  return "world", {ort = "start", screen = "weiden", weiden = true}
end

-- Stammbaum: ein Pferd mit drei Generationen bekannter Ahnen, Bildschirm offen.
function Scenarios.stammbaum()
  return "world", {ort = "start", stammbaum = true, screen = "stammbaum"}
end

-- Jobbrett: drei Pferde (Hof), Jobliste offen.
function Scenarios.jobbrett()
  return "world", {ort = "start", hof = true, screen = "jobs"}
end

-- Bestellungen: drei Pferde (Hof), eine Bestellung passt auf das erste, Liste offen.
function Scenarios.bestellung()
  return "world", {ort = "start", hof = true, bestellung = true, screen = "bestellung"}
end

-- Käufer: drei Pferde (Hof), save.kaeufer = sammlerin, reithof, zuechter oder schlachter; Dialog offen.
function Scenarios.kaeufer(save)
  return "world", {ort = "start", hof = true, kaeufer = save.kaeufer or "sammlerin", screen = "kaeufer"}
end

-- Pferdemarkt: am Stand, save.geld setzt das Geld, save.gebiet das weiteste erreichbare Gebiet.
function Scenarios.markt(save)
  return "world", {ort = "markt", screen = "markt", hof = true, geld = save.geld or 600}
end

-- Hof: Startausstattung, drei eigene Pferde (Weide, Stall, Leine).
function Scenarios.hof_start()
  return "world", {ort = "start", hof = true}
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
