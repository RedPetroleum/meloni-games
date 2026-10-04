extends Node3D
## Baut die Welt zusammen: Gelände, Himmel, Wasser, Bewuchs, Pferde, Kamera, Anzeige.

var gelaende := Gelaende.new()
var himmel := Himmel.new()
var kamera := Kamera.new()
var pferd: Pferd
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	add_child(gelaende)
	add_child(himmel)
	var wasser := Wasser.new()
	wasser.gelaende = gelaende
	add_child(wasser)
	var siedlung := Siedlung.new()
	siedlung.gelaende = gelaende
	add_child(siedlung)
	var bewuchs := Bewuchs.new()
	bewuchs.gelaende = gelaende
	add_child(bewuchs)
	# Spielstand laden (E35); Testläufe beginnen immer neu
	if not Testlauf.ist_aktiv() and Spiel.laden():
		himmel.tag = Spiel.tag
		himmel.uhrzeit = Spiel.uhrzeit
	if Testlauf.optionen.has("zeit"):
		himmel.uhrzeit = float(Testlauf.optionen.zeit)
	var start := Gelaende.HOF
	if Testlauf.optionen.has("pos"):
		var p: PackedStringArray = Testlauf.optionen.pos.split(",")
		start = Vector2(float(p[0]), float(p[1]))
	rng.seed = int(Testlauf.optionen.get("seed", "1"))
	# Probepferd, bis es die Spielfigur gibt: in Hoofy startet man ohne Pferd und zähmt das erste
	var daten := HoofyDaten.wildpferd(rng, 1, Testlauf.optionen.get("rasse", "haflinger"))
	daten.wild = false
	daten.sattel = "einfacher_sattel"
	if Testlauf.optionen.has("farbe"):
		daten.farbe = Testlauf.optionen.farbe
	pferd = Pferd.new(daten)
	pferd.gelaende = gelaende
	pferd.kamera = kamera
	add_child(pferd)
	pferd.global_position = Vector3(start.x, gelaende.hoehe(start.x, start.y) + 0.2, start.y)
	kamera.ziel = pferd
	var gras := Gras.new()
	gras.gelaende = gelaende
	gras.ziel = pferd
	add_child(gras)
	kamera.ausnehmen(pferd)
	kamera.gelaende = gelaende
	if Testlauf.optionen.has("yaw"):
		kamera.yaw = deg_to_rad(float(Testlauf.optionen.yaw))
	add_child(kamera)
	himmel.neuer_tag.connect(func(_t: int) -> void: pferd.neuer_tag())
	var wild := Wildpferde.new()
	wild.gelaende = gelaende
	wild.spieler = pferd
	wild.himmel = himmel
	wild.siedlung = siedlung
	add_child(wild)
	if Testlauf.optionen.has("am_wildpferd"):
		# Test: 3 m neben das erste Wildpferd stellen, Kamera dahinter
		var w: Node3D = wild.pferde[0]
		var neben := w.global_position + w.global_basis.x * 3.0
		pferd.global_position = Vector3(neben.x, gelaende.hoehe(neben.x, neben.z) + 0.2, neben.z)
		kamera.yaw = atan2(w.global_position.x - neben.x, w.global_position.z - neben.z) + PI
	var anzeige := Anzeige.new()
	anzeige.pferd = pferd
	anzeige.himmel = himmel
	anzeige.wildpferde = wild
	anzeige.siedlung = siedlung
	add_child(anzeige)
	var menue := Menue.new()
	menue.himmel = himmel
	menue.siedlung = siedlung
	menue.spieler = pferd
	add_child(menue)
	Einstellungen.anwenden(get_viewport(), himmel.env, himmel.sonne)
	# Für Leistungsmessungen: --ohne=gras,bewuchs,schatten,ssao,nebel,wild
	var ohne: PackedStringArray = Testlauf.optionen.get("ohne", "").split(",", false)
	gras.visible = not "gras" in ohne
	bewuchs.visible = not "bewuchs" in ohne
	wild.visible = not "wild" in ohne
	if "schatten" in ohne:
		himmel.sonne.shadow_enabled = false
	if "ssao" in ohne:
		himmel.env.ssao_enabled = false
	if "nebel" in ohne:
		himmel.env.volumetric_fog_enabled = false
		himmel.env.fog_enabled = false
