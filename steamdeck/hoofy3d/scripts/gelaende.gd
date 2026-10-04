class_name Gelaende
extends Node3D
## Das Heimattal: 1024 × 1024 m aus festem Seed (wie in Hoofy: Gebiet aus Zufall erzeugen,
## nur Änderungen speichern). Höhen liegen einmal als Array (Kollision, Bewuchs, Pferde) und
## als Textur (Shader verschiebt flache Kacheln) vor.

const GROESSE := 1024.0
const RASTER := 2.0                       # Meter zwischen zwei Höhenpunkten
const N := int(GROESSE / RASTER) + 1      # 513 Punkte je Seite
const KACHEL := 64.0
const WEG_AUFL := 1024                    # Wegemaske: 1 m pro Pixel
const WASSER := 0.0                       # Höhe des Seespiegels

const HOF := Vector2(0, 40)               # Startpunkt, flach
const SEE := Vector2(150, -130)
## Wege als Linienzüge (x, z), vom Hof durchs Tal
const WEGE := [
	[Vector2(0, 40), Vector2(30, 0), Vector2(70, -60), Vector2(95, -120), Vector2(80, -200), Vector2(20, -260), Vector2(-80, -280), Vector2(-170, -230), Vector2(-230, -140)],
	[Vector2(0, 40), Vector2(-40, 90), Vector2(-110, 140), Vector2(-150, 210), Vector2(-120, 290), Vector2(-30, 320), Vector2(80, 300), Vector2(180, 240), Vector2(240, 140), Vector2(230, 30), Vector2(205, -60)],
	[Vector2(-110, 140), Vector2(-190, 80), Vector2(-230, -10), Vector2(-230, -140)],
]

@export var saat := 2040

var hoehen := PackedFloat32Array()
var wald_dichte := PackedFloat32Array()
var hoehen_bild: Image
var masken_bild: Image                    # G = Wald, B = Blumenwiese
var wege_bild: Image                      # R = Weg
var material: ShaderMaterial

var _n_huegel := FastNoiseLite.new()
var _n_grat := FastNoiseLite.new()
var _n_wald := FastNoiseLite.new()
var _n_detail := FastNoiseLite.new()


func _ready() -> void:
	var t := Time.get_ticks_msec()
	_rauschen_einrichten()
	_hoehen_berechnen()
	_wege_zeichnen()
	_kacheln_bauen()
	_kollision_bauen()
	print("Gelände: %d ms" % (Time.get_ticks_msec() - t))


func _rauschen_einrichten() -> void:
	for n in [_n_huegel, _n_grat, _n_wald, _n_detail]:
		n.seed = saat
		n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_n_huegel.frequency = 0.0032
	_n_huegel.fractal_octaves = 5
	_n_grat.seed = saat + 1
	_n_grat.frequency = 0.0045
	_n_grat.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	_n_grat.fractal_octaves = 3
	_n_grat.fractal_gain = 0.4
	_n_wald.seed = saat + 2
	_n_wald.frequency = 0.008
	_n_wald.fractal_octaves = 3
	_n_detail.seed = saat + 3
	_n_detail.frequency = 0.05
	_n_detail.fractal_octaves = 2


func _roh_hoehe(x: float, z: float) -> float:
	var h := _n_huegel.get_noise_2d(x, z) * 16.0 + 9.0
	h += _n_detail.get_noise_2d(x, z) * 0.6
	# Ringsum Berge: das Tal ist geschlossen, der Rand der Welt ist nie zu sehen
	var rand := maxf(absf(x), absf(z)) + _n_huegel.get_noise_2d(z * 0.7, x * 0.7) * 70.0
	var berg := smoothstep(250.0, 490.0, rand)
	var grat := (_n_grat.get_noise_2d(x, z) + 1.0) * 0.5
	h += berg * berg * (45.0 + grat * grat * 75.0)
	return h


func _hoehe_formen(x: float, z: float, hof_h: float) -> float:
	var h := _roh_hoehe(x, z)
	var p := Vector2(x, z)
	# See: Mulde mit unregelmäßigem Ufer
	var d_see := p.distance_to(SEE) + _n_wald.get_noise_2d(x * 2.0, z * 2.0) * 30.0
	h = lerpf(h, -4.5, smoothstep(95.0, 45.0, d_see))
	# Hof: flach, damit später Stall und Weiden draufpassen
	h = lerpf(h, hof_h, smoothstep(75.0, 35.0, p.distance_to(HOF)))
	return h


