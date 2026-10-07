class_name Wirtschaft
## Geld, Laden und Ausrüstung wie game/economy.lua im 2D-Hoofy (KATALOG §7, §8, §9): Warenliste,
## Kaufen (1 Stück), Ausrüsten am Pferd aus dem Vorrat. Alles auf Spiel.geld und Spiel.inv.

const KATEGORIEN := [
	{"id": "futter", "name": "Futter"},
	{"id": "saettel", "name": "Sättel"},
	{"id": "zubehoer", "name": "Zubehör"},
	{"id": "schmuck", "name": "Schmuck"},
	{"id": "samen", "name": "Samen"},
	{"id": "fahrzeuge", "name": "Fahrzeuge"},
]
const LATERNE_PREIS := 80
const FAHRZEUG_TEXT := {
	"fahrrad": "Strampeln statt tanken: bringt dich bis in den Birkenwald, kostet nur Muskelkater.",
	"mofa": "Knattert bis in die Flussauen. Schluckt ein bisschen Sprit, und jedes Wildpferd hört dich kommen.",
	"kleinwagen": "Klein, aber mit Heizung. Schafft es bis in die Steppe, wenn du ab und zu tankst.",
	"suv": "Groß, schwarz, durstig. Rollt bis in den Canyon und trinkt unterwegs ordentlich Sprit.",
	"flugzeug": "Fliegt bis zur Nebelinsel, wo keine Straße hinführt. Der Tank ist teuer, die Aussicht unbezahlbar.",
}
const FAHRZEUG_AKK := {"fahrrad": "das Fahrrad", "mofa": "das Mofa", "kleinwagen": "den Kleinwagen", "suv": "den SUV", "flugzeug": "das Flugzeug"}
const GARAGE_NOM := {"schuppen": "ein Schuppen", "garage": "eine Garage", "hangar": "ein Hangar"}
const SLOTS := {
	"sattel": ["einfacher_sattel", "sportsattel", "rennsattel", "goldsattel"],
	"taschen": ["satteltaschen_s", "satteltaschen_m", "satteltaschen_l"],
}
const SCHMUCK := ["maehnenschleife", "blumenkranz", "glitzerdecke", "goldhufeisen"]

static var futter_aufschlag := 0      # Hafersteuer in Prozent (Reformen, später)


static func _k() -> Dictionary:
	return HoofyDaten.daten()


static func _ware(kat: String, e: Dictionary) -> Dictionary:
	return {"id": e.id, "name": e.name, "preis": int(e.preis), "text": e.get("text", ""), "kat": kat, "einmalig": e.get("einmalig", false)}


## Alle Waren; maxgebiet = weitestes erreichbares Gebiet (bestimmt die Samen)
static func katalog(maxgebiet := 1) -> Array:
	var liste := []
	for f in _k().futter.kaufen:
		liste.append(_ware("zubehoer" if f.id in ["buerste", "hacke"] else "futter", f))
	for a in _k().ausruestung.liste:
		var kat := "schmuck"
		if a.get("sattel", false) and a.id != "sattellampe":
			kat = "saettel"
		elif a.id.begins_with("satteltaschen") or a.id == "sattellampe":
			kat = "zubehoer"
		liste.append(_ware(kat, a))
	liste.append({"id": "laterne", "name": "Laterne", "preis": LATERNE_PREIS, "kat": "zubehoer", "einmalig": true,
		"text": "Leuchtet nachts um dich herum. Trägst du von selbst."})
	for p in _k().futter.anbau:
		if int(p.gebiet) <= maxgebiet:
			liste.append({"id": "samen_" + p.id, "name": "Samen: " + p.name, "preis": int(p.samen), "text": p.get("text", ""), "kat": "samen", "pflanze": p.id})
	for f in _k().welt.fahrzeuge:
		if int(f.preis) > 0:
			liste.append({"id": f.id, "name": f.name, "preis": int(f.preis), "kat": "fahrzeuge", "einmalig": true, "fahrzeug": true,
				"text": FAHRZEUG_TEXT.get(f.id, "Erreicht Gebiet 1 bis %d." % f.gebiete)})
	for a in _k().welt.anhaenger:
		var n := int(a.plaetze)
		liste.append({"id": "anhaenger_%d" % n, "name": "Anhänger %d Platz%s" % [n, "e" if n > 1 else ""], "preis": int(a.preis),
			"kat": "fahrzeuge", "einmalig": true, "anhaenger": n, "text": "Nimmt %d Pferd%s mit auf die Reise." % [n, "e" if n > 1 else ""]})
	return liste


static func finde(id: String) -> Dictionary:
	for w in katalog(6):
		if w.id == id:
			return w
	return {}


