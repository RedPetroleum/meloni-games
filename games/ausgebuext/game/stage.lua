-- Baut aus einem Level (game/levels.lua) die laufende Welt: Karte, Figuren, Kamera, Spur.
-- Das Ergebnis (ctx) ist der gemeinsame Zustand, den Spieler, Pferde und Szenen benutzen.
local S = require("sprites")
local Map = require("lib.tilemap")
local World = require("lib.world")
local Camera = require("lib.camera")
local Trail = require("lib.trail")
local FX = require("lib.fx")
local Tiles = require("game.tiles")
local Horse = require("game.horse")
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
  rope = rgb(0xd9, 0xc3, 0x8c),
  rope_dark = rgb(0x6b, 0x4a, 0x2a),
  grass = Tiles.COLORS.grass,
}

function Stage.build(level)
  local ctx = {S = S, sfx = SFX, colors = Stage.COLORS, level = level}
  ctx.map = Map.new({
    rows = level.map, legend = Tiles.LEGEND, grounds = Tiles.GROUNDS, props = Tiles.PROPS,
    sprites = S, seed = level.seed or 3,
  })
  ctx.world = World.new(ctx.map)
  ctx.fx = FX.new(S)
  ctx.horses = {}
  local px, py
  for _, sp in ipairs(ctx.map.spawns) do
    if sp.kind == "player" then
      px, py = sp.x, sp.y
    elseif sp.kind == "horse" then
      local def = level.horses[sp.id]
      if not def then error("level map has horse " .. sp.id .. " but no entry in horses") end
      local h = Horse.new(ctx, def, sp.x, sp.y)
      ctx.horses[#ctx.horses + 1] = h
      ctx.world:add(h)
    end
  end
  if not px then error("level map has no @ (start)") end
  ctx.player = ctx.world:add(Player.new(ctx, px, py))
  ctx.trail = Trail.new(px, py)
  ctx.camera = Camera.new(ctx.map.pw, ctx.map.ph, {top = Stage.HUD_H, dz_w = 72, dz_h = 48})
  ctx.camera:snap(px, py)
  ctx.hint = function() end
  ctx.say = function() end
  return ctx
end

-- Zeichnet Boden, Welt und Effekte aus Sicht der Kamera.
function Stage.draw_world(ctx, extra)
  local cam = ctx.camera
  cls(Stage.COLORS.grass)
  cam:apply()
  ctx.map:draw(cam.x, cam.y, SCREEN_W, SCREEN_H)
  ctx.world:draw(cam.x, cam.y, SCREEN_W, SCREEN_H)
  if extra then extra() end
  ctx.fx:draw()
  camera()
end

return Stage
