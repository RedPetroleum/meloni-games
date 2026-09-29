-- Charakterzüge der Pferde. Ein Zug ist eine Tabelle mit Werten und optionalen Hooks:
--   speed          Schritttempo beim Herumlaufen
--   graze          Faktor für die Zeit, die das Pferd frisst oder steht
--   hint           Erklärung beim ersten Kontakt (%s = Name)
--   can_grab(h, ctx)  -> ok, text   darf man es jetzt am Halfter nehmen?
--   loose(h, ctx)                   jeden Frame, solange es frei herumläuft
--   led(h, ctx)    -> true          jeden Frame am Strick; true heißt: bleibt diesen Frame stehen
--   coax(h, ctx)   -> true          A am Strick: gut zureden
-- Neuer Zug = neuer Eintrag hier, im Level dann trait = "name".
local U = require("lib.util")

local Traits = {}

Traits.brav = {
  label = "brav", speed = 0.5,
  hint = "%s ist brav und kommt einfach mit.",
}

Traits.faul = {
  label = "faul", speed = 0.3, graze = 2,
  hint = "%s ist faul und bleibt gern stehen. A: gut zureden!",
  led = function(h, ctx)
    if h.stubborn > 0 then
      h.stubborn = h.stubborn - 1
      if h.stubborn == 0 then
        h:emote(nil)
        h.calm = 45  -- wer gerade noch A gedrückt hat, soll das Pferd nicht versehentlich loslassen
      end
      return true
    end
    if (h.calm or 0) > 0 then h.calm = h.calm - 1 end
    if ctx.player.moving and rnd(1) < 1 / 300 then
      h.stubborn = 110 + flr(rnd(90))
      h:emote("emo_zzz", h.stubborn)
      ctx.sfx.grumble()
      ctx.hint("faul_stop", h.name .. " bockt! A drücken: gut zureden.")
    end
  end,
  coax = function(h, ctx)
    if h.stubborn <= 0 then return (h.calm or 0) > 0 end
    h.stubborn = max(1, h.stubborn - 35)
    ctx.fx:spawn(h:head_x(), h.y - 26, {sprite = "heart", life = 30})
    ctx.sfx.coax()
    return true
  end,
}

Traits.scheu = {
  label = "scheu", speed = 0.6,
  hint = "%s ist scheu. Nicht rennen, langsam anschleichen!",
  loose = function(h, ctx)
    local p = ctx.player
    if h.state == "flee" or not p.moving or not p.running then return end
    if U.dist(h.x, h.y, p.x, p.y) < 64 then
      h:flee_from(p.x, p.y)
      ctx.sfx.whinny()
      ctx.hint("scheu_flee", h.name .. " erschrickt! Mit B rennst du, ohne B schleichst du.")
    end
  end,
}

Traits.verfressen = {
  label = "verfressen", speed = 0.45, graze = 1.5,
  hint = "%s kommt nur für eine Möhre mit.",
  can_grab = function(h, ctx)
    local p = ctx.player
    if p.carrots > 0 then
      p.carrots = p.carrots - 1
      return true, h.name .. " mampft die Möhre und kommt mit."
    end
    h:emote("emo_carrot", 90)
    return false, h.name .. " will erst eine Möhre! Die wachsen im Beet."
  end,
}

-- Ab hier die Zicken (Level 3). Sie bleiben schwierig, auch wenn man sie schon kennt.

-- Steht der Spieler vor dem Pferd (auf der Kopfseite)?
local FRONT = {right = {1, 0}, left = {-1, 0}, down = {0, 1}, up = {0, -1}}
local function in_front(h, p)
  local v = FRONT[h.dir] or FRONT.down
  return (p.x - h.x) * v[1] + (p.y - (h.y - 6)) * v[2] > 2
end

