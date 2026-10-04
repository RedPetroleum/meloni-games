class_name Gelaende
extends Node3D
## Das Heimattal: 1024 × 1024 m aus festem Seed (wie in Hoofy: Gebiet aus Zufall erzeugen,
## nur Änderungen speichern). Höhen liegen einmal als Array (Kollision, Bewuchs, Pferde) und
## als Textur (Shader verschiebt flache Kacheln) vor.
##
## Aufbau wie im 2D-Hoofy (E12, E17, E20): Hof in der Mitte des Tals, das Dorf etwa einen
## Bildschirm daneben, der Fluss auf der anderen Seite von Nord nach Süd, Wege vom Hof zum Dorf,
## nach Norden, Süden und über eine Brücke zum Fluss und weiter. Ringsum dichter Waldrand,
## dahinter Berge (statt des Kartenrands).

const GROESSE := 1024.0
const RASTER := 2.0                       # Meter zwischen zwei Höhenpunkten
const N := int(GROESSE / RASTER) + 1      # 513 Punkte je Seite
const KACHEL := 64.0
const WEG_AUFL := 1024                    # Wegemaske: 1 m pro Pixel
const KEIN_WASSER := -1000.0

const HOF := Vector2(0, 40)               # Grundstück und Startpunkt, flach
const DORF := Vector2(150, 30)            # Laden, Pferdemarkt, Jobbrett, Turnierplatz
const FLUSS_X := -230.0                   # mittlere Lage des Flusses (Westen, Dorf liegt im Osten)
const FLUSS_TIEFE := 1.7
const AUE := 95.0                         # so weit senkt sich das Land zum Fluss hin
## Wasserspiegel im Norden und Süden (der Fluss fließt von Nord = -z nach Süd = +z)
const SPIEGEL_NORD := 4.0
const SPIEGEL_SUED := 1.0
## Wege als Linienzüge (x, z). BRUECKE wird durch den Kreuzungspunkt mit dem Fluss ersetzt.
const BRUECKE := Vector2(INF, INF)
const WEGE := [
	[Vector2(0, 40), Vector2(55, 25), Vector2(105, 35), Vector2(150, 30)],
	[Vector2(0, 40), Vector2(15, -60), Vector2(-15, -170), Vector2(10, -300), Vector2(0, -430)],
	[Vector2(0, 40), Vector2(-15, 150), Vector2(20, 280), Vector2(5, 430)],
	[Vector2(0, 40), Vector2(-80, 55), BRUECKE, Vector2(-330, 85), Vector2(-430, 70)],
]

@export var saat := 2040

var hoehen := PackedFloat32Array()
var wald_dichte := PackedFloat32Array()
var spiegel := PackedFloat32Array()      # Wasserspiegel je Rasterpunkt, KEIN_WASSER fern vom Fluss
var hoehen_bild: Image
var masken_bild: Image                    # R = nass, G = Wald, B = Blumenwiese
var wege_bild: Image                      # R = Weg
var material: ShaderMaterial
var fluss := PackedVector3Array()         # Mittellinie: x, Wasserspiegel, z
var fluss_breite := PackedFloat32Array()
var bruecke := Vector3.ZERO               # Mitte der Brücke auf Höhe des Ufers
var bruecke_richtung := Vector3.RIGHT     # Richtung des Wegs über die Brücke
var bruecke_form := Transform3D()         # Fahrbahn als Einheitsquader (setzt Wasser)

var _n_huegel := FastNoiseLite.new()
var _n_grat := FastNoiseLite.new()
var _n_wald := FastNoiseLite.new()
var _n_detail := FastNoiseLite.new()


func _ready() -> void:
	var t := Time.get_ticks_msec()
	_rauschen_einrichten()
	_fluss_legen()
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


## Flusslage x(z): geschwungen, aber immer von Nord nach Süd
func _fluss_x(z: float) -> float:
	return FLUSS_X + sin(z * 0.009 + 1.3) * 40.0 + _n_wald.get_noise_2d(z * 0.4, 777.0) * 30.0


func _fluss_spiegel(z: float) -> float:
	return lerpf(SPIEGEL_NORD, SPIEGEL_SUED, clampf((z + GROESSE * 0.5) / GROESSE, 0.0, 1.0))


func _fluss_legen() -> void:
	var z := -GROESSE * 0.5 - 20.0
	while z <= GROESSE * 0.5 + 20.0:
		fluss.append(Vector3(_fluss_x(z), _fluss_spiegel(z), z))
		fluss_breite.append(10.0 + _n_detail.get_noise_2d(z * 0.1, 31.0) * 3.0)
		z += 6.0


func _roh_hoehe(x: float, z: float) -> float:
	var h := _n_huegel.get_noise_2d(x, z) * 16.0 + 9.0
	h += _n_detail.get_noise_2d(x, z) * 0.6
	# Ringsum Berge: das Tal ist geschlossen, der Rand der Welt ist nie zu sehen
	var rand := maxf(absf(x), absf(z)) + _n_huegel.get_noise_2d(z * 0.7, x * 0.7) * 70.0
	var berg := smoothstep(250.0, 490.0, rand)
	var grat := (_n_grat.get_noise_2d(x, z) + 1.0) * 0.5
	h += berg * berg * (45.0 + grat * grat * 75.0)
	return h


