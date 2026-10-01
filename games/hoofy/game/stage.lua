-- Baut aus einem Gebiet (game/area.lua) die laufende Welt: Karte, Figuren, Kamera, Spur.
-- Das Ergebnis (ctx) ist der gemeinsame Zustand, den Spieler, Pferde und Szenen benutzen.
local S = require("sprites")
local Area = require("game.area")
local World = require("lib.world")
local Camera = require("lib.camera")
local Trail = require("lib.trail")
local FX = require("lib.fx")
local Tiles = require("game.tiles")
local Player = require("game.player")
local SFX = require("game.sfx")
local Explore = require("game.explore")

local Stage = {}

Stage.HUD_H = 14

Stage.COLORS = {
  panel = rgb(0x2b, 0x1f, 0x1d),
  panel_light = rgb(0x4a, 0x36, 0x2c),
  text = rgb(0xfb, 0xf8, 0xef),
  dim = rgb(0xb8, 0xa8, 0x90),
  gold = rgb(0xf3, 0xd5, 0x7f),
  red = rgb(0xe0, 0x47, 0x5a),
  grass = Tiles.COLORS.grass,
}

-- nr: Gebiet (1 = Heimattal), seed: Welt-Seed (nil: Standard).
function Stage.build(nr, seed, farm)
  local area = Area.get(nr, seed, farm)
  Tiles.set_palette(area.info.palette)
  Stage.COLORS.grass = Tiles.COLORS.grass
  local ctx = {S = S, sfx = SFX, colors = Stage.COLORS, area = area}
  ctx.map = area.map
  ctx.hof = area.farm            -- der Hof (auch in fremden Gebieten, dann ist area.farm leer)
  ctx.world = World.new(ctx.map)
  ctx.fx = FX.new(S)
  local st = area.places.start
  local px, py = st[1] * 16 + 8, st[2] * 16 + 14
  -- Vorrat (E31): das Startinventar; Kauf und Ernte kommen mit B1/C5
  ctx.herd, ctx.herd_horses, ctx.lead = {}, {}, {}   -- eigene Pferde: Daten, Figuren, an der Leine
  ctx.explored = Explore.new(ctx.map.w, ctx.map.h)
  ctx.orders = {}
  ctx.seed = seed or area.seed
  ctx.max_gebiet = 1              -- weitestes erreichbares Gebiet (Fahrzeuge kommen mit D1)
  ctx.money = 300                 -- Startgeld (KATALOG §15)
  ctx.inv = {heu = 3, karotte = 2, hafer = 0, premiumfutter = 0, buerste = 1}
  ctx.player = ctx.world:add(Player.new(ctx, px, py))
  ctx.trail = Trail.new(px, py)
  ctx.camera = Camera.new(ctx.map.pw, ctx.map.ph, {top = Stage.HUD_H, dz_w = 72, dz_h = 48})
  ctx.camera:snap(px, py)
  return ctx
end

-- Namen der Orte im Dorf über Tür bzw. Stand (Weltkoordinaten, Kamera ist gesetzt).
local function draw_labels(ctx)
  local cam = ctx.camera
  for id, L in pairs(Area.LABELS) do
    local p = ctx.area.places[id]
    if p then
      local text = L[1]
      local x = p[1] * 16 + 8 + L[2] - textw(text) // 2
      local y = p[2] * 16 + L[3]
      if x + 80 > cam.x and x < cam.x + SCREEN_W and y + 8 > cam.y and y < cam.y + SCREEN_H then
        rectfill(x - 2, y - 1, x + textw(text) + 1, y + 8, Stage.COLORS.panel)
        print(text, x, y, Stage.COLORS.gold)
      end
    end
  end
end

-- Dunkelheit (E14, geändert): ein Dither-Schleier aus Kacheln (16 × 16, Stufen dunkel_1 … dunkel_14 von 16
-- Pixeln je 4 × 4 dunkel). Je dunkler, desto dichter; um den Spieler (cx, cy auf dem Bildschirm) bleibt es
-- heller (erst ab etwa Nachtbeginn): bis SIGHT_IN um 8 Stufen, nach außen weich abnehmend bis SIGHT_OUT. Die Sattellampe vergrößert
-- beide Radien. dark: 0 (Tag) bis 1 (Nacht).
Stage.DARK_MAX = 14
Stage.SIGHT_IN, Stage.SIGHT_OUT, Stage.SIGHT_BONUS = 40, 112, 8

local DARK, BAND = {}, {}
for l = 1, 14 do DARK[l], BAND[l] = "dunkel_" .. l, "dunkelband_" .. l end

-- Stufe einer Kachel mit Mittelpunktabstand² d2 (light: Aufhellung im Sichtbereich).
local function level_at(full, light, d2, rin, rout, span)
  local level = full
  if light > 0 and d2 < rout * rout then
    local w = (rout - math.sqrt(d2)) / span
    if w > 1 then w = 1 end
    level = full - light * w
  end
  level = flr(level + 0.5)
  return level > 14 and 14 or level
end

local row = {}                        -- Stufen einer Reihe (wiederverwendet)

function Stage.draw_dark(cx, cy, dark, lamp)
  if dark <= 0.03 then return end
  local top = Stage.HUD_H
  local f = lamp and 1.8 or 1
  local rin, rout = Stage.SIGHT_IN * f, Stage.SIGHT_OUT * f
  local span = rout - rin
  local full = dark * Stage.DARK_MAX
  -- Sichtbereich erst mit der Nacht: am Abend wird alles gleichmäßig dunkler
  local light = Stage.SIGHT_BONUS * mid(0, (dark - 0.45) / 0.45, 1)
  local S = require("sprites")
  local cols = SCREEN_W // 16
  clip(0, top, SCREEN_W, SCREEN_H - top)
  for y = top, SCREEN_H - 1, 16 do
    local dy = y + 8 - cy
    for i = 1, cols do
      local dx = (i - 1) * 16 + 8 - cx
      row[i] = level_at(full, light, dx * dx + dy * dy, rin, rout, span)
    end
    -- gleiche Stufe in vier Kacheln hintereinander: ein Streifen statt vier Kacheln
    local i = 1
    while i <= cols do
      local l = row[i]
      if i + 3 <= cols and row[i + 1] == l and row[i + 2] == l and row[i + 3] == l then
        if l >= 1 then S.draw(BAND[l], (i - 1) * 16, y) end
        i = i + 4
      else
        if l >= 1 then S.draw(DARK[l], (i - 1) * 16, y) end
        i = i + 1
      end
    end
  end
  clip()
end

-- Zeichnet Boden, Welt und Effekte aus Sicht der Kamera.
function Stage.draw_world(ctx, extra)
  local cam = ctx.camera
  cls(Stage.COLORS.grass)
  cam:apply()
  ctx.map:draw(cam.x, cam.y, SCREEN_W, SCREEN_H)
  ctx.world:draw(cam.x, cam.y, SCREEN_W, SCREEN_H)
  draw_labels(ctx)
  if extra then extra() end
  ctx.fx:draw()
  camera()
end

function Stage.panel(x0, y0, x1, y1)
  local C = Stage.COLORS
  rectfill(x0, y0, x1, y1, C.panel)
  rect(x0 + 1, y0 + 1, x1 - 1, y1 - 1, C.panel_light)
end

function Stage.center(text, y, c, scale)
  print(text, (SCREEN_W - textw(text, scale)) // 2, y, c, scale)
end

return Stage
