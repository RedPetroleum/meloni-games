-- Selbsttests für Töne (Aufgabe A16): die Aufrufe passieren zur richtigen Zeit. Gehört wird es im WAV.
local Stage = require("game.stage")
local Wild = require("game.wild")
local Ride = require("game.ride")
local SFX = require("game.sfx")
local C = require("game.tests.check")

local function press(keys, fn)
  local old = btn
  btn = function(b) return keys[b] or false end
  fn()
  btn = old
end

-- Zählt Aufrufe einer SFX-Funktion während fn läuft.
local function count(name, fn)
  local n, old = 0, SFX[name]
  SFX[name] = function(...) n = n + 1 end
  fn()
  SFX[name] = old
  return n
end

local function riding()
  local ctx = Stage.build(1)
  local w = Wild.new(ctx, 3)
  w.count = 0
  local h = w:add_own({bindung = 80})
  w:attach(h)
  Ride.mount(ctx, h)
  -- freie Bahn: Streifen zwischen Stall und Weide
  local pl = ctx.area.plot
  ctx.player.x, ctx.player.y = (pl.x + 2) * 16, (pl.y + 7) * 16 + 8
  return ctx, h
end

return {
  {"Hufschlag: Galopp dichter als Schritt, keiner im Stand", function()
    local ctx, h = riding()
    local walk = count("hoof", function()
      press({[BTN_RIGHT] = true}, function() for _ = 1, 120 do ctx.player:update() end end)
    end)
    local gallop = count("hoof", function()
      press({[BTN_LEFT] = true, [BTN_B] = true}, function() for _ = 1, 120 do ctx.player:update() end end)
    end)
    local stand = count("hoof", function()
      press({}, function() for _ = 1, 120 do ctx.player:update() end end)
    end)
    C.between(walk, 7, 9, "Schritt: alle 15 Frames")
    C.between(gallop, 14, 16, "Galopp: alle 8 Frames")
    C.eq(stand, 0, "im Stand")
  end},
  {"Sprung und Landung machen je ein Geräusch", function()
    local ctx, h = riding()
    local j, l = 0, 0
    local oj, ol = SFX.jump, SFX.land
    SFX.jump, SFX.land = function() j = j + 1 end, function() l = l + 1 end
    Ride.jump(ctx.player)
    press({}, function() for _ = 1, 50 do ctx.player:update() end end)
    SFX.jump, SFX.land = oj, ol
    C.eq(j, 1, "Sprung")
    C.eq(l, 1, "Landung")
  end},
  {"Musik wechselt Tag/Nacht, doppelter Aufruf startet nicht neu, alle Geräusche laufen", function()
    local starts, old = 0, tune
    tune = function(...) starts = starts + 1 return old(...) end
    SFX.music("day")
    SFX.music("day")
    SFX.music("night")
    SFX.music("night")
    SFX.music(nil)
    tune = old
    C.eq(starts, 2, "Tag und Nacht je einmal")
    for _, name in ipairs({"select", "ok", "back", "start", "key", "whinny", "snort", "warn", "tame", "snap",
      "jump", "land", "mount", "eat", "brush", "pet", "dusk", "dawn"}) do
      SFX[name]()
    end
    for i = 1, 4 do SFX.hoof(i % 2 == 0, i) end
  end},
}
