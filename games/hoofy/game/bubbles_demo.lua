-- Szenario blasen: je ein Pferd pro Zustand in einer Reihe, mit Beschriftung.
local Stage = require("game.stage")
local Wild = require("game.wild")
local H = require("game.horse_model")
local Rng = require("lib.rng")

local Demo = {}
local ctx

local CASES = {
  {"Schatz", function(h) h.schatz = true end},
  {"Angst", function(h) h.scared = true end},
  {"Hunger", function(h) h.data.hunger = 80 end},
  {"schmutzig", function(h) h.data.sauberkeit = 20 end},
  {"müde", function(h) h.data.energie = 10 end},
  {"verfressen", function(h) h.data.zug = "verfressen" end},
  {"schreckhaft", function(h) h.data.zug = "schreckhaft" end},
  {"faul", function(h) h.data.zug = "faul" end},
  {"eitel", function(h) h.data.zug = "eitel" end},
  {"Nachteule", function(h) h.data.zug = "nachteule" end},
  {"Herz", function(h) h.data.bindung = 80; h.heart_t = 999 end},
  {"keine", function(h) end},
}

function Demo.enter()
  ctx = Stage.build(1)
  local rng = Rng.new(4)
  local st = ctx.area.places.start
  for i, c in ipairs(CASES) do
    local data = H.wild({rng = rng})
    data.hunger, data.sauberkeit, data.energie, data.bindung = 30, 60, 80, 30
    local col, row = (i - 1) % 3, (i - 1) // 3
    local h = Wild.Horse.new(ctx, data, (st[1] - 3) * 16 + col * 92, (st[2] - 3) * 16 + 10 + row * 50)
    h.state, h.timer, h.update, h.dir = "graze", 1e9, function() end, "right"
    c[2](h)
    h.demo = c[1]
    if i >= 6 and i <= 10 then h.force_trait = true end
    ctx.world:add(h)
  end
  ctx.player.x, ctx.player.y = st[1] * 16 - 300, st[2] * 16
  ctx.camera:snap((st[1] - 3) * 16 + 92, (st[2] - 3) * 16 + 95)
end

function Demo.update()
  ctx.world:update()
  if btnp(BTN_B) then return "title" end
end

function Demo.draw()
  Stage.draw_world(ctx)
  local C = Stage.COLORS
  local cam = ctx.camera
  for _, e in ipairs(ctx.world.entities) do
    if e.demo then print(e.demo, e.x - cam.x - textw(e.demo) // 2, e.y - cam.y + 2, C.panel) end
  end
end

return Demo
