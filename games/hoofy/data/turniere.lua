-- Erzeugt von tools/hoofy_katalog.py aus KATALOG.md §13 Turniere, nicht von Hand ändern.
return {
  klassen = {
    {
      id = "dorf",
      name = "Dorf",
      fahrzeug = "",
      gebuehr = 10,
      preise = {50, 25, 10},
    },
    {
      id = "kreis",
      name = "Kreis",
      fahrzeug = "fahrrad",
      gebuehr = 40,
      preise = {200, 100, 50},
    },
    {
      id = "bezirk",
      name = "Bezirk",
      fahrzeug = "mofa",
      gebuehr = 120,
      preise = {750, 350, 180},
    },
    {
      id = "land",
      name = "Land",
      fahrzeug = "kleinwagen",
      gebuehr = 400,
      preise = {2500, 1200, 600},
    },
    {
      id = "national",
      name = "National",
      fahrzeug = "suv",
      gebuehr = 1200,
      preise = {7500, 3500, 1800},
    },
    {
      id = "international",
      name = "International",
      fahrzeug = "flugzeug",
      gebuehr = 4000,
      preise = {25000, 12000, 6000},
    },
  },
  wettbewerbe = {
    {
      id = "schoenheitswettbewerb",
      name = "Schönheitswettbewerb",
      text = "Seltenheit Farbe + Rasse, Sauberkeit, Schmuck",
    },
    {
      id = "springreiten",
      name = "Springreiten (Minispiel)",
      text = "Stärke → Sprunghöhe, Ausdauer → Parcours ohne Leistungsabfall",
    },
    {
      id = "pferderennen",
      name = "Pferderennen (Minispiel)",
      text = "Tempo → Höchstgeschwindigkeit, Ausdauer → wie lange sie hält",
    },
  },
  rotation_tage = 3,
  wertung_basis = 0.5,
  wertung_teiler = 200,
  gegner_basis = 15,
  gegner_klasse = 12,
  gegner_streuung = 12,
  stange_basis = 18,
  stange_klasse = 3,
}
