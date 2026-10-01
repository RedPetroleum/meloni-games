-- Galerie (Szenario galerie): alle Rassen mit je drei Farben aus ihrer Farbmatrix, die Posen
-- laufen der Reihe nach durch. Seite 1: Rassen 1–6, Seite 2: 7–12 (wechselt alle 4 s, A: sofort).
local K = require("game.katalog")
local G = require("game.horse_gfx")
local Stage = require("game.stage")

local Gallery = {}

local t, page
local ANIM = {"side", "side_walk", "side", "side_walk", "gallop1", "gallop2", "gallop1", "gallop2",
  "graze", "down", "down_walk", "up", "up_walk"}

-- Drei Farben einer Rasse: die erste Farbe jeder Stufe, von selten nach häufig aufgefüllt.
local function colors_for(rasse)
  local out, per = {}, K.farben.matrix[rasse.id]
  for s = 1, #per do
    if per[s][1] then out[#out + 1] = per[s][1] end
  end
  while #out > 3 do table.remove(out, 2) end
  return out
end

local schmuck_mode
local ALL = {glitzerdecke = true, blumenkranz = true, maehnenschleife = true, goldhufeisen = true}

-- arg.schmuck = true (Szenario schmuck): alle Körper in fünf Posen mit allem Schmuck, die erste Spalte gespiegelt.
function Gallery.enter(arg)
  t, page = 0, 1
  schmuck_mode = arg and arg.schmuck
end

local function draw_schmuck()
  local C = Stage.COLORS
  cls(rgb(0x7f, 0xb0, 0x4f))
  print("Schmuck an allen Körpern", 4, 2, C.panel)
  local poses = {"side", "side", "side_walk", "gallop1", "graze", "down", "up"}
  for i, body in ipairs(G.BODIES) do
    local y = 50 + (i - 1) * 52
    for j, pose in ipairs(poses) do
      G.draw(i % 2 == 0 and "schimmel" or "rappe", body, pose, 24 + (j - 1) * 45, y, j == 1, ALL)
    end
  end
end

function Gallery.update()
  t = t + 1
  if t % 240 == 0 or btnp(BTN_A) then page = 3 - page end
  if btnp(BTN_B) then return "title" end
end

function Gallery.draw()
  if schmuck_mode then return draw_schmuck() end
  local C = Stage.COLORS
  cls(rgb(0x7f, 0xb0, 0x4f))
  rectfill(0, 0, SCREEN_W - 1, 11, C.panel)
  local pose = ANIM[(t // 20) % #ANIM + 1]
  print("Galerie " .. page .. "/2  Pose: " .. pose, 4, 2, C.text)
  for i = 1, 6 do
    local r = K.rassen.liste[(page - 1) * 6 + i]
    local y = 14 + (i - 1) * 38
    print(r.name, 4, y + 2, C.panel)
    print(r.koerper, 4, y + 12, rgb(0x2b, 0x4f, 0x1d))
    for j, coat in ipairs(colors_for(r)) do
      local x = 150 + (j - 1) * 60
      G.draw(coat, r.koerper, pose, x, y + 34, false)
      print(coat, x - textw(coat) // 2, y + 36 - 36, rgb(0x2b, 0x4f, 0x1d))
    end
  end
end

return Gallery
