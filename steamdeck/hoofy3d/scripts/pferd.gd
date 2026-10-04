class_name Pferd
extends CharacterBody3D
## Das gerittene Pferd. Steuerung wie in Red Dead: Stick gibt die Richtung (relativ zur Kamera),
## Antreiben (A) schaltet eine Gangart hoch, Halten hält das Tempo, Zügeln (B) schaltet runter.
##
## Regeln aus dem 2D-Hoofy (game/ride.lua, KATALOG §2, E30):
## - Tempo = wirksames Tempo (Gewichtsmalus) + Sattel-Bonus; es wirkt wie in Hoofy auf Schritt
##   (1,3 + 0,6 × T/100) und Galopp (2,0 + 1,4 × T/100), umgerechnet auf die 3D-Gangarten
## - Sprunghöhe 6 + 0,3 × Stärke (Hoofy-Pixel, 16 px = 1 m), Sprung kostet 5 Energie
## - Energie ist der Tagesvorrat (= Ausdauer, Reset am Morgen). Reiten 1 je 10 s Hoofy-Zeit; der
##   3D-Tag ist doppelt so lang, also 1 je 20 s. Galopp doppelt, Renngalopp (nur 3D) vierfach.
##   Bei 0 nur noch langsamer Schritt und kein Sprung.

enum Gang { STEHEN, SCHRITT, TRAB, GALOPP, RENNGALOPP }
const GANG_NAMEN := ["Stehen", "Schritt", "Trab", "Galopp", "Renngalopp"]
const GANG_ID := ["stehen", "schritt", "trab", "galopp", "renngalopp"]
## m/s bei Tempo 50. Trab ist vorerst ein zügiger Schritt: dem Pferdemodell fehlt eine
## Trab-Animation, und schneller abgespielter Schritt sieht albern aus.
const GANG_TEMPO := [0.0, 1.6, 2.3, 7.5, 11.0]
const ENERGIE_JE_S := [0.0, 0.05, 0.05, 0.1, 0.2] # Reiten 1 je 20 s, Galopp doppelt, Renngalopp vierfach
const SPRUNG_ENERGIE := 5.0
const HOOFY_PX_JE_M := 16.0
const SCHWERKRAFT := 18.0
const RENNGALOPP_HALTEN := 1.6   # Sekunden ohne Antreiben, dann zurück in den Galopp
const MUEDE_SCHRITT := 0.6       # ohne Energie: so viel vom Schritttempo

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
	modell = PferdModell.new(daten, true)
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
	energie_max = float(HoofyDaten.stat(daten, "ausdauer"))
	energie = float(daten.get("energie", energie_max))


func tempo() -> float:
	return _tempo


func blickwinkel() -> float:
	return _richtung


func gang_name() -> String:
	return GANG_NAMEN[gang]


## Wie stark das Tempo-Stat die Gangart beschleunigt, im selben Verhältnis wie im 2D-Hoofy
## (dort Pixel je Frame), 1,0 bei Tempo 50
func _tempo_faktor(g: int) -> float:
	var t := HoofyDaten.reittempo(daten) / 100.0
	if g >= Gang.GALOPP:
		return (2.0 + 1.4 * t) / 2.7
	return (1.3 + 0.6 * t) / 1.6


## Neuer Tag: Energie zurück auf die Ausdauer (KATALOG §1)
func neuer_tag() -> void:
	energie = energie_max
	daten.energie = energie


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
	if energie <= 0.0 and _stufe > Gang.SCHRITT:
		_stufe = Gang.SCHRITT
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

	# --- Energie: Tagesvorrat, erholt sich erst am nächsten Morgen ---
	if _tempo > 0.3:
		energie = maxf(energie - ENERGIE_JE_S[gang] * delta, 0.0)
	daten.energie = energie

	# --- Tempo ---
	var ziel: float = GANG_TEMPO[gang] * _tempo_faktor(gang)
	if energie <= 0.0:
		ziel = minf(ziel, GANG_TEMPO[Gang.SCHRITT] * MUEDE_SCHRITT)
	var vorne := Vector3(sin(_richtung), 0, cos(_richtung)) * -1.0
	var n := gelaende.normale(global_position.x, global_position.z)
	var bergauf := -n.dot(vorne)                     # > 0 heißt bergauf
	if gelaende.auf_bruecke(global_position.x, global_position.z):
		bergauf = 0.0
	ziel *= clampf(1.0 - bergauf * 1.6, 0.35, 1.12)
	# Wassertiefe an den Hufen (auf der Brücke: keine)
	var tiefe := gelaende.wasserspiegel(global_position.x, global_position.z) - global_position.y
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
	# Der Fluss ist nur über die Brücke passierbar (Heimattal, wie im 2D-Hoofy)
	var vorn := global_position + Vector3(sin(_richtung), 0, cos(_richtung)) * -1.4
	if gelaende.wassertiefe(vorn.x, vorn.z) > 0.6 and not gelaende.auf_bruecke(vorn.x, vorn.z):
		ziel = 0.0
		_tempo = minf(_tempo, 0.5)
	var beschl := 3.5 if ziel > _tempo else 6.0
	_tempo = move_toward(_tempo, ziel, beschl * delta)

	# --- Bewegung ---
	vorne = Vector3(sin(_richtung), 0, cos(_richtung)) * -1.0
	var vy := velocity.y
	velocity = vorne * _tempo
	if is_on_floor():
		vy = 0.0
		_sprung = false
		if Input.is_action_just_pressed("springen") and _tempo > 2.0 and energie > 0.0:
			var hoehe := (6.0 + 0.3 * HoofyDaten.wirksam(daten, "staerke")) / HOOFY_PX_JE_M
			vy = sqrt(2.0 * SCHWERKRAFT * hoehe)
			energie = maxf(energie - SPRUNG_ENERGIE, 0.0)
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
	if Testlauf.optionen.has("log") and Engine.get_physics_frames() % 30 == 0:
		var v := global_position + Vector3(sin(_richtung), 0, cos(_richtung)) * -1.4
		var stoss := ""
		for k in get_slide_collision_count():
			var c := get_slide_collision(k)
			stoss += "%s@%s " % [(c.get_collider() as Node).name, c.get_normal().snapped(Vector3.ONE * 0.1)]
		print("Pferd f=%d pos=%s tempo=%.1f gang=%s boden=%s vorn: tiefe=%.2f bruecke=%s stoss=%s" % [Engine.get_physics_frames(), global_position.snapped(Vector3.ONE * 0.1), _tempo, GANG_NAMEN[gang], is_on_floor(), gelaende.wassertiefe(v.x, v.z), gelaende.auf_bruecke(v.x, v.z), stoss])
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
	var tiefe := gelaende.wasserspiegel(p.x, p.z) - p.y
	var anim: String = GANG_ID[gang]
	if _sprung and not is_on_floor():
		anim = "springen"
	elif tiefe > 1.1:
		anim = "schwimmen"
	modell.animieren(anim, _tempo, _drehrate)
	modell.schmutz(clampf(tiefe * 0.5, 0.0, 0.6))
