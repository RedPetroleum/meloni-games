class_name Wildpferde
extends Node3D
## Wildpferde, Zähmen und Leine wie im 2D-Hoofy (game/wild.lua, game/leash.lua; KATALOG §1, §2,
## §10; E16, E25–E29, E71, E81).
##
## Wild: im Heimattal 4 gleichzeitig, alle 3 Tage wechseln 1–2 (gezähmte werden erst dann
## ersetzt). Sie grasen und ziehen umher. Kommt man in die Zone, bleiben sie grasend stehen und
## lauschen: Bewegung macht Lärm (am Rand langsamer, nah schneller), Stehen beruhigt; ab 60 %
## zeigen sie ❗, voll = Flucht. Galopp in der Zone: sofort Flucht.
## Zähmen: nah dran die Aktionstaste halten und stillstehen, 1,5 s + 1 Frame je fehlendem
## Bindungspunkt. Dann ist es an der Leine (höchstens 2 am Strick, 4 insgesamt; ab Bindung 100
## folgt es frei). Einmal pro Sekunde wird Ausreißen gewürfelt. Ein neues Pferd, das noch nie auf
## dem Hof war, ist danach wieder wild.
##
## Abstände für 3D vergrößert: Zone 20 m (Hoofy 110 px ≈ 7 m), Zähmen ab 3,5 m.
## Der Spieler ist vorerst das gerittene Pferd; mit der Spielfigur geht Zähmen wie in Hoofy nur
## zu Fuß (dort springt die Aktionstaste beim Reiten).

const ANZAHL := 4                 # Heimattal (KATALOG §10)
const WECHSEL_TAGE := 3
const MIN_ABSTAND_HOF := 110.0
const ZONE := 20.0
const ZAEHM_ABSTAND := 3.5
const RUHE_ABSTAND := 20.0        # nach der Flucht erst ab hier wieder grasen
const LAERM_AN := 0.6
const LAERM_AUS := 0.35
const LAERM_RAND := 0.6           # je Sekunde Bewegung am Rand der Zone (voll nach 1,7 s) …
const LAERM_NAH := 0.6            # … plus so viel ganz nah (voll nach knapp 1 s)
const LAERM_RUHE := 1.0 / 1.5     # je Sekunde Stillstand (voll → leer in 1,5 s)
const FLUCHT_TEMPO := 8.0         # m/s, wie Galopp
const MAX_STRICK := 2             # Pferde am Strick (Leash.MAX_LED)
const MAX_FUEHREN := 4            # geführte und folgende zusammen (Leash.MAX_LEAD)
const FRISCH_BINDUNG := 6         # reitbar erst bei Bindung + 6 (E71)
const FRISCH_FAKTOR := 3.0        # frisch: Ausreißen beim Rennen/Reiten ×3

signal meldung(text: String, sekunden: float)

var gelaende: Gelaende
var spieler: Node3D               # braucht bewegt(), rennt(), reitet(), spur_punkt(abstand)
var himmel: Himmel
var gebiet := 1
var pferde: Array[WildPferd] = []        # wild
var eigene: Array[WildPferd] = []        # gezähmt, in der Welt (geführt, folgend, lose)
var fuehrung: Array[WildPferd] = []      # an der Leine oder folgend, in Reihenfolge
var benutzte_namen: Array = []
var zaehmen: WildPferd                   # läuft gerade
var zaehm_fortschritt := 0.0             # 0–1
var _rng := RandomNumberGenerator.new()
var _seil := MeshInstance3D.new()
var _seil_netz := ImmediateMesh.new()


class WildPferd extends Node3D:
	var daten: Dictionary
	var modell: PferdModell
	var heim: Vector2                     # Weideplatz, um den es umherzieht
	var ziel := Vector2.ZERO
	var tempo := 0.0
	var soll_tempo := 0.0
	var zustand := "grasen"               # wild: grasen, wandern, fliehen; eigen: gefuehrt, folgt, lose, ausgerissen
	var uhr := 0.0
	var neigung := 0.0
	var laerm := 0.0
	var alarm := false
	var leine_uhr := 0.0
	var zaehm_noetig := 0.0
	var blase := Label3D.new()
	var blase_uhr := 0.0

	func gang() -> String:
		if tempo < 0.2:
			return "grasen" if zustand == "grasen" else "stehen"
		if tempo < 2.0:
			return "schritt"
		if tempo < 4.5:
			return "trab"
		return "galopp" if tempo < 10.0 else "renngalopp"

	func eigen() -> bool:
		return zustand in ["gefuehrt", "folgt", "lose", "ausgerissen"]

	## Sprechblase über dem Kopf (E10), z. B. ❗ beim Lauschen, ♥ nach dem Zähmen
	func zeige(text: String, farbe: Color, sekunden := 0.0) -> void:
		blase.text = text
		blase.modulate = farbe
		blase.visible = true
		blase_uhr = sekunden


