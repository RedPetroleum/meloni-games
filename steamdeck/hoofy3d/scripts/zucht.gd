class_name Zucht
## Zucht wie game/breeding.lua im 2D-Hoofy (KATALOG §1, §4; E43, E44): Hengst und Stute im Stall,
## Trächtigkeit 2 Tage, danach 3 Tage Pause für die Stute; das Fohlen wächst in 4 Tagen aus.
## Gen-Stats: Mittel der Eltern ± σ 6 (Inzucht-Malus), Rasse 50:50, Farbe nach der Farbgenetik
## (je Elternteil sichtbar 70 % / versteckt 30 %, 1 % Mutation), Stammbaum 3 Ebenen.

const TIEFE := 3


static func _k() -> Dictionary:
	return HoofyDaten.daten()


## Eindeutige Kennung eines Pferds (für den Stammbaum)
static func kennung(d: Dictionary) -> String:
	if not d.has("id"):
		d.id = "%010d" % (randi() % 1000000000)
	return d.id


static func _erwachsen(d: Dictionary) -> bool:
	return float(d.get("alter", 1)) >= 1.0


static func hengst_bereit(d: Dictionary) -> bool:
	return d.sex == "m" and _erwachsen(d) and d.get("ort") == "stall"


static func stute_bereit(d: Dictionary, tag: int) -> bool:
	return d.sex == "w" and _erwachsen(d) and d.get("ort") == "stall" and not d.has("traechtig") and int(d.get("zucht_pause", 0)) <= tag


static func hengste() -> Array:
	return Spiel.herde.filter(func(d): return hengst_bereit(d))


static func stuten(tag: int) -> Array:
	return Spiel.herde.filter(func(d): return stute_bereit(d, tag))


## Warum geht Zucht mit diesem Pferd nicht? "" wenn es geht (HM.partners)
static func grund(d: Dictionary, tag: int) -> String:
	if not _erwachsen(d):
		return "noch ein Fohlen"
	if d.get("ort") != "stall":
		return "nur im Stall"
	if d.sex == "m":
		return "" if stuten(tag) else "keine bereite Stute im Stall"
	if d.has("traechtig"):
		return "schon trächtig"
	if int(d.get("zucht_pause", 0)) > tag:
		return "Pause bis Tag %d" % d.zucht_pause
	return "" if hengste() else "kein Hengst im Stall"


# --- Stammbaum ---

static func _kuerzen(a, tiefe: int):
	if not (a is Dictionary):
		return null
	var aus := {"id": a.get("id"), "name": a.name, "rasse": a.rasse, "farbe": a.farbe}
	if tiefe > 1:
		aus.v = _kuerzen(a.get("v"), tiefe - 1)
		aus.m = _kuerzen(a.get("m"), tiefe - 1)
	return aus


static func _ahn(d: Dictionary, tiefe: int) -> Dictionary:
	var knoten := {"id": d.get("id"), "name": d.name, "rasse": d.rasse, "farbe": d.farbe}
	if d.get("ahnen") is Dictionary:
		knoten.v = d.ahnen.get("v")
		knoten.m = d.ahnen.get("m")
	return _kuerzen(knoten, tiefe)


## Verwandtschaft und Inzucht-Malus in Prozent: Eltern/Kind und Geschwister −15, Halbgeschwister und
## Großeltern/Enkel −8, Cousins −3. Gibt [Prozent, Bezeichnung] zurück.
static func verwandtschaft(a: Dictionary, b: Dictionary) -> Array:
	var i: Dictionary = _k().farben.inzucht
	var eltern := func(d: Dictionary) -> Array:
		var ah: Dictionary = d.get("ahnen") if d.get("ahnen") is Dictionary else {}
		var v = ah.get("v")
		var m = ah.get("m")
		return [v.id if v is Dictionary else null, m.id if m is Dictionary else null]
	var grosseltern := func(d: Dictionary) -> Dictionary:
		var aus := {}
		var ah: Dictionary = d.get("ahnen") if d.get("ahnen") is Dictionary else {}
		for p in [ah.get("v"), ah.get("m")]:
			if p is Dictionary:
				for g in [p.get("v"), p.get("m")]:
					if g is Dictionary:
						aus[g.id] = true
		return aus
	var ea: Array = eltern.call(a)
	var eb: Array = eltern.call(b)
	var ida = a.get("id")
	var idb = b.get("id")
	if (ida != null and ida in eb) or (idb != null and idb in ea):
		return [int(i.eltern), "Eltern und Kind"]
	if ea[0] != null and ea[1] != null and ea[0] == eb[0] and ea[1] == eb[1]:
		return [int(i.eltern), "Geschwister"]
	for x in ea:
		if x != null and x in eb:
			return [int(i.halb), "Halbgeschwister"]
	var ga: Dictionary = grosseltern.call(a)
	var gb: Dictionary = grosseltern.call(b)
	if (idb != null and ga.has(idb)) or (ida != null and gb.has(ida)):
		return [int(i.halb), "Großeltern und Enkel"]
	for x in ga:
		if gb.has(x):
			return [int(i.cousins), "Cousins"]
	return [0, ""]


# --- Paarung und Geburt ---

