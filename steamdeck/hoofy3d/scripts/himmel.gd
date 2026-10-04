class_name Himmel
extends Node3D
## Tag und Nacht: Sonne, Mond, physikalischer Himmel mit Sternen, Nebel mit Luftperspektive.
## Hoofy: 5 Minuten pro Tag, 3 hell und 2 dunkel. In 3D doppelt so lang (entschieden 2026-10-05):
## 6 Minuten hell (Sonnenaufgang bis -untergang), 4 Minuten dunkel. Start am Morgen.

const AUFGANG := 5.5
const UNTERGANG := 20.5

const HELL_SEKUNDEN := 360.0
const DUNKEL_SEKUNDEN := 240.0

signal neuer_tag(tag: int)

@export var uhrzeit := 7.0  # Stunden, 0–24

var sonne := DirectionalLight3D.new()
var mond := DirectionalLight3D.new()
var umgebung := WorldEnvironment.new()
var env := Environment.new()
var himmel_mat := PhysicalSkyMaterial.new()
var tag := 1
var _sternenhimmel: ImageTexture


func _ready() -> void:
	himmel_mat.rayleigh_coefficient = 2.0
	himmel_mat.mie_coefficient = 0.004
	himmel_mat.mie_eccentricity = 0.85
	himmel_mat.turbidity = 5.0
	himmel_mat.sun_disk_scale = 1.4
	himmel_mat.ground_color = Color(0.22, 0.2, 0.16)
	himmel_mat.energy_multiplier = 2.0
	_sternenhimmel = _sterne()
	var sky := Sky.new()
	sky.sky_material = himmel_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_256
	sky.process_mode = Sky.PROCESS_MODE_REALTIME
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.0
	env.tonemap_white = 6.0
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.6
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_bloom = 0.04
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.fog_enabled = true
	env.fog_density = 0.00045
	env.fog_aerial_perspective = 0.75
	env.fog_sky_affect = 0.1
	env.fog_sun_scatter = 0.08
	env.volumetric_fog_density = 0.001
	env.volumetric_fog_anisotropy = 0.4
	env.volumetric_fog_length = 96.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.08
	env.adjustment_contrast = 1.04
	umgebung.environment = env
	add_child(umgebung)

	sonne.name = "Sonne"
	sonne.shadow_enabled = true
	sonne.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sonne.directional_shadow_max_distance = 160.0
	sonne.directional_shadow_blend_splits = true
	sonne.shadow_bias = 0.04
	sonne.shadow_normal_bias = 1.2
	sonne.light_angular_distance = 0.5
	sonne.light_volumetric_fog_energy = 1.5
	add_child(sonne)
	mond.name = "Mond"
	mond.shadow_enabled = true
	mond.directional_shadow_max_distance = 80.0
	mond.light_color = Color(0.6, 0.7, 1.0)
	mond.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	add_child(mond)
	_aktualisieren()


func _process(delta: float) -> void:
	var hell := uhrzeit >= AUFGANG and uhrzeit < UNTERGANG
	var stunden := (UNTERGANG - AUFGANG) / HELL_SEKUNDEN if hell else (24.0 - UNTERGANG + AUFGANG) / DUNKEL_SEKUNDEN
	var vorher := uhrzeit
	uhrzeit = fmod(uhrzeit + delta * stunden, 24.0)
	# Der neue Tag beginnt am Morgen (Hoofy: Tageswechsel beim Aufwachen)
	if vorher < AUFGANG and uhrzeit >= AUFGANG:
		tag += 1
		neuer_tag.emit(tag)
	_aktualisieren()


