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
    -- tools/sprites.py verteilt große Sätze auf mehrere Bilder; ein Bild allein braucht beim Laden
    -- auf der Konsole kurz 7 Byte je Pixel am Stück (E77)
    local px, big = 0, 0
    for _, img in ipairs(S.imgs or {S.img}) do
      px = px + img.w * img.h
      big = max(big, img.w * img.h)
    end
    log(string.format("PFERDEGRAFIK %d Bilder, %d Pixel, etwa %.1f MB auf der Konsole, größtes Bild %d Pixel",
      #(S.imgs or {S.img}), px, px * 3 / 1048576, big))
    C.ok(px < 800000, "Sprite-Bilder zu groß")
    C.ok(big <= 256 * 512, "ein Sprite-Bild zu groß zum Laden auf der Konsole")
  end},
}
