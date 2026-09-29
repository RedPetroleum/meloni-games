-- Töne und Musik. Kurze Melodien laufen auf Kanal 6, die Hintergrundmusik auf Kanal 7.
local SFX = {}

local JINGLE = 6
local MUSIC = 7

function SFX.grab() tune("G5:0.5 C6:0.5", 700, "square", 0.22, false, JINGLE) end
function SFX.release() tone(note("E4"), 0.08, "triangle", 0.3) end
function SFX.deny() tune("E4:0.5 C4:0.5", 600, "square", 0.18, false, JINGLE) end
function SFX.carrot() tune("C5:0.3 E5:0.3 G5:0.5", 900, "triangle", 0.35, false, JINGLE) end
function SFX.coax() tone(note("A5"), 0.05, "sine", 0.3) end
function SFX.grumble() tune("D3:0.5 C3:1", 500, "saw", 0.12, false, JINGLE) end
function SFX.whinny() tune("A5:0.25 C6:0.25 A5:0.25 C6:0.25 E5:0.5", 900, "saw", 0.12, false, JINGLE) end
function SFX.home() tune("C5:0.5 E5:0.5 G5:0.5 C6:1.5", 560, "square", 0.22, false, JINGLE) end
function SFX.kick() tone(90, 0.12, "noise", 0.4) tune("C3:0.25 G2:0.5", 700, "saw", 0.15, false, JINGLE) end
function SFX.tick() tone(note("C6"), 0.03, "square", 0.15) end
function SFX.win() tune("C5:0.5 E5:0.5 G5:0.5 C6:1 G5:0.5 C6:2", 360, "square", 0.25, false, JINGLE) end
function SFX.lose() tune("G4:1 E4:1 C4:2", 240, "triangle", 0.3, false, JINGLE) end
function SFX.select() tone(note("E5"), 0.04, "square", 0.2) end

local SONG = table.concat({
  "E4 G4 C5 G4 A4:2 G4 E4",
  "F4 A4 D5 A4 G4:3 -",
  "E4 G4 C5 G4 A4:2 C5 B4",
  "A4 G4 E4 D4 C4:3 -",
}, " ")

function SFX.music(on)
  if on then
    tune(SONG, 150, "triangle", 0.12, true, MUSIC)
  else
    stoptune(MUSIC)
  end
end

return SFX
