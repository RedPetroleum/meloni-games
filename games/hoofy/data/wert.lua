-- Erzeugt von tools/hoofy_katalog.py aus KATALOG.md §6 Pferdewert, nicht von Hand ändern.
return {
  leistung_teiler = 400,
  ausdauer_basis = 50,
  ausdauer_faktor = 2,
  leistung_basis = 0.5,
  fohlen_faktor = 0.6,
  kauf_faktor = 1.5,
  kaeufer = {
    sammlerin = {
      basis = 1,
      farbe = 0.1,
      min_sauberkeit = 70,
    },
    reithof = {
      faktor = 0.7,
      basis = 0.5,
      teiler = 100,
      bindung_andere = 5,
    },
    zuechter = {
      basis = 0.8,
      teiler = 600,
      hengst = 1.25,
      bindung_andere = -5,
    },
    schlachter = {
      faktor = 0.9,
      teiler = 50,
      bindung_andere = -20,
    },
    bestellung = {
      faktor = 1.5,
      alle_tage = 3,
      frist_min = 5,
      frist_max = 10,
    },
  },
}
