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

-- Dunkelheit (E14, geändert, Engine-Funktion shade ab API 2): die Welt wird stufenlos mit Nachtblau
-- gemischt, höchstens DARK_MAX deckend. Um den Spieler (cx, cy auf dem Bildschirm) bleibt es nachts heller:
-- bis SIGHT_IN fast so hell wie am Abend, bis SIGHT_OUT weicher Übergang. Der Sichtbereich kommt erst mit der
-- Nacht, am Abend wird alles gleichmäßig dunkler. Den Sichtbereich gibt es nur mit Licht (Rückmeldung 0.5.2):
-- light = 1 Laterne, 1,8 Sattellampe; ohne Licht (nil) ist alles gleichmäßig dunkel. dark: 0 (Tag) bis 1 (Nacht).
Stage.DARK_COLOR = rgb(0x0e, 0x10, 0x28)
Stage.DARK_MAX = 0.86
Stage.SIGHT_IN, Stage.SIGHT_OUT = 40, 112
Stage.SIGHT_FROM = 0.45                -- ab dieser Dunkelheit bleibt es um den Spieler so hell wie jetzt
Stage.SIGHT_KEEP = 0.85                -- Anteil der weiteren Verdunkelung, den der Sichtbereich aufhält

-- Deckkraft außen und im Sichtbereich für dark (0–1).
function Stage.dark_alpha(dark)
  local a = dark * Stage.DARK_MAX
  local base = Stage.SIGHT_FROM * Stage.DARK_MAX
  if a <= base then return a, a end
  local keep = Stage.SIGHT_KEEP * mid(0, (dark - Stage.SIGHT_FROM) / 0.3, 1)
  return a, base + (a - base) * (1 - keep)
end

function Stage.draw_dark(cx, cy, dark, light)
  if dark <= 0.01 then return end
  local a, a0 = Stage.dark_alpha(dark)
  local f = light or 1
  clip(0, Stage.HUD_H, SCREEN_W, SCREEN_H - Stage.HUD_H)
  if light and a0 < a then
    shade(Stage.DARK_COLOR, a, cx, cy, Stage.SIGHT_IN * f, Stage.SIGHT_OUT * f, a0)
  else
    shade(Stage.DARK_COLOR, a)
  end
  clip()
end

-- Zeichnet Boden, Welt und Effekte aus Sicht der Kamera.
function Stage.draw_world(ctx, extra)
  local cam = ctx.camera
  cls(Stage.COLORS.grass)
  cam:apply()
  ctx.map:draw(cam.x, cam.y, SCREEN_W, SCREEN_H)
  ctx.fx:draw(true)
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
