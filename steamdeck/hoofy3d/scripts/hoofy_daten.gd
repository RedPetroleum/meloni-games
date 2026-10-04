class_name HoofyDaten
## Rassen, Farben, Werte, Charakterzüge und Namen aus dem 2D-Hoofy (data/hoofy.json, erzeugt von
## tools/hoofy_daten.py) und die Regeln dazu wie in games/hoofy/game/horse_model.lua, plus das,
## was nur 3D braucht: Körpermaße und Fellfarben.

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
	"zebra": {"fell": Color(0.92, 0.91, 0.88), "muster": Muster.STREIFEN, "abzeichen": Color(0.04, 0.035, 0.035), "maehne": Color(0.12, 0.11, 0.1)},
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


## Anteile der Farbstufen in Gebiet n (Prozent): pro Gebietsstufe gehen Punkte von „häufig“
## an die selteneren Stufen, im Verhältnis ihrer Anteile (wie H.tier_shares im 2D-Hoofy).
static func stufen_anteile(gebiet: int) -> Array:
	var st: Array = daten().farben.stufen
	var verschiebung: float = daten().farben.gebiet_verschiebung * (gebiet - 1)
	var rest := 0.0
	for i in range(1, st.size()):
		rest += st[i].anteil
	var aus := [st[0].anteil - verschiebung]
	for i in range(1, st.size()):
		aus.append(st[i].anteil + verschiebung * st[i].anteil / rest)
	return aus


## Stufe würfeln; erlaubt[i] = false: Stufe fällt weg, ihr Anteil verteilt sich. ab: nur Stufen ab dieser.
static func _stufe_wuerfeln(anteile: Array, erlaubt: Array, rng: RandomNumberGenerator, ab := 0) -> int:
	var summe := 0.0
	for i in range(ab, anteile.size()):
		if erlaubt[i]:
			summe += anteile[i]
	var r := rng.randf() * summe
	for i in range(ab, anteile.size()):
		if erlaubt[i]:
			r -= anteile[i]
			if r < 0.0:
				return i
	for i in range(anteile.size() - 1, ab - 1, -1):
		if erlaubt[i]:
			return i
	return -1


## Farben eines Wildpferds wie im 2D-Hoofy: sichtbar nach der Farbtabelle der Rasse,
## versteckt gleich selten oder seltener. Gibt [sichtbar, versteckt] zurück.
static func wildfarben(rasse_id: String, gebiet: int, rng: RandomNumberGenerator) -> Array:
	var je_stufe: Array = daten().farben.matrix[rasse_id]
	var erlaubt := je_stufe.map(func(l: Array) -> bool: return l.size() > 0)
	var anteile := stufen_anteile(gebiet)
	var t := _stufe_wuerfeln(anteile, erlaubt, rng)
	var t2 := _stufe_wuerfeln(anteile, erlaubt, rng, t)
	if t2 < 0:
		t2 = t
	return [je_stufe[t][rng.randi() % je_stufe[t].size()], je_stufe[t2][rng.randi() % je_stufe[t2].size()]]


## Rasse eines Wildpferds in Gebiet n: Rassen dieses Gebiets dreifach, frühere einfach.
static func wildrasse(gebiet: int, rng: RandomNumberGenerator) -> String:
	var liste := rassen(gebiet)
	var summe := 0.0
	for r in liste:
		summe += 3.0 if r.gebiet == gebiet else 1.0
	var x := rng.randf() * summe
	for r in liste:
		x -= 3.0 if r.gebiet == gebiet else 1.0
		if x < 0.0:
			return r.id
	return liste[-1].id


const STATS := ["tempo", "staerke", "spuer", "ausdauer"]


## Neues Wildpferd wie H.wild im 2D-Hoofy (gleiche Felder, damit Spielstände und Tauschcodes
## später zusammenpassen). belegt: Namen, die schon vergeben sind.
static func wildpferd(rng: RandomNumberGenerator, gebiet := 1, rasse_id := "", belegt: Array = []) -> Dictionary:
	var r := rasse(rasse_id if rasse_id else wildrasse(gebiet, rng))
	var st: Dictionary = daten().stats
	var zuege: Array = daten().charakter.keys()
	var h := {
		"rasse": r.id, "wild": true, "alter": 1,
		"sex": "m" if rng.randf() < 0.5 else "w",
		"zug": zuege[rng.randi() % zuege.size()],
		"gen": {}, "train": {}, "pot": {},
	}
	for key in STATS:
		var lo: int = st.gen_min
		var hi: int = st.gen_max
		if key == "ausdauer":
			lo = st.ausdauer_min
			hi = st.ausdauer_max
		var g := clampi(roundi(r[key] + rng.randfn(0.0, st.gen_sigma)), lo, hi)
		var pot := roundi(g + r.spanne + rng.randfn(0.0, st.potenzial_sigma))
		h.gen[key] = g
		h.train[key] = 0
		h.pot[key] = clampi(pot, g, st.potenzial_max)
	var farben := wildfarben(r.id, gebiet, rng)
	h.farbe = farben[0]
	h.farbe2 = farben[1]
	h.bindung = clampi(int(r.bindung) + int(daten().zug_bindung[h.zug]) + roundi((rng.randf() * 2.0 - 1.0) * 5.0), 0, 100)
	h.hunger = st.hunger.start
	h.gewicht = st.gewicht.start
	h.sauberkeit = st.sauberkeit.start
	h.energie = stat(h, "ausdauer")
	h.name = freier_name(rng, h.sex, belegt)
	return h