func _ready() -> void:
	_rng.seed = 4711 + gebiet * 1000     # Hoofy E18: Gebiet n nutzt Seed + n × 1000
	for i in ANZAHL:
		_neues_pferd()
	if himmel:
		himmel.neuer_tag.connect(_tageswechsel)
	_seil.mesh = _seil_netz
	var seil_mat := StandardMaterial3D.new()
	seil_mat.albedo_color = Color(0.55, 0.42, 0.28)
	seil_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_seil.material_override = seil_mat
	_seil.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_seil)


func _pferd_knoten(daten: Dictionary, p: Vector2) -> WildPferd:
	var w := WildPferd.new()
	w.daten = daten
	w.modell = PferdModell.new(daten)
	w.add_child(w.modell)
	w.heim = p
	w.position = Vector3(p.x, gelaende.hoehe(p.x, p.y), p.y)
	w.rotation.y = _rng.randf() * TAU
	w.uhr = _rng.randf_range(0.0, 6.0)
	w.blase.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	w.blase.font_size = 96
	w.blase.outline_size = 24
	w.blase.pixel_size = 0.004
	w.blase.no_depth_test = true
	w.blase.visible = false
	add_child(w)
	w.blase.position.y = w.modell.stockmass * 1.55
	w.add_child(w.blase)
	return w


func _neues_pferd() -> void:
	var belegt := benutzte_namen + pferde.map(func(x): return x.daten.name)
	var daten := HoofyDaten.wildpferd(_rng, gebiet, "", belegt)
	pferde.append(_pferd_knoten(daten, _weideplatz()))


## Freie Wiese: nicht im Wald, nicht steil, nicht nass, weg vom Hof und von den anderen
func _weideplatz() -> Vector2:
	var halb := Gelaende.GROESSE * 0.5 - 60.0
	for versuch in 200:
		var p := Vector2(_rng.randf_range(-halb, halb), _rng.randf_range(-halb, halb))
		if p.distance_to(Gelaende.HOF) < MIN_ABSTAND_HOF or gelaende.wald(p.x, p.y) > 0.2:
			continue
		if gelaende.wassertiefe(p.x, p.y) > -0.5 or gelaende.normale(p.x, p.y).y < 0.9:
			continue
		if pferde.any(func(w): return Vector2(w.position.x, w.position.z).distance_to(p) < 80.0):
			continue
		return p
	return Gelaende.HOF + Vector2(150, 0)


## Alle 3 Tage gehen 1–2 Wildpferde, neue kommen; gezähmte werden jetzt ersetzt (KATALOG §1)
func _tageswechsel(tag: int) -> void:
	if (tag - 1) % WECHSEL_TAGE != 0:
		return
	for i in _rng.randi_range(1, 2):
		if pferde.is_empty():
			break
		var weg: WildPferd = pferde.pop_at(_rng.randi() % pferde.size())
		weg.queue_free()
	while pferde.size() < ANZAHL:
		_neues_pferd()


func _process(delta: float) -> void:
	for w in pferde:
		_wild(w, delta)
		_bewegen(w, delta)
	for w in eigene:
		_eigen(w, delta)
		_bewegen(w, delta)
	for w in pferde + eigene:
		if w.blase.visible and w.blase_uhr > 0.0:
			w.blase_uhr -= delta
			if w.blase_uhr <= 0.0:
				w.blase.visible = false
	_zaehmen_steuern(delta)
	_seil_zeichnen()


# --- Wild ---

