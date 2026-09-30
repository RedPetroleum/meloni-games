-- Selbsttests für die Pferdegrafik (Aufgabe A3).
local S = require("sprites")
local K = require("game.katalog")
local G = require("game.horse_gfx")
local C = require("game.tests.check")

return {
  {"jede Katalogfarbe hat Grundfarbe (+ Muster) für jeden Körper und jede Pose", function()
    for _, f in ipairs(K.farben.liste) do
      local def = G.COATS[f.id]
      C.ok(def, "keine Grafik für Farbe " .. f.id)
      for _, body in ipairs(G.BODIES) do
        for _, pose in ipairs(G.POSES) do
          C.ok(S.rects[def[1] .. "_" .. body .. "_" .. pose], f.id .. " " .. body .. " " .. pose)
          if def[2] then C.ok(S.rects["muster_" .. def[2] .. "_" .. body .. "_" .. pose], "Muster " .. def[2]) end
        end
      end
    end
  end},
  {"jede Rasse hat eine Körperform mit Grafik", function()
    local bodies = {}
    for _, b in ipairs(G.BODIES) do bodies[b] = true end
    for _, r in ipairs(K.rassen.liste) do C.ok(bodies[r.koerper], r.id .. ": " .. r.koerper) end
  end},
  {"Pony kleiner als Warmblut, Kaltblut größer", function()
    local pw, ph = G.size("brauner", "pony", "side")
    local ww, wh = G.size("brauner", "warmblut", "side")
    local kw, kh = G.size("brauner", "kaltblut", "side")
    C.ok(pw < ww and ph < wh, "Pony")
    C.ok(kw > ww and kh > wh, "Kaltblut")
  end},
  {"Größe des Sprite-Bilds", function()
    local px = S.img.w * S.img.h
    log(string.format("PFERDEGRAFIK sprites.png %dx%d = %d Pixel, etwa %.1f MB auf der Konsole",
      S.img.w, S.img.h, px, px * 3 / 1048576))
    C.ok(px < 800000, "Sprite-Bild zu groß")
  end},
}
