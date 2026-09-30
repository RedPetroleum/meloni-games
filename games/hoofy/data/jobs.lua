-- Erzeugt von tools/hoofy_katalog.py aus KATALOG.md §12 Jobs, nicht von Hand ändern.
return {
  liste = {
    {
      id = "postritt",
      name = "Postritt",
      braucht = "bindung",
      braucht_wert = 40,
      lohn_basis = 15,
      lohn_stat = "tempo",
      lohn_teiler = 2,
      training = {
        tempo = 2,
        ausdauer = 1,
      },
      energie = 30,
    },
    {
      id = "kutschtaxi",
      name = "Kutschtaxi",
      braucht = "staerke",
      braucht_wert = 30,
      lohn_basis = 15,
      lohn_stat = "staerke",
      lohn_teiler = 2,
      training = {
        staerke = 2,
        ausdauer = 1,
      },
      energie = 30,
    },
    {
      id = "pfluegen",
      name = "Pflügen",
      braucht = "staerke",
      braucht_wert = 50,
      lohn_basis = 25,
      lohn_stat = "staerke",
      lohn_teiler = 3,
      training = {
        staerke = 3,
        ausdauer = 1,
      },
      energie = 40,
    },
  },
  pro_tag = 1,
}
