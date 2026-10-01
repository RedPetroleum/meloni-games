-- Selbsttests für Sattellampe und Nachtsicht (Aufgabe D5).
local Clock = require("game.clock")
local C = require("game.tests.check")

return {
  {"Nachts 70 Pixel mit Laterne, Sattellampe × 1,8, ohne Licht weniger; tagsüber unbegrenzt", function()
    local c = Clock.new(1, 0)
    C.eq(c:sight(70, 1), nil, "Tag")
    c.t = Clock.LIGHT + 10
    C.eq(c:sight(70, 1), 70)
    C.near(c:sight(70, 1.8), 126, 0.01)
    C.ok(c:sight(70, nil) < 70, "ohne Licht")
    c.t = Clock.LIGHT - Clock.DUSK // 2
    local d = c:sight(70, 1)
    C.ok(d > 70 and d < 420, "Dämmerung weich")
    C.ok(c:sight(70, 1.8) > d, "Lampe auch in der Dämmerung weiter")
  end},
}