## Beginnt die Trächtigkeit; der Vater wird festgehalten (wird er verkauft, erbt das Fohlen trotzdem)
static func starten(hengst: Dictionary, stute: Dictionary, tag: int) -> String:
	if not hengst_bereit(hengst):
		return "Hengst nicht bereit"
	if not stute_bereit(stute, tag):
		return "Stute nicht bereit"
	kennung(hengst)
	kennung(stute)
	stute.traechtig = {
		"tag": tag + int(_k().zeit.traechtig_tage),
		"vater": {"id": hengst.id, "name": hengst.name, "rasse": hengst.rasse, "farbe": hengst.farbe,
			"farbe2": hengst.get("farbe2", hengst.farbe), "gen": hengst.gen.duplicate(),
			"ahnen": hengst.get("ahnen"), "zug": hengst.zug},
	}
	return ""


static func _elternfarbe(sichtbar: String, versteckt: String, rng: RandomNumberGenerator) -> String:
	return sichtbar if rng.randf() < float(_k().farben.vererbung.sichtbar) / 100.0 else versteckt


static func _mutation(farbe: String, rng: RandomNumberGenerator) -> String:
	var stufen: Array = _k().farben.stufen
	var stufe := 1
	for f in _k().farben.liste:
		if f.id == farbe:
			stufe = int(f.stufe)
	if stufe >= stufen.size():
		return farbe
	var liste: Array = stufen[stufe].farben
	return liste[rng.randi() % liste.size()]


## Farben des Fohlens: je Elternteil eine ziehen, eine zeigt das Fohlen (50:50), die andere trägt es
## versteckt; 1 % Mutation der gezeigten zur nächsten Stufe
static func fohlenfarben(v_s: String, v_v: String, m_s: String, m_v: String, rng: RandomNumberGenerator) -> Array:
	var a := _elternfarbe(v_s, v_v, rng)
	var b := _elternfarbe(m_s, m_v, rng)
	var gezeigt := a
	var versteckt := b
	if rng.randf() < 0.5:
		gezeigt = b
		versteckt = a
	if rng.randf() < float(_k().farben.vererbung.mutation) / 100.0:
		gezeigt = _mutation(gezeigt, rng)
	return [gezeigt, versteckt]


static func fohlen(vater: Dictionary, mutter: Dictionary, rng: RandomNumberGenerator, inzucht: int) -> Dictionary:
	var s: Dictionary = _k().stats
	var r := HoofyDaten.rasse(vater.rasse if rng.randf() < float(_k().farben.rasse_vater) / 100.0 else mutter.rasse)
	var zuege: Array = _k().charakter.keys()
	var d := {
		"rasse": r.id, "alter": 0.0, "sex": "m" if rng.randf() < 0.5 else "w",
		"zug": zuege[rng.randi() % zuege.size()], "gen": {}, "train": {}, "pot": {},
	}
	var malus := 1.0 - inzucht / 100.0
	for key in HoofyDaten.STATS:
		var lo: int = s.gen_min
		var hi: int = s.gen_max
		if key == "ausdauer":
			lo = s.ausdauer_min
			hi = s.ausdauer_max
		var mittel := (float(vater.gen[key]) + float(mutter.gen[key])) / 2.0
		var g := clampi(roundi((mittel + rng.randfn(0.0, s.fohlen_sigma)) * malus), lo, hi)
		var p := roundi(g + float(r.spanne) + rng.randfn(0.0, s.potenzial_sigma))
		d.gen[key] = g
		d.train[key] = 0
		d.pot[key] = clampi(p, g, int(s.potenzial_max))
	var farben := fohlenfarben(vater.farbe, vater.get("farbe2", vater.farbe), mutter.farbe, mutter.get("farbe2", mutter.farbe), rng)
	d.farbe = farben[0]
	d.farbe2 = farben[1]
	d.bindung = clampi(int(r.bindung) + int(_k().zug_bindung[d.zug]) + roundi((rng.randf() * 2.0 - 1.0) * 5.0), 0, 100)
	d.hunger = s.hunger.start
	d.gewicht = s.gewicht.start
	d.sauberkeit = s.sauberkeit.start
	d.energie = d.gen.ausdauer
	d.name = HoofyDaten.freier_name(rng, d.sex, Spiel.namen)
	d.ahnen = {"v": _ahn(vater, TIEFE), "m": _ahn(mutter, TIEFE)}
	return d


## Tageswechsel: Stuten, deren Zeit um ist, bekommen ihr Fohlen (im Stall). Gibt [{fohlen, mutter}] zurück.
static func tick(tag: int) -> Array:
	var geboren := []
	var rng := RandomNumberGenerator.new()
	rng.seed = Handel.WELT_SAAT * 71 + tag * 17 + 1
	for m in Spiel.herde.duplicate():
		if m.has("traechtig") and tag >= int(m.traechtig.tag):
			kennung(m)
			var vater: Dictionary = m.traechtig.vater
			var malus: int = verwandtschaft(vater, m)[0]
			var f := fohlen(vater, m, rng, malus)
			Spiel.namen.append(f.name)
			kennung(f)
			m.erase("traechtig")
			m.zucht_pause = tag + int(_k().zeit.stute_pause_tage)
			f.ort = "stall"
			Spiel.herde.append(f)
			geboren.append({"fohlen": f, "mutter": m})
	return geboren
