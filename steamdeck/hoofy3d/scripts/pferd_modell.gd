class_name PferdModell
extends Node3D
## Das sichtbare Pferd: Modell laden, ausrichten und auf Rassengröße bringen, Fell-Shader mit
## Hoofy-Farbe setzen, Animation zur Gangart wählen.
##
## Modelle stehen in MODELLE. Ausgerichtet wird über Knochen (Huf, Widerrist, Kopf, Schweif),
## damit jedes Modell egal welcher Achsen-Konvention gleich dasteht. Fehlt das gute Modell
## (tools/assets.py ohne Sketchfab-Token), wird der Platzhalter genommen.

const MODELLE := [
	{
		# „Horse“ von henry_7 (Sketchfab, CC-BY)
		"pfad": "res://assets/download/pferd/horse_henry7.glb",
		"hufe": ["BN_L_Toe_042_0_044", "BN_R_Toe_047_0_050", "BN_L_Toe_2_055_0_059", "BN_R_Toe_2_059_0_065"],
		"widerrist": "BN_Neck_00_06_06",
		"kopf": "BN_Head_01_029_028",
		"schweif": "BN_Tail_00_061_067",
		# Steigbügel-Knochen: ihre Aufhängung liegt mittig unter der Sitzfläche (die Knochen selbst
		# zeigen nach oben, taugen also nicht als Fußposition)
		"buegel": ["BN_L_Stirrup_048_051", "BN_R_Stirrup_049_052"],
		"sitz_hoehe": 0.16,                      # Sattelfläche über den Aufhängungen
		"sitz_zurueck": 0.07,                    # tiefster Punkt des Sattels liegt etwas hinter der Mitte
		# Bügel relativ zum Sitz bei 1,65 m Stockmaß: seitlich, tief (Bauchunterkante), Ferse
		# unter der Hüfte (Linie Ohr–Schulter–Hüfte–Ferse)
		"buegel_lage": Vector3(0.44, -0.66, 0.03),
		# Knie: außen am Sattelblatt, vorn und tiefer als die Hüfte (Oberschenkel schräg nach unten)
		"knie_lage": Vector3(0.52, -0.24, -0.32),
		# Hände: knapp über dem Widerrist, eine Unterarmlänge vor dem Bauch, ~16 cm auseinander
		"haende_lage": Vector3(0.08, 0.40, -0.30),
		"maul": "BN_UP_Lip_030_029",
		"fell": "Horse",
		"haar": "Hair",
		"ausruestung": ["Saddle"],
		# Gangart → [Animation, Bodentempo in m/s bei normalem Abspieltempo]
		"anim": {
			"stehen": ["Skeleton|1 Ilde", 1.0],
			"grasen": ["Skeleton|6 Eat", 1.0],
			"schritt": ["Skeleton|Walk", 1.6],
			"schritt_l": ["Skeleton|Walk_L", 1.6],
			"schritt_r": ["Skeleton|Walk_R", 1.6],
			"trab": ["Skeleton|Walk", 1.7],          # kein Trab im Modell: zügiger Schritt
			"galopp": ["Skeleton|Gallop", 8.0],
			"galopp_l": ["Skeleton|Gallop_L", 8.0],
			"galopp_r": ["Skeleton|Gallop_R", 8.0],
			"renngalopp": ["Skeleton|Gallop", 8.0],
			"springen": ["Skeleton|Jump_Run", 1.0],
			"schwimmen": ["Skeleton|Swim", 1.5],
		},
	},
	{
		# Platzhalter: three.js-Beispiel, nur Galopp, keine Normalen
		"pfad": "res://assets/download/pferd/pferd.glb",
		"drehung": PI,
		"anim": {"galopp": ["horse_A_", 4.7]},
	},
]
## Kopfhöhe ist etwa so viel höher als das Stockmaß (Widerrist), für Modelle ohne Knochen
const KOPF_FAKTOR := 1.4

static var _cache := {}

var daten: Dictionary
var gesattelt := false
var stockmass := 1.65
var breite := 1.0
var fell := ShaderMaterial.new()
var _modell: Dictionary
var _player: AnimationPlayer
var _aktuell := ""
var _skelett: Skeleton3D
var _zu_szene := Transform3D()      # Skelettraum → Szenenraum


func _init(pferd: Dictionary, sattel := false) -> void:
	daten = pferd
	gesattelt = sattel


