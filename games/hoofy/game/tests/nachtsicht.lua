-- Selbsttests für Sattellampe und Nachtsicht (Aufgabe D5).
local Clock = require("game.clock")
local C = require("game.tests.check")

return {
  {"Nachts 70 Pixel, mit Sattellampe × 1,8; tagsüber unbegrenzt", function()
    local c = Clock.new(1, 0)
    C.eq(c:sight(70, false), nil, "Tag")
    c.t = Clock.LIGHT + 10
    C.eq(c:sight(70, false), 70)
    C.near(c:sight(70, true), 126, 0.01)
    c.t = Clock.LIGHT - Clock.DUSK // 2
    local d = c:sight(70, false)
    C.ok(d > 70 and d < 420, "Dämmerung weich")
    C.ok(c:sight(70, true) > d, "Lampe auch in der Dämmerung weiter")
  end},
}
