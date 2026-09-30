-- Töne und Musik. Kurze Melodien laufen auf Kanal 6, die Hintergrundmusik auf Kanal 7.
-- Richtige Töne kommen mit Aufgabe A16.
local SFX = {}

local JINGLE = 6

function SFX.select() tone(note("E5"), 0.04, "square", 0.2) end
function SFX.start() tune("C5:0.5 E5:0.5 G5:1", 600, "square", 0.2, false, JINGLE) end

return SFX
