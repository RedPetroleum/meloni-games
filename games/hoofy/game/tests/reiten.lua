-- Selbsttests für das Reiten (Aufgabe A9): Energie, Sattel, Verweigern, Springen.
local Stage = require("game.stage")
local Wild = require("game.wild")
local Ride = require("game.ride")
local Rng = require("lib.rng")
local C = require("game.tests.check")

-- Spieler mit aufgesessenem Pferd (Haflinger, Bindung 80) am Hof.
local function setup(opts)
  opts = opts or {}
  local ctx = Stage.build(1)
  local w = Wild.new(ctx, 3)
  w.count = 0
  local h = w:spawn_at(ctx.player.x + 10, ctx.player.y, {rasse = "haflinger", rng = w.rng})
  table.remove(w.list)
  h.wild, h.data.wild, h.tamed = false, nil, true
  h.data.bindung = opts.bindung or 80
  h.data.sattel = opts.sattel
  if opts.staerke then h.data.gen.staerke, h.data.pot.staerke, h.data.train.staerke = opts.staerke, 100, 0 end
  ctx.herd[1], ctx.herd_horses[1] = h.data, h
  w:attach(h)
  return ctx, w, h
end

local function press(keys, fn)
  local old = btn
  btn = function(b) return keys[b] or false end
  fn()
  btn = old
end

return {
  {"Sattel-Bonus: Tempo +5 einfach … +20 Gold, zählt über das Potenzial", function()
    local _, _, h = setup()
    local base = Ride.tempo(h.data)
    C.eq(base, h.data.gen.tempo, "ohne Sattel")
    h.data.sattel = "einfacher_sattel"
    C.eq(Ride.tempo(h.data), base + 5)
    h.data.sattel = "goldsattel"
    C.eq(Ride.tempo(h.data), base + 20)
    h.data.pot.tempo = h.data.gen.tempo
    C.eq(Ride.tempo(h.data), base + 20, "über Max-Potenzial")
    local walk0, gal0 = Ride.speeds({gen = {tempo = 30}, train = {tempo = 0}, pot = {tempo = 60}})
    local walk1, gal1 = Ride.speeds({gen = {tempo = 30}, train = {tempo = 0}, pot = {tempo = 60}, sattel = "rennsattel"})
    C.ok(walk1 > walk0 and gal1 > gal0 and gal0 > walk0, "schneller mit Sattel, Galopp schneller als Schritt")
  end},
  {"Energie: Reiten 1 je 10 s, Galopp doppelt, Sprung 5", function()
    local ctx, w, h = setup()
    local d = h.data
    d.energie = 80
    Ride.mount(ctx, h)
    press({[BTN_RIGHT] = true}, function() for _ = 1, 600 do ctx.player:update() end end)
    C.near(d.energie, 79, 0.05, "600 Frames Schritt")
    d.energie = 80
    press({[BTN_RIGHT] = true, [BTN_B] = true}, function() for _ = 1, 600 do ctx.player:update() end end)
    C.near(d.energie, 78, 0.05, "600 Frames Galopp")
    d.energie = 80
    C.ok(Ride.jump(ctx.player), "Sprung")
    C.eq(d.energie, 75, "Sprung kostet 5")
    d.energie = 4
    ctx.player.jump_t = 0
    C.ok(not Ride.jump(ctx.player), "zu wenig Energie")
  end},
  {"Erschöpftes Pferd (Energie 0) galoppiert nicht", function()
    local ctx, w, h = setup()
    h.data.energie = 0
    Ride.mount(ctx, h)
    local x0 = ctx.player.x
    press({[BTN_RIGHT] = true, [BTN_B] = true}, function() for _ = 1, 60 do ctx.player:update() end end)
    local walk = Ride.speeds(h.data)
    C.ok(ctx.player.x - x0 < walk * 60, "langsamer als Schritt")
  end},
  {"Bindung < 20 verweigert zu 50 %, sonst nie", function()
    local rng = Rng.new(3)
    local n, refused = 10000, 0
    for _ = 1, n do if Ride.refuses({bindung = 10}, rng) then refused = refused + 1 end end
    C.near(refused / n * 100, 50, 2, "Bindung 10")
    for _ = 1, 500 do C.ok(not Ride.refuses({bindung = 20}, rng), "Bindung 20") end
  end},
  {"Springen nach Stärke: Busch (12) ja ab Stärke 20, Zaun (18) erst ab 40, Baum nie", function()
    local function crosses(staerke, char)
      local ctx, w, h = setup({staerke = staerke})
      local p = ctx.player
      Ride.mount(ctx, h)
      -- Hindernis 1 Kachel rechts vom Spieler, lang genug zum Überspringen
      local cx, cy = p.x // 16 + 3, p.y // 16
      for dy = -1, 1 do ctx.map:set("coll", cx, cy + dy, char) end
      Ride.jump(p)
      local x0 = p.x
      press({[BTN_RIGHT] = true, [BTN_B] = true}, function()
        for _ = 1, 45 do ctx.player:update() end
      end)
      return p.x > (cx + 1) * 16 + 4, p.jump_t
    end
    C.ok(crosses(50, "u"), "Stärke 50 über Busch")
    C.ok(not crosses(10, "u"), "Stärke 10 nicht über Busch (8,... < 12)")
    C.ok(crosses(50, "A"), "Stärke 50 über Zaun")
    C.ok(not crosses(25, "A"), "Stärke 25 nicht über Zaun (13,5 < 18)")
    C.ok(not crosses(100, "T"), "Baum nie")
  end},
  {"Aufsteigen und Absteigen", function()
    local ctx, w, h = setup()
    local p = ctx.player
    h.x, h.y = p.x + 12, p.y
    local m, res = w:try_mount()
    C.ok(m == h and res == "ok", "aufgestiegen")
    C.eq(p.riding, h)
    C.eq(#ctx.lead, 0, "nicht mehr an der Leine")
    Ride.dismount(ctx)
    C.eq(p.riding, nil)
    C.ok(h.state == "led" or h.state == "follow", "wieder an der Leine")
    C.eq(p.fw, 8)
    h.data.bindung = 5
    local refused = 0
    for _ = 1, 40 do
      local m2, r2 = w:try_mount()
      if r2 == "verweigert" then refused = refused + 1 elseif p.riding then Ride.dismount(ctx) end
    end
    C.between(refused, 8, 32, "Verweigern bei Bindung 5")
  end},
}
