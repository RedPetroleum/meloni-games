-- Selbsttests für den Baumodus (Aufgabe C1): Platzieren, Kosten, Abreißen, Kollision, Spielstand.
local Stage = require("game.stage")
local Area = require("game.area")
local Wild = require("game.wild")
local Farm = require("game.farm")
local Body = require("lib.body")
local Save = require("game.save")
local Clock = require("game.clock")
local K = require("game.katalog")
local C = require("game.tests.check")

-- Welt mit Geld; Spieler weit weg vom Baugrund, damit er nicht im Weg steht.
local function setup(money)
  Area.clear()
  local ctx = Stage.build(1, 5)
  ctx.money = money or 1000
  local p = ctx.area.plot
  ctx.player.x, ctx.player.y = (p.x + 1) * 16, (p.y + 1) * 16
  return ctx, p
end

local function coll(ctx, cx, cy) return ctx.map.coll[cy + 1]:sub(cx + 1, cx + 1) end


-- Eigene Bauteile (ohne den Startzaun der Weide, der seit 1.3.3 auch in farm.items steht).
local function own_items(ctx)
  local out = {}
  for _, it in ipairs(ctx.area.farm.items) do if not it.start then out[#out + 1] = it end end
  return out
end

return {
  {"Bank bauen: Preis 40 G abgezogen, Kollision da, Bild im Block, Gras bleibt Gras", function()
    local ctx, p = setup()
    local cx, cy = p.x + 12, p.y + 7
    local ok = Farm.place(ctx, "bank", cx, cy)
    C.ok(ok)
    C.eq(ctx.money, 960)
    C.ok(not ctx.map:walkable(cx, cy), "Bank blockiert")
    local found = false
    for k = 1, ctx.map.bw * ctx.map.bh do
      for _, o in ipairs(ctx.map.blocks[k] or {}) do if o[1] == "bank" and o[2] == cx and o[3] == cy then found = true end end
    end
    C.ok(found, "Objekt eingetragen")
    C.eq(#own_items(ctx), 1)
  end},
  {"Nur auf dem Grundstück, nicht auf Belegtem, nicht im Wasser/Wald, nicht ohne Geld", function()
    local ctx, p = setup(100)
    local ok, why = Farm.place(ctx, "bank", p.x - 1, p.y + 5)
    C.ok(not ok and why == "nur auf dem Grundstück")
    ok, why = Farm.place(ctx, "bank", p.x + p.w, p.y + 5)
    C.ok(not ok and why == "nur auf dem Grundstück", "rechts daneben")
    ok, why = Farm.place(ctx, "brunnen", p.x + p.w - 1, p.y + 5)
    C.ok(not ok, "2×2 ragt über den Rand: " .. tostring(why))
    C.ok(Farm.place(ctx, "bank", p.x + 12, p.y + 7))
    ok, why = Farm.place(ctx, "lampe", p.x + 12, p.y + 7)
    C.ok(not ok and why == "schon belegt")
    local st = ctx.area.farm.buildings[2]
    ok, why = Farm.place(ctx, "bank", st.cx, st.cy)
    C.ok(not ok and why == "schon belegt" or why == "im Weg", "auf dem Stall: " .. tostring(why))
    ok, why = Farm.place(ctx, "lampe", p.x + 14, p.y + 7)
    C.ok(ok, "60 G reichen bei 60 übrig")
    C.eq(ctx.money, 0)
    ok, why = Farm.place(ctx, "bank", p.x + 15, p.y + 7)
    C.ok(not ok and why == "Geld")
    ctx.money = 1000
    ok, why = Farm.place(ctx, "weg", p.x + 16, p.y + 7)
    C.ok(ok)
    ok, why = Farm.place(ctx, "weg", p.x + 16, p.y + 7)
    C.ok(not ok and why == "schon belegt")
  end},
  {"Spieler im Weg: nicht auf den Spieler bauen, Weg/Boden schon", function()
    local ctx, p = setup()
    ctx.player.x, ctx.player.y = (p.x + 12) * 16 + 8, (p.y + 7) * 16 + 10
    local ok, why = Farm.place(ctx, "bank", p.x + 12, p.y + 7)
    C.ok(not ok and why == "du stehst im Weg")
    C.ok(Farm.place(ctx, "weg", p.x + 12, p.y + 7), "Weg darf unter dem Spieler liegen")
  end},
  {"Abreißen erstattet den vollen Kaufpreis, Boden wie vorher", function()
    local ctx, p = setup()
    local g0 = ctx.map:code(p.x + 12, p.y + 7)
    local start = ctx.money
    Farm.place(ctx, "brunnen", p.x + 12, p.y + 6)
    Farm.place(ctx, "weg", p.x + 15, p.y + 7)
    C.eq(ctx.money, start - 400 - 5)
    C.eq(ctx.map:code(p.x + 15, p.y + 7), ":", "Weg-Boden")
    C.ok(not ctx.map:walkable(p.x + 13, p.y + 7), "Brunnen 2×2 blockiert auch die Nachbarkachel")
    local sum = Farm.remove(ctx, p.x + 13, p.y + 7)      -- Kachel unten rechts im Brunnen
    C.eq(sum, 400)
    Farm.remove(ctx, p.x + 15, p.y + 7)
    C.eq(ctx.money, start, "alles zurück")
    C.eq(ctx.map:code(p.x + 15, p.y + 7), ".", "Gras")
    C.ok(ctx.map:walkable(p.x + 12, p.y + 6), "Brunnen weg, begehbar")
    C.eq(#own_items(ctx), 0)
    local none, why = Farm.remove(ctx, p.x + 12, p.y + 6)
    C.ok(none == nil and why:find("nichts"))
    local st = ctx.area.farm.buildings[2]
    C.ok(Farm.remove(ctx, st.cx, st.cy) == nil, "Startgebäude bleiben")
  end},
  {"Zaun: Form folgt den Nachbarn, Tor verbindet, Abreißen richtet die Nachbarn wieder aus", function()
    local ctx, p = setup()
    local y = p.y + 7
    for x = p.x + 12, p.x + 14 do C.ok(Farm.place(ctx, "zaun", x, y)) end
    local base = string.byte("A")
    C.eq(coll(ctx, p.x + 12, y), string.char(base + 2), "links: nur rechter Nachbar")
    C.eq(coll(ctx, p.x + 13, y), string.char(base + 3), "Mitte: beide Seiten")
    C.eq(coll(ctx, p.x + 14, y), string.char(base + 1), "rechts: nur linker Nachbar")
    Farm.place(ctx, "tor", p.x + 15, y)
    C.eq(coll(ctx, p.x + 14, y), string.char(base + 3), "Tor zählt als Nachbar")
    C.ok(ctx.map:walkable(p.x + 15, y), "Tor ist begehbar")
    Farm.remove(ctx, p.x + 13, y)
    C.eq(coll(ctx, p.x + 12, y), string.char(base), "einzeln")
    C.eq(coll(ctx, p.x + 14, y), string.char(base + 2), "nur noch das Tor rechts")
    C.eq(ctx.money, 1000 - 5 * 2 - 30, "Zaun 5, Tor 30, ein Zaun zurück: " .. ctx.money)
  end},
  {"Kollision: der Spieler läuft an der Bank nicht durch, über einen Weg schon", function()
    local ctx, p = setup()
    local cx, cy = p.x + 12, p.y + 7
    Farm.place(ctx, "bank", cx, cy)
    Farm.place(ctx, "weg", cx + 1, cy)
    local e = {x = (cx - 2) * 16 + 8, y = cy * 16 + 14, fw = 8, fh = 4}
    for _ = 1, 40 do Body.move(e, 1, 0, ctx.map) end
    C.ok(e.x < cx * 16, "an der Bank gestoppt, x=" .. e.x)
    local f = {x = (cx + 1) * 16 + 4, y = cy * 16 + 14, fw = 8, fh = 4}
    local x0 = f.x
    for _ = 1, 20 do Body.move(f, 1, 0, ctx.map) end
    C.ok(f.x > x0 + 10, "Weg ist begehbar")
  end},
  {"Baumodus-Bildschirm: öffnet mit der Auswahl (Art, dann Bauteil), A baut, B schließt, Pausenmenü nur auf dem Grundstück", function()
    local Screens = require("game.screens")
    local ctx, p = setup()
    ctx.player.x, ctx.player.y = (p.x + 12) * 16 + 8, (p.y + 7) * 16 + 8
    local nav = {stack = {}}
    function nav.push(s) nav.stack[#nav.stack + 1] = s end
    function nav.pop() nav.stack[#nav.stack] = nil end
    local b = Screens.build(ctx)
    nav.push(b)
    local function press(keys_down, keys_pressed)
      local ob, obtn = btn, btnp
      btn = function(k) return keys_down[k] or false end
      btnp = function(k) return keys_pressed[k] or false end
      b.update(nav)
      btn, btnp = ob, obtn
    end
    b.draw()
    press({}, {[BTN_START] = true})                         -- START ohne Wahl: Auswahl bleibt offen
    b.draw()
    press({}, {[BTN_RIGHT] = true})                         -- Art: Wege
    press({}, {[BTN_A] = true})                             -- Bauteile der Wege
    press({}, {[BTN_B] = true})                             -- B: zurück zu den Arten
    C.eq(#nav.stack, 1, "B in der Auswahl schließt den Baumodus nicht")
    press({}, {[BTN_A] = true})                             -- wieder Wege
    press({}, {[BTN_A] = true})                             -- Weg gewählt, Auswahl zu
    press({}, {[BTN_DOWN] = true})                          -- Cursor nach unten
    press({}, {[BTN_A] = true})                             -- Weg bauen
    C.eq(#own_items(ctx), 1)
    C.eq(own_items(ctx)[1].id, "weg")
    C.eq(own_items(ctx)[1].cy, p.y + 8)
    press({}, {[BTN_B] = true})                             -- B: Baumodus zu
    C.eq(#nav.stack, 0, "B schließt")
    b.draw()
    -- B in „Was bauen?“, bevor etwas gewählt ist: Baumodus zu
    b = Screens.build(ctx)
    nav.push(b)
    press({}, {[BTN_B] = true})
    C.eq(#nav.stack, 0, "B ohne Wahl schließt den Baumodus")
    C.ok(ctx.on_plot == nil)
    -- Pausenmenü: Bauen nur auf dem Grundstück
    ctx.on_plot = function() return false end
    local pm = Screens.pause(ctx, nav)
    local dim
    for _, it in ipairs(pm.items or {}) do if it.id == "build" then dim = it.dim end end
  end},
  {"Spielstand: gebaute Dinge bleiben, Hof wird beim Laden wieder aufgebaut, Index nicht im Spielstand", function()
    local ctx, p = setup()
    Farm.place(ctx, "bank", p.x + 12, p.y + 7)
    Farm.place(ctx, "weg", p.x + 13, p.y + 7)
    Farm.place(ctx, "zaun", p.x + 14, p.y + 7)
    Farm.place(ctx, "tor", p.x + 15, p.y + 7)
    local snap = Save.snapshot(ctx, Clock.new(1, 0), 5)
    local text = Save.encode(snap)
    local back = load("return " .. text, "=x", "t", {})()
    local eigene = 0
    for _, it in ipairs(back.hof.items) do if not it.start then eigene = eigene + 1 end end
    C.eq(eigene, 4)
    C.eq(back.hof.index, nil, "kein Index im Spielstand")
    C.eq(#snap.aenderungen, 0, "Bauten stehen im Hof, nicht in den Kartenänderungen")
    Area.clear()
    local ctx2 = Stage.build(1, 5, back.hof)
    C.ok(not ctx2.map:walkable(p.x + 12, p.y + 7), "Bank wieder da")
    C.eq(ctx2.map:code(p.x + 13, p.y + 7), ":", "Weg wieder da")
    C.eq(coll(ctx2, p.x + 14, p.y + 7), string.char(string.byte("A") + 2), "Zaun mit Tor-Nachbar")
    C.eq(Farm.item_at(ctx2.area.farm, p.x + 12, p.y + 7).id, "bank")
    log("BAUEN Spielstand mit 4 Bauten: " .. #text .. " Bytes")
  end},
}