func _ready() -> void:
	for m in MODELLE:
		if ResourceLoader.exists(m.pfad):
			_modell = m
			break
	var rasse := HoofyDaten.rasse(daten.rasse)
	var koerper: Dictionary = HoofyDaten.KOERPER.get(rasse.get("koerper", "warmblut"), HoofyDaten.KOERPER.warmblut)
	stockmass = koerper.stockmass
	breite = koerper.breite
	var szene: Node3D = _geteilt(_modell.pfad).instantiate()
	add_child(szene)

	var ausrichtung := _ausrichten(szene, koerper.breite)
	_materialien(szene, ausrichtung)

	var players := szene.find_children("*", "AnimationPlayer", true, false)
	if players:
		_player = players[0]
		for a in _player.get_animation_list():
			if not a.contains("Jump"):
				_player.get_animation(a).loop_mode = Animation.LOOP_LINEAR


## Modell so drehen, skalieren und verschieben, dass es auf y = 0 steht, nach -Z schaut und
## das Stockmaß der Rasse hat. Gibt [Drehung (Modell → aufrecht), Einheit, Boden, Widerristhöhe,
## Mitte am Boden, halbe Länge] in Modelleinheiten zurück.
func _ausrichten(szene: Node3D, breite: float) -> Array:
	var sk: Skeleton3D = null
	var skelette := szene.find_children("*", "Skeleton3D", true, false)
	if skelette and _modell.has("hufe"):
		sk = skelette[0]
	var drehung := Basis()
	var einheit := 1.0
	var mitte := Vector3.ZERO
	var boden := 0.0
	var hoehe := 1.0
	var laenge := 1.0
	if sk:
		_skelett = sk
		_zu_szene = szene.global_transform.affine_inverse() * sk.global_transform
		var knochen := func(name: String) -> Vector3: return _zu_szene * sk.get_bone_global_rest(sk.find_bone(name)).origin
		# hufe: vorne links, vorne rechts, hinten links, hinten rechts
		var vl: Vector3 = knochen.call(_modell.hufe[0])
		var vr: Vector3 = knochen.call(_modell.hufe[1])
		var hl: Vector3 = knochen.call(_modell.hufe[2])
		var hr: Vector3 = knochen.call(_modell.hufe[3])
		var huf := (vl + vr + hl + hr) * 0.25
		var widerrist: Vector3 = knochen.call(_modell.widerrist)
		var kopf: Vector3 = knochen.call(_modell.kopf)
		var schweif: Vector3 = knochen.call(_modell.schweif)
		# Boden = Ebene der vier Hufe; oben steht senkrecht darauf
		var vorne := ((vl + vr) - (hl + hr)).normalized()
		var links := ((vl + hl) - (vr + hr)).normalized()
		var oben := vorne.cross(links).normalized()
		if oben.dot(widerrist - huf) < 0.0:
			oben = -oben
		vorne = (vorne - oben * vorne.dot(oben)).normalized()
		var z := -vorne
		drehung = Basis(oben.cross(z).normalized(), oben, z).transposed()
		einheit = stockmass / (widerrist - huf).dot(oben)
		mitte = drehung * ((kopf + schweif) * 0.5)
		boden = (drehung * huf).y
		hoehe = (drehung * widerrist).y - boden
		laenge = absf((drehung * kopf).z - (drehung * schweif).z) * 0.5
	else:
		# Ohne Knochen: Größe aus der Hülle (Kopfhöhe ≈ Stockmaß × KOPF_FAKTOR)
		drehung = Basis(Vector3.UP, _modell.get("drehung", 0.0))
		var aabb := AABB()
		var erste := true
		for mi: MeshInstance3D in szene.find_children("*", "MeshInstance3D", true, false):
			var box := mi.transform * mi.mesh.get_aabb()
			aabb = box if erste else aabb.merge(box)
			erste = false
		einheit = stockmass * KOPF_FAKTOR / aabb.size.y
		boden = aabb.position.y
		hoehe = aabb.size.y / KOPF_FAKTOR
		laenge = maxf(aabb.size.x, aabb.size.z) * 0.5
		mitte = drehung * aabb.get_center()
	var skala := Basis.from_scale(Vector3(breite, 1.0, 1.0))
	szene.transform = Transform3D(skala * drehung * Basis.from_scale(Vector3.ONE * einheit),
		skala * Vector3(-mitte.x, -boden, -mitte.z) * einheit)
	return [drehung, einheit, boden, hoehe, Vector3(mitte.x, boden, mitte.z), laenge]