func _wild(w: WildPferd, delta: float) -> void:
	var p := Vector2(w.position.x, w.position.z)
	var s := Vector2(spieler.global_position.x, spieler.global_position.z)
	var d := p.distance_to(s)
	w.uhr -= delta
	if w.zustand != "fliehen":
		if d < ZONE and spieler.rennt() and spieler.bewegt():
			_fliehen(w)
			return
		if _lauschen(w, d, delta):
			_fliehen(w)
			return
		if d < ZONE:
			# in der Nähe: steht grasend und lauscht, läuft nicht weiter
			w.zustand = "grasen"
			w.soll_tempo = 0.0
			w.uhr = maxf(w.uhr, 0.1)
			return
	match w.zustand:
		"fliehen":
			# Richtung regelmäßig neu wählen, weg vom Spieler
			if fmod(w.uhr, 0.2) < delta:
				w.ziel = p + _fluchtrichtung(w, s) * 30.0
			if w.uhr <= 0.0 and d > RUHE_ABSTAND:
				w.zustand = "grasen"
				w.soll_tempo = 0.0
				w.uhr = randf_range(2.0, 6.0)
				w.heim = p
			elif w.uhr <= 0.0:
				w.uhr = 0.5
		"wandern":
			if w.uhr <= 0.0 or p.distance_to(w.ziel) < 1.0:
				w.zustand = "grasen"
				w.soll_tempo = 0.0
				w.uhr = randf_range(2.5, 6.5)
		_:
			if w.uhr <= 0.0:
				if randf() < 0.6:
					w.zustand = "wandern"
					w.ziel = w.heim + Vector2.from_angle(randf() * TAU) * randf_range(3.0, 25.0)
					w.soll_tempo = 1.4
					w.uhr = randf_range(3.0, 6.0)
				else:
					w.uhr = randf_range(2.0, 6.0)


## Lärmpegel nachführen (E81). Gibt true zurück, wenn er voll ist.
func _lauschen(w: WildPferd, d: float, delta: float) -> bool:
	if d < ZONE and spieler.bewegt():
		w.laerm += (LAERM_RAND + LAERM_NAH * (1.0 - d / ZONE)) * delta
	else:
		w.laerm -= LAERM_RUHE * delta
	w.laerm = clampf(w.laerm, 0.0, 1.0)
	if not w.alarm and w.laerm >= LAERM_AN:
		w.alarm = true
		w.zeige("!", Color(1.0, 0.85, 0.2))
	elif w.alarm and w.laerm <= LAERM_AUS:
		w.alarm = false
		w.blase.visible = false
	return w.laerm >= 1.0


func _fliehen(w: WildPferd) -> void:
	var s := Vector2(spieler.global_position.x, spieler.global_position.z)
	var p := Vector2(w.position.x, w.position.z)
	w.zustand = "fliehen"
	w.uhr = 1.5
	w.laerm = 0.0
	w.alarm = false
	w.blase.visible = false
	w.ziel = p + _fluchtrichtung(w, s) * 30.0
	w.soll_tempo = FLUCHT_TEMPO * (2.0 + 1.4 * HoofyDaten.wirksam(w.daten, "tempo") / 100.0) / 2.7


## Weg vom Spieler, aber nur in eine Richtung, in die es auch laufen kann (wie Horse:flee_dir)
func _fluchtrichtung(w: WildPferd, von: Vector2) -> Vector2:
	var p := Vector2(w.position.x, w.position.z)
	var basis := (p - von).normalized()
	for t in [0.0, 0.45, -0.45, 0.9, -0.9, 1.35, -1.35, 1.8, -1.8, 2.3, -2.3]:
		var r := basis.rotated(t)
		if _frei(p + r * 8.0) and _frei(p + r * 16.0):
			return r
	return basis


func _frei(p: Vector2) -> bool:
	return gelaende.wassertiefe(p.x, p.y) < 0.4 and gelaende.normale(p.x, p.y).y > 0.75 and gelaende.im_tal(p.x, p.y, 20.0)


# --- Zähmen ---

func _zaehmen_steuern(delta: float) -> void:
	var halten := Input.is_action_pressed("interagieren")
	if zaehmen == null:
		zaehm_fortschritt = 0.0
		if Input.is_action_just_pressed("interagieren"):
			var w := _zaehm_ziel()
			if w:
				zaehmen = w
				# 1,5 s plus 1 Frame je fehlendem Bindungspunkt (Wild.tame_frames)
				w.zaehm_noetig = (90.0 + (100.0 - float(w.daten.bindung))) / 60.0
		return
	var w := zaehmen
	var d := Vector2(w.position.x, w.position.z).distance_to(Vector2(spieler.global_position.x, spieler.global_position.z))
	if not halten or spieler.bewegt() or w.zustand == "fliehen" or d > ZAEHM_ABSTAND + 0.5:
		zaehmen = null
		if w.zustand == "fliehen":
			meldung.emit("Es ist davongelaufen.", 1.5)
		elif not halten:
			meldung.emit("Zu früh losgelassen. Halte die Taste und bleib still stehen.", 2.0)
		else:
			meldung.emit("Abgebrochen: still stehen bleiben.", 1.5)
		return
	zaehm_fortschritt += delta / w.zaehm_noetig
	if zaehm_fortschritt >= 1.0:
		zaehmen = null
		_gezaehmt(w)