-- zickig: nur von vorne zu nehmen, sonst keilt sie aus. Am Strick nicht rennen, sonst reißt sie sich los.
Traits.zickig = {
  label = "zickig", speed = 0.55, graze = 1.2,
  hint = "%s ist zickig. Am Strick nicht rennen, sonst reißt sie sich los!",
  can_grab = function(h, ctx)
    local p = ctx.player
    if (h.sulk or 0) > 0 then
      h:emote("emo_storm", 60)
      return false, h.name .. " ist noch beleidigt. Kurz warten!"
    end
    if in_front(h, p) then return true end
    local dx, dy = p.x - h.x, p.y - (h.y - 4)
    local d = max(1, math.sqrt(dx * dx + dy * dy))
    p:knock(dx / d * 3, dy / d * 3, 14)
    h:flee_from(p.x, p.y)
    h.sulk = 150
    ctx.sfx.kick()
    return false, h.name .. " keilt aus! Zicken nur von vorne nehmen, am Kopf."
  end,
  loose = function(h)
    if (h.sulk or 0) > 0 then h.sulk = h.sulk - 1 end
  end,
  led = function(h, ctx)
    local p = ctx.player
    if p.moving and p.running then
      h.yank = (h.yank or 0) + 1
      if h.yank == 8 then h:emote("emo_bang", 30) ctx.sfx.grumble() end
      if h.yank > 24 then
        h.yank = 0
        ctx.release(h)
        h:flee_from(p.x, p.y)
        h.sulk = 150
        ctx.sfx.whinny()
        ctx.say(h.name .. " reißt sich los! Mit einer Zicke am Strick nicht rennen.")
        return true
      end
    elseif (h.yank or 0) > 0 then
      h.yank = h.yank - 1
    end
  end,
}

-- launisch: Die Laune wechselt. Bei Gewitterwolke lässt sie sich nicht nehmen und bleibt am
-- Strick stur stehen, gut zureden hilft nicht. Warten!
local function mood(h, ctx)
  if not h.mood_t then
    h.bad, h.mood_t = false, 120 + flr(rnd(240))
  end
  h.mood_t = h.mood_t - 1
  if h.mood_t > 0 then return h.bad end
  h.bad = not h.bad
  if h.bad then
    h.mood_t = 150 + flr(rnd(120))
    h:emote("emo_storm", h.mood_t)
    if h.led then
      ctx.sfx.grumble()
      ctx.hint("launisch_stop", h.name .. " hat plötzlich schlechte Laune. Warten, bis die Wolke weg ist.")
    end
  else
    h.mood_t = 300 + flr(rnd(300))
    h:emote(nil)
    h.stubborn = 0
  end
  return h.bad
end

Traits.launisch = {
  label = "launisch", speed = 0.5,
  hint = "%s ist launisch. Bei Gewitterwolke hilft nur warten.",
  can_grab = function(h, ctx)
    if h.bad then
      h:emote("emo_storm", max(h.mood_t, 30))
      return false, h.name .. " hat schlechte Laune. Warte, bis die Wolke weg ist!"
    end
    return true
  end,
  loose = function(h, ctx) mood(h, ctx) end,
  led = function(h, ctx)
    if mood(h, ctx) then
      h.stubborn = 1   -- hält den Strick fest
      return true
    end
  end,
  coax = function(h, ctx)
    if not h.bad then return false end
    ctx.say(h.name .. " lässt sich nicht bequatschen. Einfach warten.", 90)
    return true
  end,
}

-- diva: geht nur allein am Strick, kommt nur für eine Möhre mit und will unterwegs immer
-- wieder eine. Ohne Möhre bleibt sie stehen, bis man eine holt (A lässt sie dann los).
local function next_demand() return 300 + flr(rnd(180)) end

Traits.diva = {
  label = "Diva", speed = 0.45, graze = 1.5, alone = true,
  hint = "%s ist eine Diva: geht nur allein am Strick und will unterwegs Möhren.",
  can_grab = function(h, ctx)
    local p = ctx.player
    if p.carrots > 0 then
      p.carrots = p.carrots - 1
      h.demand = next_demand()
      return true, h.name .. " nimmt die Möhre gnädig an."
    end
    h:emote("emo_carrot", 90)
    return false, h.name .. " rührt ohne Möhre keinen Huf!"
  end,
  led = function(h, ctx)
    if h.stubborn > 0 then return true end
    if (h.calm or 0) > 0 then h.calm = h.calm - 1 end
    if ctx.player.moving then h.demand = (h.demand or next_demand()) - 1 end
    if (h.demand or 1) <= 0 then
      h.stubborn = 1
      h:emote("emo_carrot", 100000)
      ctx.sfx.grumble()
      ctx.hint("diva_stop", h.name .. " will eine Möhre! A: füttern. Ohne Möhre lässt A sie los.")
      return true
    end
  end,
  coax = function(h, ctx)
    if h.stubborn <= 0 then return (h.calm or 0) > 0 end
    local p = ctx.player
    if p.carrots <= 0 then return false end
    p.carrots = p.carrots - 1
    h.stubborn, h.demand, h.calm = 0, next_demand(), 45
    h:emote("emo_heart", 50)
    ctx.fx:spawn(h:head_x(), h.y - 26, {sprite = "icon_carrot", life = 30})
    ctx.sfx.carrot()
    ctx.say(h.name .. " mampft und stolziert weiter.", 90)
    return true
  end,
}

return Traits
