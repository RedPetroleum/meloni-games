-- Tageslauf (KATALOG §1): 1 Spieltag = 5 min echt, davon 3 min hell und 2 min dunkel.
-- Zeit zählt Frames seit Tagesanfang (Morgen). Pause und Menüs halten sie an (der Aufrufer
-- ruft update nur, wenn die Welt läuft).
local K = require("game.katalog")

local Clock = {}
Clock.__index = Clock

Clock.DAY = K.zeit.tag_min * 3600            -- 18 000 Frames
Clock.LIGHT = K.zeit.hell_min * 3600         -- 10 800 Frames hell, danach dunkel
Clock.DUSK = 900                             -- so lange dauert die Dämmerung vor der Nacht (15 s)
Clock.DAWN = 600                             -- und der Sonnenaufgang nach dem Aufwachen (10 s)

function Clock.new(day, t)
  return setmetatable({day = day or 1, t = t or 0}, Clock)
end

function Clock:is_night()
  return self.t >= Clock.LIGHT
end

-- Ein Frame weiter. Gibt "dusk" beim Einbruch der Nacht, "day" beim Tageswechsel zurück.
function Clock:update()
  self.t = self.t + 1
  if self.t == Clock.LIGHT then return "dusk" end
  if self.t >= Clock.DAY then
    self.t = 0
    self.day = self.day + 1
    self.woke = true
    return "day"
  end
end

-- Schlafen überspringt den Rest der Nacht. Nur nachts; gibt true zurück, wenn es geklappt hat.
function Clock:sleep()
  if not self:is_night() then return false end
  self.t = 0
  self.day = self.day + 1
  self.woke = true
  return true
end

-- Sichtradius in Pixeln um den Spieler (E14): tagsüber unbegrenzt (nil), nachts `night`, dazwischen
-- weicher Übergang in der Dämmerung und beim Sonnenaufgang. lamp: Sattellampe vergrößert ihn.
function Clock:sight(night, lamp)
  night = night * (lamp and 1.8 or 1)
  local far = 420
  local t = self.t
  if t >= Clock.LIGHT then return night end
  if t >= Clock.LIGHT - Clock.DUSK then
    local f = (t - (Clock.LIGHT - Clock.DUSK)) / Clock.DUSK
    return far + (night - far) * f
  end
  if t < Clock.DAWN and self.woke then
    return night + (far - night) * (t / Clock.DAWN)
  end
  return nil
end

-- Uhrzeit für die Anzeige: Sonne/Mond und Anteil der Hell- bzw. Dunkelphase (0–1).
function Clock:face()
  if self.t < Clock.LIGHT then return "icon_sun", self.t / Clock.LIGHT end
  return "icon_moon", (self.t - Clock.LIGHT) / (Clock.DAY - Clock.LIGHT)
end

return Clock
