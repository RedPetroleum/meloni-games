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
  local ctx = {S = S, sfx = SFX, colors = Stage.COLORS, area = area}
  ctx.map = area.map
  ctx.world = World.new(ctx.map)
  ctx.fx = FX.new(S)
  local st = area.places.start
  local px, py = st[1] * 16 + 8, st[2] * 16 + 14
  -- Vorrat (E31): das Startinventar; Kauf und Ernte kommen mit B1/C5
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

-- Nacht (E14): außerhalb eines Kreises um (cx, cy) ist alles schwarz. Gezeichnet mit waagerechten
-- Streifen von STRIP Pixeln Höhe (ein paar Dutzend rectfill), der Kreis wird dadurch treppenförmig.
local STRIP = 4
function Stage.draw_night(cx, cy, radius)
  local top = Stage.HUD_H
  for y0 = top, SCREEN_H - 1, STRIP do
    local y1 = min(SCREEN_H - 1, y0 + STRIP - 1)
    -- engster Abstand zur Mitte in diesem Streifen bestimmt die Breite (Kreis bleibt innen)
    local dy = max(abs(y0 - cy), abs(y1 - cy))
    if dy >= radius then
      rectfill(0, y0, SCREEN_W - 1, y1, 0)
    else
      local hw = flr(math.sqrt(radius * radius - dy * dy))
      if cx - hw > 0 then rectfill(0, y0, cx - hw - 1, y1, 0) end
      if cx + hw < SCREEN_W - 1 then rectfill(cx + hw, y0, SCREEN_W - 1, y1, 0) end
    end
  end
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
