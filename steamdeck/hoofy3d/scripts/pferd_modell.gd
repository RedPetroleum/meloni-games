class_name PferdModell
extends Node3D
## Das sichtbare Pferd: Modell laden, auf Rassengröße bringen, Fell-Shader setzen, Animation
## zur Gangart wählen.
##
## Austauschbar: Ein anderes Modell (z. B. ein gekauftes realistisches Pferd) unter MODELL
## eintragen. Animationen werden über ihre Namen gefunden (ANIMATIONEN); fehlt eine, wird die
## nächstbeste mit angepasster Geschwindigkeit abgespielt.

const MODELL := "res://assets/download/pferd/pferd.glb"
## Drehung, damit das Modell nach -Z (Godots „vorne“) schaut
const MODELL_DREHUNG := PI
## Kopfhöhe ist etwa so viel höher als das Stockmaß (Widerrist)
const KOPF_FAKTOR := 1.4

const ANIMATIONEN := {
	"stehen": ["idle", "stand", "Idle"],
	"schritt": ["walk", "Walk"],
	"trab": ["trot", "Trot"],
	"galopp": ["canter", "gallop", "Gallop"],
	"renngalopp": ["gallop", "run", "Gallop", "Run"],
	"grasen": ["eat", "graze", "Eating"],
}
## Mit welcher Bodengeschwindigkeit (m/s) eine Animation natürlich aussieht
const ANIM_TEMPO := {"schritt": 1.7, "trab": 3.6, "galopp": 7.5, "renngalopp": 12.0}

var daten: Dictionary
var stockmass := 1.65
var fell := ShaderMaterial.new()
var _player: AnimationPlayer
var _anims := {}             # Gangart → Animationsname
var _ersatz := ""            # einzige vorhandene Animation (Platzhalter-Pferd)
var _aktuell := ""


func _init(pferd: Dictionary) -> void:
	daten = pferd


func _ready() -> void:
	var rasse := HoofyDaten.rasse(daten.rasse)
	var koerper: Dictionary = HoofyDaten.KOERPER.get(rasse.get("koerper", "warmblut"), HoofyDaten.KOERPER.warmblut)
	stockmass = koerper.stockmass
	var szene: Node3D = load(MODELL).instantiate()
	add_child(szene)

	var aabb := AABB()
	var erste := true
	for mi: MeshInstance3D in szene.find_children("*", "MeshInstance3D", true, false):
		var box := mi.transform * mi.mesh.get_aabb()
		aabb = box if erste else aabb.merge(box)
		erste = false
		mi.material_override = fell
		var arrays := mi.mesh.surface_get_arrays(0)
		if arrays[Mesh.ARRAY_NORMAL] == null:
			fell.set_shader_parameter("flache_normalen", true)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var einheit := stockmass * KOPF_FAKTOR / aabb.size.y
	szene.scale = Vector3(einheit * koerper.breite, einheit, einheit)
	szene.rotation.y = MODELL_DREHUNG
	szene.position.y = -aabb.position.y * einheit

	fell.shader = load("res://shaders/fell.gdshader")
	var f: Dictionary = HoofyDaten.FELL.get(daten.farbe, HoofyDaten.FELL.brauner)
	fell.set_shader_parameter("fell", f.fell)
	fell.set_shader_parameter("beine", f.get("beine", f.fell))
	fell.set_shader_parameter("abzeichen", f.get("abzeichen", Color(0.92, 0.9, 0.86)))
	fell.set_shader_parameter("muster", f.get("muster", HoofyDaten.Muster.KEINS))
	fell.set_shader_parameter("glanz", f.get("glanz", 0.0))
	fell.set_shader_parameter("tupfen", f.get("tupfen", 0.08))
	fell.set_shader_parameter("einheit", einheit)
	fell.set_shader_parameter("boden", aabb.position.y)
	fell.set_shader_parameter("hoehe", aabb.size.y)
	fell.set_shader_parameter("saat", float(hash(daten) % 1000) / 10.0)

	var players := szene.find_children("*", "AnimationPlayer", true, false)
	if players:
		_player = players[0]
		var liste := _player.get_animation_list()
		for gang in ANIMATIONEN:
			for name in ANIMATIONEN[gang]:
				var treffer := Array(liste).filter(func(a: String): return a.to_lower().contains(name.to_lower()))
				if treffer:
					_anims[gang] = treffer[0]
					break
		if liste.size() > 0:
			_ersatz = liste[0]
		for a in liste:
			_player.get_animation(a).loop_mode = Animation.LOOP_LINEAR


## gang: "stehen", "schritt", "trab", "galopp", "renngalopp", "grasen"; tempo in m/s
func animieren(gang: String, tempo: float) -> void:
	if _player == null:
		return
	var name: String = _anims.get(gang, "")
	var skala := 1.0
	if name == "":
		# Platzhalter hat nur Galopp: langsamer abspielen statt gar nicht bewegen
		name = _anims.get("galopp", _ersatz)
		skala = tempo / ANIM_TEMPO.galopp * 1.6 if tempo > 0.2 else 0.0
	elif ANIM_TEMPO.has(gang):
		skala = clampf(tempo / ANIM_TEMPO[gang], 0.6, 1.5)
	if name == "":
		return
	if name != _aktuell:
		_player.play(name, 0.25)
		_aktuell = name
	_player.speed_scale = skala


func schmutz(wert: float) -> void:
	fell.set_shader_parameter("schmutz", wert)
