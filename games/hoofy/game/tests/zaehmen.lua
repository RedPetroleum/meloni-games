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

-- Zähmt h wie im Spiel: Spieler 20 px daneben, A drücken und still halten.
local function tame(ctx, w, h)
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
  {"A halten und stillstehen zähmt nach 1,5 s + 1 Frame je fehlendem Bindungspunkt, zu weit weg nicht", function()
    local ctx, w, h = setup(35)
    C.eq(w:tame_target(), nil, "60 px entfernt")
    C.eq(tame(ctx, w, h), Wild.tame_frames(35))
    C.eq(Wild.tame_frames(35), 155)
    C.eq(#w.list, 0, "nicht mehr wild")
    C.eq(#ctx.herd, 1, "im Bestand")
    C.eq(ctx.herd[1].wild, nil)
    C.ok(h.state == "led" or h.state == "follow", "kommt an die Leine (A8)")
    C.eq(require("game.bubbles").choose(h, frame()), "emo_heart", "zeigt ein Herz")
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
  {"Kein Wegschauen mehr: in der Nähe steht es grasend, A geht jederzeit; Sprinten verscheucht, Loslassen oder Gehen bricht ab", function()
    local ctx, w, h = setup(35)
    ctx.player.x, ctx.player.y = h.x - 20, h.y
    for _ = 1, 600 do ctx.world:update() end
    C.eq(h.state, "graze", "steht 10 s still da")
    C.ok(w:tame_begin(h), "A beginnt sofort")
    C.eq(w:tame_step(h, true), nil)
    C.eq(w:tame_step(h, false), "weg", "losgelassen")
    C.ok(w:tame_begin(h))
    ctx.player.moving = true
    C.eq(w:tame_step(h, true), "weg", "bewegt")
    C.eq(#ctx.herd, 0)
    ctx, w, h = setup(35)
    ctx.player.running, ctx.player.moving = true, true
    h:update()
    C.eq(h.state, "flee", "Sprinten verscheucht")
    ctx.player.x, ctx.player.y = h.x - 10, h.y
    C.eq(w:tame_target(), nil, "auf der Flucht nicht zähmbar")
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
  {"Es hört: Durchgehen verscheucht es (vorher ❗), kurz gehen und stehen nicht; ❗ mit Hysterese", function()
    local ctx, w, h = setup(100)
    local p = ctx.player
    -- Spieler steht 20 px daneben, nur das Hören zählt
    local function step(moving)
      h.state, h.timer = "graze", 1000
      p.x, p.y, p.moving, p.running = h.x - 20, h.y, moving, false
      h:update()
    end
    local warned, n = nil, 0
    repeat
      n = n + 1
      step(true)
      if h.alarm and not warned then warned = n end
    until h.state == "flee" or n > 300
    C.eq(h.state, "flee", "durchgehen")
    C.ok(warned and warned < n - 10, "❗ kommt vorher: " .. tostring(warned) .. " / " .. n)
    log("ZAEHMEN Hören: ❗ nach " .. warned .. " Frames, Flucht nach " .. n)
    ctx, w, h = setup(100)
    p = ctx.player
    for _ = 1, 10 do
      for _ = 1, 15 do step(true) end
      for _ = 1, 30 do step(false) end
    end
    C.eq(h.state, "graze", "kurz gehen, stehen")
    C.ok(not h.alarm, "kein ❗")
    repeat step(true) until h.alarm
    for _ = 1, 5 do step(false) end
    C.ok(h.alarm, "❗ bleibt kurz nach dem Stehenbleiben")
    for _ = 1, 40 do step(false) end
    C.ok(not h.alarm, "❗ geht weg")
    C.ok(h.noise < 0.35, "fast still")
  end},
}
