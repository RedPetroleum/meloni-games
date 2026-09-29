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

return Traits
