-- Selbsttests für Leine und Folgen (Aufgabe A8).
local Stage = require("game.stage")
local Wild = require("game.wild")
local Leash = require("game.leash")
local Rng = require("lib.rng")
local C = require("game.tests.check")

-- Anteil der 10-s-Fenster (mit je 10 Sekunden-Würfen), in denen das Pferd ausreißt.
local function rate(bindung, mode, zug, windows)
  local rng = Rng.new(11)
  local hits = 0
  for _ = 1, windows do
    for _ = 1, 10 do
      if Leash.escape_roll(bindung, mode, zug, rng) then hits = hits + 1 break end
    end
  end
  return hits / windows * 100
end

local function setup(bindung)
  local ctx = Stage.build(1)
  local w = Wild.new(ctx, 3)
  w.count = 0
  local h = w:spawn_at(ctx.player.x + 20, ctx.player.y, {rasse = "haflinger", rng = w.rng})
  h.data.bindung = bindung
  h.tamed, h.data.wild = true, nil
  ctx.herd[1], ctx.herd_horses[1] = h.data, h
  w:attach(h)
  return ctx, w, h
end

return {
  {"Ausreiß-Chance laut Katalog: Bindung 10 → 9 % gehend, 27 % reitend, sprinten ×2", function()
    C.near(Leash.chance10(10, "gehen") * 100, 9, 0.001)
    C.near(Leash.chance10(10, "sprinten") * 100, 18, 0.001)
    C.near(Leash.chance10(10, "reiten") * 100, 27, 0.001)
    C.near(Leash.chance10(10, "gehen", "schreckhaft") * 100, 13.5, 0.001)
    C.near(Leash.chance10(100, "reiten"), 0, 0.001)
  end},
  {"Ausreiß-Rate über 20 000 Fenster à 10 s ≈ 9 % / 27 % (Bindung 10)", function()
    local walk, ride = rate(10, "gehen", nil, 20000), rate(10, "reiten", nil, 20000)
    log(string.format("LEINE Ausreißen Bindung 10: gehend %.1f %%, reitend %.1f %%", walk, ride))
    C.near(walk, 9, 1, "gehend")
    C.near(ride, 27, 1.5, "reitend")
    C.near(rate(50, "gehen", nil, 20000), 5, 0.8, "Bindung 50")
  end},
  {"Geführtes Pferd hält den Abstand der Leine ein und folgt um Ecken", function()
    local ctx, w, h = setup(10)
    C.eq(h.state, "led")
    h.data.bindung = 100                                   -- reißt nicht aus
    h.state = "led"
    local p = ctx.player
    for f = 1, 240 do
      p.moving = true
      if f < 120 then p.x = p.x + 1.2 else p.y = p.y + 1.2 end
      ctx.trail:push(p.x, p.y)
      ctx.world:update()
      h.leash_t = 0
    end
    local d = math.sqrt((h.x - p.x) ^ 2 + (h.y - p.y) ^ 2)
    C.between(d, 20, 50, "Abstand zum Spieler")
  end},
  {"Reißt die Leine: Pferd läuft weg, bleibt lose, A leint wieder an", function()
    local ctx, w, h = setup(0)
    h.data.bindung = 0
    h.data.zug = "schreckhaft"
    local n = 0
    repeat
      n = n + 1
      h.leash_t = 59
      ctx.world:update()
    until h.state == "escape" or n > 2000
    C.eq(h.state, "escape")
    C.eq(#ctx.lead, 0, "nicht mehr an der Leine")
    for _ = 1, 400 do ctx.world:update() end
    C.eq(h.state, "free")
    ctx.player.x, ctx.player.y = h.x - 10, h.y
    C.ok(w:try_leash() == h, "wieder anleinen")
    C.eq(#ctx.lead, 1)
  end},
  {"Bindung ≥ 70 folgt ohne Leine und reißt nie aus, ≥ 90 kommt auf Pfiff", function()
    local ctx, w, h = setup(70)
    C.eq(h.state, "follow")
    for _ = 1, 3000 do ctx.world:update() end
    C.eq(h.state, "follow", "reißt nicht aus")
    local ctx2, w2, h2 = setup(95)
    w2:escape(h2)
    for _ = 1, 200 do ctx2.world:update() end
    C.ok(h2.state == "free", "lose")
    C.eq(w2:whistle(), 1, "Pfiff holt es")
    C.eq(h2.state, "follow")
    local ctx3, w3, h3 = setup(75)
    w3:escape(h3)
    for _ = 1, 200 do ctx3.world:update() end
    C.eq(w3:whistle(), 0, "Bindung 75 kommt nicht auf Pfiff")
  end},
}
