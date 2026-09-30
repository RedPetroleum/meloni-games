-- Selbsttests für die Bildschirme (Aufgabe A13): Tastatur, Info, Liste, Pausenmenü.
local Stage = require("game.stage")
local Wild = require("game.wild")
local Screens = require("game.screens")
local C = require("game.tests.check")

-- Drückt die Tasten nacheinander (je einen Frame lang) und ruft dabei s.update.
local function keys(s, nav, list)
  local old = btnp
  for _, k in ipairs(list) do
    btnp = function(b) return b == k end
    s.update(nav)
  end
  btnp = old
end

local function nav_new()
  local stack = {}
  local nav = {stack = stack}
  function nav.push(s) stack[#stack + 1] = s end
  function nav.pop() stack[#stack] = nil end
  return nav
end

return {
  {"Tastatur: Buchstaben, Umlaute, Löschen, Höchstlänge, Fertig", function()
    local result
    local nav = nav_new()
    local kb = Screens.keyboard("Name", "", 5, function(t) result = t end)
    nav.push(kb)
    -- A tippt "A"; rechts, A = "B"; nach unten zur 3. Reihe (UVWXYZÄÖÜß-), Ä = 7. Taste
    keys(kb, nav, {BTN_A, BTN_RIGHT, BTN_A})
    for _ = 1, 2 do keys(kb, nav, {BTN_DOWN}) end
    for _ = 1, 5 do keys(kb, nav, {BTN_RIGHT}) end   -- von B (x=2) auf Ä (x=7)
    keys(kb, nav, {BTN_A})
    keys(kb, nav, {BTN_B})                            -- löscht das Ä
    keys(kb, nav, {BTN_A, BTN_A, BTN_A, BTN_A})       -- Ä viermal: Länge begrenzt auf 5
    -- zur Reihe FERTIG (letzte Zeile), zweite Taste
    for _ = 1, 4 do keys(kb, nav, {BTN_DOWN}) end
    keys(kb, nav, {BTN_RIGHT, BTN_A})
    C.eq(result, "ABÄÄÄ", "Text")
    C.eq(#nav.stack, 0, "Tastatur geschlossen")
  end},
  {"Tastatur: B bei leerem Text schließt ohne Ergebnis", function()
    local nav, called = nav_new(), false
    local kb = Screens.keyboard("Name", "", 5, function() called = true end)
    nav.push(kb)
    keys(kb, nav, {BTN_B})
    C.eq(#nav.stack, 0)
    C.ok(not called, "kein Ergebnis")
  end},
  {"Info: A öffnet die Tastatur und Umbenennen ändert den Namen", function()
    local ctx = Stage.build(1)
    local w = Wild.new(ctx, 3)
    local h = w:add_own({name = "Hilde"})
    local nav = nav_new()
    local info = Screens.info(ctx, h.data)
    nav.push(info)
    keys(info, nav, {BTN_A})
    C.eq(#nav.stack, 2, "Tastatur oben")
    local kb = nav.stack[2]
    keys(kb, nav, {BTN_B, BTN_B, BTN_B, BTN_B, BTN_B})       -- "Hilde" löschen
    keys(kb, nav, {BTN_A})                                     -- "A"
    for _ = 1, 6 do keys(kb, nav, {BTN_DOWN}) end              -- FERTIG-Zeile
    keys(kb, nav, {BTN_RIGHT, BTN_A})
    C.eq(h.data.name, "A")
    C.eq(#nav.stack, 1)
    keys(info, nav, {BTN_B})
    C.eq(#nav.stack, 0)
  end},
  {"Pausenmenü: START öffnet/schließt, Pferde und Inventar öffnen Unterbildschirme", function()
    local ctx = Stage.build(1)
    Wild.new(ctx, 3):add_own({name = "Hilde"})
    local nav = nav_new()
    local p = Screens.pause(ctx, nav)
    nav.push(p)
    keys(p, nav, {BTN_START})
    C.eq(#nav.stack, 0, "START schließt")
    nav.push(p)
    keys(p, nav, {BTN_DOWN, BTN_A})                            -- Pferde
    C.eq(#nav.stack, 2)
    keys(nav.stack[2], nav, {BTN_B})
    keys(p, nav, {BTN_DOWN, BTN_A})                            -- Inventar
    C.eq(#nav.stack, 2)
    keys(nav.stack[2], nav, {BTN_A})
    keys(p, nav, {BTN_DOWN, BTN_A})                            -- Bestellungen
    C.eq(#nav.stack, 2)
    keys(nav.stack[2], nav, {BTN_B})
    keys(p, nav, {BTN_DOWN, BTN_A})                            -- Karte
    C.eq(#nav.stack, 2)
    keys(nav.stack[2], nav, {BTN_B})
    keys(p, nav, {BTN_DOWN, BTN_A})                            -- ausgegraute Einträge werden übersprungen
    C.eq(#nav.stack, 0, "springt zu Weiter und schließt")
  end},
  {"Alle Bildschirme zeichnen ohne Fehler", function()
    local ctx = Stage.build(1)
    local w = Wild.new(ctx, 3)
    local h = w:add_own({name = "Hilde"})
    h.data.alter = 0.4
    h.data.sattel = "sportsattel"
    local nav = nav_new()
    for _, s in ipairs({Screens.pause(ctx, nav), Screens.horses(ctx), Screens.info(ctx, h.data),
      Screens.keyboard("Name", "Test", 12), Screens.inventory(ctx), Screens.map(ctx)}) do
      s.draw()
    end
    ctx.herd = {}
    Screens.horses(ctx).draw()
  end},
}
