-- Töne und Musik (Aufgabe A16). Kurze Melodien laufen auf Kanal 6, die Hintergrundmusik auf 7,
-- Geräusche auf den freien Kanälen. Lautstärken bewusst leise: ruhig und beruhigend.
-- Keine tiefen Töne (Rückmeldung 0.5.4), die scheppern auf kleinen Lautsprechern: nichts unter A4 (440 Hz),
-- Rauschen ab 400 Hz.
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
  local f = 440 + (step % 2) * 200
  if running then tone(f + 160, 0.045, "noise", 0.16) else tone(f, 0.035, "noise", 0.09) end
end
function SFX.whinny() tune("A5:0.25 C6:0.25 A5:0.25 C6:0.25 E5:0.5", 900, "saw", 0.1, false, JINGLE) end
function SFX.snort() tone(400, 0.12, "noise", 0.2) end
function SFX.warn() tone(note("E6"), 0.08, "square", 0.15) end                        -- ❗ beim Zähmen
function SFX.tame() tune("G5:0.5 C6:0.5 E6:1", 700, "triangle", 0.25, false, JINGLE) end
function SFX.snap() tone(note("C5"), 0.08, "noise", 0.3) tone(note("A4"), 0.12, "saw", 0.12) end  -- Leine reißt
function SFX.jump() tone(note("C5"), 0.12, "triangle", 0.18) end
function SFX.pieks() tone(note("B6"), 0.05, "square", 0.16) tone(note("E6"), 0.07, "saw", 0.12) end   -- Kaktus (E84)
function SFX.land() tone(420, 0.09, "noise", 0.22) end
function SFX.mount() tone(note("D5"), 0.05, "triangle", 0.2) tone(note("A5"), 0.07, "triangle", 0.2) end

-- ---- Pflege ----
function SFX.eat() tone(800, 0.04, "noise", 0.14) tone(600, 0.05, "noise", 0.12) end
function SFX.brush() tone(1200, 0.08, "noise", 0.07) end
function SFX.pet() tune("E5:0.5 G5:0.5", 500, "sine", 0.22, false, JINGLE) end

-- ---- Tageszeit ----
function SFX.dusk() tune("G5:1 E5:1 C5:2", 230, "sine", 0.2, false, JINGLE) end
function SFX.dawn() tune("C5:1 E5:1 G5:1 C6:2", 270, "sine", 0.2, false, JINGLE) end

-- ---- Musik: ruhige Melodie, nachts langsamer und leiser (E37), eine Oktave höher und etwas schneller (E67) ----
local SONGS = {
  day = {
    "C5 E5 G5 E5 A5:2 G5 E5 D5 C5:2 -",
    "E5 G5 C6 G5 A5:2 G5 E5 G5 D5:3 -",
    "C5 E5 G5 E5 A5:2 C6 A5 G5 E5:2 -",
    "D5 E5 G5 A5 G5:2 E5 D5 C5:3 -",
  },
  night = {
    "A4:2 E5:2 C5:2 -:2",
    "B4:2 G5:2 E5:3 -:1",
  },
}
local PLAY = {
  day = {bpm = 112, wave = "triangle", vol = 0.08},
  night = {bpm = 66, wave = "sine", vol = 0.07},
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
