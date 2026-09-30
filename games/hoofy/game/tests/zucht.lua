-- Selbsttests für die Zucht (Aufgabe B6): Voraussetzungen, Zeitplan, Vererbung, Farben, Rassen.
local Stage = require("game.stage")
local Wild = require("game.wild")
local Days = require("game.days")
local Breeding = require("game.breeding")
local K = require("game.katalog")
local H = require("game.horse_model")
local Rng = require("lib.rng")
local C = require("game.tests.check")

local function parent(sex, extra)
  local d = H.wild({rng = Rng.new(3), rasse = "haflinger", zug = "faul", sex = sex})
  d.gen = {tempo = 50, staerke = 50, spuer = 50, ausdauer = 75}
  d.train = {tempo = 0, staerke = 0, spuer = 0, ausdauer = 0}
  d.pot = {tempo = 90, staerke = 90, spuer = 90, ausdauer = 100}
  d.farbe, d.farbe2, d.alter, d.name = "fuchs", "rappe", 1, sex == "m" and "Vater" or "Mutter"
  for k, v in pairs(extra or {}) do d[k] = v end
  return d
end

local function farm()
  local ctx = Stage.build(1, 5)
  local w = Wild.new(ctx, 3)
  w.count = 0
  local m = w:add_own({rasse = "haflinger", name = "Mutter"})
  local f = w:add_own({rasse = "haflinger", name = "Vater"})
  m.data.sex, f.data.sex = "w", "m"
  m.data.ort, f.data.ort = "stall", "stall"
  m.hidden, f.hidden = true, true
  m.state, f.state = "stall", "stall"
  return ctx, w, m, f
end

