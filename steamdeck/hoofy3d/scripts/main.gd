extends Node3D
## Baut die Welt zusammen: Gelände, Himmel, Wasser, Hof und Dorf, Bewuchs, Wildpferde, Spielfigur,
## Kamera, Anzeige, Menüs. Gesteuert wird die Figur oder, nach dem Aufsitzen, das Pferd.
## Start wie im 2D-Hoofy: zu Fuß auf dem Hof, ohne Pferd (KATALOG §15).

var gelaende := Gelaende.new()
var himmel := Himmel.new()
var kamera := Kamera.new()
var figur := Figur.new()
var pferd: Pferd                          # das gerittene Pferd, sonst null
var spieler: Node3D                       # wer gerade gesteuert wird: Figur oder Pferd
var gras := Gras.new()
var wild := Wildpferde.new()
var anzeige := Anzeige.new()
var menue := Menue.new()
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

	figur.gelaende = gelaende
	figur.kamera = kamera
	add_child(figur)
	figur.global_position = Vector3(start.x, gelaende.hoehe(start.x, start.y) + 0.1, start.y)
	gras.gelaende = gelaende
	add_child(gras)
	kamera.ausnehmen(figur)
	kamera.gelaende = gelaende
	if Testlauf.optionen.has("yaw"):
		kamera.yaw = deg_to_rad(float(Testlauf.optionen.yaw))
	add_child(kamera)
	himmel.neuer_tag.connect(func(_t: int) -> void:
		if pferd:
			pferd.neuer_tag()
		Tage.neuer_tag(Spiel.herde))
	himmel.abend.connect(func() -> void:
		Tage.abend(Spiel.herde)
		_kaeufer_zeigen())
	himmel.neuer_tag.connect(_morgen)

	wild.gelaende = gelaende
	wild.himmel = himmel
	wild.siedlung = siedlung
	wild.spieler = figur
	add_child(wild)
	if Testlauf.optionen.has("am_wildpferd"):
		# Test: 3 m neben das erste Wildpferd stellen, Kamera dahinter
		var w: Node3D = wild.pferde[0]
		var neben := w.global_position + w.global_basis.x * 3.0
		figur.global_position = Vector3(neben.x, gelaende.hoehe(neben.x, neben.z) + 0.1, neben.z)
		kamera.yaw = atan2(w.global_position.x - neben.x, w.global_position.z - neben.z) + PI

	anzeige.himmel = himmel
	anzeige.wildpferde = wild
	anzeige.siedlung = siedlung
	add_child(anzeige)
	menue.himmel = himmel
	menue.siedlung = siedlung
	menue.wildpferde = wild
	add_child(menue)
	wild.angesprochen.connect(menue.aktionsmenue)
	wild.am_ort.connect(_am_ort)
	menue.aufsitzen.connect(_aufsitzen)
	_steuern(figur)
	if Testlauf.optionen.has("tag"):
		himmel.tag = int(Testlauf.optionen.tag)
	_kaeufer_figur.siedlung = siedlung
	add_child(_kaeufer_figur)
	add_to_group("kaeufer_weg")
	_morgen(himmel.tag, false)
	if Testlauf.optionen.has("eigenes_pferd"):
		# Test: ein eigenes, gepflegtes Pferd an der Leine
		var d := HoofyDaten.wildpferd(rng, 1, "noriker")
		d.erase("wild")
		d.bindung = 75
		d.sauberkeit = 80
		d.hunger = 20
		Spiel.herde.append(d)
		wild.adoptieren(d)
		wild.unterbringen(wild.knoten_von(d), "weide")
	if Testlauf.optionen.has("probepferd"):
		# Test: gleich auf einem gesattelten Pferd sitzen (im Spiel zähmt man das erste selbst)
		var daten := HoofyDaten.wildpferd(rng, 1, Testlauf.optionen.get("rasse", "haflinger"))
		daten.erase("wild")
		daten.sattel = "einfacher_sattel"
		if Testlauf.optionen.has("farbe"):
			daten.farbe = Testlauf.optionen.farbe
		_reiten(daten, figur.global_position, 0.0)

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


## Alles, was dem Spieler folgt, auf die Figur oder das gerittene Pferd umstellen
func _steuern(ziel: Node3D) -> void:
	spieler = ziel
	kamera.ziel = ziel
	gras.ziel = ziel
	wild.spieler = ziel
	menue.spieler = ziel
	anzeige.spieler = ziel
	anzeige.pferd = pferd


var _geritten: Wildpferde.WildPferd     # das Pferd aus der Herde, das gerade geritten wird
var _absteigen_halten := 0.0


