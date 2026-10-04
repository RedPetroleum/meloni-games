class_name Pferd
extends CharacterBody3D
## Das gerittene Pferd. Steuerung wie in Red Dead: Stick gibt die Richtung (relativ zur Kamera),
## Antreiben (A) schaltet eine Gangart hoch, Halten hält das Tempo, Zügeln (B) schaltet runter.
## Renngalopp kostet Energie (Hoofy: Energie bis zur Ausdauer), im Schritt erholt sich das Pferd.
## Tempo, Stärke und Ausdauer kommen aus den Hoofy-Werten des Pferdes.

enum Gang { STEHEN, SCHRITT, TRAB, GALOPP, RENNGALOPP }
const GANG_NAMEN := ["Stehen", "Schritt", "Trab", "Galopp", "Renngalopp"]
const GANG_ID := ["stehen", "schritt", "trab", "galopp", "renngalopp"]
const GANG_TEMPO := [0.0, 1.7, 3.6, 7.5, 12.0]   # m/s bei durchschnittlichem Tempo-Wert
const SCHWERKRAFT := 18.0
const RENNGALOPP_HALTEN := 1.6   # Sekunden ohne Antreiben, dann zurück in den Galopp

signal gangart_gewechselt(gang: int)
signal erschoepft

var daten: Dictionary
var gelaende: Gelaende
var kamera: Kamera
var modell: PferdModell
var hoehe_kamera := 2.2

var gang := Gang.STEHEN
var energie := 100.0
var energie_max := 100.0
var _stufe := Gang.SCHRITT       # gewünschte Gangart, wenn der Stick gedrückt ist
var _seit_antreiben := 0.0
var _tempo := 0.0
var _richtung := 0.0             # Gierwinkel, 0 = schaut nach -Z
var _drehrate := 0.0
var _neigung := Vector2.ZERO     # sichtbare Längs- und Querneigung
var _sprung := false


func _init(pferd: Dictionary) -> void:
	daten = pferd


func _ready() -> void:
	modell = PferdModell.new(daten)
	add_child(modell)
	var s := modell.stockmass / 1.65
	hoehe_kamera = 1.55 + modell.stockmass * 0.45
	# Liegende Kapsel als Rumpf, unten am Boden: so rutscht das Pferd sauber über Hänge
	var form := CapsuleShape3D.new()
	form.radius = 0.55 * s
	form.height = 2.3 * s
	var cs := CollisionShape3D.new()
	cs.shape = form
	cs.rotation.x = PI / 2
	cs.position.y = form.radius
	add_child(cs)
	floor_max_angle = deg_to_rad(42.0)
	floor_snap_length = 0.8
	safe_margin = 0.04
	energie_max = float(daten.ausdauer)
	energie = energie_max


func tempo() -> float:
	return _tempo


func blickwinkel() -> float:
	return _richtung


func gang_name() -> String:
	return GANG_NAMEN[gang]


func _tempo_faktor() -> float:
	return 0.82 + float(daten.tempo) / 220.0


