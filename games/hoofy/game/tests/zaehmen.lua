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

-- Zähmt h wie im Spiel: Spieler 20 px daneben, A drücken, während es wegschaut, dann halten.
local function tame(ctx, w, h)
  until_state(ctx, h, "away", 600)
  ctx.player.x, ctx.player.y = h.x - 20, h.y
  ctx.player.moving = false
  C.ok(w:tame_target() == h, "in Reichweite")
  C.ok(w:tame_begin(h), "beginnt beim Wegschauen")
  for n = 1, 400 do
    ctx.player.moving = false
    local r = w:tame_step(h, true)
    if r == "ok" then return n end
    C.ok(r == nil, "bricht nicht ab")
  end
  error("nicht gezähmt")
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
    C.eq(w:tame_target(), nil, "auf der Flucht")
  end},
  {"A halten und stillstehen zähmt nach 1,5 s + 1 Frame je fehlendem Bindungspunkt, zu weit weg nicht", function()
    local ctx, w, h = setup(35)
    C.eq(w:tame_target(), nil, "60 px entfernt")
    C.eq(tame(ctx, w, h), Wild.tame_frames(35))
    C.eq(Wild.tame_frames(35), 155)
    C.eq(#w.list, 0, "nicht mehr wild")
    C.eq(#ctx.herd, 1, "im Bestand")
    C.eq(ctx.herd[1].wild, nil)
    C.ok(h.state == "led" or h.state == "follow", "kommt an die Leine (A8)")
  end},
  {"Frisch gezähmt: erst nach 3× Heu, Striegeln und Streicheln reitbar (E71)", function()
    local ctx, w, h = setup(35)
    tame(ctx, w, h)
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
  {"Schwerer zähmen: A beim Hinschauen verscheucht es, Sprinten in der Zone auch; Loslassen oder Gehen bricht ab", function()
    local ctx, w, h = setup(35)
    until_state(ctx, h, "look", 600)
    ctx.player.x, ctx.player.y = h.x - 20, h.y
    C.ok(not w:tame_begin(h), "sieht die Hand")
    C.eq(h.state, "flee")
    ctx, w, h = setup(35)
    ctx.world:update()
    C.eq(h.state, "away")
    ctx.player.running, ctx.player.moving = true, true
    h:update()
    C.eq(h.state, "flee", "Sprinten verscheucht")
    ctx, w, h = setup(35)
    until_state(ctx, h, "away", 5)
    ctx.player.x, ctx.player.y = h.x - 20, h.y
    C.ok(w:tame_begin(h))
    C.eq(w:tame_step(h, true), nil)
    C.eq(w:tame_step(h, false), "weg", "losgelassen")
    C.ok(w:tame_begin(h))
    ctx.player.moving = true
    C.eq(w:tame_step(h, true), "weg", "bewegt")
    C.eq(#ctx.herd, 0)
  end},
  {"Neu gezähmt reißt sich los: wieder wild, bis es einmal auf dem Grundstück war", function()
    local ctx, w, h = setup(35)
    tame(ctx, w, h)
    C.ok(h.data.neu, "neu")
    w:escape(h)
    C.ok(ctx.escaped_wild, "Meldung: wieder wild")
    C.eq(#ctx.herd, 0, "nicht mehr deins")
    C.eq(#ctx.lead, 0)
    C.ok(h.wild and not h.tamed and h.data.wild, "wild")
    C.eq(h.state, "flee")
    C.eq(h.data.bindung, 35, "Bindung wie vor dem Zähmen")
    C.eq(w.list[#w.list], h, "wieder bei den Wildpferden")
    C.eq(Wild.gezaehmt(ctx, w.gebiet), 0, "zählt nicht mehr als gezähmt")
    -- noch einmal zähmen, auf das Grundstück führen: dann bleibt es deins
    ctx.player.x, ctx.player.y = h.x + 60, h.y
    h.state, h.timer, h.cool = "graze", 60, 0
    tame(ctx, w, h)
    local plot = ctx.area.plot
    h.x, h.y = (plot.x + 10) * 16 + 8, (plot.y + 8) * 16 + 14
    for _ = 1, 31 do h:update() end
    C.eq(h.data.neu, nil, "auf dem Hof gewesen")
    w:escape(h)
    C.eq(#ctx.herd, 1, "bleibt deins")
    C.eq(h.state, "escape")
  end},
}
