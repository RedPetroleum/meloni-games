class_name Gras
extends MultiMeshInstance3D
## Grasbüschel in einem Quadrat um das Pferd (siehe shaders/gras.gdshader). Das Gitter rastet
## auf ganze Abstände ein, so stehen die Halme beim Mitwandern immer an derselben Weltstelle.

var gelaende: Gelaende
var ziel: Node3D
var abstand := 0.32
var radius := 40.0


func _ready() -> void:
	if Einstellungen.stufe == Einstellungen.Stufe.DECK:
		abstand = 0.45
		radius = 30.0
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/gras.gdshader")
	for p in ["hoehen", "masken", "wege", "groesse", "punkte", "raster"]:
		mat.set_shader_parameter(p, gelaende.material.get_shader_parameter(p))
	mat.set_shader_parameter("gras_diff", load("res://assets/download/texturen/boden_gras_diff.jpg"))
	mat.set_shader_parameter("abstand", abstand)
	mat.set_shader_parameter("radius", radius)
	material_override = mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var seite := int(radius * 2.0 / abstand)
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = _bueschel()
	multimesh.instance_count = seite * seite
	for iz in seite:
		for ix in seite:
			multimesh.set_instance_transform(iz * seite + ix, Transform3D(Basis(), Vector3((ix - seite / 2) * abstand, 0, (iz - seite / 2) * abstand)))
	# Höhe kommt erst im Shader: Culling-Box groß genug machen
	custom_aabb = AABB(Vector3(-radius, -50, -radius), Vector3(radius * 2, 400, radius * 2))


func _process(_delta: float) -> void:
	if ziel == null:
		return
	var p := ziel.global_position
	global_position = Vector3(snappedf(p.x, abstand), 0, snappedf(p.z, abstand))
	(material_override as ShaderMaterial).set_shader_parameter("spieler", p)


## Ein Büschel aus 7 schmalen, gebogenen Halmen (y von 0 bis 1, Höhe setzt der Shader)
func _bueschel() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for h in 7:
		var w := TAU * h / 7.0 + rng.randf() * 0.8
		var quer := Vector3(cos(w), 0, sin(w))
		var raus := Vector3(-sin(w), 0, cos(w)) * rng.randf_range(0.08, 0.22)
		var versatz := Vector3(rng.randf_range(-0.12, 0.12), 0, rng.randf_range(-0.12, 0.12))
		var breite := rng.randf_range(0.012, 0.02)
		var ringe := []
		for s in 4:
			var t := s / 3.0
			var mitte := versatz + raus * t * t + Vector3(0, t * rng.randf_range(0.7, 1.0) if s == 3 else t, 0)
			var b := breite * (1.0 - t * 0.85)
			ringe.append([mitte - quer * b, mitte + quer * b, t])
		for s in 3:
			var a: Array = ringe[s]
			var c: Array = ringe[s + 1]
			for e in [[a[0], a[2]], [a[1], a[2]], [c[1], c[2]], [a[0], a[2]], [c[1], c[2]], [c[0], c[2]]]:
				st.set_normal(Vector3.UP)
				st.set_uv(Vector2(0, e[1]))
				st.add_vertex(e[0])
	return st.commit()