func _zaehm_ziel() -> WildPferd:
	var s := spieler.global_position
	for w in pferde:
		if w.zustand != "fliehen" and Vector2(w.position.x, w.position.z).distance_to(Vector2(s.x, s.z)) <= ZAEHM_ABSTAND:
			return w
	return null


func _gezaehmt(w: WildPferd) -> void:
	if Testlauf.optionen.has("log"):
		print("Zähmen: %s gezähmt (Bindung %d, %s)" % [w.daten.name, w.daten.bindung, HoofyDaten.beschreibung(w.daten)])
	pferde.erase(w)
	eigene.append(w)
	w.daten.erase("wild")
	w.daten.reit_ab = int(w.daten.bindung) + FRISCH_BINDUNG       # frisch: noch nicht reitbar
	w.daten.neu = true                                            # bis es einmal auf dem Hof war
	benutzte_namen.append(w.daten.name)
	w.laerm = 0.0
	w.alarm = false
	w.zeige("♥", Color(1.0, 0.35, 0.45), 2.5)
	var wie := _anleinen(w)
	var sie: bool = w.daten.sex == "w"
	meldung.emit("%s ist %s Bring %s auf deinen Hof, sonst ist %s wieder wild, wenn %s sich losreißt." % [
		w.daten.name, wie, "sie" if sie else "ihn", "sie" if sie else "er", "sie" if sie else "er"], 4.0)


## An die Leine nehmen oder frei folgen lassen; geht beides nicht, wartet es (Wild:attach)
func _anleinen(w: WildPferd) -> String:
	var sie: bool = w.daten.sex == "w"
	var folgt := int(w.daten.bindung) >= int(HoofyDaten.daten().stats.bindung.folgt)
	var am_strick := fuehrung.filter(func(x): return x.zustand == "gefuehrt").size()
	if fuehrung.size() >= MAX_FUEHREN or (not folgt and am_strick >= MAX_STRICK):
		w.zustand = "lose"
		w.soll_tempo = 0.0
		return "gezähmt. Deine Leine ist belegt, %s wartet hier." % ("sie" if sie else "er")
	fuehrung.append(w)
	w.zustand = "folgt" if folgt else "gefuehrt"
	w.leine_uhr = 0.0
	return "gezähmt, folgt dir." if folgt else "gezähmt, an der Leine."


# --- Eigene Pferde ---

func _eigen(w: WildPferd, delta: float) -> void:
	match w.zustand:
		"gefuehrt", "folgt":
			var p := Vector2(w.position.x, w.position.z)
			var i := fuehrung.find(w)
			var z: Vector3 = spieler.spur_punkt(4.0 + i * 3.5)
			w.ziel = Vector2(z.x, z.z)
			var d := p.distance_to(w.ziel)
			w.soll_tempo = 0.0 if d < 0.8 else clampf(d * 1.4, 0.8, 13.0)
			if w.zustand == "gefuehrt":
				w.leine_uhr += delta
				if w.leine_uhr >= 1.0:
					w.leine_uhr = 0.0
					if _reisst_aus(w):
						_ausreissen(w)
		"ausgerissen":
			w.uhr -= delta
			if w.uhr <= 0.0:
				w.zustand = "lose"
				w.soll_tempo = 0.0
		"lose":
			w.soll_tempo = 0.0


## Einmal pro Sekunde würfeln, entspricht der Katalog-Chance je 10 s (Leash.escape_roll)
func _reisst_aus(w: WildPferd) -> bool:
	var leine: Dictionary = HoofyDaten.daten().stats.leine
	var p := (100.0 - float(w.daten.bindung)) / float(leine.teiler) / 100.0
	var frisch: bool = w.daten.has("reit_ab") and int(w.daten.bindung) < int(w.daten.reit_ab)
	if spieler.reitet():
		p *= float(leine.reiten)
	elif spieler.rennt():
		p *= float(leine.sprinten)
	if frisch and (spieler.reitet() or spieler.rennt()):
		p *= FRISCH_FAKTOR
	if w.daten.zug == "schreckhaft":
		p *= float(HoofyDaten.daten().charakter.schreckhaft.ausreiss_faktor)
	p = minf(p, 1.0)
	var je_sekunde := 1.0 - pow(1.0 - p, 1.0 / float(leine.sek))
	return _rng.randf() < je_sekunde


