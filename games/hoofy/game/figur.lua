-- Zeichnet die Spielfigur aus ihren Schichten (figur.txt, erzeugt nach game/figur_pos.lua): Umhang dahinter,
-- Körper, Unterteil, Oberteil, Haare, Hut. Die Flächen in der gewählten Farbe (game/garderobe.lua) sind
-- Rechtecke, darüber kommt das Sprite der Schicht mit Umriss und festen Farben; so reicht ein Sprite je Schicht
-- für alle Farben. Das Bild ist 12×20 wie player_down; x, y ist seine linke obere Ecke, flip spiegelt um seine
-- Mitte (Blick nach links, Schritt).
local S = require("sprites")
local Pos = require("game.figur_pos")
local Garderobe = require("game.garderobe")

local F = {}

F.W, F.H = 12, 20

local P = Pos.pos
local DEFAULT = Garderobe.neu().an
-- Oberteile beim Gehen von vorn und hinten wie im Stehen, Unterteile von hinten wie von vorn (der Schritt ist
-- gespiegelt), Haare und Hüte immer wie im Stehen
local TOP_VIEW = {down = "down", down_walk = "down", up = "up", up_walk = "up", side = "side", side_walk = "side_walk"}
local BOTTOM_VIEW = {down = {"down"}, down_walk = {"down_walk"}, up = {"up", "down"}, up_walk = {"up_walk", "down_walk", true},
  side = {"side"}, side_walk = {"side_walk"}}
local HEAD_VIEW = {down = "down", down_walk = "down", up = "up", up_walk = "up", side = "side", side_walk = "side"}
local VIEW = {down = {"down", "down_walk"}, up = {"up", "up_walk"}, side = {"side", "side_walk"}}

-- Farben je Farbvariante als rgb-Werte (Zeichen → Farbe), einmal ausgepackt ("Ld9b04ayf0d27a": L, RRGGBB, y, …)
local COLORS = {}
for id, s in pairs(Pos.farbe) do
  local t = {}
  for j = 1, #s, 7 do
    local v = tonumber(s:sub(j + 1, j + 6), 16)
    t[s:sub(j, j)] = rgb(v >> 16, (v >> 8) & 255, v & 255)
  end
  COLORS[id] = t
end
F.COLORS = COLORS

local cache, cached = {}, 0

-- Eine Schicht für die Liste: {Sprite oder false, x, y, Breite, Rechtecke {x0, y0, x1, y1, Farbe, …}, gespiegelt,
-- Rechtecke gespiegelt, x gespiegelt}.
-- Rechtecke in Koordinaten des 12×20-Bilds. mirror: die Schicht selbst ist gespiegelt (Unterteil von hinten).
-- Die Daten sind Bytes (game/figur_pos.lua): x + 8, y + 16, Breite, Höhe, Sprite?, je Zeichen: Zeichen, Anzahl,
-- x0 y0 x1 y1 …
local function layer(name, kind_color, lift, mirror)
  local p = P[name]
  if not p then return nil end
  local ox, oy, w, _, spr = p:byte(1, 5)
  ox, oy = ox - 8, oy - 16 - (lift or 0)
  if mirror then ox = F.W - ox - w end
  local r = {}
  local cols = kind_color and COLORS[kind_color]
  local i = 6
  while i <= #p do
    local c, n = cols and cols[p:sub(i, i)], p:byte(i + 1)
    i = i + 2
    for _ = 1, n do
      local x0, y0, x1, y1 = p:byte(i, i + 3)
      i = i + 4
      if c then
        if mirror then x0, x1 = w - 1 - x1, w - 1 - x0 end
        r[#r + 1] = ox + x0
        r[#r + 1] = oy + y0
        r[#r + 1] = ox + x1
        r[#r + 1] = oy + y1
        r[#r + 1] = c
      end
    end
  end
  local rf = {}                         -- dieselben Rechtecke um die Bildmitte gespiegelt (Blick nach links, Schritt)
  for k = 1, #r, 5 do
    rf[k], rf[k + 1], rf[k + 2], rf[k + 3], rf[k + 4] = F.W - 1 - r[k + 2], r[k + 1], F.W - 1 - r[k], r[k + 3], r[k + 4]
  end
  return {spr == 1 and name, ox, oy, w, r, mirror or false, rf, F.W - ox - w}
end

-- Liste der Schichten für Kleidung an (Garderobe-Feld an) und Ansicht v (down_walk …).
local function layers(an, v)
  local key = an.hut .. ":" .. an.haarfarbe .. ":" .. an.frisur .. ":" .. an.oberteil .. ":" .. an.ofarbe .. ":"
    .. an.unterteil .. ":" .. an.ufarbe .. ":" .. v
  local list = cache[key]
  if list then return list end
  if cached > 96 then cache, cached = {}, 0 end   -- im Editor kommen viele Kombinationen zusammen
  list = {}
  local function add(l) if l then list[#list + 1] = l end end
  local tv, hv = TOP_VIEW[v], HEAD_VIEW[v]
  local oc, uc, hc = "foben_" .. an.ofarbe, "funten_" .. an.ufarbe, "fhaar_" .. an.haarfarbe
  add(layer("foben_" .. an.oberteil .. "_" .. tv .. "_b", oc))
  add(layer("fkoerper_" .. v))
  -- Unterteil: eigene Ansicht, sonst die Ersatzansicht (von hinten wie von vorn, Schritt gespiegelt)
  local bv = BOTTOM_VIEW[v]
  local b = layer("funten_" .. an.unterteil .. "_" .. bv[1], uc)
  if not b and bv[2] then b = layer("funten_" .. an.unterteil .. "_" .. bv[2], uc, 0, bv[3]) end
  add(b)
  add(layer("foben_" .. an.oberteil .. "_" .. tv, oc))
  add(layer("fhaar_" .. an.frisur .. "_" .. hv, hc))
  if an.hut ~= "ohne" then add(layer("fhut_" .. an.hut .. "_" .. hv, nil, Garderobe.hut_hoehe(an.frisur))) end
  cache[key], cached = list, cached + 1
  return list
end
F.layers = layers

-- view: "down", "up", "side"; step 1 (stehen) oder 2 (Schrittbild). scale (optional): vergrößert (Editor).
function F.draw(an, view, step, x, y, flip, scale)
  local list = layers(an or DEFAULT, VIEW[view][step or 1])
  for i = 1, #list do
    local l = list[i]
    local r = flip and l[7] or l[5]
    local ox, fl = l[2], l[6]
    if flip then ox, fl = l[8], not fl end
    if scale then
      local sc = scale
      for k = 1, #r, 5 do
        rectfill(x + r[k] * sc, y + r[k + 1] * sc, x + (r[k + 2] + 1) * sc - 1, y + (r[k + 3] + 1) * sc - 1, r[k + 4])
      end
      if l[1] then
        local s = S.rects[l[1]]
        sspr(s[5] or S.img, s[1], s[2], s[3], s[4], x + ox * sc, y + l[3] * sc, s[3] * sc, s[4] * sc, fl)
      end
    else
      for k = 1, #r, 5 do rectfill(x + r[k], y + r[k + 1], x + r[k + 2], y + r[k + 3], r[k + 4]) end
      if l[1] then S.draw(l[1], x + ox, y + l[3], fl) end
    end
  end
end

return F
