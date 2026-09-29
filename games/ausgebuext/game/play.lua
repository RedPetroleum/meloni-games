-- Die Spielszene: Regeln eines Levels (Pferde einfangen, heimbringen, Uhr), Anzeige, Pause.
local Stage = require("game.stage")
local Levels = require("game.levels")
local Save = require("game.save")
local U = require("lib.util")

local Play = {}

local GRAB_RANGE = 22     -- Abstand zum Pferdekörper
local ROPE_MAX = 44      -- weiter lässt sich ein bockendes Pferd nicht ziehen
local MSG_TIME = 180

local ctx, level, level_no
local state, timer, home_count, lead, msg, msg_t, hints_seen, result_t, anim_frame

local function say(text, frames)
  msg, msg_t = U.wrap(text, SCREEN_W - 16), frames or MSG_TIME
end

-- Zeigt einen Hinweis nur beim ersten Mal (pro Level-Versuch).
local function hint(key, text)
  if hints_seen[key] then return end
  hints_seen[key] = true
  say(text, 240)
end

local function update_lead_distances()
  for i, h in ipairs(lead) do h.lead_dist = 16 + i * 20 end
end

local function grab(h)
  local t = h.trait
  if #lead >= level.lead then
    say(level.lead == 1 and "Du kannst nur ein Pferd auf einmal führen." or
      "Mehr als " .. level.lead .. " Pferde auf einmal gehen nicht.")
    ctx.sfx.deny()
    return
  end
  local ok, text = true, nil
  if t.can_grab then ok, text = t.can_grab(h, ctx) end
  if not ok then
    say(text)
    ctx.sfx.deny()
    return
  end
  h.led, h.state, h.grazing = true, "led", false
  lead[#lead + 1] = h
  update_lead_distances()
  h:emote("emo_heart", 50)
  ctx.sfx.grab()
  if text then say(text) end
  if not hints_seen["trait_" .. h.name] and t.hint then
    hint("trait_" .. h.name, string.format(t.hint, h.name))
  end
end

local function release(h)
  h.led = false
  for i, other in ipairs(lead) do
    if other == h then table.remove(lead, i) break end
  end
  update_lead_distances()
  h.stubborn = 0
  h:emote(nil)
  h:idle(90)
  ctx.sfx.release()
end

local function bring_home(h)
  release(h)
  h.home = true
  home_count = home_count + 1
  for i = 1, 4 do
    ctx.fx:spawn(h.x - 8 + i * 4, h.y - 20, {sprite = "heart", vx = (i - 2.5) * 0.2, vy = -0.6, life = 45})
  end
  h:emote("emo_heart", 80)
  ctx.sfx.home()
  if home_count < #ctx.horses then
    say(h.name .. " ist zu Hause! Noch " .. (#ctx.horses - home_count) .. ".")
  end
end

-- A: Pferd nehmen, bockendem Pferd gut zureden, Möhre ernten oder loslassen.
local function interact()
  local p = ctx.player
  local h, best = nil, GRAB_RANGE
  for _, e in ipairs(ctx.horses) do
    if not e.led and not e.home and e.state ~= "flee" then
      local d = e:distance_to(p.x, p.y - 6)
      if d <= best then h, best = e, d end
    end
  end
  if h then return grab(h) end
  for _, lh in ipairs(lead) do
    if lh.trait.coax and lh.trait.coax(lh, ctx) then return end
  end
  if ctx.map:tag_at(p.x, p.y) == "carrots" then
    if p.carrots >= 3 then
      say("Mehr Möhren passen nicht in die Taschen.")
      return
    end
    p.carrots = p.carrots + 1
    ctx.fx:spawn(p.x, p.y - 22, {sprite = "icon_carrot", life = 30})
    ctx.sfx.carrot()
    hint("carrot", "Eine Möhre! Manche Pferde kommen nur dafür mit.")
    return
  end
  if #lead > 0 then
    local last = lead[#lead]
    release(last)
    say(last.name .. " ist wieder frei.")
  end
end

function Play.enter(n)
  level_no = n
  level = Levels[n]
  ctx = Stage.build(level)
  ctx.say, ctx.hint = say, hint
  state = "play"
  timer = level.time * 60
  home_count, lead, hints_seen = 0, {}, {}
  msg, msg_t, result_t, anim_frame = nil, 0, 0, 1
  say("Level " .. n .. ": " .. level.intro, 240)
  ctx.sfx.music(true)
end

local function finish(won)
  state = won and "won" or "lost"
  result_t = 0
  ctx.player.frozen = true
  ctx.sfx.music(false)
  if won then
    ctx.sfx.win()
    Save.level_done(level_no, timer, #Levels)
  else
    ctx.sfx.lose()
  end
end

-- Liefert beim Verlassen der Szene den Namen der nächsten Szene (und Argumente).
function Play.update()
  if state == "pause" then
    if btnp(BTN_START) then state = "play" end
    return
  end
  if state == "won" or state == "lost" then
    result_t = result_t + 1
    ctx.world:update()
    ctx.fx:update()
    if result_t > 30 then
      if btnp(BTN_A) or btnp(BTN_START) then
        if state == "lost" then return "play", level_no end
        if level_no < #Levels then return "play", level_no + 1 end
        return "title"
      end
      if btnp(BTN_B) then return "title" end
    end
    return
  end
  if btnp(BTN_START) then state = "pause" return end

  if btnp(BTN_A) then interact() end
  ctx.world:update()
  ctx.fx:update()

  local p = ctx.player
  for _, h in ipairs(lead) do
    -- Ein bockendes Pferd hält den Strick fest.
    if h.stubborn > 0 then
      local d = U.dist(h.x, h.y, p.x, p.y)
      if d > ROPE_MAX then
        p.x = h.x + (p.x - h.x) * ROPE_MAX / d
        p.y = h.y + (p.y - h.y) * ROPE_MAX / d
      end
    end
  end
  for i = #lead, 1, -1 do
    local h = lead[i]
    if ctx.map:tag_at(h.x, h.y) == "paddock" then bring_home(h) end
  end
  ctx.camera:follow(p.x, p.y - 10)

  local frame_no = (timer // 40) % 2 + 1
  if frame_no ~= anim_frame then
    anim_frame = frame_no
    ctx.map:set_anim_frame(frame_no)
  end

  if msg_t > 0 then
    msg_t = msg_t - 1
    if msg_t == 0 then msg = nil end
  end
  timer = timer - 1
  if timer <= 600 and timer % 60 == 0 and timer > 0 then ctx.sfx.tick() end
  if timer == 1800 then say("Die Sonne geht bald unter!") end
  if home_count == #ctx.horses then
    finish(true)
  elseif timer <= 0 then
    timer = 0
    finish(false)
  end
end

local function draw_rope()
  local C = ctx.colors
  local hx, hy = ctx.player:hand()
  for _, h in ipairs(lead) do
    local ax, ay = h:head_x(), h:head_y()
    local d = U.dist(hx, hy, ax, ay)
    local sag = max(0, 12 - d / 4)
    local mx, my = (hx + ax) / 2, (hy + ay) / 2 + sag
    line(hx, hy + 1, mx, my + 1, C.rope_dark)
    line(mx, my + 1, ax, ay + 1, C.rope_dark)
    line(hx, hy, mx, my, C.rope)
    line(mx, my, ax, ay, C.rope)
    hx, hy = h.x + (h.dir == "right" and -12 or h.dir == "left" and 12 or 0), h.y - 12
  end
end

local function panel(x0, y0, x1, y1)
  local C = ctx.colors
  rectfill(x0, y0, x1, y1, C.panel)
  rect(x0 + 1, y0 + 1, x1 - 1, y1 - 1, C.panel_light)
end

local function center(text, y, c, scale)
  print(text, (SCREEN_W - textw(text, scale)) // 2, y, c, scale)
end

local function draw_hud()
  local C, S = ctx.colors, ctx.S
  rectfill(0, 0, SCREEN_W - 1, Stage.HUD_H - 1, C.panel)
  for i, h in ipairs(ctx.horses) do
    S.draw(h.home and "icon_horse" or "icon_horse_empty", 4 + (i - 1) * 12, 3)
  end
  local x = 8 + #ctx.horses * 12
  if ctx.player.carrots > 0 then
    S.draw("icon_carrot", x, 3)
    print("x" .. ctx.player.carrots, x + 7, 3, C.text)
  end
  local name = level.name
  print(name, (SCREEN_W - textw(name)) // 2, 3, C.dim)
  local clock = U.clock(timer)
  local tw = textw(clock)
  local late = timer <= 30 * 60
  S.draw(late and "icon_moon" or "icon_sun", SCREEN_W - tw - 14, 3)
  print(clock, SCREEN_W - tw - 4, 3, late and C.red or C.text)
  if msg then
    local y = SCREEN_H - 6 - #msg * 10
    rectfill(0, y, SCREEN_W - 1, SCREEN_H - 1, C.panel)
    for i, text in ipairs(msg) do center(text, y + 4 + (i - 1) * 10, C.text) end
  end
end

function Play.draw()
  Stage.draw_world(ctx, draw_rope)
  draw_hud()
  local C = ctx.colors
  if state == "pause" then
    panel(90, 90, 230, 140)
    center("Pause", 100, C.gold, 2)
    center("START: weiter", 124, C.text)
  elseif state == "won" and result_t > 20 then
    panel(40, 64, 280, 176)
    center("Geschafft!", 76, C.gold, 2)
    center("Alle Pferde sind auf der Koppel.", 100, C.text)
    center("Restzeit " .. U.clock(timer), 116, C.text)
    local best = Save.best(level_no)
    if best then center("Beste Restzeit " .. U.clock(best), 130, C.dim) end
    center(level_no < #Levels and "A: nächstes Level  B: Titel" or "Alle Level geschafft!  A: Titel", 156, C.text)
  elseif state == "lost" and result_t > 20 then
    panel(40, 70, 280, 170)
    center("Die Sonne ist weg!", 82, C.red, 2)
    center(home_count .. " von " .. #ctx.horses .. " Pferden sind zu Hause.", 108, C.text)
    center("A: nochmal  B: Titel", 146, C.text)
  end
end

return Play
