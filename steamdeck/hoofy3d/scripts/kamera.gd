class_name Kamera
extends Node3D
## Third-Person-Kamera: rechter Stick/Maus dreht, beim Reiten schwenkt sie nach kurzer Zeit
## von selbst hinter das Pferd. Im Galopp etwas weiter weg und breiteres Sichtfeld.

const MAUS_EMPFINDLICHKEIT := 0.0025
const STICK_TEMPO := Vector2(2.6, 1.6)

var ziel: Node3D                 # braucht tempo() und blickwinkel()
var gelaende: Gelaende
var yaw := 0.0                  # Start: Blick nach Norden auf den Hof
var pitch := -0.2
var arm := SpringArm3D.new()
var cam := Camera3D.new()
var _ruhe := 10.0                # Sekunden ohne Kameraeingabe
var _tempo := 0.0


func _ready() -> void:
	arm.spring_length = 5.5
	arm.margin = 0.4
	arm.position.y = 0.0
	var kugel := SphereShape3D.new()
	kugel.radius = 0.3
	arm.shape = kugel
	add_child(arm)
	cam.fov = 66.0
	cam.near = 0.1
	cam.far = 2400.0
	arm.add_child(cam)
	if not Testlauf.ist_aktiv():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= e.relative.x * MAUS_EMPFINDLICHKEIT
		pitch = clampf(pitch - e.relative.y * MAUS_EMPFINDLICHKEIT, -1.2, 0.45)
		_ruhe = 0.0
	elif e is InputEventMouseButton and e.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func ausnehmen(koerper: CollisionObject3D) -> void:
	arm.add_excluded_object(koerper.get_rid())


func _process(delta: float) -> void:
	if ziel == null:
		return
	var stick := Input.get_vector("kamera_links", "kamera_rechts", "kamera_hoch", "kamera_runter")
	if stick.length() > 0.05:
		yaw -= stick.x * STICK_TEMPO.x * delta
		pitch = clampf(pitch - stick.y * STICK_TEMPO.y * delta, -1.2, 0.45)
		_ruhe = 0.0
	else:
		_ruhe += delta

	_tempo = lerpf(_tempo, ziel.tempo(), 1.0 - exp(-delta * 2.0))
	# Hinter das Pferd schwenken, wenn es läuft und niemand die Kamera bewegt
	if Input.is_action_just_pressed("kamera_zentrieren"):
		_ruhe = 99.0
	var folgen := clampf((_ruhe - 1.2) * 0.8, 0.0, 1.0) * clampf(_tempo / 3.0, 0.0, 1.0)
	if _ruhe > 50.0:
		folgen = 1.0
	if folgen > 0.0:
		yaw = lerp_angle(yaw, ziel.blickwinkel(), 1.0 - exp(-delta * 2.2 * folgen))
		pitch = lerpf(pitch, -0.17, 1.0 - exp(-delta * 1.0 * folgen))

	var schnell := clampf((_tempo - 4.0) / 9.0, 0.0, 1.0)
	var kopf_hoehe: float = 2.1 if ziel.get("hoehe_kamera") == null else ziel.hoehe_kamera
	var soll := ziel.global_position + Vector3(0, kopf_hoehe, 0)
	global_position = global_position.lerp(soll, 1.0 - exp(-delta * 12.0)) if global_position.distance_to(soll) < 10.0 else soll
	rotation = Vector3(pitch, yaw, 0)
	var nah := float(Testlauf.optionen.get("abstand", "5.2"))
	arm.spring_length = lerpf(arm.spring_length, lerpf(nah, nah + 1.8, schnell), 1.0 - exp(-delta * 2.0))
	cam.fov = lerpf(cam.fov, lerpf(64.0, 76.0, schnell), 1.0 - exp(-delta * 2.0))
	# Nie unter den Boden schauen (SpringArm fängt Hänge ab, das hier die Bodenhöhe selbst)
	if gelaende:
		var p := cam.global_position
		var boden := gelaende.hoehe(p.x, p.z) + 0.5
		if p.y < boden:
			cam.global_position.y = boden
