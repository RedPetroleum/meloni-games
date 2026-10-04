class_name Pflege
## Pflege und Training wie game/care.lua im 2D-Hoofy (KATALOG §2, §5, §7): reine Regeln auf den
## Pferdedaten, ohne Grafik.

const STREICHELN_NOCHMAL := 1      # zweites Streicheln am Tag (Care.STROKE_AGAIN)
const FUETTERN_MAX := 5            # Bindung durch Füttern höchstens am Tag


static func _k() -> Dictionary:
	return HoofyDaten.daten()


## Bonus aus Sauberkeit und Bindung auf den Trainingszuwachs (bis ×1,5); eitel: Sauberkeit doppelt
static func training_bonus(d: Dictionary) -> float:
	var c := float(d.sauberkeit) / 100.0 * 0.25
	if d.zug == "eitel":
		c *= float(_k().charakter.eitel.sauberkeit_faktor)
	return minf(float(_k().stats.training_bonus_max), 1.0 + c + float(d.bindung) / 100.0 * 0.25)


static func training_zuwachs(d: Dictionary, key: String, basis: float) -> float:
	if HoofyDaten.stat(d, key) >= int(d.pot[key]):
		return 0.0
	var g := basis * float(_k().stats.training_tempo) * training_bonus(d)
	if d.zug == "faul":
		g *= 1.0 - float(_k().charakter.faul.training_malus) / 100.0
	if int(d.get("boost", 0)) > 0:
		g *= 2.0
	return g


## Tagesgrenze je Stat: bis „weich“ voll, darüber 1/teiler, bei „hart“ Schluss (Drachenfrucht: doppelt)
static func tagesgrenze(d: Dictionary, schon: float, g: float) -> float:
	var t: Dictionary = _k().stats.training_tag
	var f := 2.0 if int(d.get("boost", 0)) > 0 else 1.0
	var weich: float = t.weich * f
	var hart: float = t.hart * f
	var voll := minf(g, maxf(0.0, weich - schon))
	return voll + minf((g - voll) / float(t.teiler), maxf(0.0, hart - maxf(schon, weich)))


## Trainiert d.train[key], begrenzt durch Tagesgrenze und Max-Potenzial. Gibt den Zuwachs zurück.
## (Werte bleiben Gleitkommazahlen wie im 2D-Hoofy; angezeigt wird abgerundet.)
static func trainieren(d: Dictionary, key: String, basis: float) -> float:
	if not d.has("heute_train"):
		d.heute_train = {}
	var schon := float(d.heute_train.get(key, 0.0))
	var g := tagesgrenze(d, schon, training_zuwachs(d, key, basis))
	g = minf(g, maxf(0.0, float(d.pot[key]) - HoofyDaten.stat(d, key)))
	d.train[key] = float(d.train[key]) + g
	d.heute_train[key] = schon + g
	return g


## Streicheln: +2 Bindung, ein zweites Mal am Tag +1, danach nichts. Gibt den Zuwachs zurück.
static func streicheln(d: Dictionary) -> int:
	var n := int(d.get("gestreichelt", 0))
	var dazu := int(_k().stats.bindung.streicheln) if n == 0 else (STREICHELN_NOCHMAL if n == 1 else 0)
	d.gestreichelt = n + 1
	d.bindung = clampi(int(d.bindung) + dazu, 0, 100)
	return dazu


## Futter aus dem Laden (Heu, Hafer, Karotte, Premiumfutter)
static func futter(id: String) -> Dictionary:
	for f in _k().futter.kaufen:
		if f.id == id:
			return f
	return {}


## Füttern: Hunger, Energie, Sauberkeit, Gewicht nach Futter; Bindung +1 je Fütterung (höchstens 5 am Tag)
static func fuettern(d: Dictionary, id: String) -> int:
	var w: Dictionary = futter(id).get("wirkung", {})
	var heute := int(d.get("gefuettert", 0))
	var bindung := mini(int(_k().stats.bindung.fuettern), maxi(0, FUETTERN_MAX - heute))
	d.gefuettert = heute + bindung
	d.hunger = clampi(int(d.hunger) + int(w.get("hunger", 0)), 0, 100)
	if w.has("energie"):
		d.energie = minf(HoofyDaten.stat(d, "ausdauer"), float(d.energie) + float(w.energie))
	if w.has("sauberkeit"):
		d.sauberkeit = clampi(int(d.sauberkeit) + int(w.sauberkeit), 0, 100)
	if w.has("gewicht"):
		d.gewicht = clampi(int(d.gewicht) + int(w.gewicht), 0, 100)
	d.bindung = clampi(int(d.bindung) + bindung, 0, 100)
	var pot_dazu: int = futter(id).get("fohlen_potenzial", 0)
	if pot_dazu > 0 and float(d.get("alter", 1)) < 1.0:
		var platz := int(futter(id).get("fohlen_potenzial_max", 10)) - int(d.get("pot_bonus", 0))
		var dazu := mini(pot_dazu, maxi(0, platz))
		if dazu > 0:
			d.pot_bonus = int(d.get("pot_bonus", 0)) + dazu
			for key in HoofyDaten.STATS:
				d.pot[key] = mini(int(_k().stats.potenzial_max), int(d.pot[key]) + dazu)
	return bindung


## Striegeln (braucht die Bürste): Sauberkeit +40, Bindung +1, solange noch nicht ganz sauber
static func striegeln(d: Dictionary) -> int:
	var dazu: int = futter("buerste").get("wirkung", {}).get("sauberkeit", 40)
	var bindung := 1 if int(d.sauberkeit) < 100 else 0
	d.sauberkeit = clampi(int(d.sauberkeit) + dazu, 0, 100)
	d.bindung = clampi(int(d.bindung) + bindung, 0, 100)
	return bindung


## Bindung eines Tages aus den Zuständen: −3 bei Hunger > 70, −2 bei Sauberkeit < 30 (eitel doppelt)
static func tagesbindung(d: Dictionary) -> int:
	var b: Dictionary = _k().stats.bindung
	var delta := 0
	if int(d.hunger) > int(b.hunger_grenze):
		delta -= int(b.hunger_malus)
	if int(d.sauberkeit) < int(b.schmutz_grenze):
		delta -= int(b.schmutz_malus) * (int(_k().charakter.eitel.sauberkeit_faktor) if d.zug == "eitel" else 1)
	d.bindung = clampi(int(d.bindung) + delta, 0, 100)
	return delta


## Darf das Pferd frei auf dem Hof laufen? (Farm.may_roam)
static func darf_frei(d: Dictionary) -> bool:
	var u: Dictionary = _k().stats.unterbringung.frei
	return HoofyDaten.stat(d, "staerke") >= int(u.min_staerke) and int(d.bindung) >= int(u.min_bindung)