## Preis mit Aufschlag (Hafersteuer: Futter +50 %)
static func preis(w: Dictionary) -> int:
	var p: int = w.preis
	if w.kat == "futter" and futter_aufschlag > 0:
		p = ceili(p * (1.0 + futter_aufschlag / 100.0))
	return p


static func besitz(id: String) -> int:
	return int(Spiel.inv.get(id, 0))


## Fahrzeuge, die eine Unterkunft auf dem Hof haben (Schuppen, Garage, Hangar; kommt mit dem Baumodus)
static func untergestellt() -> Dictionary:
	return {}


static func garage_text(id: String) -> String:
	for b in _k().bau.liste:
		if id in b.get("fahrzeuge", []):
			return "Für %s fehlt dir %s." % [FAHRZEUG_AKK.get(id, id), GARAGE_NOM.get(b.id, b.name)]
	return "Dafür fehlt dir die Unterbringung."


## Kaufen: 1 Stück. Gibt "" (gekauft) oder den Grund zurück: "Geld", "schon da", "Garage".
static func kaufen(id: String) -> String:
	var w := finde(id)
	if w.get("einmalig", false) and besitz(id) > 0:
		return "schon da"
	if w.get("fahrzeug", false) and not untergestellt().has(id):
		return "Garage"
	var p := preis(w)
	if Spiel.geld < p:
		return "Geld"
	Spiel.geld -= p
	Spiel.inv[id] = besitz(id) + 1
	return ""


## Rüstet id aus dem Vorrat aus; das alte Stück geht zurück. Gibt "" oder den Grund zurück.
## Sättel: einer; Taschen: nur mit Sattel; Lampe und Schmuck: je einmal.
static func ausruesten(d: Dictionary, id: String) -> String:
	if besitz(id) < 1:
		return "nicht im Vorrat"
	for slot in SLOTS:
		if id in SLOTS[slot]:
			if slot == "taschen" and not d.get("sattel"):
				return "braucht einen Sattel"
			if d.get(slot):
				Spiel.inv[d[slot]] = besitz(d[slot]) + 1
			d[slot] = id
			Spiel.inv[id] = besitz(id) - 1
			return ""
	if id == "sattellampe":
		if d.get("lampe", false):
			return "schon an"
		d.lampe = true
		Spiel.inv[id] = besitz(id) - 1
		return ""
	if id in SCHMUCK:
		if not d.has("schmuck"):
			d.schmuck = {}
		if d.schmuck.get(id, false):
			return "schon an"
		d.schmuck[id] = true
		Spiel.inv[id] = besitz(id) - 1
		return ""
	return "unbekannt"


## Legt ein Stück ab (zurück in den Vorrat); ohne Sattel gehen die Taschen mit ab
static func ablegen(d: Dictionary, id: String) -> bool:
	if d.get("sattel") == id:
		d.erase("sattel")
		Spiel.inv[id] = besitz(id) + 1
		if d.get("taschen"):
			Spiel.inv[d.taschen] = besitz(d.taschen) + 1
			d.erase("taschen")
		return true
	if d.get("taschen") == id:
		d.erase("taschen")
		Spiel.inv[id] = besitz(id) + 1
		return true
	if id == "sattellampe" and d.get("lampe", false):
		d.erase("lampe")
		Spiel.inv[id] = besitz(id) + 1
		return true
	if d.has("schmuck") and d.schmuck.get(id, false):
		d.schmuck.erase(id)
		Spiel.inv[id] = besitz(id) + 1
		return true
	return false


## Was das Pferd trägt (Ids)
static func getragen(d: Dictionary) -> Array:
	var aus := []
	if d.get("sattel"):
		aus.append(d.sattel)
	if d.get("taschen"):
		aus.append(d.taschen)
	if d.get("lampe", false):
		aus.append("sattellampe")
	for j in SCHMUCK:
		if d.has("schmuck") and d.schmuck.get(j, false):
			aus.append(j)
	return aus


## Alles ablegen (Verkauf, Tausch); gibt die Namen zurück
static func abziehen(d: Dictionary) -> Array:
	var namen := []
	for id in getragen(d):
		ablegen(d, id)
		namen.append(finde(id).name)
	return namen


## Plätze in den Satteltaschen (S/M/L = 1/2/4)
static func taschen_plaetze(d: Dictionary) -> int:
	for a in _k().ausruestung.liste:
		if a.id == d.get("taschen"):
			return int(a.get("plaetze", 0))
	return 0


## Schönheit aus Schmuck und Sattel (Goldsattel +20)
static func schoenheit(d: Dictionary) -> int:
	var summe := 0
	for a in _k().ausruestung.liste:
		if a.id == d.get("sattel") or (d.has("schmuck") and d.schmuck.get(a.id, false)):
			summe += int(a.get("wirkung", {}).get("schoenheit", 0))
	return summe