func _materialien(szene: Node3D, a: Array) -> void:
	fell.shader = load("res://shaders/fell.gdshader")
	var f: Dictionary = HoofyDaten.FELL.get(daten.farbe, HoofyDaten.FELL.brauner)
	fell.set_shader_parameter("fell", f.fell)
	fell.set_shader_parameter("beine", f.get("beine", f.fell))
	fell.set_shader_parameter("abzeichen", f.get("abzeichen", Color(0.92, 0.9, 0.86)))
	fell.set_shader_parameter("muster", f.get("muster", HoofyDaten.Muster.KEINS))
	fell.set_shader_parameter("glanz", f.get("glanz", 0.0))
	fell.set_shader_parameter("tupfen", f.get("tupfen", 0.08))
	fell.set_shader_parameter("ruhe", a[0])
	fell.set_shader_parameter("einheit", a[1])
	fell.set_shader_parameter("zentrum", a[4])
	fell.set_shader_parameter("hoehe", a[3])
	fell.set_shader_parameter("laenge", a[5])
	fell.set_shader_parameter("saat", float(hash(daten) % 1000) / 10.0)

	for mi: MeshInstance3D in szene.find_children("*", "MeshInstance3D", true, false):
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		var mat := mi.mesh.surface_get_material(0)
		var name: String = mat.resource_name if mat else ""
		if not _modell.has("fell") or name == _modell.fell:
			# Fell: Hoofy-Farbe, Feinheiten (Muskeln, Haarstruktur) aus den Texturen des Modells
			if mat is BaseMaterial3D and mat.albedo_texture:
				fell.set_shader_parameter("detail", mat.albedo_texture)
				fell.set_shader_parameter("normalen", mat.normal_texture)
				fell.set_shader_parameter("hat_textur", true)
			if mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL] == null:
				fell.set_shader_parameter("flache_normalen", true)
			mi.mesh = _mit_ruhepositionen(mi.mesh, Transform3D(a[0]) * _mesh_zu_szene(mi))
			mi.material_override = fell
		elif name == _modell.get("haar", ""):
			var haar: StandardMaterial3D = mat.duplicate()
			haar.albedo_color = f.get("maehne", _maehne(f))
			mi.material_override = haar
		elif name in _modell.get("ausruestung", []):
			mi.visible = gesattelt


## Mähnenfarbe, wenn nicht eigens angegeben: wie die Beine (Braune, Falben: schwarz)
func _maehne(f: Dictionary) -> Color:
	var c: Color = f.get("beine", f.fell)
	return c.lerp(Color(0.5, 0.5, 0.5), 0.1)


## CUSTOM0 = aufrechte Ruheposition (y oben, -z vorne, Modelleinheiten).
## Muster sollen auf dem Fell kleben und nicht wandern, wenn sich die Beine bewegen: die
## Ruheposition jedes Punkts als CUSTOM0 mitgeben (der Shader sieht sonst nur die bewegte).
## Alle Pferde teilen sich das umgebaute Mesh.
static func _mit_ruhepositionen(alt: Mesh, zu_szene: Transform3D) -> Mesh:
	if _cache.has(alt):
		return _cache[alt]
	var neu := ArrayMesh.new()
	for s in alt.get_surface_count():
		var arrays := alt.surface_get_arrays(s)
		var ruhe := PackedFloat32Array()
		for v: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
			var r := zu_szene * v
			ruhe.append_array([r.x, r.y, r.z, 0.0])
		arrays[Mesh.ARRAY_CUSTOM0] = ruhe
		var format: int = (alt.surface_get_format(s) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS) \
			| (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
		neu.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, alt.surface_get_blend_shape_arrays(s), {}, format)
		neu.surface_set_material(s, alt.surface_get_material(s))
	_cache[alt] = neu
	return neu


## Mesh-Raum → Szenenraum in Ruhehaltung. Bei Skin-Meshes liegen die Punkte in einem eigenen
## Raum (anderer Maßstab, andere Achsen); die Bindung des ersten Knochens rechnet ihn um.
func _mesh_zu_szene(mi: MeshInstance3D) -> Transform3D:
	if _skelett == null or mi.skin == null or mi.skin.get_bind_count() == 0:
		return Transform3D()
	var b := mi.skin.get_bind_bone(0)
	if b < 0:
		b = _skelett.find_bone(mi.skin.get_bind_name(0))
	return _zu_szene * _skelett.get_bone_global_rest(b) * mi.skin.get_bind_pose(0)


