class_name Bewuchs
extends Node3D
## Verteilt Bäume, Büsche, Felsen, Farne, Blumen und Totholz nach den Masken des Geländes.
## Alles als MultiMesh in Zellen, damit weit entfernte Zellen gar nicht gezeichnet werden und
## Bäume in der Ferne eine einfachere Form bekommen (Sichtweiten unten).

const ZELLE := 128.0
const BAUM_NAH := 120.0        # bis hier volle Bäume, dahinter vereinfachte
const BAUM_FERN := 750.0
const VARIANTEN := 3

@export var saat := 2040

var gelaende: Gelaende
var _zellen := {}              # Vector2i → { Schlüssel → [Mesh, Sichtweite von, bis, Schatten, Array[Transform3D]] }
var _kollision := StaticBody3D.new()
var anzahl := {}


func _ready() -> void:
	var t := Time.get_ticks_msec()
	var rng := RandomNumberGenerator.new()
	rng.seed = saat
	var rinde_laub := Baumbauer.rinde("laub")
	var rinde_nadel := Baumbauer.rinde("nadel")
	var laub := Baumbauer.laub(Baumbauer.blatt_textur(rng), Color(1, 1, 1))
	var busch_laub := Baumbauer.laub(Baumbauer.blatt_textur(rng), Color(0.9, 1.0, 0.85))
	var nadeln := Baumbauer.laub(Baumbauer.nadel_textur(rng), Color(1, 1, 1))
	nadeln.set_shader_parameter("wind", 0.5)

	# Varianten: gleiche Saat für nah und fern, damit die Form beim Wechsel ähnlich bleibt
	var laubbaeume := []
	var fichten := []
	var buesche := []
	for v in VARIANTEN:
		var r := RandomNumberGenerator.new()
		r.seed = saat + 100 + v
		var nah := Baumbauer.laubbaum(r, rinde_laub, laub, true)
		r.seed = saat + 100 + v
		laubbaeume.append([nah, Baumbauer.laubbaum(r, rinde_laub, laub, false)])
		r.seed = saat + 200 + v
		var fn := Baumbauer.fichte(r, rinde_nadel, nadeln, true)
		r.seed = saat + 200 + v
		fichten.append([fn, Baumbauer.fichte(r, rinde_nadel, nadeln, false)])
		r.seed = saat + 300 + v
		buesche.append(Baumbauer.busch(r, busch_laub))

	var felsen := _teile("rock_moss_set_01") + _teile("rock_moss_set_02")
	var findling := _teile("boulder_01")
	var farne := _teile("fern_02")
	var blumen := _teile("celandine_01")
	var totholz := _teile("dead_tree_trunk_02")

	var halb := Gelaende.GROESSE * 0.5 - 6.0
	# Bäume: Wald dicht, auf Wiesen vereinzelt
	_streuen(rng, 6.5, func(x: float, z: float, h: float, steil: float) -> float:
		if steil > 0.55 or h < 1.2 or gelaende.weg(x, z) > 0.05:
			return 0.0
		return gelaende.wald(x, z) * 0.85 + 0.004,
		func(x: float, z: float, h: float) -> void:
			var nadel := rng.randf() < 0.2 + smoothstep(12.0, 40.0, h) * 0.7
			var v := rng.randi() % VARIANTEN
			var paar: Array = fichten[v] if nadel else laubbaeume[v]
			var s := rng.randf_range(0.8, 1.2)
			var tf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s), Vector3(x, h - 0.15, z))
			_dazu(("f" if nadel else "l") + str(v) + "n", paar[0], 0.0, BAUM_NAH, true, tf)
			_dazu(("f" if nadel else "l") + str(v) + "w", paar[1], BAUM_NAH, BAUM_FERN, true, tf)
			_baum_kollision(Vector3(x, h, z), 0.35 * s)
			_zaehlen("Bäume"),
		halb)
	# Büsche: Waldrand und Wiesen
	_streuen(rng, 4.0, func(x: float, z: float, h: float, steil: float) -> float:
		if steil > 0.5 or h < 0.8 or gelaende.weg(x, z) > 0.05:
			return 0.0
		var w := gelaende.wald(x, z)
		return w * (1.0 - w) * 0.9 + 0.012,
		func(x: float, z: float, h: float) -> void:
			var tf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.7, 1.3)), Vector3(x, h - 0.1, z))
			_dazu("b" + str(rng.randi() % VARIANTEN), buesche[rng.randi() % VARIANTEN], 0.0, 260.0, true, tf)
			_zaehlen("Büsche"),
		halb)
	# Felsen: Hänge, Bergfuß und hier und da auf der Wiese
	_streuen(rng, 9.0, func(x: float, z: float, h: float, steil: float) -> float:
		return smoothstep(0.15, 0.4, steil) * 0.35 + 0.01,
		func(x: float, z: float, h: float) -> void:
			var teil: Array = felsen[rng.randi() % felsen.size()] if rng.randf() < 0.8 else findling[0]
			var s := rng.randf_range(0.7, 2.2)
			var tf: Transform3D = Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s), Vector3(x, h - 0.25 * s, z)) * teil[1]
			_dazu("r" + str(felsen.find(teil)) + str(findling.find(teil)), teil[0], 0.0, 420.0, true, tf)
			if s > 1.3:
				_baum_kollision(Vector3(x, h, z), 0.6 * s)
			_zaehlen("Felsen"),
		halb)
	# Farne und Totholz im Wald
	_streuen(rng, 2.6, func(x: float, z: float, h: float, steil: float) -> float:
		return gelaende.wald(x, z) * 0.5 if steil < 0.45 else 0.0,
		func(x: float, z: float, h: float) -> void:
			if rng.randf() < 0.03:
				var tt: Array = totholz[0]
				_dazu("t", tt[0], 0.0, 140.0, true, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(x, h - 0.1, z)) * tt[1])
				return
			var teil: Array = farne[rng.randi() % farne.size()]
			var tf: Transform3D = Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.8, 1.4)), Vector3(x, h - 0.05, z)) * teil[1]
			_dazu("n" + str(farne.find(teil)), teil[0], 0.0, 70.0, false, tf)
			_zaehlen("Farne"),
		halb)
	# Blumen auf den Wiesen
	_streuen(rng, 2.2, func(x: float, z: float, h: float, steil: float) -> float:
		if steil > 0.3 or h < 1.0 or gelaende.weg(x, z) > 0.05:
			return 0.0
		return gelaende.wiese(x, z) * 0.35,
		func(x: float, z: float, h: float) -> void:
			var teil: Array = blumen[rng.randi() % blumen.size()]
			var tf: Transform3D = Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(1.0, 1.6)), Vector3(x, h - 0.02, z)) * teil[1]
			_dazu("m" + str(blumen.find(teil)), teil[0], 0.0, 55.0, false, tf)
			_zaehlen("Blumen"),
		halb)

	_bauen()
	add_child(_kollision)
	print("Bewuchs: %d ms, %s" % [Time.get_ticks_msec() - t, anzahl])


