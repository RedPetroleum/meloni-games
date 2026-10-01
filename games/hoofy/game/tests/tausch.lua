-- Selbsttests für den Tauschcode (Aufgabe E6): Hin- und Rückweg, Prüfsumme, Abgeben und Annehmen.
local Stage = require("game.stage")
local Area = require("game.area")
local Wild = require("game.wild")
local Tausch = require("game.tausch")
local K = require("game.katalog")
local H = require("game.horse_model")
local Rng = require("lib.rng")
local C = require("game.tests.check")

local function setup()
  Area.clear()
  local ctx = Stage.build(1, 81)
  ctx.wild = Wild.new(ctx, 3)
  ctx.wild.count = 0
  return ctx
end

local function same(a, b)
  for _, f in ipairs({"rasse", "sex", "zug", "farbe", "bindung"}) do C.eq(b[f], a[f], f) end
  C.eq(b.farbe2, a.farbe2 or a.farbe, "farbe2")
  for _, k in ipairs(H.STATS) do
    C.eq(b.gen[k], flr(a.gen[k] + 0.5), "gen " .. k)
    C.eq(b.pot[k], flr(a.pot[k] + 0.5), "pot " .. k)
    C.near(b.train[k], a.train[k], 0.5 + 1e-6, "train " .. k)
  end
end

return {
  {"1 000 Zufallspferde: Code hin und zurück, 28 Zeichen aus dem Alphabet", function()
    local rng = Rng.new(2024)
    for i = 1, 1000 do
      local d = H.wild({rng = rng, gebiet = 1 + i % 6})
      d.train = {tempo = rng:int(0, 20), staerke = rng:int(0, 20), spuer = rng:int(0, 20), ausdauer = rng:int(0, 20)}
      for _, k in ipairs(H.STATS) do d.train[k] = math.min(d.train[k], d.pot[k] - d.gen[k]) end
      d.bindung = rng:int(0, 100)
      d.id = string.format("%06d%03d", rng:int(0, 999999), i % 1000)
      d.alter = (i % 7 == 0) and rng:next() or 1
      local code = Tausch.encode(d)
      C.eq(#code, Tausch.LENGTH)
      C.ok(not code:find("[^ABCDEFGHJKLMNPQRSTUVWXYZ23456789]"), "Zeichen: " .. code)
      local back = Tausch.decode(code)
      C.ok(back ~= nil, "decode " .. i)
      same(d, back)
      C.near(back.alter, math.min(1, d.alter), 1 / 30 + 1e-6)
    end
  end},
  {"Falscher Code wird abgelehnt: Länge, Zeichen, Tippfehler (Prüfsumme)", function()
    local d = H.wild({rng = Rng.new(5)})
    d.id = "123456789"
    local code = Tausch.encode(d)
    local ok = Tausch.decode(Tausch.format(code):lower())
    C.ok(ok ~= nil, "Striche und Kleinbuchstaben sind okay")
    local _, why = Tausch.decode(code:sub(1, 27))
    C.eq(why, "Länge")
    _, why = Tausch.decode(code:sub(1, 27) .. "O")
    C.eq(why, "Zeichen")
    local bad = 0
    for i = 1, Tausch.LENGTH - 1 do         -- jedes Zeichen einzeln verfälschen: das Ergebnis darf nicht stillschweigend ein anderes Pferd sein
      local c = code:sub(i, i)
      local other = c == "A" and "B" or "A"
      local mod = code:sub(1, i - 1) .. other .. code:sub(i + 1)
      local back, w = Tausch.decode(mod)
      if back then bad = bad + 1 else C.eq(w == "Prüfsumme" or w == "ungültig", true) end
    end
    C.eq(bad, 0, "kein verfälschter Code geht durch")
    local transposed = code:sub(1, 3) .. code:sub(5, 5) .. code:sub(4, 4) .. code:sub(6)
    if transposed ~= code then C.ok(Tausch.decode(transposed) == nil, "Vertauschte Zeichen fallen auf") end
  end},
  {"Abgeben: Pferd und Ausrüstung weg, Code gesperrt; Annehmen: Pferd folgt, doppelt nicht", function()
    local ctx = setup()
    local h = ctx.wild:add_own({rasse = "friese", name = "Mona", bindung = 61})
    h.data.sattel, h.data.lampe = "einfacher_sattel", true
    local d = h.data
    local code = Tausch.abgeben(ctx, d)
    C.ok(code and #code == Tausch.LENGTH)
    C.eq(#ctx.herd, 0)
    C.eq(#ctx.herd_horses, 0)
    C.eq(ctx.inv.einfacher_sattel, 1, "Sattel zurück im Vorrat")
    C.eq(ctx.inv.sattellampe, 1)
    local again, why = Tausch.annehmen(ctx, code)
    C.ok(not again and why == "schon benutzt", "auf diesem Hof schon eingelöst")
    -- anderer Spieler (neuer Hof)
    local other = setup()
    local got = Tausch.annehmen(other, Tausch.format(code))
    C.ok(got ~= nil)
    C.eq(#other.herd, 1)
    local nd = other.herd[1]
    C.eq(nd.rasse, "friese")
    C.eq(nd.bindung, 61)
    C.eq(nd.sattel, nil, "Ausrüstung bleibt beim Absender")
    C.ok(nd.name and #nd.name > 0)
    local dup, why2 = Tausch.annehmen(other, code)
    C.ok(not dup and why2 == "schon benutzt")
    local bad, why3 = Tausch.annehmen(other, "AAAA-BBBB")
    C.ok(not bad and why3 == "Länge")
  end},
  {"Tauschbildschirm: Abgeben mit Rückfrage und Code anzeigen", function()
    local Screens = require("game.screens")
    local ctx = setup()
    ctx.wild:add_own({rasse = "haflinger", name = "Hilde"})
    local nav = {stack = {}}
    function nav.push(s) nav.stack[#nav.stack + 1] = s end
    function nav.pop() nav.stack[#nav.stack] = nil end
    local s = Screens.tausch(ctx)
    nav.push(s)
    local old = btnp
    local function key(k) btnp = function(b) return b == k end; s.update(nav) s.draw() end
    key(BTN_A)                                   -- Pferd abgeben
    key(BTN_A)                                   -- Hilde
    key(BTN_UP)                                  -- Ja
    C.eq(#ctx.herd, 1, "noch da")
    key(BTN_A)
    C.eq(#ctx.herd, 0)
    key(BTN_A)                                   -- Code schließen
    key(BTN_DOWN) key(BTN_A)                     -- Code eingeben (Tastatur)
    C.eq(#nav.stack, 2)
    btnp = old
  end},
}