func _aktualisieren() -> void:
	# Sommer: Aufgang 5:30 im Osten, Untergang 20:30 im Westen
	var winkel := (uhrzeit - AUFGANG) / (UNTERGANG - AUFGANG) * PI
	var hoch := sin(winkel)
	var richtung := Vector3(-cos(winkel), hoch * 0.85, -0.45).normalized()
	sonne.look_at_from_position(Vector3.ZERO, -richtung, Vector3.UP if absf(richtung.y) < 0.99 else Vector3.FORWARD)
	mond.look_at_from_position(Vector3.ZERO, Vector3(richtung.x, -richtung.y, richtung.z * -0.6), Vector3.UP)

	var tag_anteil := smoothstep(-0.06, 0.12, hoch)       # 0 Nacht, 1 Tag
	var golden := 1.0 - smoothstep(0.0, 0.35, hoch)        # Morgen-/Abendlicht
	sonne.light_energy = tag_anteil * 1.9
	sonne.light_color = Color(1.0, 0.93, 0.84).lerp(Color(1.0, 0.58, 0.32), golden * tag_anteil)
	sonne.visible = tag_anteil > 0.001
	mond.light_energy = (1.0 - tag_anteil) * 0.13
	mond.visible = tag_anteil < 0.999

	env.ambient_light_sky_contribution = lerpf(0.35, 1.0, tag_anteil)
	env.ambient_light_color = Color(0.05, 0.07, 0.13)
	env.ambient_light_energy = lerpf(0.8, 1.0, tag_anteil)
	env.fog_light_color = Color(0.03, 0.04, 0.08).lerp(Color(0.62, 0.7, 0.8).lerp(Color(0.95, 0.66, 0.45), golden), tag_anteil)
	env.fog_light_energy = lerpf(0.4, 1.0, tag_anteil)
	env.tonemap_exposure = lerpf(1.8, 1.0, tag_anteil)
	# Sterne nur, wenn es dunkel genug ist (der Himmel addiert sie sonst auch tagsüber)
	var sterne := _sternenhimmel if tag_anteil < 0.6 else null
	if himmel_mat.night_sky != sterne:
		himmel_mat.night_sky = sterne


func ist_nacht() -> bool:
	return uhrzeit < AUFGANG or uhrzeit > UNTERGANG


## Anteil des hellen (Sonne) bzw. dunklen Abschnitts, 0–1, für die Anzeige wie in Hoofy
func abschnitt() -> float:
	if uhrzeit >= AUFGANG and uhrzeit < UNTERGANG:
		return (uhrzeit - AUFGANG) / (UNTERGANG - AUFGANG)
	return fmod(uhrzeit - UNTERGANG + 24.0, 24.0) / (24.0 - UNTERGANG + AUFGANG)


## Sternenhimmel als Panorama (2:1), einmal beim Start erzeugt
func _sterne() -> ImageTexture:
	var bild := Image.create_empty(2048, 1024, false, Image.FORMAT_RGB8)
	bild.fill(Color(0.004, 0.006, 0.014))
	var rng := RandomNumberGenerator.new()
	rng.seed = 2040
	for i in 3500:
		var x := rng.randi_range(0, 2047)
		var y := rng.randi_range(0, 520)
		var hell := pow(rng.randf(), 6.0) * 0.9 + 0.08
		var farbe := Color(1, 1, 1).lerp(Color(0.7, 0.8, 1.0) if rng.randf() < 0.5 else Color(1.0, 0.85, 0.7), rng.randf() * 0.6)
		bild.set_pixel(x, y, farbe * hell)
	# Milchstraße: ein schwaches, schräges Band
	for x in 2048:
		var mitte := 300.0 + sin(x / 2048.0 * TAU) * 160.0
		for dy in range(-40, 41):
			var y := int(mitte) + dy
			if y < 0 or y > 600:
				continue
			var v := exp(-dy * dy / 500.0) * 0.035 * (0.6 + 0.4 * sin(x * 0.05 + dy * 0.3))
			var c := bild.get_pixel(x, y)
			bild.set_pixel(x, y, c + Color(v, v * 0.95, v * 1.1))
	return ImageTexture.create_from_image(bild)
