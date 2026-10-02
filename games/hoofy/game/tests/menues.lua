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
    keys(kb, nav, {BTN_A, BTN_A, BTN_A, BTN_A, BTN_A}) -- Ä fünfmal: Länge begrenzt auf 5
    -- zur letzten Zeile: LÖSCHEN nimmt ein Ä weg, dann FERTIG
    for _ = 1, 4 do keys(kb, nav, {BTN_DOWN}) end
    keys(kb, nav, {BTN_A})
    keys(kb, nav, {BTN_RIGHT, BTN_A})
    C.eq(result, "ABÄÄ", "Text")
    C.eq(#nav.stack, 0, "Tastatur geschlossen")
  end},
  {"Tastatur: B bricht ab, auch mit Text, ohne Ergebnis (Rückmeldung 1.3.4)", function()
    local nav, called = nav_new(), false
    local kb = Screens.keyboard("Name", "Hilde", 12, function() called = true end)
    nav.push(kb)
    keys(kb, nav, {BTN_A})                            -- ein Zeichen dazu
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
    keys(kb, nav, {BTN_A})                                     -- "A" anhängen
    for _ = 1, 6 do keys(kb, nav, {BTN_DOWN}) end              -- FERTIG-Zeile
    keys(kb, nav, {BTN_RIGHT, BTN_A})
    C.eq(h.data.name, "HildeA")
    C.eq(#nav.stack, 1)
    -- noch einmal: tippen, dann B bricht ab, der Name bleibt
    keys(info, nav, {BTN_A})
    kb = nav.stack[2]
    keys(kb, nav, {BTN_A})
    keys(kb, nav, {BTN_B})
    C.eq(h.data.name, "HildeA", "B übernimmt nichts")
    C.eq(#nav.stack, 1)
    keys(info, nav, {BTN_B})
    C.eq(#nav.stack, 0)
  end},
  {"Pausenmenü: START öffnet/schließt, Pferde und Inventar öffnen Unterbildschirme", function()
    local ctx = Stage.build(1)
    ctx.clock = {day = 20}                 -- alles freigeschaltet
    Wild.new(ctx, 3):add_own({name = "Hilde"})
    local nav = nav_new()
    local p = Screens.pause(ctx, nav)
    nav.push(p)
    keys(p, nav, {BTN_START})
    C.eq(#nav.stack, 0, "START schließt")
    nav.push(p)
    -- Raster 5 × 2: Weiter Pferde Vorrat Kunden Karte / Bauen Zeitung Album Tausch Sichern
    for _, step in ipairs({{BTN_RIGHT, "Pferde"}, {BTN_RIGHT, "Inventar"}, {BTN_RIGHT, "Bestellungen"}, {BTN_RIGHT, "Karte"},
        {BTN_DOWN, "Speichern"}, {BTN_LEFT, "Tauschen"}, {BTN_LEFT, "Album"}, {BTN_LEFT, "Zeitung"}}) do
      keys(p, nav, {step[1]})
      if step[2] ~= "Speichern" then
        keys(p, nav, {BTN_A})
        C.eq(#nav.stack, 2, step[2] .. " öffnet")
        keys(nav.stack[2], nav, {BTN_B})
        C.eq(#nav.stack, 1, step[2] .. " zu")
      end
    end
    keys(p, nav, {BTN_LEFT, BTN_A})                            -- Bauen ist ausgegraut (nicht auf dem Hof)
    C.eq(#nav.stack, 1, "ausgegraut: nichts passiert")
    keys(p, nav, {BTN_DOWN, BTN_A})                            -- nach oben umlaufen: Weiter
    C.eq(#nav.stack, 0, "Weiter schließt")
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
  {"Kachelmenü: vier Richtungen, kurze letzte Reihe, ausgegraute Kacheln wählbar, aber nicht bestätigbar", function()
    local Menu = require("game.menu")
    local items = {}
    for k = 1, 7 do items[k] = {label = "E" .. k, id = k, icon = "ico_info", dim = k == 6} end
    local m = Menu.new(items, "Test")
    C.ok(m.grid)
    C.eq(m.cols, 4)
    C.eq(m.rows, 2)
    local old = btnp
    local function press(b) btnp = function(x) return x == b end return m:update() end
    press(BTN_LEFT)  C.eq(m.sel, 4, "links umlaufen")
    press(BTN_DOWN)  C.eq(m.sel, 7, "unter der letzten Spalte: letzte Kachel")
    press(BTN_RIGHT) C.eq(m.sel, 5, "rechts hinaus: Anfang der Reihe")
    press(BTN_RIGHT) C.eq(m.sel, 6)
    C.eq(press(BTN_A), nil, "ausgegraut")
    press(BTN_UP)    C.eq(m.sel, 2)
    C.eq(press(BTN_A), 2)
    C.eq(press(BTN_B), "close")
    btnp = old
    m:draw()
    local list = Menu.new({{label = "a", id = 1}, {label = "b", id = 2}})
    C.ok(not list.grid, "ohne Bilder bleibt es eine Liste")
    list:draw(10, 10)
  end},
  {"Schriften (API 3): font wählt 8×8, 8×16, 12×24 für print und textw", function()
    C.eq(font(), 0, "Standard")
    C.eq(textw("Ab"), 16)
    C.eq(font(1), 0, "gibt die vorherige zurück")
    C.eq(textw("Ab"), 16)
    font(2)
    C.eq(textw("Ab"), 24)
    rectfill(0, 0, 40, 30, 0)
    print("H", 0, 0, rgb(255, 255, 255))
    local lit = 0
    for y = 0, 23 do for x = 0, 11 do if pget(x, y) ~= pget(39, 29) then lit = lit + 1 end end end
    C.ok(lit > 20, "H in 12×24 gezeichnet: " .. lit)
    C.eq(font(0), 2)
    C.ok(not pcall(font, 3), "nur 0–2")
    cls()
  end},
}
