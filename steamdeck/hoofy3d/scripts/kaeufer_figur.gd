class_name KaeuferFigur
extends Node3D
## Der Käufer des Tages als Figur im Dorf (E40): steht vor dem Laden, redet, mit ❗ und Namen.
## Dasselbe Mixamo-Modell wie die Spielfigur, in den Farben des Käufers.

const FARBEN := {
	"sammlerin": [Color(0.55, 0.15, 0.45), Color(0.15, 0.1, 0.12)],
	"reithof": [Color(0.25, 0.55, 0.3), Color(0.35, 0.25, 0.15)],
	"zuechter": [Color(0.2, 0.3, 0.6), Color(0.2, 0.2, 0.22)],
	"schlachter": [Color(0.85, 0.85, 0.82), Color(0.35, 0.1, 0.1)],
}

var siedlung: Siedlung
var typ := ""
var modell := FigurModell.new()
var _name := Label3D.new()
var _ruf := Label3D.new()


func _ready() -> void:
	add_child(modell)
	for l in [_name, _ruf]:
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.outline_size = 16
		l.no_depth_test = true
		add_child(l)
	_name.font_size = 48
	_name.pixel_size = 0.006
	_name.position.y = 2.15
	_ruf.text = "!"
	_ruf.font_size = 110
	_ruf.pixel_size = 0.005
	_ruf.modulate = Color(1.0, 0.85, 0.2)
	_ruf.position.y = 2.55
	var wo := Gelaende.DORF + Vector2(-6, -4)
	position = Vector3(wo.x, siedlung.gelaende.hoehe(wo.x, wo.y), wo.y)
	rotation.y = PI * 0.15
	visible = false


func zeigen(neu: String) -> void:
	typ = neu
	visible = typ != ""
	if visible:
		siedlung.orte.kaeufer = global_position
		_name.text = Handel.INFO[typ].name
		var f: Array = FARBEN[typ]
		for teil in ["Shirt", "Pants"]:
			var mi: MeshInstance3D = modell.teile.get(teil)
			if mi:
				var m := StandardMaterial3D.new()
				m.albedo_color = f[0] if teil == "Shirt" else f[1]
				m.roughness = 0.8
				mi.material_override = m
		modell.animieren("reden")
	else:
		siedlung.orte.erase("kaeufer")