func _ausreissen(w: WildPferd) -> void:
	if Testlauf.optionen.has("log"):
		print("Leine: %s reißt aus (Frame %d)" % [w.daten.name, Engine.get_physics_frames()])
	fuehrung.erase(w)
	if w.daten.get("neu", false):
		# noch nie auf dem Hof: wieder wild, mit der Bindung von vor dem Zähmen (Wild:rewild)
		eigene.erase(w)
		pferde.append(w)
		benutzte_namen.erase(w.daten.name)
		w.daten.bindung = clampi(int(w.daten.reit_ab) - FRISCH_BINDUNG, 0, 100)
		w.daten.erase("reit_ab")
		w.daten.erase("neu")
		w.daten.wild = true
		_fliehen(w)
		w.uhr = 2.5
		meldung.emit("%s hat sich losgerissen und ist wieder wild!" % w.daten.name, 2.5)
		return
	w.zustand = "ausgerissen"
	w.uhr = 1.2
	var s := Vector2(spieler.global_position.x, spieler.global_position.z)
	w.ziel = Vector2(w.position.x, w.position.z) + _fluchtrichtung(w, s) * 20.0
	w.soll_tempo = FLUCHT_TEMPO
	meldung.emit("%s ist ausgerissen!" % w.daten.name, 2.5)


# --- Bewegung (wild und eigen) ---

func _bewegen(w: WildPferd, delta: float) -> void:
	var p := Vector2(w.position.x, w.position.z)
	var richtung := w.ziel - p
	if w.soll_tempo > 0.0 and richtung.length() > 0.5:
		var soll := atan2(-richtung.x, -richtung.y)
		w.rotation.y = rotate_toward(w.rotation.y, soll, delta * (2.5 if w.tempo < 4.0 else 1.6))
	w.tempo = move_toward(w.tempo, w.soll_tempo, delta * 5.0)
	var vorne := Vector2(-sin(w.rotation.y), -cos(w.rotation.y))
	var neu := p + vorne * w.tempo * delta
	# Nicht ins tiefe Wasser (außer über die Brücke), nicht steile Hänge hoch, im Tal bleiben
	var bruecke := gelaende.auf_bruecke(neu.x, neu.y)
	if (not bruecke and gelaende.wassertiefe(neu.x, neu.y) > 0.4) or gelaende.normale(neu.x, neu.y).y < 0.75 or not gelaende.im_tal(neu.x, neu.y, 20.0):
		if not w.eigen():
			w.ziel = w.heim
		w.rotation.y += delta * 3.0
		w.tempo = 0.0
		w.modell.animieren("stehen", 0.0)
		return
	var h := gelaende.bruecke.y if bruecke else gelaende.hoehe(neu.x, neu.y)
	w.position = Vector3(neu.x, h, neu.y)
	var lang := w.modell.stockmass * 0.75
	var laengs := 0.0 if bruecke else atan2(gelaende.hoehe(neu.x + vorne.x * lang, neu.y + vorne.y * lang) - gelaende.hoehe(neu.x - vorne.x * lang, neu.y - vorne.y * lang), lang * 2.0)
	w.neigung = lerpf(w.neigung, laengs, 1.0 - exp(-delta * 6.0))
	w.modell.rotation.x = w.neigung
	w.modell.animieren(w.gang(), w.tempo)


## Seil vom Spieler zu jedem Pferd am Strick, leicht durchhängend
func _seil_zeichnen() -> void:
	_seil_netz.clear_surfaces()
	var am_strick := fuehrung.filter(func(x): return x.zustand == "gefuehrt")
	if am_strick.is_empty():
		return
	_seil_netz.surface_begin(Mesh.PRIMITIVE_LINES)
	var hand: Vector3 = spieler.global_position + Vector3.UP * 1.6
	for w: WildPferd in am_strick:
		var kopf := w.global_position + Vector3.UP * w.modell.stockmass * 1.25 - w.global_basis.z * w.modell.stockmass * 0.7
		var vorher := hand
		for k in range(1, 13):
			var t := k / 12.0
			var p := hand.lerp(kopf, t) + Vector3.DOWN * sin(t * PI) * 0.6
			_seil_netz.surface_add_vertex(vorher)
			_seil_netz.surface_add_vertex(p)
			vorher = p
	_seil_netz.surface_end()