## Aufsitzen aus dem Aktionsmenü (Wild:try_mount): frisch gezähmt geht nicht, Bindung unter 20
## verweigert zu 50 %
func _aufsitzen(w: Wildpferde.WildPferd) -> void:
	var d := w.daten
	var b: Dictionary = HoofyDaten.daten().stats.bindung
	if d.has("reit_ab") and int(d.bindung) < int(d.reit_ab):
		w.zeige("⚡", Color(0.6, 0.65, 0.9), 2.0)
		anzeige.meldung("%s ist frisch gezähmt und lässt dich noch nicht aufsitzen. Füttern, striegeln und streicheln." % d.name, 3.0)
		return
	d.erase("reit_ab")
	if int(d.bindung) < int(b.zickig) and rng.randf() < float(b.zickig_verweigert) / 100.0:
		w.zeige("⚡", Color(0.6, 0.65, 0.9), 2.0)
		return
	wild.reiten_beginnen(w)
	_geritten = w
	_reiten(d, w.global_position, w.rotation.y)


## Auf ein Pferd mit diesen Daten setzen; die Figur sitzt im Sattel
func _reiten(daten: Dictionary, wo: Vector3, winkel: float) -> void:
	pferd = Pferd.new(daten)
	pferd.gelaende = gelaende
	pferd.kamera = kamera
	add_child(pferd)
	pferd.global_position = wo + Vector3.UP * 0.2
	pferd.rotation.y = winkel
	pferd._richtung = winkel
	kamera.ausnehmen(pferd)
	figur.modell.reparent(self)
	figur.modell.sitzen(true)
	pferd.reiter = figur.modell
	figur.process_mode = Node.PROCESS_MODE_DISABLED
	figur.collision_layer = 0
	figur.collision_mask = 0
	_steuern(pferd)


## Absteigen (Aktionstaste halten): Figur steht links neben dem Pferd
func _absteigen() -> void:
	var neben := pferd.global_position - pferd.global_basis.x * 1.4
	neben.y = gelaende.hoehe(neben.x, neben.z) + 0.1
	figur.modell.sitzen(false)
	figur.modell.reparent(figur)
	figur.modell.transform = Transform3D()
	figur.process_mode = Node.PROCESS_MODE_INHERIT
	figur.collision_layer = 1
	figur.collision_mask = 1
	figur.global_position = neben
	figur.ausrichten(pferd.rotation.y)
	var text := "Abgestiegen."
	if _geritten:
		text = wild.reiten_beenden(_geritten, pferd.global_position, pferd.rotation.y)
		_geritten = null
	pferd.queue_free()
	pferd = null
	_steuern(figur)
	anzeige.meldung(text, 2.0)


func _process(delta: float) -> void:
	if pferd and Input.is_action_pressed("interagieren"):
		_absteigen_halten += delta
		if _absteigen_halten >= 0.5:
			_absteigen_halten = 0.0
			_absteigen()
	else:
		_absteigen_halten = 0.0


var _kaeufer_figur := KaeuferFigur.new()


## Nach einem Verkauf geht der Käufer (pro Besuch ein Verkauf)
func kaeufer_weg() -> void:
	_kaeufer_zeigen()


## Tagesbeginn: Käufer des Tages, Markt, Neuigkeiten (world.lua beim Aufwachen)
func _morgen(tag: int, melden := true) -> void:
	if Spiel.kaeufer.get("tag", -1) != tag:
		Spiel.kaeufer = Handel.besuch(tag)
	Handel.markt(tag)
	_kaeufer_zeigen()
	if melden:
		for text in Handel.neu_am(tag):
			anzeige.meldung(text, 5.0)


## Der Käufer steht tagsüber im Dorf, bis er etwas gekauft hat (Buyers.sync)
func _kaeufer_zeigen() -> void:
	var da: bool = not Spiel.kaeufer.is_empty() and not Spiel.kaeufer.verkauft and not himmel.ist_nacht()
	_kaeufer_figur.zeigen(Spiel.kaeufer.typ if da else "")


## Aktionstaste vor einem Ort auf dem Hof oder im Dorf
func _am_ort(ort: String) -> void:
	if ort == "stall":
		menue.stall()
	elif ort == "laden":
		menue.laden()
	elif ort == "wohnwagen":
		_schlafen()
	elif ort == "markt":
		menue.markt(himmel.tag)
	elif ort == "kaeufer":
		menue.kaeufer(himmel.tag)
	elif ort == "jobbrett":
		anzeige.meldung("Am Jobbrett hängen noch keine Aufträge. Postritt, Kutschtaxi und Pflügen kommen bald.", 3.0)


## Im Wohnwagen schlafen (E33, E35): überspringt die Nacht, Tagesregeln, speichern
func _schlafen() -> void:
	if not himmel.darf_schlafen():
		anzeige.meldung("Noch nicht müde. Ab dem Abend kannst du hier schlafen.", 2.5)
		return
	await anzeige.abblenden()
	himmel.schlafen()
	Spiel.speichern(himmel)
	anzeige.meldung("Gut geschlafen. Gespeichert.", 4.0)
	await anzeige.aufblenden()