func _hoehen_berechnen() -> void:
	hoehen.resize(N * N)
	wald_dichte.resize(N * N)
	hoehen_bild = Image.create_empty(N, N, false, Image.FORMAT_RF)
	masken_bild = Image.create_empty(N, N, false, Image.FORMAT_RGBA8)
	var hof_h := maxf(_roh_hoehe(HOF.x, HOF.y), 4.0)
	var halb := GROESSE * 0.5
	for iz in N:
		var z := iz * RASTER - halb
		for ix in N:
			var x := ix * RASTER - halb
			var h := _hoehe_formen(x, z, hof_h)
			var i := iz * N + ix
			hoehen[i] = h
			hoehen_bild.set_pixel(ix, iz, Color(h, 0, 0))
			var p := Vector2(x, z)
			var w := smoothstep(0.05, 0.35, _n_wald.get_noise_2d(x, z))
			w *= smoothstep(60.0, 120.0, p.distance_to(HOF))
			w *= smoothstep(1.5, 4.0, h)                      # nicht am Ufer
			w *= 1.0 - smoothstep(60.0, 110.0, h)              # nicht auf den Gipfeln
			wald_dichte[i] = w
			var wiese := smoothstep(0.0, 0.5, _n_wald.get_noise_2d(x * 1.7 + 500.0, z * 1.7)) * (1.0 - w)
			masken_bild.set_pixel(ix, iz, Color(0, w, wiese, 1))


func _wege_zeichnen() -> void:
	wege_bild = Image.create_empty(WEG_AUFL, WEG_AUFL, false, Image.FORMAT_L8)
	var px_pro_m := WEG_AUFL / GROESSE
	for zug in WEGE:
		var punkte := _glaetten(zug)
		for i in punkte.size() - 1:
			var a: Vector2 = punkte[i]
			var b: Vector2 = punkte[i + 1]
			var schritte := int(a.distance_to(b) * 2.0) + 1
			for s in schritte:
				var p := a.lerp(b, float(s) / schritte)
				var breite := 1.6 + _n_detail.get_noise_2d(p.x * 0.5, p.y * 0.5) * 0.4
				_scheibe(wege_bild, (p + Vector2(GROESSE, GROESSE) * 0.5) * px_pro_m, breite * px_pro_m)
				# Wald vom Weg fernhalten
				_wald_freiraeumen(p, 4.0)


## Catmull-Rom, damit Wege geschwungen statt eckig sind
func _glaetten(zug: Array) -> PackedVector2Array:
	var aus := PackedVector2Array()
	for i in zug.size() - 1:
		var p0: Vector2 = zug[maxi(i - 1, 0)]
		var p1: Vector2 = zug[i]
		var p2: Vector2 = zug[i + 1]
		var p3: Vector2 = zug[mini(i + 2, zug.size() - 1)]
		for s in 8:
			var t := s / 8.0
			aus.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t * t * t))
	aus.append(zug[-1])
	return aus


func _scheibe(bild: Image, mitte: Vector2, radius: float) -> void:
	var r := int(ceil(radius)) + 1
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var x := int(mitte.x) + dx
			var y := int(mitte.y) + dy
			if x < 0 or y < 0 or x >= bild.get_width() or y >= bild.get_height():
				continue
			var d := Vector2(x + 0.5, y + 0.5).distance_to(mitte)
			var v := clampf(radius + 0.5 - d, 0.0, 1.0)
			if v > bild.get_pixel(x, y).r:
				bild.set_pixel(x, y, Color(v, v, v))


func _wald_freiraeumen(p: Vector2, radius: float) -> void:
	var halb := GROESSE * 0.5
	var r := int(radius / RASTER) + 1
	var cx := int((p.x + halb) / RASTER)
	var cz := int((p.y + halb) / RASTER)
	for dz in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var ix := cx + dx
			var iz := cz + dz
			if ix >= 0 and iz >= 0 and ix < N and iz < N:
				wald_dichte[iz * N + ix] = 0.0
				var c := masken_bild.get_pixel(ix, iz)
				masken_bild.set_pixel(ix, iz, Color(c.r, 0.0, c.b * 0.3, 1))


