class_name Siedlung
extends Node3D
## Hof und Dorf im Heimattal wie im 2D-Hoofy.
##
## Hof (E17, E32): Grundstück 20 × 20 Kacheln in der Mitte des Tals. Wohnwagen und Stall S im
## Norden, Weide im Süden (Zaunring 10 × 7 Kacheln mit Tor oben, innen 8 × 5), Start im Hof
## dazwischen. 1 Kachel = 2,5 m.
## Dorf (E20, E21): Laden, Pferdemarkt (Marktstand mit Koppel), Jobbrett und Turnierplatz mit
## Hindernissen, mit Namensschildern; Innenräume gibt es nicht (E13).

const KACHEL := 2.5
const GRUNDSTUECK := 20                  # Kacheln je Seite

var gelaende: Gelaende
var _holz: StandardMaterial3D
var _kollision := StaticBody3D.new()
## Orte für die Spielregeln (Türen, Tor, Weide), in Weltkoordinaten
var orte := {}


func _ready() -> void:
	_holz = StandardMaterial3D.new()
	_holz.albedo_texture = load("res://assets/download/texturen/holz_bruecke_diff.jpg")
	_holz.normal_enabled = true
	_holz.normal_texture = load("res://assets/download/texturen/holz_bruecke_nor.jpg")
	_holz.roughness = 0.85
	_holz.uv1_triplanar = true
	_holz.uv1_scale = Vector3(0.6, 0.6, 0.6)
	_kollision.name = "Siedlung"
	add_child(_kollision)
	_hof()
	_dorf()


# --- Hof ---

func _hof() -> void:
	var h := Gelaende.HOF
	var halb := GRUNDSTUECK * KACHEL * 0.5
	orte.grundstueck = Rect2(h - Vector2(halb, halb), Vector2(halb, halb) * 2.0)
	# Norden = -z
	orte.wohnwagen = _modell("hof/wohnwagen", 8.5, h + Vector2(-11, -16), PI * 0.5)
	orte.stall = _modell("hof/stall_s", 13.0, h + Vector2(11, -17), PI * 0.5)
	_schild("Wohnwagen", orte.wohnwagen + Vector3(0, 4.2, 0))
	_schild("Stall", orte.stall + Vector3(0, 5.0, 0))
	# Weide: Zaunring 10 × 7 Kacheln im Süden, Tor oben in der Mitte
	var mitte := h + Vector2(0, 11)
	var b := 10 * KACHEL * 0.5
	var t := 7 * KACHEL * 0.5
	orte.weide = Rect2(mitte - Vector2(b, t), Vector2(b, t) * 2.0)
	orte.tor = _zaun([mitte + Vector2(-b, -t), mitte + Vector2(b, -t), mitte + Vector2(b, t), mitte + Vector2(-b, t)], true, 0.5)
	# Ecken des Grundstücks mit Pfosten markieren
	for ecke in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var p: Vector2 = h + ecke * halb
		_kasten(Vector3(0.25, 1.4, 0.25), Vector3(p.x, gelaende.hoehe(p.x, p.y) + 0.7, p.y), 0.0, false)


# --- Dorf ---

func _dorf() -> void:
	var d := Gelaende.DORF
	orte.laden = _modell("dorf/laden", 10.0, d + Vector2(-20, -14), 0.0)
	_schild("Laden", orte.laden + Vector3(0, 6.0, 0))
	orte.markt = _modell("dorf/marktstand", 3.2, d + Vector2(-3, -16), 0.0, "hoehe")
	_schild("Pferdemarkt", orte.markt + Vector3(0, 4.2, 0))
	_zaun([d + Vector2(-9, -11), d + Vector2(3, -11), d + Vector2(3, -3), d + Vector2(-9, -3)], true, 0.0)
	orte.jobbrett = _jobbrett(d + Vector2(10, -12))
	_schild("Jobbrett", orte.jobbrett + Vector3(0, 3.3, 0))
	# Turnierplatz: eingezäunte Fläche mit Hindernissen
	var platz := d + Vector2(14, 12)
	_zaun([platz + Vector2(-18, -11), platz + Vector2(18, -11), platz + Vector2(18, 11), platz + Vector2(-18, 11)], true, 0.15)
	orte.turnier = _modell("dorf/hindernisse", 0.0, platz, 0.0, "", false)
	_schild("Turnierplatz", Vector3(platz.x, gelaende.hoehe(platz.x, platz.y) + 4.5, platz.y))


# --- Bausteine ---

## Modell laden, auf Größe bringen und auf den Boden stellen. mass: längste Seite (oder Höhe,
## wenn nach = "hoehe"; 0 = Originalgröße). Gibt die Position (Boden, Mitte) zurück.
func _modell(name: String, mass: float, wo: Vector2, drehung: float, nach := "", kollision := true) -> Vector3:
	var szene: Node3D = load("res://assets/download/%s.glb" % name).instantiate()
	var halter := Node3D.new()
	add_child(halter)
	halter.add_child(szene)
	var box := _huelle(szene)
	var skala := 1.0
	if mass > 0.0:
		skala = mass / (box.size.y if nach == "hoehe" else maxf(box.size.x, box.size.z))
	szene.scale = Vector3.ONE * skala
	szene.position = -Vector3(box.get_center().x, box.position.y, box.get_center().z) * skala
	var boden := gelaende.hoehe(wo.x, wo.y)
	halter.position = Vector3(wo.x, boden, wo.y)
	halter.rotation.y = drehung
	for mi: MeshInstance3D in szene.find_children("*", "MeshInstance3D", true, false):
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	if kollision:
		_kollision_kasten(box.size * skala * Vector3(0.95, 1.0, 0.95), halter.position + Vector3.UP * box.size.y * skala * 0.5, drehung)
	return halter.position


