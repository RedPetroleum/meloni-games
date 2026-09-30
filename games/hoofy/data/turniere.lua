-- Erzeugt von tools/hoofy_katalog.py aus KATALOG.md §13 Turniere, nicht von Hand ändern.
return {
  klassen = {
    {
      id = "dorf",
      name = "Dorf",
      fahrzeug = "",
      gebuehr = 20,
      preise = {100, 50, 25},
    },
    {
      id = "kreis",
      name = "Kreis",
      fahrzeug = "fahrrad",
      gebuehr = 80,
      preise = {400, 200, 100},
    },
    {
      id = "bezirk",
      name = "Bezirk",
      fahrzeug = "mofa",
      gebuehr = 250,
      preise = {1500, 700, 350},
    },
    {
      id = "land",
      name = "Land",
      fahrzeug = "kleinwagen",
      gebuehr = 800,
      preise = {5000, 2500, 1200},
    },
    {
      id = "national",
      name = "National",
      fahrzeug = "suv",
      gebuehr = 2500,
      preise = {15000, 7000, 3500},
    },
    {
      id = "international",
      name = "International",
      fahrzeug = "flugzeug",
      gebuehr = 8000,
      preise = {50000, 25000, 12000},
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
}
