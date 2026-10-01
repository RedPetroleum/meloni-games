-- Titelbild: der Hof im Hintergrund, START oder A: los.
-- Neues Spiel über einem vorhandenen Spielstand fragt nach, weil der alte dabei überschrieben wird.
local Stage = require("game.stage")
local Save = require("game.save")
local U = require("lib.util")

local Title = {}

local ctx, t

local has_save, choice, confirm, info

function Title.enter()
  local snap = Save.read()
  has_save = snap ~= nil
  choice = has_save and 1 or 2      -- 1 = Weiter, 2 = Neues Spiel
  confirm = nil                     -- Nachfrage: 1 = Nein, zurück (vorgewählt), 2 = Ja, neu anfangen
  if snap then
    local n = #(snap.herd or {})
    info = "Tag " .. (snap.tag or 1) .. ", " .. n .. (n == 1 and " Pferd, " or " Pferde, ") .. (snap.geld or 0) .. " G"
  end
  ctx = snap and Stage.build(1, snap.seed, snap.hof) or Stage.build(1)
  ctx.player.frozen = true
  t = 0
end

function Title.update()
  t = t + 1
  ctx.world:update()
  if confirm then
    if btnp(BTN_UP) or btnp(BTN_DOWN) then confirm = 3 - confirm ctx.sfx.select() end
    if btnp(BTN_B) then confirm = nil ctx.sfx.back() return end
    if btnp(BTN_START) or btnp(BTN_A) then
      if confirm == 2 then ctx.sfx.start() return "intro" end
      confirm = nil
      ctx.sfx.back()
    end
    return
  end
  if has_save and (btnp(BTN_UP) or btnp(BTN_DOWN)) then
    choice = 3 - choice
    ctx.sfx.select()
  end
  if btnp(BTN_START) or btnp(BTN_A) then
    if choice == 2 and has_save then confirm = 1 ctx.sfx.select() return end
    ctx.sfx.start()
    if choice == 1 then return "world", {laden = true} end
    return "intro"
  end
end

function Title.draw()
  Stage.draw_world(ctx)
  local C = ctx.colors
  local title = "Hoofy"
  local x = (SCREEN_W - textw(title, 4)) // 2
  for dy = 1, 3 do print(title, x + 2, 20 + dy, C.panel, 4) end
  print(title, x, 20, C.gold, 4)
  if confirm then
    Stage.panel(24, 112, 295, 229)
    Stage.center("Neues Spiel beginnen?", 120, C.gold)
    local text = "Dein Spielstand (" .. info .. ") wird gelöscht: alle Pferde, der Hof, Geld und Fundstücke. "
      .. "Das lässt sich nicht rückgängig machen."
    for i, l in ipairs(U.wrap(text, 256)) do Stage.center(l, 124 + i * 11, C.text) end
    Stage.center((confirm == 1 and "> " or "  ") .. "Nein, zurück", 196, confirm == 1 and C.gold or C.dim)
    Stage.center((confirm == 2 and "> " or "  ") .. "Ja, alles löschen", 210, confirm == 2 and C.red or C.dim)
    return
  end
  Stage.panel(40, 182, 279, 225)
  if has_save then
    Stage.center((choice == 1 and "> " or "  ") .. "Weiter", 192, choice == 1 and C.gold or C.dim)
    Stage.center((choice == 2 and "> " or "  ") .. "Neues Spiel", 206, choice == 2 and C.gold or C.dim)
  elseif (t // 30) % 2 == 0 then
    Stage.center("START oder A: los!", 204, C.gold)
  end
end

return Title