## Modelle nur einmal laden: viele Wildpferde teilen sich dieselbe Szene
static func _geteilt(pfad: String) -> PackedScene:
	if not _cache.has(pfad):
		_cache[pfad] = load(pfad)
	return _cache[pfad]


## gang: "stehen", "schritt", "trab", "galopp", "renngalopp", "grasen", "springen",
## "schwimmen"; tempo in m/s; kurve > 0 links, < 0 rechts
func animieren(gang: String, tempo: float, kurve := 0.0) -> void:
	if _player == null:
		return
	var anims: Dictionary = _modell.anim
	var schluessel := gang
	if absf(kurve) > 0.35 and anims.has(gang + ("_l" if kurve > 0.0 else "_r")):
		schluessel = gang + ("_l" if kurve > 0.0 else "_r")
	if not anims.has(schluessel):
		schluessel = "galopp"   # Platzhalter kann nur Galopp
	var eintrag: Array = anims[schluessel]
	if Testlauf.optionen.has("anim"):
		eintrag = ["Skeleton|" + Testlauf.optionen.anim, 1.0]
	var skala := 1.0
	if gang not in ["stehen", "grasen", "springen"] or not anims.has(gang):
		# Nur in einem glaubwürdigen Bereich schneller/langsamer abspielen
		skala = clampf(tempo / eintrag[1], 0.6, 1.4) if tempo > 0.15 else 0.0
	if eintrag[0] != _aktuell:
		_player.play(eintrag[0], 0.3)
		_aktuell = eintrag[0]
	_player.speed_scale = skala


func _knochen_welt(name: String) -> Vector3:
	return _skelett.global_transform * _skelett.get_bone_global_pose(_skelett.find_bone(name)).origin


## Sitzfläche des Sattels in Weltkoordinaten: mittig zwischen den Steigbügel-Aufhängungen, darüber;
## Ausrichtung wie der Pferdekörper
func sattel() -> Transform3D:
	var b := global_basis.orthonormalized()
	if _skelett and _modell.has("buegel"):
		var mitte := (_knochen_welt(_modell.buegel[0]) + _knochen_welt(_modell.buegel[1])) * 0.5
		return Transform3D(b, mitte + b.y * _modell.sitz_hoehe + b.z * _modell.get("sitz_zurueck", 0.0))
	return Transform3D(b, global_position + Vector3.UP * stockmass)


## Wo die Hände hingehören (Zügel): [links, rechts] in Weltkoordinaten
func haende() -> Array:
	if not _modell.has("haende_lage"):
		return []
	var s := sattel()
	var lage: Vector3 = _modell.haende_lage * (stockmass / 1.65)
	lage.x *= breite
	return [s * Vector3(-lage.x, lage.y, lage.z), s * Vector3(lage.x, lage.y, lage.z)]


## Gebiss (Zügelende) in Weltkoordinaten
func maul() -> Vector3:
	if _skelett and _modell.has("maul"):
		return _knochen_welt(_modell.maul)
	return global_position - global_basis.z * stockmass + Vector3.UP * stockmass


## Wo die Knie hingehören: [links, rechts] in Weltkoordinaten
func knie() -> Array:
	if not _modell.has("knie_lage"):
		return []
	var s := sattel()
	var lage: Vector3 = _modell.knie_lage * (stockmass / 1.65)
	lage.x *= breite
	return [s * Vector3(-lage.x, lage.y, lage.z), s * Vector3(lage.x, lage.y, lage.z)]


## Wo die Füße hingehören: die Steigbügel [links, rechts] in Weltkoordinaten (leer ohne Bügel).
## Links ist die linke Seite des Pferdes (-X, das Pferd schaut nach -Z).
func steigbuegel() -> Array:
	if not _modell.has("buegel_lage"):
		return []
	var s := sattel()
	var lage: Vector3 = _modell.buegel_lage * (stockmass / 1.65)
	lage.x *= breite
	return [s * Vector3(-lage.x, lage.y, lage.z), s * Vector3(lage.x, lage.y, lage.z)]


func schmutz(wert: float) -> void:
	fell.set_shader_parameter("schmutz", wert)