func _physics_process(delta: float) -> void:
	var stick := Input.get_vector("links", "rechts", "vor", "zurueck")
	var staerke := minf(stick.length(), 1.0)
	var welt := Vector3(stick.x, 0, stick.y).rotated(Vector3.UP, kamera.yaw if kamera else 0.0)

	# --- Gangart wählen ---
	if Input.is_action_just_pressed("antreiben"):
		_stufe = mini(_stufe + 1, Gang.RENNGALOPP) as Gang
		_seit_antreiben = 0.0
	elif Input.is_action_pressed("antreiben"):
		_seit_antreiben = 0.0
	else:
		_seit_antreiben += delta
	if Input.is_action_just_pressed("zuegeln"):
		_stufe = maxi(_stufe - 1, Gang.SCHRITT) as Gang
	if _stufe == Gang.RENNGALOPP and _seit_antreiben > RENNGALOPP_HALTEN:
		_stufe = Gang.GALOPP
	if energie < 1.0 and _stufe >= Gang.RENNGALOPP:
		_stufe = Gang.GALOPP
		erschoepft.emit()

	var neu := Gang.STEHEN
	if staerke > 0.2:
		neu = _stufe
		# leicht angetippter Stick = gemütlicher, auch ohne Zügeln
		if staerke < 0.6 and neu > Gang.TRAB:
			neu = Gang.TRAB
	elif _tempo < 0.3:
		_stufe = Gang.SCHRITT
	if Input.is_action_pressed("zuegeln") and staerke < 0.2:
		neu = Gang.STEHEN
	if neu != gang:
		gang = neu
		gangart_gewechselt.emit(gang)

	# --- Energie (Hoofy: Ausdauer bestimmt den Vorrat) ---
	match gang:
		Gang.RENNGALOPP: energie -= 9.0 * delta * 60.0 / energie_max
		Gang.GALOPP: energie -= 1.0 * delta
		Gang.TRAB: energie += 1.5 * delta
		_: energie += 5.0 * delta
	energie = clampf(energie, 0.0, energie_max)

	# --- Tempo ---
	var ziel: float = GANG_TEMPO[gang] * _tempo_faktor()
	var vorne := Vector3(sin(_richtung), 0, cos(_richtung)) * -1.0
	var n := gelaende.normale(global_position.x, global_position.z)
	var bergauf := -n.dot(vorne)                     # > 0 heißt bergauf
	ziel *= clampf(1.0 - bergauf * 1.6, 0.35, 1.12)
	var tiefe := Gelaende.WASSER - gelaende.hoehe(global_position.x, global_position.z)
	if tiefe > 0.3:
		ziel = minf(ziel, lerpf(4.0, 1.2, clampf((tiefe - 0.3) / 1.2, 0.0, 1.0)))

	# --- Richtung: wendiger im Schritt, weite Bögen im Galopp ---
	var drehung := 0.0
	if staerke > 0.2:
		var soll := atan2(-welt.x, -welt.z)
		var diff := wrapf(soll - _richtung, -PI, PI)
		var rate := lerpf(2.4, 1.0, clampf(_tempo / 12.0, 0.0, 1.0))
		drehung = clampf(diff, -rate * delta, rate * delta)
		# scharf zurück: erst abbremsen
		if absf(diff) > 2.2 and _tempo > 3.0:
			ziel *= 0.25
	_richtung = wrapf(_richtung + drehung, -PI, PI)
	_drehrate = lerpf(_drehrate, drehung / maxf(delta, 0.0001), 1.0 - exp(-delta * 6.0))
	var beschl := 3.5 if ziel > _tempo else 6.0
	_tempo = move_toward(_tempo, ziel, beschl * delta)

	# --- Bewegung ---
	vorne = Vector3(sin(_richtung), 0, cos(_richtung)) * -1.0
	var vy := velocity.y
	velocity = vorne * _tempo
	if is_on_floor():
		vy = 0.0
		_sprung = false
		if Input.is_action_just_pressed("springen") and _tempo > 2.0:
			vy = 4.2 + float(daten.staerke) / 45.0
			_sprung = true
			floor_snap_length = 0.0
	else:
		vy -= SCHWERKRAFT * delta
	if is_on_floor() and not _sprung:
		floor_snap_length = 0.8
	velocity.y = vy
	move_and_slide()
	rotation.y = _richtung
	# An Hindernissen bremsen statt dagegenzulaufen
	var echt := Vector2(get_real_velocity().x, get_real_velocity().z).length()
	if _tempo > 1.0 and echt < _tempo * 0.4:
		_tempo = move_toward(_tempo, echt, 12.0 * delta)
	# Talgrenze
	if not gelaende.im_tal(global_position.x, global_position.z, 12.0):
		global_position.x = clampf(global_position.x, -Gelaende.GROESSE * 0.5 + 12.0, Gelaende.GROESSE * 0.5 - 12.0)
		global_position.z = clampf(global_position.z, -Gelaende.GROESSE * 0.5 + 12.0, Gelaende.GROESSE * 0.5 - 12.0)
	if global_position.y < gelaende.hoehe(global_position.x, global_position.z) - 1.0:
		global_position.y = gelaende.hoehe(global_position.x, global_position.z) + 0.1


func _process(delta: float) -> void:
	# Körper folgt dem Boden (Längsneigung) und legt sich in Kurven (Querneigung)
	var vorne := -global_transform.basis.z
	var p := global_position
	var lang := modell.stockmass * 0.75
	var hv := gelaende.hoehe(p.x + vorne.x * lang, p.z + vorne.z * lang)
	var hh := gelaende.hoehe(p.x - vorne.x * lang, p.z - vorne.z * lang)
	var laengs := atan2(hv - hh, lang * 2.0)
	if not is_on_floor():
		laengs = clampf(velocity.y * 0.07, -0.3, 0.35)
	var quer := clampf(-_drehrate * _tempo * 0.035, -0.22, 0.22)
	_neigung = _neigung.lerp(Vector2(laengs, quer), 1.0 - exp(-delta * 8.0))
	modell.rotation = Vector3(_neigung.x, 0, _neigung.y)
	modell.animieren(GANG_ID[gang], _tempo)
	var tiefe := Gelaende.WASSER - p.y
	modell.schmutz(clampf(tiefe * 0.5, 0.0, 0.6))
