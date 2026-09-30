-- Töne und Musik (Aufgabe A16). Kurze Melodien laufen auf Kanal 6, die Hintergrundmusik auf 7,
-- Geräusche auf den freien Kanälen. Lautstärken bewusst leise: ruhig und beruhigend.
local SFX = {}

local JINGLE = 6
local MUSIC = 7

-- ---- Menü ----
function SFX.select() tone(note("E5"), 0.04, "square", 0.15) end                    -- Cursor bewegen
function SFX.ok() tone(note("A5"), 0.05, "square", 0.18) tone(note("E6"), 0.06, "square", 0.12) end
function SFX.back() tone(note("C5"), 0.06, "triangle", 0.2) end
function SFX.start() tune("C5:0.5 E5:0.5 G5:1", 600, "square", 0.2, false, JINGLE) end
function SFX.key() tone(note("G5"), 0.03, "square", 0.12) end                        -- Tastatur

-- ---- Pferde ----
-- Hufschlag: Rauschstoß, tiefer und leiser im Schritt. step zählt die Schläge (wechselt die Höhe).
function SFX.hoof(running, step)
  local f = 110 + (step % 2) * 50
  if running then tone(f + 40, 0.045, "noise", 0.16) else tone(f, 0.035, "noise", 0.09) end
end
function SFX.whinny() tune("A5:0.25 C6:0.25 A5:0.25 C6:0.25 E5:0.5", 900, "saw", 0.1, false, JINGLE) end
function SFX.snort() tone(90, 0.12, "noise", 0.2) end
function SFX.warn() tone(note("E6"), 0.08, "square", 0.15) end                        -- ❗ beim Zähmen
function SFX.tame() tune("G5:0.5 C6:0.5 E6:1", 700, "triangle", 0.25, false, JINGLE) end
function SFX.snap() tone(note("C3"), 0.08, "noise", 0.3) tone(note("A2"), 0.12, "saw", 0.15) end  -- Leine reißt
function SFX.jump() tone(260, 0.12, "triangle", 0.18) end
function SFX.land() tone(80, 0.09, "noise", 0.22) end
function SFX.mount() tone(note("D4"), 0.05, "triangle", 0.2) tone(note("A4"), 0.07, "triangle", 0.2) end

-- ---- Pflege ----
function SFX.eat() tone(200, 0.04, "noise", 0.14) tone(150, 0.05, "noise", 0.12) end
function SFX.brush() tone(300, 0.08, "noise", 0.07) end
function SFX.pet() tune("E5:0.5 G5:0.5", 500, "sine", 0.22, false, JINGLE) end

-- ---- Tageszeit ----
function SFX.dusk() tune("E5:1 C5:1 G4:2", 200, "sine", 0.2, false, JINGLE) end
function SFX.dawn() tune("G4:1 C5:1 E5:1 G5:2", 240, "sine", 0.2, false, JINGLE) end

-- ---- Musik: ruhige Melodie, nachts langsamer und leiser (E37) ----
local SONGS = {
  day = {
    "C4 E4 G4 E4 A4:2 G4 E4 D4 C4:2 -",
    "E4 G4 C5 G4 A4:2 G4 E4 G4 D4:3 -",
    "C4 E4 G4 E4 A4:2 C5 A4 G4 E4:2 -",
    "D4 E4 G4 A4 G4:2 E4 D4 C4:3 -",
  },
  night = {
    "A3:2 E4:2 C4:2 -:2",
    "B3:2 G3:2 E3:3 -:1",
  },
}
local PLAY = {
  day = {bpm = 96, wave = "triangle", vol = 0.09},
  night = {bpm = 56, wave = "sine", vol = 0.08},
}

local current

-- name: "day", "night" oder nil (aus). Wechselt nur, wenn sich etwas ändert.
function SFX.music(name)
  if name == current then return end
  current = name
  stoptune(MUSIC)
  if name then
    local p = PLAY[name]
    tune(table.concat(SONGS[name], " "), p.bpm, p.wave, p.vol, true, MUSIC)
  end
end

return SFX
