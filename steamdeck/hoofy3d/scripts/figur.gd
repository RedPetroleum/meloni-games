class_name Figur
extends CharacterBody3D
## Die Spielfigur zu Fuß. Linker Stick: laufen (relativ zur Kamera), A/Shift halten: rennen,
## B/Strg: schleichen an/aus, X/Leertaste: springen, Y/E: Aktion (Wildpferde und eigene Pferde
## kümmern sich darum). Bietet dieselbe Spieler-Schnittstelle wie das gerittene Pferd.
##
## Tempo kommt aus den Animationen (Hüftweg in den Mixamo-Dateien), damit die Füße nicht rutschen.
## Schleichen ist eine 3D-Ergänzung: halber Lärm beim Anschleichen an Wildpferde.

const SCHWERKRAFT := 18.0
const SPRUNG := 4.6                      # m/s nach oben

var gelaende: Gelaende
var kamera: Kamera
var modell := FigurModell.new()
var hoehe_kamera := 1.55
var schleicht := false

var _tempo := 0.0
var _richtung := 0.0
var _rennt := false
var _sprung := false
var _spur := PackedVector3Array()
const SPUR_ABSTAND := 0.3
const SPUR_LAENGE := 120


func _ready() -> void:
	add_child(modell)
	var form := CapsuleShape3D.new()
	form.radius = 0.3
	form.height = 1.7
	var cs := CollisionShape3D.new()
	cs.shape = form
	cs.position.y = 0.85
	add_child(cs)
	floor_max_angle = deg_to_rad(46.0)
	floor_snap_length = 0.5


# --- Spieler-Schnittstelle ---

func tempo() -> float:
	return _tempo


func blickwinkel() -> float:
	return _richtung


func bewegt() -> bool:
	return _tempo > 0.2


func rennt() -> bool:
	return _rennt and _tempo > 2.0


func reitet() -> bool:
	return false


## Wie laut die Schritte für ein lauschendes Wildpferd sind (Schleichen: halb so laut)
func laerm() -> float:
	return 0.5 if schleicht else 1.0


func spur_punkt(abstand: float) -> Vector3:
	var rest := abstand
	var vorher := global_position
	for p in _spur:
		var d := vorher.distance_to(p)
		if d >= rest:
			return vorher.lerp(p, rest / d)
		rest -= d
		vorher = p
	return vorher + global_basis.z * rest


## Blickrichtung setzen (nach dem Absteigen, im Test)
func ausrichten(winkel: float) -> void:
	_richtung = winkel
	rotation.y = winkel


func _physics_process(delta: float) -> void:
	var stick := Input.get_vector("links", "rechts", "vor", "zurueck")
	var staerke := minf(stick.length(), 1.0)
	var welt := Vector3(stick.x, 0, stick.y).rotated(Vector3.UP, kamera.yaw if kamera else 0.0)
	if Input.is_action_just_pressed("zuegeln"):
		schleicht = not schleicht
	_rennt = Input.is_action_pressed("antreiben") and staerke > 0.2
	if _rennt:
		schleicht = false
	var art := "schleichen" if schleicht else ("rennen" if _rennt else "gehen")
	var ziel := FigurModell.natuerliches_tempo(art) * (staerke if staerke > 0.2 else 0.0)
	if staerke > 0.2:
		var soll := atan2(-welt.x, -welt.z)
		_richtung = rotate_toward(_richtung, soll, delta * 9.0)
	# Tiefes Wasser: nur über die Brücke (wie beim Pferd)
	var vorn := global_position - Vector3(sin(_richtung), 0, cos(_richtung)) * 0.6
	if gelaende.wassertiefe(vorn.x, vorn.z) > 0.6 and not gelaende.auf_bruecke(vorn.x, vorn.z):
		ziel = 0.0
		_tempo = 0.0
	_tempo = move_toward(_tempo, ziel, (10.0 if ziel > _tempo else 14.0) * delta)
	var vorne := -Vector3(sin(_richtung), 0, cos(_richtung))
	var vy := velocity.y
	velocity = vorne * _tempo
	if is_on_floor():
		vy = 0.0
		_sprung = false
		if Input.is_action_just_pressed("springen"):
			vy = SPRUNG
			_sprung = true
			schleicht = false
	else:
		vy -= SCHWERKRAFT * delta
	velocity.y = vy
	move_and_slide()
	rotation.y = _richtung
	if _spur.is_empty() or _spur[0].distance_to(global_position) >= SPUR_ABSTAND:
		_spur.insert(0, global_position)
		if _spur.size() > SPUR_LAENGE:
			_spur.resize(SPUR_LAENGE)
	if not gelaende.im_tal(global_position.x, global_position.z, 12.0):
		global_position.x = clampf(global_position.x, -Gelaende.GROESSE * 0.5 + 12.0, Gelaende.GROESSE * 0.5 - 12.0)
		global_position.z = clampf(global_position.z, -Gelaende.GROESSE * 0.5 + 12.0, Gelaende.GROESSE * 0.5 - 12.0)
	if global_position.y < gelaende.hoehe(global_position.x, global_position.z) - 1.0:
		global_position.y = gelaende.hoehe(global_position.x, global_position.z) + 0.1


func _process(_delta: float) -> void:
	if _sprung and not is_on_floor():
		modell.animieren("springen")
	elif _tempo > 0.1:
		modell.animieren("schleichen" if schleicht else ("rennen" if _rennt else "gehen"), _tempo)
	else:
		modell.animieren("schleichen" if schleicht else "stehen", 0.0)
