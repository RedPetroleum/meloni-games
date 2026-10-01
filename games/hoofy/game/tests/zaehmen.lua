-- Selbsttests für das Zähmen (Aufgabe A7, E16).
local Stage = require("game.stage")
local Wild = require("game.wild")
local Care = require("game.care")
local Leash = require("game.leash")
local C = require("game.tests.check")

local function setup(bindung)
  local ctx = Stage.build(1)
  local w = Wild.new(ctx, 3)
  w.count = 0
  local h = w:spawn_at(ctx.player.x + 60, ctx.player.y, {rasse = "haflinger", rng = w.rng})
  h.data.bindung = bindung or 35
  ctx.player.moving = false
  return ctx, w, h
end

-- Läuft Frames, bis das Pferd in Zustand state ist (höchstens max). Gibt die Frames zurück.
local function until_state(ctx, h, state, max_frames)
  for n = 1, max_frames do
    ctx.world:update()
    if h.state == state then return n end
  end
  error("Zustand " .. state .. " nicht erreicht, steht bei " .. h.state)
end

return {
  {"Wegschauen 2–4 s bei voller Bindung, bei niedriger kürzer", function()
    local function avg(bond)
      local sum, n = 0, 40
      for _ = 1, n do
        local ctx, w, h = setup(bond)
        h.data.bindung = bond
        ctx.world:update()                 -- betritt die Zone: away
        C.eq(h.state, "away")
        sum = sum + h.timer
      end
      return sum / n / 60
    end
    local full, low = avg(100), avg(10)
    C.between(full, 2, 4, "Bindung 100")
    C.ok(low < full * 0.7, "niedrige Bindung schaut kürzer weg")
    log(string.format("ZAEHMEN Wegschauen: Bindung 100 %.2f s, Bindung 10 %.2f s", full, low))
  end},
  {"Ablauf away → warn (0,3 s) → look (1–2 s) → away", function()
    local ctx, w, h = setup(100)
    until_state(ctx, h, "away", 5)
    until_state(ctx, h, "warn", 400)
    local warn = until_state(ctx, h, "look", 100)
    C.eq(warn, 18, "Warnung 0,3 s")
    local look = until_state(ctx, h, "away", 200)
    C.between(look, 60, 120, "Hinschauen 1–2 s")
  end},
  {"Bewegung beim Hinschauen: Pferd flieht und ist nicht zähmbar", function()
    local ctx, w, h = setup(35)
    until_state(ctx, h, "look", 600)
    ctx.player.moving = true
    h:update()                        -- (world:update würde moving zurücksetzen)
    C.eq(h.state, "flee")
    ctx.player.x, ctx.player.y = h.x - 10, h.y
    C.eq(w:try_tame(), nil, "auf der Flucht")
  end},
  {"Stillstehen und A in Reichweite zähmt, zu weit weg nicht", function()
    local ctx, w, h = setup(35)
    C.eq(w:try_tame(), nil, "60 px entfernt")
    until_state(ctx, h, "look", 600)
    ctx.player.x, ctx.player.y = h.x - 20, h.y
    C.ok(w:try_tame() == h, "gezähmt")
    C.eq(#w.list, 0, "nicht mehr wild")
    C.eq(#ctx.herd, 1, "im Bestand")
    C.eq(ctx.herd[1].wild, nil)
    C.ok(h.state == "led" or h.state == "follow", "kommt an die Leine (A8)")
  end},
  {"Frisch gezähmt: erst nach 3× Heu, Striegeln und Streicheln reitbar (E71)", function()
    local ctx, w, h = setup(35)
    until_state(ctx, h, "look", 600)
    ctx.player.x, ctx.player.y = h.x - 20, h.y
    C.ok(w:try_tame() == h, "gezähmt")
    C.eq(w:mount(h), "frisch", "gleich nach dem Zähmen")
    for _ = 1, 3 do Care.feed(h.data, "heu") end
    Care.brush(h.data)
    C.eq(w:mount(h), "frisch", "noch nicht ohne Streicheln")
    Care.stroke(h.data)
    C.eq(w:mount(h), "ok", "nach der Pflege")
    C.eq(h.data.reit_ab, nil, "nicht mehr frisch")
  end},
  {"Frisch gezähmt: Sprinten und Reiten an der Leine ×3, Gehen unverändert (E71)", function()
    C.near(Leash.chance10(35, "gehen", nil, true), Leash.chance10(35, "gehen"), 0.0001)
    C.near(Leash.chance10(35, "sprinten", nil, true), Leash.chance10(35, "sprinten") * 3, 0.0001)
    C.near(Leash.chance10(35, "reiten", nil, true), Leash.chance10(35, "reiten") * 3, 0.0001)
  end},
}
