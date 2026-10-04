class_name Baumbauer
## Erzeugt Bäume und Büsche aus Code: Stamm und Äste als Röhren mit Rindentextur, Laub als
## gekreuzte Blattkarten mit selbst gemalter Blatttextur. So bleibt jeder Baum bei 1–3 Tausend
## Dreiecken (Poly-Haven-Bäume hätten bis zu einer Million). Zwei Detailstufen: nah und fern.

const BLATT_SHADER := preload("res://shaders/blatt.gdshader")


# --- Materialien ---

static func rinde(art: String) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://assets/download/texturen/rinde_%s_diff.jpg" % art)
	m.normal_enabled = true
	m.normal_texture = load("res://assets/download/texturen/rinde_%s_nor.jpg" % art)
	m.roughness = 0.9
	m.ao_enabled = true
	m.ao_texture = load("res://assets/download/texturen/rinde_%s_arm.jpg" % art)
	m.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	return m


static func laub(textur: Texture2D, farbe: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = BLATT_SHADER
	m.set_shader_parameter("textur", textur)
	m.set_shader_parameter("farbe", farbe)
	return m


## Blattbüschel: viele kleine Blätter mit Stielen, Farbe leicht verschieden, Rest durchsichtig
static func blatt_textur(rng: RandomNumberGenerator) -> ImageTexture:
	var g := 512
	var bild := Image.create_empty(g, g, false, Image.FORMAT_RGBA8)
	bild.fill(Color(0.18, 0.26, 0.08, 0.0))
	# Zweige
	for i in 14:
		var a := Vector2(g * 0.5, g * 0.5) + Vector2(rng.randf_range(-40, 40), rng.randf_range(-40, 40))
		var b := Vector2(rng.randf_range(20, g - 20), rng.randf_range(20, g - 20))
		_linie(bild, a, b, 2.0, Color(0.22, 0.16, 0.1, 1))
	for i in 520:
		var mitte := Vector2(g * 0.5, g * 0.5) + Vector2.from_angle(rng.randf() * TAU) * sqrt(rng.randf()) * g * 0.46
		var winkel := rng.randf() * TAU
		var laenge := rng.randf_range(16.0, 26.0)
		var hell := rng.randf_range(0.75, 1.15)
		var farbe := Color(0.2, 0.33, 0.09).lerp(Color(0.33, 0.42, 0.12), rng.randf()) * hell
		_blatt(bild, mitte, winkel, laenge, laenge * 0.42, farbe)
	bild.generate_mipmaps()
	return ImageTexture.create_from_image(bild)


## Fichtenzweig: Mittelrippe von links nach rechts, Seitentriebe mit Nadeln
static func nadel_textur(rng: RandomNumberGenerator) -> ImageTexture:
	var b := 512
	var h := 256
	var bild := Image.create_empty(b, h, false, Image.FORMAT_RGBA8)
	bild.fill(Color(0.07, 0.14, 0.07, 0.0))
	var stamm := Color(0.25, 0.18, 0.12, 1)
	_linie(bild, Vector2(0, h * 0.5), Vector2(b - 8, h * 0.5), 3.0, stamm)
	var x := 10.0
	while x < b - 30:
		var raum := (1.0 - x / b) * 0.8 + 0.2
		for seite in [-1.0, 1.0]:
			var start := Vector2(x, h * 0.5)
			var ende := start + Vector2(rng.randf_range(40, 70) * raum + 20, seite * h * 0.42 * raum)
			_linie(bild, start, ende, 1.5, stamm)
			for t in range(0, 22):
				var p := start.lerp(ende, t / 22.0)
				for s2 in [-1.0, 1.0]:
					var richtung := (ende - start).normalized().rotated(s2 * rng.randf_range(0.6, 1.1))
					var farbe := Color(0.1, 0.2, 0.09).lerp(Color(0.16, 0.28, 0.12), rng.randf())
					_linie(bild, p, p + richtung * rng.randf_range(7, 12), 1.2, farbe)
		x += rng.randf_range(16, 24)
	bild.generate_mipmaps()
	return ImageTexture.create_from_image(bild)


static func _blatt(bild: Image, mitte: Vector2, winkel: float, laenge: float, breite: float, farbe: Color) -> void:
	var r := int(laenge * 0.5) + 2
	var achse := Vector2.from_angle(winkel)
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var p := Vector2(dx, dy)
			var u := p.dot(achse) / (laenge * 0.5)
			var v := p.dot(achse.orthogonal()) / (breite * 0.5)
			# Blattform: spitz zulaufende Ellipse
			if u * u + v * v / maxf(1.0 - absf(u) * 0.6, 0.05) <= 1.0:
				var x := int(mitte.x) + dx
				var y := int(mitte.y) + dy
				if x >= 0 and y >= 0 and x < bild.get_width() and y < bild.get_height():
					var licht := 0.85 + 0.25 * v * signf(u + 0.001) + (0.08 if absf(v) < 0.12 else 0.0)
					bild.set_pixel(x, y, Color(farbe.r * licht, farbe.g * licht, farbe.b * licht, 1))


static func _linie(bild: Image, a: Vector2, b: Vector2, dicke: float, farbe: Color) -> void:
	var n := int(a.distance_to(b)) + 1
	var r := int(ceil(dicke * 0.5))
	for i in n + 1:
		var p := a.lerp(b, float(i) / n)
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var x := int(p.x) + dx
				var y := int(p.y) + dy
				if x >= 0 and y >= 0 and x < bild.get_width() and y < bild.get_height() and dx * dx + dy * dy <= r * r:
					bild.set_pixel(x, y, farbe)


# --- Laubbaum ---

static func laubbaum(rng: RandomNumberGenerator, rinde_mat: Material, laub_mat: Material, nah: bool) -> ArrayMesh:
	var holz := SurfaceTool.new()
	holz.begin(Mesh.PRIMITIVE_TRIANGLES)
	var blatt := SurfaceTool.new()
	blatt.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hoehe := rng.randf_range(9.0, 15.0)
	var r0 := hoehe * 0.024
	# Stamm leicht geschwungen
	var stamm := PackedVector3Array()
	var radien := PackedFloat32Array()
	var neig := Vector3(rng.randf_range(-0.5, 0.5), 0, rng.randf_range(-0.5, 0.5))
	for i in 7:
		var t := i / 6.0
		stamm.append(Vector3(0, t * hoehe * 0.8, 0) + neig * t * t + Vector3(rng.randf_range(-0.15, 0.15), 0, rng.randf_range(-0.15, 0.15)) * t)
		radien.append(r0 * (1.0 - t * 0.75) * (1.35 if i == 0 else 1.0))
	stamm[0].y = -0.4
	_rohr(holz, stamm, radien, 8 if nah else 5, 1.0)

	var buechel := []          # [Position, Größe]
	var aeste := rng.randi_range(8, 12)
	var azimut := rng.randf() * TAU
	for a in aeste:
		var t := lerpf(0.38, 0.92, float(a) / aeste) + rng.randf_range(-0.04, 0.04)
		var start := _auf_pfad(stamm, t / 0.8 * 0.8)
		start.y = t * hoehe * 0.8
		azimut += 2.4 + rng.randf_range(-0.3, 0.3)       # goldener Winkel
		var hoch := rng.randf_range(0.45, 1.0)
		var richtung := Vector3(cos(azimut), hoch, sin(azimut)).normalized()
		var laenge := hoehe * rng.randf_range(0.28, 0.42) * (1.15 - t * 0.55)
		var ast := _ast(rng, start, richtung, laenge, 4)
		var ar := PackedFloat32Array([r0 * 0.42 * (1.0 - t * 0.5), r0 * 0.25, r0 * 0.14, r0 * 0.06])
		_rohr(holz, ast, ar, 5 if nah else 3, 0.5)
		# Blätter: entlang der äußeren Asthälfte und an der Spitze
		var zahl := 7 if nah else 3
		for b in zahl:
			var p := _auf_pfad(ast, lerpf(0.35, 1.0, float(b) / (zahl - 1)))
			buechel.append([p + _zufall_kugel(rng) * 0.9, rng.randf_range(1.8, 2.8) * (1.0 if nah else 1.5)])
		if nah:
			for z in 2:
				var s := _auf_pfad(ast, rng.randf_range(0.4, 0.8))
				var zr := (richtung + _zufall_kugel(rng) * 0.9).normalized()
				zr.y = absf(zr.y) * 0.6 + 0.2
				var zweig := _ast(rng, s, zr.normalized(), laenge * 0.45, 3)
				_rohr(holz, zweig, PackedFloat32Array([r0 * 0.12, r0 * 0.07, r0 * 0.03]), 3, 0.5)
				buechel.append([zweig[2], rng.randf_range(1.6, 2.4)])
				buechel.append([zweig[1], rng.randf_range(1.6, 2.2)])
	# Krone oben zuschließen
	for i in (10 if nah else 5):
		buechel.append([stamm[-1] + _zufall_kugel(rng) * Vector3(2.0, 1.2, 2.0) + Vector3.UP * 0.8, rng.randf_range(2.0, 3.0) * (1.0 if nah else 1.4)])

	var mitte := Vector3.ZERO
	for bu in buechel:
		mitte += bu[0]
	mitte /= buechel.size()
	for bu in buechel:
		_buechel(blatt, rng, bu[0], bu[1], mitte, 3 if nah else 2)

	var netz := ArrayMesh.new()
	holz.set_material(rinde_mat)
	holz.generate_tangents()
	holz.commit(netz)
	blatt.set_material(laub_mat)
	blatt.commit(netz)
	return netz


# --- Fichte ---

static func fichte(rng: RandomNumberGenerator, rinde_mat: Material, nadel_mat: Material, nah: bool) -> ArrayMesh:
	var holz := SurfaceTool.new()
	holz.begin(Mesh.PRIMITIVE_TRIANGLES)
	var zweige := SurfaceTool.new()
	zweige.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hoehe := rng.randf_range(13.0, 22.0)
	var r0 := hoehe * 0.017
	var stamm := PackedVector3Array([Vector3(0, -0.4, 0), Vector3(0, hoehe * 0.5, 0), Vector3(0, hoehe, 0)])
	_rohr(holz, stamm, PackedFloat32Array([r0 * 1.3, r0 * 0.6, 0.02]), 7 if nah else 4, 1.0)
	var mitte := Vector3(0, hoehe * 0.55, 0)
	var y := hoehe * rng.randf_range(0.12, 0.22)
	var abstand := 0.42 if nah else 0.85
	var drehung := rng.randf() * TAU
	while y < hoehe - 0.3:
		var t := y / hoehe
		var laenge := (1.0 - t) * hoehe * 0.27 + 0.35
		var zahl := 6 if nah else 4
		for i in zahl:
			var az := drehung + TAU * i / zahl + rng.randf_range(-0.25, 0.25)
			var raus := Vector3(cos(az), 0, sin(az))
			var haengen := rng.randf_range(0.15, 0.4) + t * 0.1
			var spitze := Vector3(0, y, 0) + raus * laenge + Vector3.DOWN * laenge * haengen
			var seite := raus.cross(Vector3.UP).normalized() * laenge * 0.32
			var basis := Vector3(0, y + 0.05, 0)
			var n_aussen := ((spitze + basis) * 0.5 - mitte).normalized()
			_karte(zweige, basis - seite * 0.25, basis + seite * 0.25, spitze + seite, spitze - seite,
				Vector2(0, 0.5), Vector2(0, 0.5), Vector2(1, 0), Vector2(1, 1), (n_aussen + Vector3.UP * 0.6).normalized())
		drehung += 0.6
		y += abstand * rng.randf_range(0.85, 1.15)
	var netz := ArrayMesh.new()
	holz.set_material(rinde_mat)
	holz.generate_tangents()
	holz.commit(netz)
	zweige.set_material(nadel_mat)
	zweige.commit(netz)
	return netz


# --- Busch ---

static func busch(rng: RandomNumberGenerator, laub_mat: Material) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var radius := rng.randf_range(0.8, 1.5)
	var mitte := Vector3(0, radius * 0.5, 0)
	for i in rng.randi_range(14, 22):
		var p := mitte + _zufall_kugel(rng) * Vector3(radius, radius * 0.6, radius)
		p.y = maxf(p.y, 0.25)
		_buechel(st, rng, p, rng.randf_range(0.9, 1.4), mitte - Vector3.UP * 0.3, 2)
	st.set_material(laub_mat)
	return st.commit()


# --- Bausteine ---

static func _ast(rng: RandomNumberGenerator, start: Vector3, richtung: Vector3, laenge: float, punkte: int) -> PackedVector3Array:
	var pfad := PackedVector3Array([start])
	var r := richtung
	var p := start
	for i in punkte - 1:
		# Äste biegen sich zum Licht und hängen außen etwas durch
		r = (r + Vector3(rng.randf_range(-0.25, 0.25), rng.randf_range(-0.15, 0.25), rng.randf_range(-0.25, 0.25))).normalized()
		p += r * laenge / (punkte - 1)
		p.y -= laenge * 0.04 * i
		pfad.append(p)
	return pfad


static func _auf_pfad(pfad: PackedVector3Array, t: float) -> Vector3:
	var f := clampf(t, 0.0, 1.0) * (pfad.size() - 1)
	var i := mini(int(f), pfad.size() - 2)
	return pfad[i].lerp(pfad[i + 1], f - i)


static func _zufall_kugel(rng: RandomNumberGenerator) -> Vector3:
	return Vector3(rng.randfn(), rng.randfn(), rng.randfn()).normalized() * pow(rng.randf(), 0.33)


## Röhre entlang eines Pfads (Stamm, Ast). v läuft entlang, u einmal herum.
static func _rohr(st: SurfaceTool, pfad: PackedVector3Array, radien: PackedFloat32Array, seiten: int, v_mass: float) -> void:
	var ringe := []
	var v := 0.0
	for i in pfad.size():
		var t := (pfad[mini(i + 1, pfad.size() - 1)] - pfad[maxi(i - 1, 0)]).normalized()
		var a := t.cross(Vector3.FORWARD if absf(t.z) < 0.9 else Vector3.RIGHT).normalized()
		var b := t.cross(a).normalized()
		if i > 0:
			v += pfad[i].distance_to(pfad[i - 1]) / v_mass
		var ring := []
		for s in seiten + 1:
			var w := TAU * s / seiten
			var n := (a * cos(w) + b * sin(w))
			ring.append([pfad[i] + n * radien[i], n, Vector2(float(s) / seiten * 2.0, v * 0.5)])
		ringe.append(ring)
	for i in ringe.size() - 1:
		for s in seiten:
			var q := [ringe[i][s], ringe[i][s + 1], ringe[i + 1][s + 1], ringe[i + 1][s]]
			for k in [0, 1, 2, 0, 2, 3]:
				st.set_normal(q[k][1])
				st.set_uv(q[k][2])
				st.add_vertex(q[k][0])


## Blattbüschel: gekreuzte Karten, Normalen zeigen von der Kronenmitte weg (weiches Licht)
static func _buechel(st: SurfaceTool, rng: RandomNumberGenerator, p: Vector3, groesse: float, mitte: Vector3, karten: int) -> void:
	var raus := (p - mitte).normalized()
	if raus.length() < 0.1:
		raus = Vector3.UP
	var drehung := rng.randf() * PI
	for k in karten:
		var basis := Basis(Vector3.UP, drehung + PI * k / karten) * Basis(Vector3.RIGHT, rng.randf_range(-0.6, 0.6))
		var x := basis.x * groesse * 0.5
		var y := basis.y * groesse * 0.5
		var n := (raus * 0.8 + basis.z * 0.2).normalized()
		_karte(st, p - x - y, p + x - y, p + x + y, p - x + y, Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0), n)


static func _karte(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3,
		ua: Vector2, ub: Vector2, uc: Vector2, ud: Vector2, n: Vector3) -> void:
	for e in [[a, ua], [b, ub], [c, uc], [a, ua], [c, uc], [d, ud]]:
		st.set_normal(n)
		st.set_uv(e[1])
		st.add_vertex(e[0])
