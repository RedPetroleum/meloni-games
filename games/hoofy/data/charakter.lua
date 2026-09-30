-- Erzeugt von tools/hoofy_katalog.py aus KATALOG.md §5 Charakterzüge, nicht von Hand ändern.
return {
  verfressen = {
    name = "verfressen",
    emoji = "🥕🍎",
    text = "Hunger +35 statt +25 pro Tag",
    hunger_pro_tag = 35,
  },
  schreckhaft = {
    name = "schreckhaft",
    emoji = "😱",
    text = "Ausreiß-Chance ×1,5, flieht vor Tieren",
    ausreiss_faktor = 1.5,
    flieht = true,
  },
  faul = {
    name = "faul",
    emoji = "😴",
    text = "Trainingszuwachs −20 %",
    training_malus = 20,
  },
  eitel = {
    name = "eitel",
    emoji = "💅✨",
    text = "Sauberkeit wirkt doppelt auf Bindung",
    sauberkeit_faktor = 2,
  },
  nachteule = {
    name = "Nachteule",
    emoji = "🦉🌙",
    text = "nachts +20 Energie, morgens −10",
    nacht_energie = 20,
    morgen_energie = -10,
  },
}