return {
  {"Voraussetzungen: ausgewachsener Hengst und Stute, beide im Stall, Stute nicht trächtig/in Pause", function()
    local ctx, w, m, f = farm()
    C.ok(Breeding.stallion_ok(f.data) and Breeding.mare_ok(m.data, 1))
    f.data.alter = 0.5
    C.ok(not Breeding.stallion_ok(f.data), "Fohlen als Hengst")
    f.data.alter = 1
    m.data.ort = nil
    C.ok(not Breeding.mare_ok(m.data, 1), "nicht im Stall")
    m.data.ort = "stall"
    C.ok(not Breeding.mare_ok(parent("m", {ort = "stall"}), 1), "Hengst ist keine Stute")
    C.ok(Breeding.start(ctx, f.data, m.data, 1))
    C.ok(not Breeding.mare_ok(m.data, 1), "trächtig")
    local ok, why = Breeding.start(ctx, f.data, m.data, 1)
    C.ok(not ok and why == "Stute nicht bereit")
    C.eq(#Breeding.stallions(ctx.herd), 1)
    C.eq(#Breeding.mares(ctx.herd, 1), 0)
  end},
  {"Zeitplan: 2 Tage trächtig, dann 3 Tage Pause, Fohlen wächst in 4 Tagen aus", function()
    local ctx, w, m, f = farm()
    local day = 10
    Breeding.start(ctx, f.data, m.data, day)
    C.eq(m.data.traechtig.tag, 12)
    Days.new_day(ctx, 11)
    C.eq(#ctx.herd, 2, "noch kein Fohlen an Tag 11")
    Days.new_day(ctx, 12)
    C.eq(#ctx.herd, 3, "Fohlen an Tag 12")
    C.eq(m.data.traechtig, nil)
    C.eq(m.data.zucht_pause, 15)
    C.ok(not Breeding.mare_ok(m.data, 14), "Tag 14 noch Pause")
    C.ok(Breeding.mare_ok(m.data, 15), "Tag 15 wieder bereit")
    local foal = ctx.herd[3]
    C.eq(foal.alter, 0, "Fohlen")
    C.eq(#ctx.geburten, 1)
    for d = 13, 16 do Days.new_day(ctx, d) end
    C.near(foal.alter, 1, 1e-6, "nach 4 Tagen ausgewachsen")
    C.ok(Breeding.stallion_ok({sex = "m", alter = foal.alter, ort = "stall"}), "danach zuchtfähig")
  end},
  {"Gen-Stats ≈ Mittel der Eltern, σ ≈ 6 (5 000 Fohlen)", function()
    local f, m = parent("m"), parent("w")
    f.gen.tempo, m.gen.tempo = 40, 60
    local rng = Rng.new(21)
    local sum, sq, n = 0, 0, 5000
    for _ = 1, n do
      local d = Breeding.foal(f, m, rng, 0)
      sum = sum + d.gen.tempo
    end
    local mean = sum / n
    rng = Rng.new(21)
    for _ = 1, n do sq = sq + (Breeding.foal(f, m, rng, 0).gen.tempo - mean) ^ 2 end
    C.near(mean, 50, 0.3, "Mittel 50")
    C.near(math.sqrt(sq / n), 6, 0.4, "σ 6")
    log(string.format("ZUCHT Fohlen-Tempo Mittel %.2f σ %.2f (Eltern 40 und 60)", mean, math.sqrt(sq / n)))
  end},
  {"Potenzial ≤ 100 und ≥ Gen, Ausdauer 50–100, Zustände, Stammbaum der Eltern im Fohlen", function()
    local f, m = parent("m", {id = "V1"}), parent("w", {id = "M1"})
    f.gen.ausdauer, m.gen.ausdauer = 98, 99
    local rng = Rng.new(4)
    for _ = 1, 500 do
      local d = Breeding.foal(f, m, rng, 0)
      for _, k in ipairs(H.STATS) do
        C.ok(d.pot[k] <= 100 and d.pot[k] >= d.gen[k], "Potenzial")
        C.between(d.gen[k], k == "ausdauer" and 50 or 1, 100, k)
      end
      C.eq(d.alter, 0)
      C.eq(d.hunger, 30)
      C.eq(d.ahnen.v.id, "V1")
      C.eq(d.ahnen.m.name, "Mutter")
    end
  end},
  {"Rasse 50:50 von Vater oder Mutter, Geschlecht 50:50", function()
    local f, m = parent("m", {rasse = "mustang"}), parent("w", {rasse = "noriker"})
    local rng = Rng.new(8)
    local vater, hengst, n = 0, 0, 10000
    for _ = 1, n do
      local d = Breeding.foal(f, m, rng, 0)
      if d.rasse == "mustang" then vater = vater + 1 else C.eq(d.rasse, "noriker") end
      if d.sex == "m" then hengst = hengst + 1 end
    end
    C.near(vater / n * 100, 50, 2, "Rasse des Vaters")
    C.near(hengst / n * 100, 50, 2, "Hengste")
  end},
  {"Farbanteile 35/15/35/15 % (Vater sichtbar/versteckt, Mutter sichtbar/versteckt)", function()
    local rng = Rng.new(99)
    local n = 20000
    local count = {a = 0, b = 0, c = 0, d = 0, other = 0}
    -- vier verschiedene Farben aus derselben Stufe, Mutation trifft nur einen kleinen Rest
    for _ = 1, n do
      local shown = Breeding.foal_colors("brauner", "fuchs", "dunkelbrauner", "rappe", rng)
      if shown == "brauner" then count.a = count.a + 1
      elseif shown == "fuchs" then count.b = count.b + 1
      elseif shown == "dunkelbrauner" then count.c = count.c + 1
      elseif shown == "rappe" then count.d = count.d + 1
      else count.other = count.other + 1 end
    end
    log(string.format("ZUCHT Farben: Vater sichtbar %.1f %%, versteckt %.1f %%, Mutter sichtbar %.1f %%, versteckt %.1f %%, Mutation %.1f %%",
      count.a / n * 100, count.b / n * 100, count.c / n * 100, count.d / n * 100, count.other / n * 100))
    C.near(count.a / n * 100, 35, 2, "sichtbare vom Vater")
    C.near(count.b / n * 100, 15, 2, "versteckte vom Vater")
    C.near(count.c / n * 100, 35, 2, "sichtbare von der Mutter")
    C.near(count.d / n * 100, 15, 2, "versteckte von der Mutter")
  end},
  {"Mutation 1 % zur nächsten Stufe, das Fohlen trägt die andere Farbe versteckt", function()
    local rng = Rng.new(5)
    local n, mut, same_tier = 50000, 0, 0
    for _ = 1, n do
      local shown, hidden = Breeding.foal_colors("brauner", "brauner", "brauner", "brauner", rng)
      C.eq(hidden, "brauner")
      if shown ~= "brauner" then
        mut = mut + 1
        C.eq(K.farbe(shown).stufe, 2, "Mutation führt in die nächste Stufe")
      end
    end
    C.near(mut / n * 100, 1, 0.2, "Mutationsrate")
    local s, h = Breeding.foal_colors("gold", "gold", "gold", "gold", rng)
    C.eq(s, "gold", "höchste Stufe mutiert nicht")
  end},
  {"Zucht im Spiel: Fohlen an der Leine, Stammbaum, Spielstand mit Trächtigkeit", function()
    local ctx, w, m, f = farm()
    Breeding.start(ctx, f.data, m.data, 1)
    local Save = require("game.save")
    local Clock = require("game.clock")
    local snap = Save.snapshot(ctx, Clock.new(1, 0), 5)
    local back = load("return " .. Save.encode(snap), "=x", "t", {})()
    local mare_back
    for _, d in ipairs(back.herd) do if d.traechtig then mare_back = d end end
    C.ok(mare_back and mare_back.traechtig.tag == 3 and mare_back.traechtig.vater.name == "Vater", "Trächtigkeit im Spielstand")
    Days.new_day(ctx, 3)
    local foal = ctx.herd[3]
    C.eq(foal.ahnen.v.name, "Vater")
    C.ok(foal.id and foal.id ~= m.data.id and foal.id ~= f.data.id, "eigene Kennung")
    local h = ctx.herd_horses[3]
    C.ok(h.state == "led" or h.state == "follow", "Fohlen folgt")
    -- 24 Pferde: unbegrenzte Fohlen gibt es nicht
    C.ok(#ctx.herd <= 24)
    local Screens = require("game.screens")
    Screens.info(ctx, m.data).draw()
    Screens.info(ctx, foal).draw()
  end},
}
