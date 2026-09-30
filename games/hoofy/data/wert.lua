-- Erzeugt von tools/hoofy_katalog.py aus KATALOG.md §6 Pferdewert, nicht von Hand ändern.
return {
  leistung_teiler = 400,
  ausdauer_basis = 50,
  ausdauer_faktor = 2,
  leistung_basis = 0.5,
  fohlen_faktor = 0.6,
  kauf_faktor = 1.3,
  kaeufer = {
    sammlerin = {
      faktor = 1.5,
      min_sauberkeit = 70,
    },
    reithof = {
      faktor = 0.7,
      basis = 0.5,
      teiler = 100,
      bindung_andere = 5,
    },
    zuechter = {
      teiler = 300,
      hengst = 1.5,
      bindung_andere = -5,
    },
    schlachter = {
      faktor = 5,
      teiler = 50,
      grundwert = 0.3,
      bindung_andere = -10,
    },
    bestellung = {
      faktor = 1.5,
      alle_tage = 3,
      frist_min = 5,
      frist_max = 10,
    },
  },
}
