class_name HoofyDaten
## Rassen, Farben und Charakterzüge aus dem 2D-Hoofy (data/hoofy.json, erzeugt von
## tools/hoofy_daten.py) plus das, was nur 3D braucht: Körpermaße und Fellfarben.

static var _daten: Dictionary

## Körperbau je Hoofy-Körpertyp: Stockmaß in Metern und Breite relativ zum Warmblut.
const KOERPER := {
	"pony": {"stockmass": 1.30, "breite": 1.08},
	"warmblut": {"stockmass": 1.65, "breite": 1.0},
	"kaltblut": {"stockmass": 1.62, "breite": 1.22},
	"einhorn": {"stockmass": 1.70, "breite": 0.95},
}

## Muster für den Fell-Shader (shaders/fell.gdshader).
enum Muster { KEINS, SCHECKE, TUPFEN, STREIFEN, APFEL, STICHEL, REGENBOGEN }

## Fell, Abzeichen (Beine/Muster) und Glanz je Hoofy-Farbe.
const FELL := {
	"brauner": {"fell": Color(0.33, 0.17, 0.08), "beine": Color(0.05, 0.04, 0.035)},
	"fuchs": {"fell": Color(0.55, 0.26, 0.11)},
	"dunkelbrauner": {"fell": Color(0.17, 0.09, 0.05), "beine": Color(0.04, 0.03, 0.03)},
	"hellfuchs": {"fell": Color(0.74, 0.44, 0.22)},
	"rappe": {"fell": Color(0.045, 0.04, 0.04)},
	"grauschimmel": {"fell": Color(0.52, 0.52, 0.52), "muster": Muster.STICHEL, "abzeichen": Color(0.8, 0.8, 0.8)},
	"falbe": {"fell": Color(0.72, 0.56, 0.34), "beine": Color(0.08, 0.06, 0.05)},
	"isabell": {"fell": Color(0.86, 0.73, 0.52)},
	"schimmel": {"fell": Color(0.88, 0.87, 0.84)},
	"dunkelfuchs": {"fell": Color(0.33, 0.13, 0.06)},
	"mausfalbe": {"fell": Color(0.43, 0.39, 0.34), "beine": Color(0.08, 0.07, 0.07)},
	"rotschimmel": {"fell": Color(0.58, 0.36, 0.3), "muster": Muster.STICHEL, "abzeichen": Color(0.85, 0.82, 0.8)},
	"braunschecke": {"fell": Color(0.33, 0.17, 0.08), "muster": Muster.SCHECKE},
	"palomino": {"fell": Color(0.86, 0.64, 0.3)},
	"rappschecke": {"fell": Color(0.045, 0.04, 0.04), "muster": Muster.SCHECKE},
	"fuchsschecke": {"fell": Color(0.55, 0.26, 0.11), "muster": Muster.SCHECKE},
	"apfelschimmel": {"fell": Color(0.55, 0.55, 0.56), "muster": Muster.APFEL, "abzeichen": Color(0.86, 0.86, 0.86)},
	"fliegenschimmel": {"fell": Color(0.9, 0.89, 0.86), "muster": Muster.TUPFEN, "abzeichen": Color(0.35, 0.2, 0.12), "tupfen": 0.12},
	"silberrappe": {"fell": Color(0.22, 0.17, 0.14)},
	"windfarben": {"fell": Color(0.3, 0.22, 0.18), "muster": Muster.APFEL, "abzeichen": Color(0.5, 0.42, 0.38)},
	"tigerschecke": {"fell": Color(0.9, 0.89, 0.86), "muster": Muster.TUPFEN, "abzeichen": Color(0.06, 0.05, 0.05)},
	"cremello": {"fell": Color(0.93, 0.86, 0.72)},
	"perlino": {"fell": Color(0.9, 0.8, 0.66)},
	"champagner": {"fell": Color(0.8, 0.6, 0.42), "glanz": 0.5},
	"rosa": {"fell": Color(0.95, 0.62, 0.72)},
	"mintgruen": {"fell": Color(0.55, 0.88, 0.74)},
	"gold": {"fell": Color(0.95, 0.72, 0.26), "glanz": 1.0},
	"regenbogen": {"fell": Color(1, 1, 1), "muster": Muster.REGENBOGEN},
	"lila": {"fell": Color(0.58, 0.4, 0.85)},
	"zebra": {"fell": Color(0.92, 0.91, 0.88), "muster": Muster.STREIFEN, "abzeichen": Color(0.04, 0.035, 0.035)},
}


static func daten() -> Dictionary:
	if _daten.is_empty():
		var text := FileAccess.get_file_as_string("res://data/hoofy.json")
		_daten = JSON.parse_string(text)
	return _daten


static func rassen(gebiet := 99) -> Array:
	return daten().rassen.liste.filter(func(r): return r.gebiet <= gebiet)


static func rasse(id: String) -> Dictionary:
	for r in daten().rassen.liste:
		if r.id == id:
			return r
	return {}


static func farbe_name(id: String) -> String:
	for f in daten().farben.liste:
		if f.id == id:
			return f.name
	return id


## Seltenheitsstufe einer Farbe, z. B. "selten"
static func farbe_stufe(id: String) -> String:
	for f in daten().farben.liste:
		if f.id == id:
			return daten().farben.stufen[int(f.stufe) - 1].name
	return ""


static func beschreibung(pferd: Dictionary) -> String:
	return "%s · %s · %s" % [rasse(pferd.rasse).get("name", pferd.rasse), farbe_name(pferd.farbe), "Stute" if pferd.stute else "Hengst"]


## Zufällige Farbe nach den Seltenheitsstufen aus Hoofy (Anteil in Prozent).
static func zufallsfarbe(rng: RandomNumberGenerator) -> String:
	var stufen: Array = daten().farben.stufen
	var wurf := rng.randf() * 100.0
	for s in stufen:
		wurf -= s.anteil
		if wurf <= 0.0:
			return s.farben[rng.randi() % s.farben.size()]
	return stufen[0].farben[0]


## Ein Pferd wie in Hoofy: Rasse, Farbe, Geschlecht, Charakterzug, Gen-Werte.
static func neues_pferd(rng: RandomNumberGenerator, gebiet := 1, rasse_id := "") -> Dictionary:
	var r: Dictionary = rasse(rasse_id) if rasse_id else rassen(gebiet)[rng.randi() % rassen(gebiet).size()]
	var sigma: float = daten().stats.gen_sigma
	var gen := func(basis: float) -> int: return clampi(roundi(rng.randfn(basis, sigma)), 1, 100)
	var charaktere: Array = daten().charakter.keys()
	return {
		"name": "",
		"rasse": r.id,
		"farbe": zufallsfarbe(rng),
		"stute": rng.randf() < 0.5,
		"charakter": charaktere[rng.randi() % charaktere.size()],
		"tempo": gen.call(r.tempo),
		"staerke": gen.call(r.staerke),
		"ausdauer": clampi(roundi(rng.randfn(r.ausdauer, sigma)), 50, 100),
		"bindung": gen.call(r.bindung),
	}
