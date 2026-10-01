-- Vorspann vor einem neuen Spiel: die Story aus README_HOOFY.md (§1) in vier Bildern über dem abgedunkelten
-- Hof, der Text baut sich Buchstabe für Buchstabe auf. A: Text ganz zeigen bzw. weiter, START: überspringen.
local Stage = require("game.stage")
local Menu = require("game.menu")
local G = require("game.horse_gfx")
local U = require("lib.util")

local Intro = {}

local PAGES = {
  {pic = "autos", text = "Wir schreiben 2040. Aus dem KI-Boom wurde eine Wirtschaftskrise, und viele Autohersteller sind pleite."},
  {pic = "pferde", text = "Autos, Benzin und Strom sind sündhaft teuer geworden. Wer vorankommen will, reitet: Pferde sind gefragt wie nie."},
  {pic = "zeitung", text = "Aus Wut haben die Leute eine radikale Regierung gewählt. Ihre Reformen sind mal gut, mal völlig verrückt."},
  {pic = "hof", text = "Gut für dich, denn du bist Pferdezüchter! Ein Wohnwagen, ein kleiner Stall, 300 G. Im Heimattal grasen Wildpferde ..."},
}
local SPEED = 0.6            -- Buchstaben je Frame

local ctx, page, t, shown, done

function Intro.enter()
  ctx = Stage.build(1)
  ctx.player.frozen = true
  ctx.player.dead = true          -- nur der Hof im Hintergrund, ohne Figur
  page, t, shown, done = 1, 0, 0, false
end

function Intro.update()
  t = t + 1
  ctx.world:update()
  local text = PAGES[page].text
  shown = math.min(#text, shown + SPEED)
  if btnp(BTN_START) then ctx.sfx.start() return "world", {neu = true} end
  if btnp(BTN_A) then
    if shown < #text then shown = #text
    elseif page < #PAGES then page, shown, t = page + 1, 0, 0 ctx.sfx.select()
    else ctx.sfx.start() return "world", {neu = true} end
  end
end

-- Bilder in der oberen Hälfte (Mitte x 160, Boden bei y 132)
local DRAW = {}
function DRAW.autos(C)
  Menu.icon("fahrzeug_kleinwagen", 112, 112, 80)
  Menu.icon("fahrzeug_suv", 214, 108, 96)
  local s = "PLEITE"
  local w = textw(s, 2)
  rectfill(160 - w // 2 - 6, 52, 160 + w // 2 + 5, 75, C.red)
  rect(160 - w // 2 - 4, 54, 160 + w // 2 + 3, 73, C.text)
  print(s, 160 - w // 2, 57, C.text, 2)
end
function DRAW.pferde()
  local pose = (t // 8) % 2 == 0 and "gallop1" or "gallop2"
  local x = (t * 2) % 420 - 50
  G.draw("fuchs", "warmblut", pose, x, 132, false)
  G.draw("schimmel", "kaltblut", pose == "gallop1" and "gallop2" or "gallop1", x - 50, 128, false)
  G.draw("rappe", "pony", pose, x - 96, 134, false)
end
function DRAW.zeitung(C)
  Menu.icon("ico_zeitung", 160, 92, 72)
  local s = "REFORM!"
  print(s, 160 - textw(s, 2) // 2 + 2, 42, C.panel, 2)
  print(s, 160 - textw(s, 2) // 2, 40, C.gold, 2)
end
function DRAW.hof()
  local S = ctx.S
  local ww, wh = S.size("wohnwagen")
  local sw, sh = S.size("stable")
  S.draw("wohnwagen", 150 - ww - 22, 132 - wh)
  S.draw("stable", 170, 132 - sh)
  G.draw("brauner", "pony", "graze", 150, 134, true)
end

function Intro.draw()
  local C = ctx.colors
  Stage.draw_world(ctx)
  shade(C.panel, 0.7)
  DRAW[PAGES[page].pic](C)
  -- Text unten im Kasten, Seitenpunkte rechts
  Stage.panel(12, 150, 307, 229)
  local full = PAGES[page].text
  local n = flr(shown)
  while n < #full and full:byte(n + 1) & 0xC0 == 0x80 do n = n + 1 end   -- Umlaute nicht halbieren
  -- erst umbrechen, dann aufdecken: Wörter springen beim Tippen nicht in die nächste Zeile
  for i, l in ipairs(U.wrap(full, 276)) do
    if n <= 0 then break end
    print(l:sub(1, n), 22, 148 + i * 12, C.text)
    n = n - #l - 1
  end
  for i = 1, #PAGES do
    local x = 298 - (#PAGES - i) * 8
    rectfill(x, 154, x + 3, 157, i == page and C.gold or C.panel_light)
  end
  print("A: weiter", 22, 216, shown >= #full and C.gold or C.dim)
  print("START: überspringen", 22 + textw("A: weiter   "), 216, C.dim)
end

return Intro