## Höhe mit Fluss, Hof und Dorf. Gibt [Höhe, Wasserspiegel] zurück.
func _hoehe_formen(x: float, z: float, hof_h: float, dorf_h: float) -> Array:
	var h := _roh_hoehe(x, z)
	var p := Vector2(x, z)
	# Fluss: Abstand zur Mittellinie (fast senkrecht zu z, also über die Steigung genähert)
	var fx := _fluss_x(z)
	var steigung := (_fluss_x(z + 1.0) - _fluss_x(z - 1.0)) * 0.5
	var d := absf(x - fx) / sqrt(1.0 + steigung * steigung)
	var w := _fluss_spiegel(z)
	var halb := 5.0 + _n_detail.get_noise_2d(z * 0.1, 31.0) * 1.5
	var wasser := KEIN_WASSER
	if d < AUE:
		# Flussaue: das Land fällt sanft zum Fluss ab, dahinter das normale Gelände
		var aue := w + 0.7 + maxf(d - halb - 4.0, 0.0) * 0.06
		h = lerpf(aue, h, smoothstep(halb + 6.0, AUE, d) * smoothstep(halb + 6.0, AUE, d))
		# Flussbett
		var bett := w - FLUSS_TIEFE * (1.0 - minf(d / (halb + 2.0), 1.0) ** 2)
		h = lerpf(bett, h, smoothstep(halb - 1.0, halb + 3.0, d))
		if d < halb + 8.0:
			wasser = w
	# Hof und Dorf: flach, damit Gebäude, Weiden und Turnierplatz draufpassen
	h = lerpf(h, hof_h, smoothstep(75.0, 35.0, p.distance_to(HOF)))
	h = lerpf(h, dorf_h, smoothstep(70.0, 40.0, p.distance_to(DORF)))
	return [h, wasser]


func _hoehen_berechnen() -> void:
	hoehen.resize(N * N)
	wald_dichte.resize(N * N)
	spiegel.resize(N * N)
	hoehen_bild = Image.create_empty(N, N, false, Image.FORMAT_RF)
	masken_bild = Image.create_empty(N, N, false, Image.FORMAT_RGBA8)
	var hof_h := maxf(_roh_hoehe(HOF.x, HOF.y), 6.0)
	var dorf_h := maxf(_roh_hoehe(DORF.x, DORF.y), 6.0)
	var halb := GROESSE * 0.5
	for iz in N:
		var z := iz * RASTER - halb
		for ix in N:
			var x := ix * RASTER - halb
			var hw := _hoehe_formen(x, z, hof_h, dorf_h)
			var h: float = hw[0]
			var i := iz * N + ix
			hoehen[i] = h
			spiegel[i] = hw[1]
			hoehen_bild.set_pixel(ix, iz, Color(h, 0, 0))
			var p := Vector2(x, z)
			var nass := clampf((hw[1] + 0.9 - h) / 1.2, 0.0, 1.0)
			var w := smoothstep(0.05, 0.35, _n_wald.get_noise_2d(x, z))
			# Dichter Waldrand vor den Bergen wie in Hoofy (Rand 5 Kacheln)
			var rand := maxf(absf(x), absf(z))
			w = maxf(w, smoothstep(330.0, 400.0, rand + _n_wald.get_noise_2d(x * 3.0, z * 3.0) * 30.0))
			w *= smoothstep(60.0, 120.0, p.distance_to(HOF))
			w *= smoothstep(55.0, 100.0, p.distance_to(DORF))
			w *= 1.0 - nass
			w *= 1.0 - smoothstep(60.0, 110.0, h)              # nicht auf den Gipfeln
			wald_dichte[i] = w
			var wiese := smoothstep(0.0, 0.5, _n_wald.get_noise_2d(x * 1.7 + 500.0, z * 1.7)) * (1.0 - w)
			masken_bild.set_pixel(ix, iz, Color(nass, w, wiese, 1))


func _wege_zeichnen() -> void:
	wege_bild = Image.create_empty(WEG_AUFL, WEG_AUFL, false, Image.FORMAT_L8)
	var px_pro_m := WEG_AUFL / GROESSE
	for roh: Array in WEGE:
		var zug := roh.duplicate()
		var i_bruecke := zug.find(BRUECKE)
		if i_bruecke >= 0:
			# Brücke dort, wo der Weg den Fluss kreuzt
			var z: float = (zug[i_bruecke - 1].y + zug[i_bruecke + 1].y) * 0.5
			zug[i_bruecke] = Vector2(_fluss_x(z), z)
			bruecke = Vector3(_fluss_x(z), _fluss_spiegel(z) + 0.85, z)
			var r: Vector2 = (zug[i_bruecke + 1] - zug[i_bruecke - 1]).normalized()
			bruecke_richtung = Vector3(r.x, 0, r.y)
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


## Wasserspiegel an dieser Stelle (KEIN_WASSER, wenn kein Fluss in der Nähe)
func wasserspiegel(x: float, z: float) -> float:
	var ix := clampi(roundi((x + GROESSE * 0.5) / RASTER), 0, N - 1)
	var iz := clampi(roundi((z + GROESSE * 0.5) / RASTER), 0, N - 1)
	return spiegel[iz * N + ix]


## Liegt der Punkt auf der Brücke (von oben gesehen)?
func auf_bruecke(x: float, z: float) -> bool:
	var lokal := bruecke_form.affine_inverse() * Vector3(x, bruecke.y, z)
	return absf(lokal.x) <= 0.5 and absf(lokal.z) <= 0.5


## Wie tief das Wasser hier ist (≤ 0: trocken)
func wassertiefe(x: float, z: float) -> float:
	var w := wasserspiegel(x, z)
	return w - hoehe(x, z) if w > KEIN_WASSER else -1.0


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
