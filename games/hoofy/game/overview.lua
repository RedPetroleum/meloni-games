-- Übersicht eines ganzen Gebiets, 1 Kachel = 2 Pixel (Szenario karte_ganz; Grundlage für die
-- Karte aus Aufgabe A15). Gezeichnet wird nur einmal, der Bildschirm bleibt stehen.
local Area = require("game.area")
local Tiles = require("game.tiles")
local Stage = require("game.stage")
local Farm = require("game.farm")

local Overview = {}

local area, drawn

-- arg: {nr, seed}
function Overview.enter(arg)
  arg = arg or {}
  area = Area.get(arg.nr or 1, arg.seed)
  drawn = false
end

function Overview.update()
  if btnp(BTN_B) or btnp(BTN_START) then return "title" end
end

function Overview.draw()
  if drawn then return end
  drawn = true
  local map, C = area.map, Stage.COLORS
  local ox, oy = (SCREEN_W - map.w * 2) // 2, 20
  cls(C.panel)
  print(area.name .. "  " .. map.w .. "x" .. map.h .. "  Seed " .. area.seed, ox, 6, C.text)
  local G, byte = Tiles.GROUNDS, string.byte
  local colors = {}
  for ch, g in pairs(G) do colors[byte(ch)] = g.map end
  for cy = 0, map.h - 1 do
    local row = map.ground[cy + 1]
    local y = oy + cy * 2
    local cx = 0
    while cx < map.w do
      -- gleiche Böden in einer Zeile als ein Rechteck
      local b = byte(row, cx + 1)
      local run = cx
      while run + 1 < map.w and byte(row, run + 2) == b do run = run + 1 end
      rectfill(ox + cx * 2, y, ox + run * 2 + 1, y + 1, colors[b])
      cx = run + 1
    end
  end
  for k = 1, map.bw * map.bh do
    for _, o in ipairs(map.blocks[k] or {}) do
      local P = Tiles.PROPS[o[1]]
      local x, y = ox + o[2] * 2, oy + o[3] * 2
      rectfill(x, y, x + (P.w or 1) * 2 - 1, y + (P.h or 1) * 2 - 1, P.map)
    end
  end
  local p = area.plot
  if area.farm then Farm.outline(area.farm, ox, oy, 2, C.gold)
  else rect(ox + p.x * 2 - 1, oy + p.y * 2 - 1, ox + (p.x + p.w) * 2, oy + (p.y + p.h) * 2, C.gold) end
  local legend_y = oy + map.h * 2 + 6
  print("Hof", ox + p.x * 2 + 2, oy + p.y * 2 + 2, C.gold)
  for id in pairs(Area.LABELS) do
    local pl = area.places[id]
    if pl then pset(ox + pl[1] * 2, oy + pl[2] * 2, C.red) end
  end
  local v = area.village
  if v then print("Dorf", ox + v.x * 2 + 2, oy + (v.y + v.h) * 2 + 2, C.text) end
  print("B: zurück", ox, legend_y, C.dim)
end

return Overview