## Gitter mit Zufallsversatz; dichte() gibt die Wahrscheinlichkeit, setzen() platziert.
func _streuen(rng: RandomNumberGenerator, abstand: float, dichte: Callable, setzen: Callable, halb: float) -> void:
	var z := -halb
	while z < halb:
		var x := -halb
		while x < halb:
			var px := x + rng.randf() * abstand
			var pz := z + rng.randf() * abstand
			var h := gelaende.hoehe(px, pz)
			var steil := 1.0 - gelaende.normale(px, pz).y
			# Nichts auf Wege, Brücke, Hof und Dorf
			var frei := gelaende.weg(px, pz) < 0.05 and Vector2(px, pz).distance_to(Gelaende.HOF) > 38.0 \
					and Vector2(px, pz).distance_to(Gelaende.DORF) > 48.0 \
					and Vector2(px, pz).distance_to(Vector2(gelaende.bruecke.x, gelaende.bruecke.z)) > 16.0
			if frei and gelaende.wassertiefe(px, pz) < -0.4 and rng.randf() < dichte.call(px, pz, h, steil):
				setzen.call(px, pz, h)
			x += abstand
		z += abstand


func _dazu(schluessel: String, netz: Mesh, von: float, bis: float, schatten: bool, tf: Transform3D) -> void:
	var zelle := Vector2i(floori(tf.origin.x / ZELLE), floori(tf.origin.z / ZELLE))
	if not _zellen.has(zelle):
		_zellen[zelle] = {}
	var z: Dictionary = _zellen[zelle]
	if not z.has(schluessel):
		z[schluessel] = [netz, von, bis, schatten, []]
	z[schluessel][4].append(tf)


func _bauen() -> void:
	for zelle in _zellen:
		for schluessel in _zellen[zelle]:
			var e: Array = _zellen[zelle][schluessel]
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = e[0]
			mm.instance_count = e[4].size()
			for i in e[4].size():
				mm.set_instance_transform(i, e[4][i])
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			mmi.visibility_range_begin = e[1]
			mmi.visibility_range_end = e[2]
			mmi.visibility_range_end_margin = 10.0
			mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF if e[2] < 100.0 else GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if e[3] else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(mmi)
	_zellen.clear()


func _baum_kollision(fuss: Vector3, radius: float) -> void:
	var cs := CollisionShape3D.new()
	var form := CylinderShape3D.new()
	form.radius = radius
	form.height = 4.0
	cs.shape = form
	cs.position = fuss + Vector3.UP * 1.5
	_kollision.add_child(cs)


func _zaehlen(was: String) -> void:
	anzahl[was] = anzahl.get(was, 0) + 1


## Die Einzelteile eines Poly-Haven-Modells (z. B. sechs Felsen eines Sets) als
## [Mesh, Transform3D]: Drehung behalten, jedes Teil auf den Ursprung gesetzt.
func _teile(name: String) -> Array:
	var szene: Node3D = load("res://assets/download/modelle/%s/%s.gltf" % [name, name]).instantiate()
	var teile := []
	for mi: MeshInstance3D in szene.find_children("*", "MeshInstance3D", true, false):
		var tf := Transform3D.IDENTITY
		var n: Node = mi
		while n != szene:
			tf = (n as Node3D).transform * tf
			n = n.get_parent()
		var box := mi.mesh.get_aabb()
		var mitte := tf.basis * box.get_center()
		var unten := (tf.basis * box.position).y
		tf.origin = Vector3(-mitte.x, -minf(unten, (tf.basis * box.end).y) * 0.9, -mitte.z)
		teile.append([mi.mesh, tf])
	szene.free()
	return teile
