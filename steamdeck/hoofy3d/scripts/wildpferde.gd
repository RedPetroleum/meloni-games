class_name Wildpferde
extends Node3D
## Wildpferde wie im 2D-Hoofy (KATALOG §1, §10; E25–E27): im Heimattal 4 gleichzeitig, alle
## 3 Tage wechseln 1–2. Rasse, Farbe, Werte und Name wie H.wild. Sie grasen, ziehen langsam
## umher und fliehen, wenn man heranprescht; je wilder (niedrige Bindung), desto früher.
## Zähmen kommt als Nächstes (siehe README).

const ANZAHL := 4                 # Heimattal (KATALOG §10)
const WECHSEL_TAGE := 3
const MIN_ABSTAND_HOF := 110.0
const FLUCHT_ABSTAND := 28.0
const SCHRECK_TEMPO := 5.0     # schneller als Trab schreckt auf

var gelaende: Gelaende
var spieler: Pferd
var himmel: Himmel
var gebiet := 1
var pferde: Array[WildPferd] = []
var _rng := RandomNumberGenerator.new()


class WildPferd extends Node3D:
	var daten: Dictionary
	var modell: PferdModell
	var herde: Vector2
	var ziel := Vector2.ZERO
	var tempo := 0.0
	var soll_tempo := 0.0
	var zustand := "grasen"
	var uhr := 0.0
	var neigung := 0.0

	func gang() -> String:
		if tempo < 0.2:
			return "grasen" if zustand == "grasen" else "stehen"
		if tempo < 2.5:
			return "schritt"
		if tempo < 5.5:
			return "trab"
		return "galopp" if tempo < 10.0 else "renngalopp"


func _ready() -> void:
	_rng.seed = 4711 + gebiet * 1000     # Hoofy E18: Gebiet n nutzt Seed + n × 1000
	for i in ANZAHL:
		_neues_pferd()
	if himmel:
		himmel.neuer_tag.connect(_tageswechsel)


func _neues_pferd() -> void:
	var w := WildPferd.new()
	w.daten = HoofyDaten.wildpferd(_rng, gebiet, "", pferde.map(func(x): return x.daten.name))
	w.modell = PferdModell.new(w.daten)
	w.add_child(w.modell)
	var p := _weideplatz()
	w.herde = p
	w.position = Vector3(p.x, gelaende.hoehe(p.x, p.y), p.y)
	w.rotation.y = _rng.randf() * TAU
	w.uhr = _rng.randf_range(0.0, 6.0)
	add_child(w)
	pferde.append(w)


## Freie Wiese: nicht im Wald, nicht steil, nicht nass, weg vom Hof und von den anderen
func _weideplatz() -> Vector2:
	var halb := Gelaende.GROESSE * 0.5 - 60.0
	for versuch in 200:
		var p := Vector2(_rng.randf_range(-halb, halb), _rng.randf_range(-halb, halb))
		if p.distance_to(Gelaende.HOF) < MIN_ABSTAND_HOF or gelaende.wald(p.x, p.y) > 0.2:
			continue
		if gelaende.hoehe(p.x, p.y) < 1.5 or gelaende.normale(p.x, p.y).y < 0.9:
			continue
		if pferde.any(func(w): return Vector2(w.position.x, w.position.z).distance_to(p) < 80.0):
			continue
		return p
	return Gelaende.HOF + Vector2(150, 0)


## Alle 3 Tage gehen 1–2 Wildpferde, neue kommen (KATALOG §1)
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
		_denken(w, delta)
		_bewegen(w, delta)


func _denken(w: WildPferd, delta: float) -> void:
	var p := Vector2(w.position.x, w.position.z)
	var s := Vector2(spieler.global_position.x, spieler.global_position.z)
	var abstand := p.distance_to(s)
	# Wilde Pferde (niedrige Bindung) bemerken einen früher
	var vorsicht := 1.4 - float(w.daten.bindung) / 100.0
	var erschrickt := abstand < FLUCHT_ABSTAND * vorsicht and spieler.tempo() > SCHRECK_TEMPO
	if abstand < 7.0 * vorsicht or erschrickt:
		w.zustand = "fliehen"
		w.uhr = 5.0
		var weg := (p - s).normalized()
		w.ziel = p + weg.rotated(randf_range(-0.4, 0.4)) * 40.0
		w.soll_tempo = 8.0 * (2.0 + 1.4 * HoofyDaten.wirksam(w.daten, "tempo") / 100.0) / 2.7
	w.uhr -= delta
	if w.uhr > 0.0:
		if w.zustand != "fliehen" and p.distance_to(w.ziel) < 1.0:
			w.soll_tempo = 0.0
		return
	match w.zustand:
		"fliehen", "wandern":
			w.zustand = "grasen"
			w.soll_tempo = 0.0
			w.uhr = randf_range(4.0, 12.0)
			# Herde zieht nach einer Flucht dorthin, wo sie jetzt ist
			w.herde = w.herde.lerp(p, 0.5)
		"grasen":
			w.zustand = "wandern"
			w.ziel = w.herde + Vector2.from_angle(randf() * TAU) * randf_range(3.0, 25.0)
			w.soll_tempo = 1.4
			w.uhr = randf_range(5.0, 10.0)


func _bewegen(w: WildPferd, delta: float) -> void:
	var p := Vector2(w.position.x, w.position.z)
	var richtung := w.ziel - p
	if w.soll_tempo > 0.0 and richtung.length() > 0.5:
		var soll := atan2(-richtung.x, -richtung.y)
		w.rotation.y = rotate_toward(w.rotation.y, soll, delta * (2.5 if w.tempo < 4.0 else 1.6))
	w.tempo = move_toward(w.tempo, w.soll_tempo, delta * 5.0)
	var vorne := Vector2(-sin(w.rotation.y), -cos(w.rotation.y))
	var neu := p + vorne * w.tempo * delta
	var h := gelaende.hoehe(neu.x, neu.y)
	# Nicht ins tiefe Wasser, nicht steile Hänge hoch, im Tal bleiben
	if gelaende.wassertiefe(neu.x, neu.y) > 0.4 or gelaende.normale(neu.x, neu.y).y < 0.75 or not gelaende.im_tal(neu.x, neu.y, 20.0):
		w.ziel = w.herde
		w.rotation.y += delta * 3.0
		return
	w.position = Vector3(neu.x, h, neu.y)
	var lang := w.modell.stockmass * 0.75
	var laengs := atan2(gelaende.hoehe(neu.x + vorne.x * lang, neu.y + vorne.y * lang) - gelaende.hoehe(neu.x - vorne.x * lang, neu.y - vorne.y * lang), lang * 2.0)
	w.neigung = lerpf(w.neigung, laengs, 1.0 - exp(-delta * 6.0))
	w.modell.rotation.x = w.neigung
	w.modell.animieren(w.gang(), w.tempo)


## Das nächste Wildpferd in Reichweite (für die Anzeige, später fürs Zähmen)
func naechstes(pos: Vector3, reichweite: float) -> WildPferd:
	var bestes: WildPferd = null
	var best := reichweite
	for w in pferde:
		var d := w.position.distance_to(pos)
		if d < best:
			best = d
			bestes = w
	return bestes
