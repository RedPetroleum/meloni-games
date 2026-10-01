-- Freischalten im Spielverlauf (Rückmeldung 0.5.2, E65): damit der Anfang nicht überfordert, kommen
-- Bestellungen, Käufer, Turniere, Tauschen und die Zeitung (Reformen) erst nach und nach dazu, nach Spieltag.
local F = {}

-- ab diesem Tag
F.AB = {
  bestellungen = 4,      -- Bestellungen kommen an Tag 1, 4, 7 …: die erste an Tag 4
  kaeufer = 5,           -- Reithof, Züchter, Schlachter im Dorf
  turnier = 7,
  sammlerin = 9,
  tauschen = 9,
  zeitung = 10,          -- erste Reform; Hunde frühestens ab F.AB.hunde
  hunde = 16,
}

-- Meldung am Morgen des Tages, an dem etwas neu dazukommt
F.TEXT = {
  bestellungen = "Neu: Kunden bestellen Pferde (Pause → Kunden).",
  kaeufer = "Neu: Im Dorf wartet tagsüber ein Käufer mit ❗.",
  turnier = "Neu: Der Turnierplatz im Dorf hat geöffnet.",
  sammlerin = "Neu: Auch eine Sammlerin kommt jetzt ins Dorf. Tauschen im Pausenmenü.",
  zeitung = "Neu: Die Zeitung erscheint (Pause → Zeitung).",
}

-- Ist `was` an Tag `day` schon da?
function F.offen(was, day)
  return (day or 1) >= F.AB[was]
end

-- Tag aus dem Spielzustand (ohne Uhr: Tag 1)
function F.tag(ctx)
  return ctx.clock and ctx.clock.day or 1
end

-- Meldungen für die Dinge, die genau an Tag `day` neu sind (Liste, meist leer).
function F.neu(day)
  local out = {}
  for _, was in ipairs({"bestellungen", "kaeufer", "turnier", "sammlerin", "zeitung"}) do
    if F.AB[was] == day then out[#out + 1] = F.TEXT[was] end
  end
  return out
end

return F
