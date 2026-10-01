-- Selbsttests für Stammbaum und Inzucht (Aufgabe B7).
local Breeding = require("game.breeding")
local Stage = require("game.stage")
local Wild = require("game.wild")
local Save = require("game.save")
local Clock = require("game.clock")
local K = require("game.katalog")
local H = require("game.horse_model")
local Rng = require("lib.rng")
local C = require("game.tests.check")

local rng = Rng.new(31)
local n = 0

local function wildhorse(name, sex)
  local d = H.wild({rng = rng, rasse = "haflinger", sex = sex or (n % 2 == 0 and "m" or "w")})
  n = n + 1
  d.name, d.id = name, "W" .. n
  d.alter = 1
  return d
end

local function kid(f, m, name)
  local d = Breeding.foal(f, m, rng, 0)
  n = n + 1
  d.name, d.id, d.alter = name, "K" .. n, 1
  return d
end

return {
  {"Verwandtschaft: Eltern/Kind −15, Geschwister −15, Halbgeschwister −8, Großeltern −8, Cousins −3", function()
    local v1, m1, v2, m2, v3, m3 = wildhorse("V1"), wildhorse("M1"), wildhorse("V2"), wildhorse("M2"), wildhorse("V3"), wildhorse("M3")
    local a, b = kid(v1, m1, "A"), kid(v1, m1, "B")                -- Vollgeschwister
    local halb = kid(v1, m2, "Halb")                               -- Halbgeschwister von A
    local unrelated = wildhorse("Fremd")
    C.eq((Breeding.verwandtschaft(a, b)), 15, "Geschwister")
    C.eq(select(2, Breeding.verwandtschaft(a, b)), "Geschwister")
    C.eq((Breeding.verwandtschaft(a, halb)), 8, "Halbgeschwister")
    C.eq((Breeding.verwandtschaft(v1, a)), 15, "Vater und Kind")
    C.eq((Breeding.verwandtschaft(a, m1)), 15, "Kind und Mutter")
    C.eq((Breeding.verwandtschaft(a, unrelated)), 0, "Fremde")
    C.eq((Breeding.verwandtschaft(v1, m1)), 0, "die Eltern selbst sind nicht verwandt")
    -- Enkel und Großeltern
    local c = kid(a, wildhorse("Partner"), "Enkel")
    C.eq((Breeding.verwandtschaft(c, v1)), 8, "Enkel und Großvater")
    C.eq((Breeding.verwandtschaft(m1, c)), 8, "Großmutter und Enkel")
    -- Cousins: Kinder von Geschwistern
    local d = kid(b, wildhorse("Partnerin"), "Cousin")
    C.eq((Breeding.verwandtschaft(c, d)), 3, "Cousins")
    C.eq(select(2, Breeding.verwandtschaft(c, d)), "Cousins")
    C.eq((Breeding.verwandtschaft(c, unrelated)), 0)
  end},
  {"Inzucht-Malus senkt die Gen-Stats des Fohlens (−15 %: Mittel 50 → 42,5)", function()
    local f, m = wildhorse("V", "m"), wildhorse("M", "w")
    for _, k in ipairs(H.STATS) do f.gen[k], m.gen[k] = 50, 50 end
    local r = Rng.new(2)
    local function mean(malus)
      local sum, cnt = 0, 3000
      for _ = 1, cnt do sum = sum + Breeding.foal(f, m, r, malus).gen.tempo end
      return sum / cnt
    end
    C.near(mean(0), 50, 0.4)
    C.near(mean(15), 42.5, 0.4)
    C.near(mean(8), 46, 0.4)
    C.near(mean(3), 48.5, 0.4)
  end},
  {"Paarung von Bruder und Schwester: Fohlen bekommt den Malus aus dem Stammbaum", function()
    local ctx = Stage.build(1, 5)
    local w = Wild.new(ctx, 3)
    w.count = 0
    local v, m = wildhorse("Vater", "m"), wildhorse("Mutter", "w")
    local bruder, schwester = kid(v, m, "Bruder"), kid(v, m, "Schwester")
    bruder.sex, schwester.sex = "m", "w"
    for _, d in ipairs({bruder, schwester}) do
      for _, k in ipairs(H.STATS) do d.gen[k] = 60 end
      d.ort = "stall"
      w:adopt(d)
      d.ort = "stall"
    end
    C.ok(Breeding.start(ctx, bruder, schwester, 1))
    local Days = require("game.days")
    C.eq(Breeding.inzucht_malus(schwester.traechtig.vater, schwester), 15)
    Days.new_day(ctx, 3)
    local foal = ctx.herd[#ctx.herd]
    C.eq(foal.ahnen.v.name, "Bruder")
    C.eq(foal.ahnen.v.v.name, "Vater", "Großvater im Baum")
    C.ok(foal.gen.tempo <= 60 * 0.85 + 6 * 4, "deutlich unter dem Elternwert (Malus wirkt)")
  end},
  {"Stammbaum bleibt auf 3 Ebenen begrenzt und klein (8 Generationen)", function()
    local a, b = wildhorse("A", "m"), wildhorse("B", "w")
    local last
    for g = 1, 8 do
      last = kid(a, b, "G" .. g)
      a, b = last, wildhorse("P" .. g, g % 2 == 0 and "m" or "w")
    end
    local function depth(node)
      if not node then return 0 end
      return 1 + max(depth(node.v), depth(node.m))
    end
    C.eq(depth(last.ahnen.v), 3, "Eltern, Großeltern, Urgroßeltern")
    C.eq(depth(last.ahnen.m), 1, "die Mutter ist immer ein Wildfang ohne Ahnen")
    local text = Save.encode(last)
    C.ok(#text < 2500, "Fohlen mit Stammbaum unter 2,5 KB: " .. #text)
    log("STAMMBAUM Pferd mit 3 Generationen Ahnen: " .. #text .. " Bytes")
  end},
  {"Wildfang ohne Ahnen, Stammbaum-Bildschirm zeichnet, Info öffnet ihn mit Runter, ↑ schließt, ← → blättert", function()
    local Screens = require("game.screens")
    local ctx = Stage.build(1)
    ctx.clock = Clock.new(1, 0)
    local wilder = wildhorse("Wildfang")
    Screens.stammbaum(ctx, wilder).draw()
    local z = kid(wildhorse("Z1"), wildhorse("Z2"), "Enkel")
    Screens.stammbaum(ctx, z).draw()
    local nav = {stack = {}}
    function nav.push(s) nav.stack[#nav.stack + 1] = s end
    function nav.pop() nav.stack[#nav.stack] = nil end
    local info = Screens.info(ctx, z)
    nav.push(info)
    local old = btnp
    btnp = function(b) return b == BTN_DOWN end
    info.update(nav)
    btnp = old
    C.eq(#nav.stack, 2, "Stammbaum offen")
    btnp = function(b) return b == BTN_UP end
    nav.stack[2].update(nav)
    btnp = old
    C.eq(#nav.stack, 1)
    -- Blättern durch die eigenen Pferde (umlaufend)
    local a, b = wildhorse("Anna"), wildhorse("Berta")
    ctx.herd = {a, b}
    local inf = Screens.info(ctx, a)
    local function names_after(key)
      btnp = function(k) return k == key end
      inf.update(nav)
      btnp = old
      local seen
      local op = print
      print = function(t, ...) if t == "Anna" or t == "Berta" then seen = t end return op(t, ...) end
      inf.draw()
      print = op
      return seen
    end
    C.eq(names_after(BTN_RIGHT), "Berta")
    C.eq(names_after(BTN_RIGHT), "Anna", "umlaufend")
    C.eq(names_after(BTN_LEFT), "Berta")
    cls()
  end},
}
