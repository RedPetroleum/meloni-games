-- Besonderheiten der Gebiete (Rückmeldung 1.5.2, E84): Furten bremsen (Flussauen), Kakteen stoßen zurück
-- (Steppe, Canyon), Schluchten überspringt man nur an schmalen Stellen (Canyon, Sprung in game/ride.lua), auf der
-- Nebelinsel sieht man nur im Schein einer Lampe und kommt ohne gar nicht hin.
-- Die Landschaft selbst erzeugt game/mapgen.lua (Gen.PROFILES).
local SFX = require("game.sfx")

local G = {}

G.NEBEL_GEBIET = 6
G.NEBEL_COLOR = rgb(0xd6, 0xcf, 0xe6)
G.NEBEL_ALPHA = 0.86                 -- außen fast undurchsichtig
G.NEBEL_IN, G.NEBEL_OUT = 30, 96     -- Sichtkreis mit Laterne (Pixel), Sattellampe × LAMPE_WEIT
G.LAMPE_WEIT = 1.35
G.KAKTUS = string.byte("C")          -- Kollisionsform der Kakteen (game/tiles.lua)
G.KAKTUS_NAH = 13                    -- Abstand Fußpunkt – Kaktusmitte, ab dem es piekst (Pixel)
G.KAKTUS_STOSS = 3.2                 -- Rückstoß (Pixel je Frame, bremst ab)
G.KAKTUS_FRAMES = 16

-- Faktor auf das Tempo am Fußpunkt (Furt 0,55, sonst 1).
function G.tempo(map, x, y)
  local g = map:ground_at(x, y - 1)
  return g and g.slow or 1
end

-- Liegt der Fußpunkt über einer Schlucht?
function G.ueber_schlucht(map, x, y)
  local g = map:ground_at(x, y - 1)
  return g and g.gap ~= nil
end

-- Nächster Kaktus in der Nähe des Fußpunkts: Mitte (Pixel) und Abstand, sonst nil.
function G.kaktus_nah(map, x, y)
  local coll = map.coll
  if not coll then return nil end
  local cx0, cy0 = x // 16, (y - 1) // 16
  local best, bx, by
  for cy = cy0 - 1, cy0 + 1 do
    local row = coll[cy + 1]
    if row then
      for cx = cx0 - 1, cx0 + 1 do
        if cx >= 0 and cx < map.w and string.byte(row, cx + 1) == G.KAKTUS then
          local kx, ky = cx * 16 + 8, cy * 16 + 13
          local d = math.sqrt((x - kx) ^ 2 + (y - ky) ^ 2)
          if not best or d < best then best, bx, by = d, kx, ky end
        end
      end
    end
  end
  return bx, by, best
end

-- Piekst ein Kaktus? Dann wird p (Spieler, auch beim Reiten) weggestoßen: Rückstoß von der Kaktusmitte weg.
-- Gibt true zurück, wenn es gepiekst hat.
function G.kaktus(p)
  if (p.knock_t or 0) > 0 or (p.air or 0) > 0 then return false end
  local kx, ky, d = G.kaktus_nah(p.ctx.map, p.x, p.y)
  if not kx or d > G.KAKTUS_NAH then return false end
  local dx, dy = p.x - kx, p.y - ky
  if d < 0.5 then dx, dy, d = 0, 1, 1 end
  p:knock(dx / d * G.KAKTUS_STOSS, dy / d * G.KAKTUS_STOSS, G.KAKTUS_FRAMES)
  SFX.pieks()
  local fx = p.ctx.fx
  if fx then
    for i = 0, 2 do fx:spawn(kx - 4 + i * 4, ky - 14, {sprite = "dust", vx = (i - 1) * 0.4, vy = -0.5, life = 14}) end
  end
  if p.riding then
    local d2 = p.riding.data
    d2.energie = math.max(0, d2.energie - 1)
  end
  if p.ctx.toast and not p.autsch_gezeigt then p.ctx.toast("Autsch! Kakteen pieksen.") end
  p.autsch_gezeigt = true
  return true
end

-- Ist es hier neblig (Nebelinsel)?
function G.neblig(ctx)
  return ctx.area and ctx.area.nr == G.NEBEL_GEBIET
end

-- Hat der Spieler Licht für den Nebel: Laterne oder ein eigenes Pferd mit Sattellampe?
function G.hat_licht(ctx)
  if (ctx.inv and ctx.inv.laterne or 0) > 0 then return true end
  for _, d in ipairs(ctx.herd or {}) do
    if d.lampe then return true end
  end
  return false
end

-- Sichtweite im Nebel (Radius in Pixeln, für Erkundung und Karte), light wie WorldScene.light().
function G.nebel_sicht(light)
  if not light then return G.NEBEL_IN end
  return G.NEBEL_OUT * (light > 1 and G.LAMPE_WEIT or 1)
end

-- Nebel über der Welt: um den Spieler (cx, cy auf dem Bildschirm) ein Lichtkreis, der leicht atmet.
-- top: Höhe der Kopfleiste (dort kein Nebel).
function G.draw_nebel(cx, cy, light, t, top)
  local f = light and (light > 1 and G.LAMPE_WEIT or 1) or 0.35
  local wob = 1 + 0.05 * math.sin(t / 40)
  clip(0, top, SCREEN_W, SCREEN_H - top)
  shade(G.NEBEL_COLOR, G.NEBEL_ALPHA, cx, cy, G.NEBEL_IN * f * wob, G.NEBEL_OUT * f * wob, 0.04)
  clip()
end

return G
