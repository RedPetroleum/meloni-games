-- Erzeugt von tools/hoofy_katalog.py aus KATALOG.md §6 Pferdewert, nicht von Hand ändern.
return {
  exponent = 1.5,
  bindung_gewicht = 0.5,
  leistung_teiler = 4.5,
  steigung = 1.66,
  faktor_min = 0.3,
  stammbaum = {5, 3, 2},
  fohlen_faktor = 0.6,
  kauf_faktor = 1.5,
  kaeufer = {
    sammlerin = {
      farbe = 0.15,
      laune_min = 0.9,
      laune_max = 1.1,
      min_sauberkeit = 90,
      min_stufe = 2,
    },
    reithof = {
      basis = 0.6,
      bindung_ab = 70,
      teiler = 100,
      min_bindung = 70,
      min_sauberkeit = 50,
      max_hunger = 30,
    },
    zuechter = {
      stute = 1.05,
      hengst = 0.95,
      min_bindung = 50,
      min_sauberkeit = 50,
    },
    schlachter = {
      gewicht_basis = 50,
      gewicht_teiler = 20,
      staerke_basis = 0.9,
      staerke_teiler = 400,
      min_gewicht = 50,
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