## Gesamtwert eines Stats: Gen + Training, höchstens Max-Potenzial (H.stat)
static func stat(h: Dictionary, key: String) -> int:
	return mini(int(h.gen[key]) + int(h.train[key]), int(h.pot[key]))


## Name aus den Hoofy-Listen, der zum Geschlecht passt und noch frei ist
## Wirksamer Wert: Tempo und Stärke mit Gewichtsmalus (Care.effective im 2D-Hoofy)
static func wirksam(h: Dictionary, key: String) -> float:
	var v := float(stat(h, key))
	if key == "tempo" or key == "staerke":
		var g: Dictionary = daten().stats.gewicht
		var ueber: float = absf(float(h.get("gewicht", g.start)) - g.start) - g.toleranz
		if ueber > 0.0:
			v *= maxf(0.0, 1.0 - ueber * g.malus_prozent / 100.0)
	return v


## Tempo fürs Reiten: wirksames Tempo + Sattel-Bonus, der über das Potenzial hinaus zählt (R.tempo)
static func reittempo(h: Dictionary) -> float:
	var bonus := 0.0
	if h.get("sattel"):
		for a in daten().ausruestung.liste:
			if a.id == h.sattel:
				bonus = a.get("wirkung", {}).get("tempo", 0)
	return wirksam(h, "tempo") + bonus


# --- Pferdewert (KATALOG §6, game/value.lua) ---

static func _leistung(t: float, s: float, sp: float, a: float, b: float) -> float:
	var w: Dictionary = daten().wert
	var x: float = w.exponent
	var summe: float = pow(t / 100.0, x) + pow(s / 100.0, x) + pow(sp / 100.0, x) + pow(a / 100.0, x) + w.bindung_gewicht * pow(b / 100.0, x)
	return pow(summe / w.leistung_teiler, 1.0 / x)


static func leistungsfaktor(h: Dictionary, bindung := -1.0) -> float:
	var w: Dictionary = daten().wert
	var r := rasse(h.rasse)
	var l := _leistung(stat(h, "tempo"), stat(h, "staerke"), stat(h, "spuer"), stat(h, "ausdauer"), float(h.bindung) if bindung < 0.0 else bindung)
	var l_rasse := _leistung(r.tempo, r.staerke, r.spuer, r.ausdauer, r.bindung)
	return maxf(w.faktor_min, 1.0 + w.steigung * (l / l_rasse - 1.0))


static func farbfaktor(h: Dictionary) -> float:
	for f in daten().farben.liste:
		if f.id == h.farbe:
			return daten().farben.stufen[int(f.stufe) - 1].faktor
	return 1.0


## Stammbaum-Bonus in Prozent je bekanntem Vorfahren (Eltern, Großeltern, Urgroßeltern)
static func stammbaum(h: Dictionary) -> float:
	var ahnen = h.get("ahnen")
	if not (ahnen is Dictionary):
		return 0.0
	return _ahnen_bonus(ahnen.get("v"), 0) + _ahnen_bonus(ahnen.get("m"), 0)


static func _ahnen_bonus(knoten, gen: int) -> float:
	var pro: Array = daten().wert.stammbaum
	if not (knoten is Dictionary) or gen >= pro.size():
		return 0.0
	return float(pro[gen]) + _ahnen_bonus(knoten.get("v"), gen + 1) + _ahnen_bonus(knoten.get("m"), gen + 1)


## Wert = Grundwert × Farbfaktor × Leistungsfaktor × Alter (Fohlen ×0,6) × (1 + Stammbaum)
static func wert_roh(h: Dictionary, bindung := -1.0) -> float:
	var w: Dictionary = daten().wert
	var alter: float = w.fohlen_faktor if float(h.get("alter", 1)) < 1.0 else 1.0
	return float(rasse(h.rasse).grundwert) * farbfaktor(h) * leistungsfaktor(h, bindung) * alter * (1.0 + stammbaum(h) / 100.0)


static func wert(h: Dictionary) -> int:
	return roundi(wert_roh(h))


static func kaufpreis(h: Dictionary) -> int:
	return roundi(wert_roh(h) * daten().wert.kauf_faktor)


static func freier_name(rng: RandomNumberGenerator, sex: String, belegt: Array) -> String:
	var n: Dictionary = daten().namen
	var liste: Array = (n.w if sex == "w" else n.m) + n.x
	var frei := liste.filter(func(name): return name not in belegt)
	if frei.is_empty():
		frei = liste
	return frei[rng.randi() % frei.size()]


static func beschreibung(h: Dictionary) -> String:
	return "%s · %s · %s" % [rasse(h.rasse).get("name", h.rasse), farbe_name(h.farbe), "Stute" if h.sex == "w" else "Hengst"]
