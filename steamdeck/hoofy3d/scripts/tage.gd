class_name Tage
## Tageswechsel wie game/days.lua im 2D-Hoofy (KATALOG §1, §2). Reihenfolge je Pferd: Bindung (aus
## den Zuständen von gestern), Gewicht, Unterbringung, Hunger, Energie, Alter.


static func pferdetag(d: Dictionary) -> void:
	var s: Dictionary = HoofyDaten.daten().stats
	Pflege.tagesbindung(d)
	# Gewicht: Hunger > 70 senkt, zwei Tage Hunger < 10 (überfüttert) erhöht
	if int(d.hunger) > int(s.bindung.hunger_grenze):
		d.gewicht = int(d.gewicht) + int(s.gewicht.hunger)
	d.satt_tage = int(d.get("satt_tage", 0)) + 1 if int(d.hunger) < int(s.hunger.satt) else 0
	if int(d.satt_tage) >= int(s.hunger.satt_tage):
		d.gewicht = int(d.gewicht) + int(s.gewicht.ueberfuettert)
	d.gewicht = clampi(int(d.gewicht), 0, 100)
	# Unterbringung: Trainingsverlust auf Weide und frei, Sauberkeit (Farm.daily)
	var u: Dictionary = s.unterbringung.get(d.get("ort", ""), {})
	if not u.is_empty():
		var verlust := float(u.verlust) * (1.0 - HoofyDaten.stat(d, "staerke") / 100.0) if float(u.verlust) > 0.0 else 0.0
		for k in HoofyDaten.STATS:
			d.train[k] = maxf(0.0, float(d.train[k]) - verlust)
		d.sauberkeit = maxi(0, int(d.sauberkeit) + int(u.sauberkeit))
	# Hunger steigt
	d.hunger = clampi(int(d.hunger) + int(s.hunger.pro_tag_verfressen if d.zug == "verfressen" else s.hunger.pro_tag), 0, 100)
	# Energie zurück auf die Ausdauer (Nachteule morgens −10)
	d.energie = HoofyDaten.stat(d, "ausdauer")
	if d.zug == "nachteule":
		d.energie = float(d.energie) + float(HoofyDaten.daten().charakter.nachteule.morgen_energie)
	# Fohlen wachsen in 4 Tagen aus
	if float(d.get("alter", 1)) < 1.0:
		d.alter = minf(1.0, float(d.alter) + 1.0 / float(HoofyDaten.daten().zeit.fohlen_tage))
	if int(d.get("boost", 0)) > 0:
		d.boost = int(d.boost) - 1
	d.erase("gestreichelt")
	d.erase("gefuettert")
	d.erase("heute_train")


static func neuer_tag(herde: Array) -> void:
	for d in herde:
		pferdetag(d)
	# Stall: der Stall gibt allen Pferden darin Bindung (KATALOG §9; Stall S +1)
	for d in herde:
		if d.get("ort") == "stall":
			d.bindung = clampi(int(d.bindung) + 1, 0, 100)


## Nachteulen bekommen bei Einbruch der Nacht +20 Energie (darf über die Ausdauer gehen)
static func abend(herde: Array) -> void:
	for d in herde:
		if d.zug == "nachteule":
			d.energie = float(d.energie) + float(HoofyDaten.daten().charakter.nachteule.nacht_energie)
