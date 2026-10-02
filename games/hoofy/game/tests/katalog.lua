-- Selbsttests für die Katalogwerte (data/*.lua aus KATALOG.md, Aufgabe 0.3).
local K = require("game.katalog")
local C = require("game.tests.check")

return {
  {"12 Rassen, Stichproben", function()
    C.eq(#K.rassen.liste, 12, "Rassen")
    C.eq(K.rasse("mustang").tempo, 40, "Mustang Tempo")
    C.eq(K.rasse("einhorn").grundwert, 10000, "Einhorn Grundwert")
    C.eq(K.rasse("shetlandpony").koerper, "pony")
  end},
  {"30 Farben in 5 Stufen, Anteile 100 %", function()
    C.eq(#K.farben.stufen, 5, "Stufen")
    C.eq(#K.farben.liste, 30, "Farben")
    local sum = 0
    for _, st in ipairs(K.farben.stufen) do sum = sum + st.anteil end
    C.eq(sum, 100, "Summe der Anteile")
    C.eq(K.farbe("gold").stufe, 5)
  end},
  {"Farbmatrix für jede Rasse, nur bekannte Farben, mindestens eine", function()
    for _, r in ipairs(K.rassen.liste) do
      local per = K.farben.matrix[r.id]
      C.ok(per, "Matrix fehlt für " .. r.id)
      C.eq(#per, 5, r.id .. " Stufen")
      local n = 0
      for s, list in ipairs(per) do
        for _, f in ipairs(list) do
          C.eq(K.farbe(f).stufe, s, r.id .. " " .. f)
          n = n + 1
        end
      end
      C.ok(n > 0, r.id .. " hat keine Farbe")
    end
  end},
  {"Vererbung 35/15/35/15", function()
    local v = K.farben.vererbung
    C.eq(v.vater_sichtbar + v.vater_versteckt + v.mutter_sichtbar + v.mutter_versteckt, 100)
  end},
  {"Gebiete und neue Rassen passen zusammen", function()
    C.eq(#K.welt.gebiete, 6)
    for _, g in ipairs(K.welt.gebiete) do
      for _, id in ipairs(g.rassen) do C.eq(K.rasse(id).gebiet, g.nr, id) end
    end
    C.eq(K.welt.gebiete[1].w, 96)
  end},
  {"Stichproben andere Abschnitte", function()
    C.eq(K.zeit.tag_min, 5)
    C.eq(K.stats.gen_sigma, 8)
    C.eq(K.stats.bindung.folgt, 100)
    C.eq(K.bauteil("stall_s").plaetze, 2)
    C.eq(K.fahrzeug("mofa").preis, 10000)
    C.eq(K.wirtschaft.startgeld, 300)
    C.eq(#K.charakter.nachteule.name > 0, true)
    for _, t in ipairs(K.turniere.klassen) do
      if t.fahrzeug ~= "" then K.fahrzeug(t.fahrzeug) end
    end
  end},
}
