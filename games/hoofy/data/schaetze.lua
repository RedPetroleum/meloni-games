-- Erzeugt von tools/hoofy_katalog.py aus KATALOG.md §11 Schätze, nicht von Hand ändern.
return {
  radius_basis = 2,
  radius_teiler = 10,
  chance_teiler = 2,
  fund_training = 1,
  funde = {
    {
      id = "blume",
      name = "Blume",
      wert = 5,
      haeufigkeit = "sehr häufig",
    },
    {
      id = "samen",
      name = "Samen",
      wert = 0,
      haeufigkeit = "häufig",
      samen = true,
    },
    {
      id = "muenzbeutel",
      name = "Münzbeutel",
      wert = 30,
      haeufigkeit = "häufig",
    },
    {
      id = "goldhufeisen",
      name = "Goldhufeisen",
      wert = 200,
      haeufigkeit = "selten",
    },
    {
      id = "antiquitaet",
      name = "Antiquität",
      wert = 500,
      haeufigkeit = "sehr selten",
    },
    {
      id = "schatztruhe",
      name = "Schatztruhe",
      wert = 1500,
      haeufigkeit = "legendär",
      gebiet = 3,
    },
  },
}
