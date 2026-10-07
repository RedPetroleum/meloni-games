class_name FigurModell
extends Node3D
## Die sichtbare Spielfigur (Mixamo, Ch37) mit den Animationen aus assets/download/figur.
## Gehen, Rennen und Schleichen bewegen in der Datei die Hüfte vorwärts: das wird beim Laden
## entfernt (die Figur bewegt der Code), die Strecke ergibt das natürliche Tempo der Animation.
## Die Teile (Haare, Shirt, Hose, Schuhe) lassen sich einzeln färben (später: Garderobe).

const ORDNER := "res://assets/download/figur/"
const MODELL := "Ch37_nonPBR.fbx"
## Name → [Datei, wiederholen]
const ANIMATIONEN := {
	"stehen": ["Breathing Idle.fbx", true],
	"gehen": ["Walking.fbx", true],
	"rennen": ["Running.fbx", true],
	"schleichen": ["Crouched Walking.fbx", true],
	"springen": ["Jump.fbx", false],
	"streicheln": ["Petting Animal.fbx", false],
	"aufheben": ["Picking Up Object.fbx", false],
	"schlafen": ["Sleeping Idle.fbx", true],
	"reden": ["Talking.fbx", true],
}
const HUEFTE := "mixamorig6_Hips"

static var _bibliothek: AnimationLibrary
static var _tempo := {}                 # Animation → Bodentempo in m/s (aus der entfernten Hüftbewegung)

var player: AnimationPlayer
var skelett: Skeleton3D
var teile := {}                          # „Hair“, „Shirt“, „Pants“, „Sneakers“, „Body“ → MeshInstance3D
var _aktuell := ""
var _sitz: Reitsitz


func _ready() -> void:
	var szene: Node3D = load(ORDNER + MODELL).instantiate()
	szene.rotation.y = PI                # Mixamo schaut nach +Z, Godot-vorne ist -Z
	add_child(szene)
	skelett = szene.find_children("*", "Skeleton3D", true, false)[0]
	for mi: MeshInstance3D in szene.find_children("*", "MeshInstance3D", true, false):
		teile[mi.name.trim_prefix("Ch37_")] = mi
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	player = szene.find_children("*", "AnimationPlayer", true, false)[0]
	if _bibliothek == null:
		_bibliothek = _laden()
	player.add_animation_library("f", _bibliothek)
	animieren("stehen")


## Hand in Weltkoordinaten („Left“ oder „Right“), für die Zügel
func hand(seite: String) -> Vector3:
	var i := skelett.find_bone("mixamorig6_%sHand" % seite)
	return skelett.global_transform * skelett.get_bone_global_pose(i).origin


## Fußziele im Sattel (Steigbügel in Weltkoordinaten)
func fuesse(fuss_ziele: Array, hand_ziele: Array, knie_ziele: Array = []) -> void:
	if _sitz:
		_sitz.ziele = fuss_ziele
		_sitz.haende = hand_ziele
		_sitz.knie = knie_ziele


## Reitsitz an oder aus (im Sattel: Beine um das Pferd, Hände an den Zügeln)
func sitzen(an: bool) -> void:
	if an and _sitz == null:
		_sitz = Reitsitz.new()
		skelett.add_child(_sitz)
		animieren("stehen")
	elif not an and _sitz:
		_sitz.queue_free()
		_sitz = null


static func _laden() -> AnimationLibrary:
	var bib := AnimationLibrary.new()
	for name in ANIMATIONEN:
		var datei: String = ANIMATIONEN[name][0]
		var s: Node = load(ORDNER + datei).instantiate()
		var ap: AnimationPlayer = s.find_children("*", "AnimationPlayer", true, false)[0]
		var a: Animation = ap.get_animation(ap.get_animation_list()[0]).duplicate(true)
		a.loop_mode = Animation.LOOP_LINEAR if ANIMATIONEN[name][1] else Animation.LOOP_NONE
		_tempo[name] = _vorwaerts_entfernen(a)
		bib.add_animation(name, a)
		s.free()
	return bib


## Hüfte nicht vorwärts wandern lassen (z-Strecke abziehen). Gibt das Tempo in m/s zurück.
static func _vorwaerts_entfernen(a: Animation) -> float:
	for t in a.get_track_count():
		if a.track_get_type(t) != Animation.TYPE_POSITION_3D or not str(a.track_get_path(t)).ends_with(HUEFTE):
			continue
		var n := a.track_get_key_count(t)
		if n < 2:
			return 0.0
		var start: Vector3 = a.track_get_key_value(t, 0)
		var ende: Vector3 = a.track_get_key_value(t, n - 1)
		var strecke := ende.z - start.z
		if absf(strecke) < 0.2:
			return 0.0
		for k in n:
			var v: Vector3 = a.track_get_key_value(t, k)
			var anteil := a.track_get_key_time(t, k) / a.length
			v.z -= strecke * anteil
			v.x = start.x + (v.x - start.x) * 0.3      # seitliches Schwanken etwas dämpfen
			a.track_set_key_value(t, k, v)
		return absf(strecke) / a.length
	return 0.0


## Spielt eine Animation; bei Fortbewegung passend zum Bodentempo (m/s), damit nichts rutscht.
func animieren(name: String, tempo := 0.0) -> void:
	var skala := 1.0
	var natur: float = _tempo.get(name, 0.0)
	if natur > 0.0:
		skala = clampf(tempo / natur, 0.5, 1.6) if tempo > 0.05 else 0.0
	if name != _aktuell:
		player.play("f/" + name, 0.25)
		_aktuell = name
	player.speed_scale = skala


func laeuft_noch() -> bool:
	return player.is_playing() and player.current_animation_position < player.current_animation_length - 0.05


static func natuerliches_tempo(name: String) -> float:
	return _tempo.get(name, 0.0)
