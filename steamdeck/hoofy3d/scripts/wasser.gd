class_name Wasser
extends Node3D
## Der Fluss als Wasserband entlang der Mittellinie des Geländes (fließt von Nord nach Süd) und
## die Holzbrücke, wo der Weg nach Westen ihn kreuzt (wie im 2D-Hoofy: Fluss mit Brücken).

var gelaende: Gelaende


func _ready() -> void:
	_fluss_bauen()
	_bruecke_bauen()


func _fluss_bauen() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var f := gelaende.fluss
	var laenge := 0.0
	var ringe := []
	for i in f.size():
		var t := (f[mini(i + 1, f.size() - 1)] - f[maxi(i - 1, 0)])
		t.y = 0.0
		t = t.normalized()
		var quer := Vector3(t.z, 0, -t.x)
		var halb := gelaende.fluss_breite[i] * 0.5 + 4.0   # unter die Ufer, die Tiefe blendet aus
		if i > 0:
			laenge += f[i].distance_to(f[i - 1])
		ringe.append([f[i] - quer * halb, f[i] + quer * halb, laenge])
	for i in ringe.size() - 1:
		var a: Array = ringe[i]
		var b: Array = ringe[i + 1]
		for e in [[a[0], 0.0, a[2]], [b[0], 0.0, b[2]], [b[1], 1.0, b[2]], [a[0], 0.0, a[2]], [b[1], 1.0, b[2]], [a[1], 1.0, a[2]]]:
			st.set_normal(Vector3.UP)
			st.set_uv(Vector2(e[1], e[2] / 12.0))
			st.add_vertex(e[0])
	st.generate_tangents()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/wasser.gdshader")
	mat.set_shader_parameter("fluss", true)
	for name in ["wellen_a", "wellen_b"]:
		var tex := NoiseTexture2D.new()
		tex.seamless = true
		tex.as_normal_map = true
		tex.bump_strength = 6.0 if name == "wellen_a" else 3.0
		tex.width = 512
		tex.height = 512
		tex.generate_mipmaps = true
		tex.noise = FastNoiseLite.new()
		tex.noise.seed = 11 if name == "wellen_a" else 12
		tex.noise.frequency = 0.02 if name == "wellen_a" else 0.04
		tex.noise.fractal_octaves = 3
		mat.set_shader_parameter(name, tex)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


## Holzbrücke: Bohlen, zwei Geländer, Pfosten bis ins Flussbett, begehbar
func _bruecke_bauen() -> void:
	var mitte := gelaende.bruecke
	if mitte == Vector3.ZERO:
		return
	var i := 0
	var best := INF
	for k in gelaende.fluss.size():
		var d := Vector2(gelaende.fluss[k].x, gelaende.fluss[k].z).distance_to(Vector2(mitte.x, mitte.z))
		if d < best:
			best = d
			i = k
	# Die Brücke folgt dem Weg; kreuzt er schräg, wird sie entsprechend länger
	var fluss_richtung := (gelaende.fluss[mini(i + 1, gelaende.fluss.size() - 1)] - gelaende.fluss[maxi(i - 1, 0)])
	fluss_richtung.y = 0.0
	var schraeg := absf(gelaende.bruecke_richtung.cross(fluss_richtung.normalized()).y)
	var ueber_wasser := (gelaende.fluss_breite[i] + 3.0) / maxf(schraeg, 0.5)
	var laenge := ueber_wasser + 10.0
	var breite := 4.4
	var holz := StandardMaterial3D.new()
	holz.albedo_texture = load("res://assets/download/texturen/holz_bruecke_diff.jpg")
	holz.normal_enabled = true
	holz.normal_texture = load("res://assets/download/texturen/holz_bruecke_nor.jpg")
	holz.roughness = 0.85
	holz.uv1_triplanar = true
	holz.uv1_scale = Vector3(0.5, 0.5, 0.5)
	var bruecke := StaticBody3D.new()
	bruecke.name = "Bruecke"
	bruecke.rotation.y = atan2(-gelaende.bruecke_richtung.z, gelaende.bruecke_richtung.x)
	# Fahrbahn auf Höhe des höheren Ufers, damit man von beiden Seiten hinauftritt statt darunter
	var quer := Vector3(cos(bruecke.rotation.y), 0, -sin(bruecke.rotation.y)) * laenge * 0.5
	var a := mitte + quer
	var b := mitte - quer
	mitte.y = maxf(gelaende.hoehe(a.x, a.z), gelaende.hoehe(b.x, b.z)) + 0.12
	gelaende.bruecke.y = mitte.y
	bruecke.position = mitte
	add_child(bruecke)
	gelaende.bruecke_form = bruecke.transform * Transform3D(Basis.from_scale(Vector3(laenge + 2.0, 1.0, breite)), Vector3.ZERO)
	var teile := [
		[Vector3(laenge, 0.22, breite), Vector3(0, -0.11, 0)],                  # Bohlen
	]
	# Geländer nur über dem Wasser, damit man an den Enden frei auf- und abreitet
	for seite in [-1.0, 1.0]:
		teile.append([Vector3(ueber_wasser, 0.12, 0.12), Vector3(0, 1.0, seite * breite * 0.5)])   # Handlauf
		var x := -ueber_wasser * 0.5
		while x <= ueber_wasser * 0.5 + 0.01:
			teile.append([Vector3(0.16, 3.2, 0.16), Vector3(x, -0.6, seite * breite * 0.5)])  # Pfosten bis ins Bett
			x += ueber_wasser / roundf(ueber_wasser / 2.4)
	for t in teile:
		var mi := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = t[0]
		mi.mesh = box
		mi.material_override = holz
		mi.position = t[1]
		bruecke.add_child(mi)
	# Kollision: nur die Fahrbahn und die Geländer
	for t in [[Vector3(laenge, 0.22, breite), Vector3(0, -0.11, 0)],
			[Vector3(ueber_wasser, 1.2, 0.2), Vector3(0, 0.5, breite * 0.5)],
			[Vector3(ueber_wasser, 1.2, 0.2), Vector3(0, 0.5, -breite * 0.5)]]:
		var cs := CollisionShape3D.new()
		var form := BoxShape3D.new()
		form.size = t[0]
		cs.shape = form
		cs.position = t[1]
		bruecke.add_child(cs)