func _kacheln_bauen() -> void:
	material = ShaderMaterial.new()
	material.shader = load("res://shaders/gelaende.gdshader")
	material.set_shader_parameter("hoehen", ImageTexture.create_from_image(hoehen_bild))
	material.set_shader_parameter("masken", ImageTexture.create_from_image(masken_bild))
	var wege_tex := ImageTexture.create_from_image(wege_bild)
	material.set_shader_parameter("wege", wege_tex)
	material.set_shader_parameter("groesse", GROESSE)
	material.set_shader_parameter("punkte", float(N))
	material.set_shader_parameter("raster", RASTER)
	for boden in ["gras", "erde", "wald", "fels"]:
		for art in ["diff", "nor", "arm"]:
			material.set_shader_parameter("%s_%s" % [boden, art], load("res://assets/download/texturen/boden_%s_%s.jpg" % [boden, art]))
	var rausch := NoiseTexture2D.new()
	rausch.seamless = true
	rausch.width = 256
	rausch.height = 256
	rausch.generate_mipmaps = true
	rausch.noise = FastNoiseLite.new()
	rausch.noise.frequency = 0.02
	material.set_shader_parameter("makro", rausch)

	var netz := PlaneMesh.new()
	netz.size = Vector2(KACHEL, KACHEL)
	netz.subdivide_width = int(KACHEL / RASTER) - 1
	netz.subdivide_depth = int(KACHEL / RASTER) - 1
	netz.material = material
	var anzahl := int(GROESSE / KACHEL)
	for kz in anzahl:
		for kx in anzahl:
			var mi := MeshInstance3D.new()
			mi.mesh = netz
			var mitte := Vector3((kx + 0.5) * KACHEL - GROESSE * 0.5, 0, (kz + 0.5) * KACHEL - GROESSE * 0.5)
			mi.position = mitte
			# Höhen kommen erst im Shader dazu: Culling braucht die echte Ausdehnung der Kachel
			var lo := INF
			var hi := -INF
			for iz in range(kz * (N - 1) / anzahl, (kz + 1) * (N - 1) / anzahl + 1):
				for ix in range(kx * (N - 1) / anzahl, (kx + 1) * (N - 1) / anzahl + 1):
					var h := hoehen[iz * N + ix]
					lo = minf(lo, h)
					hi = maxf(hi, h)
			mi.custom_aabb = AABB(Vector3(-KACHEL * 0.5, lo - 1.0, -KACHEL * 0.5), Vector3(KACHEL, hi - lo + 2.0, KACHEL))
			add_child(mi)


func _kollision_bauen() -> void:
	var koerper := StaticBody3D.new()
	koerper.name = "Boden"
	var form := HeightMapShape3D.new()
	form.map_width = N
	form.map_depth = N
	# Gleichmäßig um RASTER skalieren (ungleichmäßige Skalierung mögen Physik-Formen nicht)
	var daten := hoehen.duplicate()
	for i in daten.size():
		daten[i] /= RASTER
	form.map_data = daten
	var cs := CollisionShape3D.new()
	cs.shape = form
	cs.scale = Vector3.ONE * RASTER
	koerper.add_child(cs)
	add_child(koerper)


# --- Abfragen für Bewuchs, Pferde, Kamera ---

func hoehe(x: float, z: float) -> float:
	return _bilinear(hoehen, x, z)


func wald(x: float, z: float) -> float:
	return _bilinear(wald_dichte, x, z)


func wiese(x: float, z: float) -> float:
	var ix := clampi(int((x + GROESSE * 0.5) / RASTER), 0, N - 1)
	var iz := clampi(int((z + GROESSE * 0.5) / RASTER), 0, N - 1)
	return masken_bild.get_pixel(ix, iz).b


func weg(x: float, z: float) -> float:
	var px := int((x + GROESSE * 0.5) * WEG_AUFL / GROESSE)
	var pz := int((z + GROESSE * 0.5) * WEG_AUFL / GROESSE)
	if px < 0 or pz < 0 or px >= WEG_AUFL or pz >= WEG_AUFL:
		return 0.0
	return wege_bild.get_pixel(px, pz).r


func normale(x: float, z: float) -> Vector3:
	var d := RASTER
	return Vector3(hoehe(x - d, z) - hoehe(x + d, z), 2.0 * d, hoehe(x, z - d) - hoehe(x, z + d)).normalized()


func im_tal(x: float, z: float, rand := 4.0) -> bool:
	var g := GROESSE * 0.5 - rand
	return absf(x) < g and absf(z) < g


func _bilinear(feld: PackedFloat32Array, x: float, z: float) -> float:
	var fx := clampf((x + GROESSE * 0.5) / RASTER, 0.0, N - 1.001)
	var fz := clampf((z + GROESSE * 0.5) / RASTER, 0.0, N - 1.001)
	var ix := int(fx)
	var iz := int(fz)
	var tx := fx - ix
	var tz := fz - iz
	var i := iz * N + ix
	# Dreiecksweise wie die HeightMapShape3D, damit Hufe genau auf der Kollision stehen
	var a := feld[i]
	var b := feld[i + 1]
	var c := feld[i + N]
	var d := feld[i + N + 1]
	return lerpf(lerpf(a, b, tx), lerpf(c, d, tx), tz)