func _huelle(szene: Node3D) -> AABB:
	var box := AABB()
	var erste := true
	var zu_szene := szene.global_transform.affine_inverse()
	for mi: MeshInstance3D in szene.find_children("*", "MeshInstance3D", true, false):
		var b := zu_szene * mi.global_transform * mi.mesh.get_aabb()
		box = b if erste else box.merge(b)
		erste = false
	return box


## Holzzaun mit Pfosten und drei Latten entlang der Punkte. tor_bei: Lücke mit offenem Tor bei
## diesem Anteil der ersten Seite (0 = kein Tor). Gibt die Mitte des Tors zurück.
func _zaun(punkte: Array, geschlossen: bool, tor_bei: float) -> Vector3:
	var tor := Vector3.ZERO
	var anzahl := punkte.size() if geschlossen else punkte.size() - 1
	for i in anzahl:
		var a: Vector2 = punkte[i]
		var b: Vector2 = punkte[(i + 1) % punkte.size()]
		var stuecke := [[a, b]]
		if i == 0 and tor_bei > 0.0:
			var m := a.lerp(b, tor_bei)
			var r := (b - a).normalized()
			stuecke = [[a, m - r * 1.6], [m + r * 1.6, b]]
			tor = Vector3(m.x, gelaende.hoehe(m.x, m.y), m.y)
			# offenes Tor: Flügel nach außen geschwenkt
			var angel := m + r * 1.6
			var fluegel := angel + r.rotated(-PI * 0.55) * 3.2 * -1.0
			_latten(angel, fluegel)
		for s in stuecke:
			_latten(s[0], s[1])
	return tor


func _latten(a: Vector2, b: Vector2) -> void:
	var laenge := a.distance_to(b)
	var feld := maxi(1, int(round(laenge / KACHEL)))
	for k in feld + 1:
		var p := a.lerp(b, float(k) / feld)
		_kasten(Vector3(0.16, 1.5, 0.16), Vector3(p.x, gelaende.hoehe(p.x, p.y) + 0.6, p.y), 0.0, false)
	var richtung := atan2(-(b - a).y, (b - a).x)
	for k in feld:
		var p := a.lerp(b, (k + 0.5) / feld)
		var boden := gelaende.hoehe(p.x, p.y)
		for hoehe in [0.45, 0.85, 1.25]:
			_kasten(Vector3(laenge / feld + 0.1, 0.1, 0.05), Vector3(p.x, boden + hoehe, p.y), richtung, false)
		_kollision_kasten(Vector3(laenge / feld, 1.4, 0.3), Vector3(p.x, boden + 0.7, p.y), richtung)


## Holzkasten (Pfosten, Latte, Brett); kollision: auch eine Kollisionsform anlegen
func _kasten(groesse: Vector3, wo: Vector3, drehung: float, kollision: bool) -> void:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = groesse
	mi.mesh = box
	mi.material_override = _holz
	mi.position = wo
	mi.rotation.y = drehung
	add_child(mi)
	if kollision:
		_kollision_kasten(groesse, wo, drehung)


func _kollision_kasten(groesse: Vector3, wo: Vector3, drehung: float) -> void:
	var cs := CollisionShape3D.new()
	var form := BoxShape3D.new()
	form.size = groesse
	cs.shape = form
	cs.position = wo
	cs.rotation.y = drehung
	_kollision.add_child(cs)


## Jobbrett: zwei Pfosten, Brett, ein paar Zettel
func _jobbrett(wo: Vector2) -> Vector3:
	var boden := gelaende.hoehe(wo.x, wo.y)
	for seite in [-1.0, 1.0]:
		_kasten(Vector3(0.15, 2.4, 0.15), Vector3(wo.x + seite * 1.0, boden + 1.2, wo.y), 0.0, true)
	_kasten(Vector3(2.3, 1.2, 0.08), Vector3(wo.x, boden + 1.6, wo.y), 0.0, true)
	_kasten(Vector3(2.6, 0.1, 0.4), Vector3(wo.x, boden + 2.3, wo.y), 0.0, false)
	var papier := StandardMaterial3D.new()
	papier.albedo_color = Color(0.93, 0.9, 0.8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 5:
		var zettel := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(0.32, 0.4)
		zettel.mesh = q
		zettel.material_override = papier
		zettel.position = Vector3(wo.x - 0.8 + i * 0.4, boden + 1.5 + rng.randf_range(-0.25, 0.25), wo.y + 0.05)
		zettel.rotation.z = rng.randf_range(-0.15, 0.15)
		add_child(zettel)
	return Vector3(wo.x, boden, wo.y)


## Namensschild über einem Ort (E21)
func _schild(text: String, wo: Vector3) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = 72
	l.outline_size = 18
	l.pixel_size = 0.008
	l.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	l.modulate = Color(1.0, 0.92, 0.7)
	l.position = wo
	add_child(l)


func auf_grundstueck(p: Vector3) -> bool:
	return orte.grundstueck.has_point(Vector2(p.x, p.z))
