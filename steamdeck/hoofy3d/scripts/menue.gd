class_name Menue
extends CanvasLayer
## Bildschirme wie im 2D-Hoofy (game/screens.lua; E7, E34): START öffnet das Pausenmenü, die Welt
## steht still, solange ein Bildschirm offen ist. Pause → Pferde → Info (← → blättern, A umbenennen)
## → Bildschirmtastatur. Einträge, die es noch nicht gibt, stehen ausgegraut da.
## Bedienung: Steuerkreuz/Stick wählen, A bestätigen, B zurück.

const GOLD := Color(0.95, 0.8, 0.35)
const TEXT := Color(0.93, 0.89, 0.8)
const BLASS := Color(0.68, 0.62, 0.55)
const GRUND := Color(0.13, 0.1, 0.08, 0.94)
const KASTEN := Color(0.2, 0.16, 0.12, 1.0)
const GEN := Color(0.95, 0.75, 0.25)
const TRAINING := Color(0.45, 0.8, 0.35)
const POTENZIAL := Color(0.9, 0.3, 0.25)
const ZUSTAND := Color(0.35, 0.65, 0.95)
const ROT := Color(0.9, 0.3, 0.25)
const ORT := {"stall": "im Stall", "weide": "auf der Weide", "frei": "frei auf dem Hof", "anhaenger": "im Anhänger", "goepel": "am Göpel", "lose": "wartet draußen"}
const TASTEN := ["ABCDEFGHIJ", "KLMNOPQRST", "UVWXYZÄÖÜß-", "abcdefghij", "klmnopqrst", "uvwxyzäöü ."]

var himmel: Himmel
var siedlung: Siedlung
var spieler: Node3D
var wildpferde: Wildpferde

signal aufsitzen(w: Wildpferde.WildPferd)
var _stapel: Array[Control] = []
var _thema := Theme.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	_thema_bauen()


func offen() -> bool:
	return not _stapel.is_empty()


func _unhandled_input(e: InputEvent) -> void:
	if not offen():
		if e.is_action_pressed("pause"):
			_oeffnen(_pause())
			get_viewport().set_input_as_handled()
		return
	if e.is_action_pressed("ui_cancel") or (e.is_action_pressed("pause") and _stapel.size() == 1):
		_zurueck()
		get_viewport().set_input_as_handled()


func _oeffnen(seite: Control) -> void:
	if _stapel.is_empty():
		get_tree().paused = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif _stapel[-1].visible:
		_stapel[-1].visible = false
	seite.theme = _thema
	add_child(seite)
	_stapel.append(seite)
	_fokus(seite)


func _zurueck() -> void:
	var oben: Control = _stapel.pop_back()
	oben.queue_free()
	if _stapel.is_empty():
		get_tree().paused = false
		if not Testlauf.ist_aktiv():
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		_stapel[-1].visible = true
		# Seiten, die sich beim Zurückkommen neu aufbauen (z. B. nach dem Umbenennen)
		if _stapel[-1].has_meta("neu"):
			var neu: Callable = _stapel[-1].get_meta("neu")
			var alt: Control = _stapel.pop_back()
			alt.queue_free()
			_oeffnen(neu.call())
			return
		_fokus(_stapel[-1])


func _fokus(seite: Control) -> void:
	await get_tree().process_frame
	if not is_instance_valid(seite):
		return
	for k in seite.find_children("*", "Button", true, false):
		if not (k as Button).disabled and k.is_visible_in_tree():
			(k as Button).grab_focus()
			return


# --- Seiten ---

func _pause() -> Control:
	var tag := himmel.tag if himmel else 1
	var seite := _seite("Pause", "Tag %d" % tag, Vector2(420, 0))
	var liste: VBoxContainer = seite.get_meta("inhalt")
	var auf_hof := siedlung != null and spieler != null and siedlung.auf_grundstueck(spieler.global_position)
	# Reihenfolge wie im 2D-Hoofy; „ab“: erst ab diesem Tag (game/fortschritt.lua)
	var eintraege := [
		["Weiter", func(): _zurueck(), true],
		["Pferde", func(): _oeffnen(_pferde()), true],
		["Inventar", null, true],
		["Bestellungen", null, tag >= 4],
		["Karte", null, true],
		["Bauen", null, auf_hof],
		["Zeitung", null, tag >= 10],
		["Album", null, true],
		["Tauschen", null, tag >= 9],
		["Speichern", func(): _speichern(), true],
	]
	for e in eintraege:
		if not e[2] and e[0] in ["Bestellungen", "Zeitung", "Tauschen"]:
			continue                       # noch nicht freigeschaltet: fehlt ganz
		var b := _knopf(e[0], e[1])
		if e[1] == null or not e[2]:
			b.disabled = true              # gibt es noch nicht: ausgegraut
		liste.add_child(b)
	return seite


func _speichern() -> void:
	Spiel.speichern(himmel)
	_zurueck()
	var anzeige := get_tree().get_first_node_in_group("anzeige")
	if anzeige:
		anzeige.meldung("Gespeichert.", 2.0)


func _pferde() -> Control:
	var seite := _seite("Pferde (%d)" % Spiel.herde.size(), "", Vector2(620, 0))
	var liste: VBoxContainer = seite.get_meta("inhalt")
	if Spiel.herde.is_empty():
		var l := _label("Noch keine Pferde.\nSuch ein Wildpferd und zähme es!", 20, BLASS)
		liste.add_child(l)
	for d in Spiel.herde:
		var b := _knopf("%s   ·   %s" % [d.name, HoofyDaten.rasse(d.rasse).name], func(): _oeffnen(_info(d)))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.icon = _farbfleck(d)
		liste.add_child(b)
	seite.set_meta("neu", func(): return _pferde())
	_fuss(seite, "A: Info   B: zurück")
	return seite


func _info(d: Dictionary) -> Control:
	var seite := _seite(d.name, "Wert %d G" % HoofyDaten.wert(d), Vector2(1100, 0))
	var inhalt: VBoxContainer = seite.get_meta("inhalt")
	seite.set_meta("neu", func(): return _info(d))
	var oben := HBoxContainer.new()
	oben.add_theme_constant_override("separation", 16)
	inhalt.add_child(oben)

	# Steckbrief
	var steck := _kasten()
	steck.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	oben.add_child(steck)
	var sv := VBoxContainer.new()
	steck.add_child(sv)
	var fohlen := float(d.get("alter", 1)) < 1.0
	var geschlecht := ("Hengstfohlen" if fohlen else "Hengst") if d.sex == "m" else ("Stutfohlen" if fohlen else "Stute")
	sv.add_child(_label("%s, %s" % [geschlecht, HoofyDaten.rasse(d.rasse).name], 20, TEXT))
	sv.add_child(_label("Farbe: " + HoofyDaten.farbe_name(d.farbe), 18, BLASS))   # die versteckte Farbe bleibt geheim
	sv.add_child(_label("Charakter: " + HoofyDaten.daten().charakter[d.zug].name, 18, BLASS))
	sv.add_child(_label("Ort: " + (ORT.get(d.get("ort", ""), "an der Leine")), 18, BLASS))
	var extra := ""
	if d.has("reit_ab") and int(d.bindung) < int(d.reit_ab):
		extra = "Frisch gezähmt: noch nicht reitbar"
	elif d.get("sattel"):
		for a in HoofyDaten.daten().ausruestung.liste:
			if a.id == d.sattel:
				extra = "Sattel: " + a.name
	if extra:
		sv.add_child(_label(extra, 18, BLASS))

	# Bild: das Pferd in 3D, dreht sich langsam
	oben.add_child(_vorschau(d))

	# Fähigkeiten und Zustand
	var werte := HBoxContainer.new()
	werte.add_theme_constant_override("separation", 16)
	inhalt.add_child(werte)
	var faeh := _kasten()
	faeh.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	werte.add_child(faeh)
	var fv := VBoxContainer.new()
	faeh.add_child(fv)
	fv.add_child(_label("Fähigkeiten", 20, GEN))
	for e in [["tempo", "Tempo"], ["staerke", "Stärke"], ["ausdauer", "Ausdauer"], ["spuer", "Spürsinn"]]:
		fv.add_child(_balkenzeile(e[1], Balken.faehigkeit(d, e[0])))
	var zust := _kasten()
	zust.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	werte.add_child(zust)
	var zv := VBoxContainer.new()
	zust.add_child(zv)
	zv.add_child(_label("Zustand", 20, ZUSTAND))
	zv.add_child(_balkenzeile("Bindung", Balken.zustand(d.bindung, 100, false)))
	zv.add_child(_balkenzeile("Hunger", Balken.zustand(d.hunger, 100, d.hunger > 60)))
	zv.add_child(_balkenzeile("Sauber", Balken.zustand(d.sauberkeit, 100, d.sauberkeit < 40)))
	var gewicht := Balken.zustand(d.gewicht, 100, false)
	gewicht.ideal = 50.0
	zv.add_child(_balkenzeile("Gewicht", gewicht))
	zv.add_child(_balkenzeile("Energie", Balken.zustand(d.energie, HoofyDaten.stat(d, "ausdauer"), false)))

	# A: umbenennen; ← →: blättern
	var umbenennen := _knopf("Umbenennen", func(): _oeffnen(_tastatur("Neuer Name", d.name, 12, func(text: String):
		d.name = text
		Spiel.namen.append(text))))
	inhalt.add_child(umbenennen)
	seite.set_meta("blaettern", func(schritt: int):
		var i := Spiel.herde.find(d)
		if i >= 0 and Spiel.herde.size() > 1:
			var n: Dictionary = Spiel.herde[(i + schritt + Spiel.herde.size()) % Spiel.herde.size()]
			var alt: Control = _stapel.pop_back()
			alt.queue_free()
			_oeffnen(_info(n)))
	_fuss(seite, "A umbenennen   ◀ ▶ blättern   B zurück")
	return seite


func _input(e: InputEvent) -> void:
	if offen() and _stapel[-1].has_meta("blaettern"):
		if e.is_action_pressed("ui_left") or e.is_action_pressed("ui_right"):
			_stapel[-1].get_meta("blaettern").call(-1 if e.is_action_pressed("ui_left") else 1)
			get_viewport().set_input_as_handled()


## Bildschirmtastatur (E7): Buchstabenreihen samt Umlauten, LÖSCHEN und FERTIG, höchstens max Zeichen
func _tastatur(titel: String, text: String, maximal: int, fertig: Callable) -> Control:
	var seite := _seite(titel, "", Vector2(760, 0))
	var inhalt: VBoxContainer = seite.get_meta("inhalt")
	var feld := _label(text + "_", 30, GOLD)
	feld.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inhalt.add_child(feld)
	var zaehler := _label("%d/%d" % [text.length(), maximal], 16, BLASS)
	zaehler.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	inhalt.add_child(zaehler)
	var stand := [text]
	var zeigen := func():
		feld.text = stand[0] + "_"
		zaehler.text = "%d/%d" % [stand[0].length(), maximal]
	var gitter := GridContainer.new()
	gitter.columns = 11
	gitter.add_theme_constant_override("h_separation", 6)
	gitter.add_theme_constant_override("v_separation", 6)
	inhalt.add_child(gitter)
	for reihe in TASTEN:
		for i in 11:
			var zeichen: String = reihe[i] if i < reihe.length() else ""
			var t := _knopf(zeichen if zeichen != " " else "␣", func():
				if stand[0].length() < maximal:
					stand[0] += zeichen
					zeigen.call())
			t.custom_minimum_size = Vector2(56, 48)
			if zeichen == "":
				t.disabled = true
				t.modulate.a = 0.0
			gitter.add_child(t)
	var unten := HBoxContainer.new()
	unten.alignment = BoxContainer.ALIGNMENT_CENTER
	unten.add_theme_constant_override("separation", 20)
	inhalt.add_child(unten)
	unten.add_child(_knopf("LÖSCHEN", func():
		stand[0] = stand[0].left(-1)
		zeigen.call()))
	unten.add_child(_knopf("FERTIG", func():
		_zurueck()
		if stand[0].strip_edges().length() > 0:
			fertig.call(stand[0].strip_edges())))
	_fuss(seite, "A: Taste   B: abbrechen")
	return seite


# --- Am eigenen Pferd (game/horse_menu.lua) ---

const FUTTER := ["heu", "hafer", "karotte", "premiumfutter"]
const ORT_NAME := {"stall": "Stall", "weide": "Weide", "frei": "Frei"}


func aktionsmenue(w: Wildpferde.WildPferd) -> void:
	if offen():
		return
	_oeffnen(_aktionen(w))


func _aktionen(w: Wildpferde.WildPferd) -> Control:
	var d := w.daten
	var seite := _seite(d.name, HoofyDaten.beschreibung(d), Vector2(520, 0))
	var liste: VBoxContainer = seite.get_meta("inhalt")
	liste.add_child(_knopf("Streicheln", func():
		var dazu := Pflege.streicheln(d)
		w.zeige("♥" if dazu > 0 else "z", Color(1.0, 0.35, 0.45) if dazu > 0 else BLASS, 2.0)
		_alle_zu()))
	liste.add_child(_knopf("Füttern", func(): _oeffnen(_futter(w))))
	var buerste := _knopf("Striegeln", func():
		Pflege.striegeln(d)
		w.zeige("✦", Color(0.7, 0.9, 1.0), 2.0)
		_alle_zu())
	buerste.disabled = int(Spiel.inv.get("buerste", 0)) < 1
	liste.add_child(buerste)
	var folgt := int(d.bindung) >= int(HoofyDaten.daten().stats.bindung.folgt)
	var leine := "Hierbleiben" if w.zustand == "folgt" else ("Leine lösen" if w.zustand == "gefuehrt" else ("Folgen lassen" if folgt else "Anleinen"))
	liste.add_child(_knopf(leine, func():
		if w.zustand in ["gefuehrt", "folgt"]:
			_sag(wildpferde.loslassen(w))
		elif wildpferde.anleinen(w):
			_sag("%s %s" % [d.name, "folgt dir." if w.zustand == "folgt" else "ist an der Leine."])
		else:
			_sag("Du führst schon zwei Pferde. Mehr passen nicht an die Leine.")
		_alle_zu()))
	liste.add_child(_knopf("Aufsitzen", func():
		_alle_zu()
		aufsitzen.emit(w)))
	var hof := siedlung.auf_grundstueck(spieler.global_position)
	var unter := _knopf("Unterbringen", func(): _oeffnen(_unterbringen(w)))
	unter.disabled = not hof
	liste.add_child(unter)
	liste.add_child(_knopf("Info", func(): _oeffnen(_info(d))))
	_fuss(seite, "A: wählen   B: zurück")
	return seite


func _futter(w: Wildpferde.WildPferd) -> Control:
	var seite := _seite("Füttern", w.daten.name, Vector2(560, 0))
	var liste: VBoxContainer = seite.get_meta("inhalt")
	for id in FUTTER:
		var f := Pflege.futter(id)
		var n := int(Spiel.inv.get(id, 0))
		var hunger: int = f.get("wirkung", {}).get("hunger", 0)
		var b := _knopf("%s: Hunger %s   (%d)" % [f.get("name", id), "±0" if hunger == 0 else str(hunger), n], func():
			Spiel.inv[id] = int(Spiel.inv[id]) - 1
			var dazu := Pflege.fuettern(w.daten, id)
			w.zeige("♥" if dazu > 0 else "●", Color(1.0, 0.35, 0.45) if dazu > 0 else Color(0.95, 0.6, 0.3), 2.0)
			# Menü bleibt offen (Rückmeldung 1.3.4), mit neuen Anzahlen
			var alt: Control = _stapel.pop_back()
			alt.queue_free()
			_oeffnen(_futter(w)))
		b.disabled = n < 1
		liste.add_child(b)
	_fuss(seite, "A: füttern   B: zurück")
	return seite


func _unterbringen(w: Wildpferde.WildPferd) -> Control:
	var d := w.daten
	var seite := _seite("Wohin mit %s?" % d.name, "", Vector2(520, 0))
	var liste: VBoxContainer = seite.get_meta("inhalt")
	for ort in ["stall", "weide", "frei"]:
		var n := wildpferde.belegt(ort)
		var platz := wildpferde.plaetze(ort)
		var b := _knopf("%s %d/%d" % [ORT_NAME[ort], n, platz], func():
			wildpferde.unterbringen(w, ort)
			_sag("%s kommt in: %s." % [d.name, ORT_NAME[ort]])
			_alle_zu())
		b.disabled = (n >= platz and d.get("ort") != ort) or d.get("ort") == ort or (ort == "frei" and not Pflege.darf_frei(d))
		liste.add_child(b)
	_fuss(seite, "Frei: nur mit Stärke 60 und Bindung 70")
	return seite


## Vor dem Stall: wer drin steht, lässt sich herausholen
func stall() -> void:
	if offen():
		return
	var seite := _seite("Stall", "%d/%d" % [wildpferde.belegt("stall"), wildpferde.plaetze("stall")], Vector2(520, 0))
	var liste: VBoxContainer = seite.get_meta("inhalt")
	var drin := Spiel.herde.filter(func(d): return d.get("ort") == "stall")
	if drin.is_empty():
		liste.add_child(_label("Der Stall ist leer.", 20, BLASS))
	for d in drin:
		liste.add_child(_knopf("%s herausholen" % d.name, func():
			var w := wildpferde.knoten_von(d)
			if w and wildpferde.anleinen(w):
				_sag("%s %s" % [d.name, "folgt dir." if w.zustand == "folgt" else "ist an der Leine."])
			else:
				_sag("Du führst schon zwei Pferde. %s bleibt im Stall." % d.name)
			_alle_zu()))
	_fuss(seite, "A: wählen   B: zurück")
	_oeffnen(seite)


func _alle_zu() -> void:
	while offen():
		_zurueck()


func _sag(text: String) -> void:
	var anzeige := get_tree().get_first_node_in_group("anzeige")
	if anzeige:
		anzeige.meldung(text, 2.5)


# --- Bausteine ---

func _seite(titel: String, daneben: String, groesse: Vector2) -> Control:
	var hinter := ColorRect.new()
	hinter.color = Color(0, 0, 0, 0.35)
	hinter.set_anchors_preset(Control.PRESET_FULL_RECT)
	var mitte := CenterContainer.new()
	mitte.set_anchors_preset(Control.PRESET_FULL_RECT)
	hinter.add_child(mitte)
	var rahmen := PanelContainer.new()
	rahmen.custom_minimum_size = groesse
	mitte.add_child(rahmen)
	var spalte := VBoxContainer.new()
	spalte.add_theme_constant_override("separation", 10)
	rahmen.add_child(spalte)
	var kopf := HBoxContainer.new()
	spalte.add_child(kopf)
	var t := _label(titel, 30, GOLD)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	kopf.add_child(t)
	if daneben:
		kopf.add_child(_label(daneben, 22, GOLD if daneben.begins_with("Wert") else BLASS))
	var inhalt := VBoxContainer.new()
	inhalt.add_theme_constant_override("separation", 8)
	spalte.add_child(inhalt)
	hinter.set_meta("inhalt", inhalt)
	hinter.set_meta("spalte", spalte)
	return hinter


func _fuss(seite: Control, text: String) -> void:
	var l := _label(text, 16, BLASS)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	(seite.get_meta("spalte") as VBoxContainer).add_child(l)


func _knopf(text: String, wenn) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 46)
	if wenn != null:
		b.pressed.connect(wenn)
	return b


func _label(text: String, groesse: int, farbe: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", groesse)
	l.add_theme_color_override("font_color", farbe)
	return l


func _kasten() -> PanelContainer:
	var k := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = KASTEN
	s.set_corner_radius_all(8)
	s.set_content_margin_all(14)
	k.add_theme_stylebox_override("panel", s)
	return k


func _balkenzeile(name: String, balken: Balken) -> HBoxContainer:
	var z := HBoxContainer.new()
	z.add_theme_constant_override("separation", 10)
	var l := _label(name, 18, TEXT)
	l.custom_minimum_size = Vector2(110, 0)
	z.add_child(l)
	balken.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	balken.custom_minimum_size = Vector2(220, 18)
	balken.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	z.add_child(balken)
	var zahl := _label(str(int(balken.wert)), 18, balken.zahl_farbe)
	zahl.custom_minimum_size = Vector2(44, 0)
	zahl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	z.add_child(zahl)
	return z


## Farbtupfer der Fellfarbe für die Pferdeliste
func _farbfleck(d: Dictionary) -> ImageTexture:
	var bild := Image.create_empty(24, 24, false, Image.FORMAT_RGBA8)
	var f: Dictionary = HoofyDaten.FELL.get(d.farbe, HoofyDaten.FELL.brauner)
	for y in 24:
		for x in 24:
			var r := Vector2(x - 11.5, y - 11.5).length()
			if r < 11.0:
				bild.set_pixel(x, y, f.fell if r < 9.0 else Color(0, 0, 0, 0.6))
	return ImageTexture.create_from_image(bild)


## Das Pferd in einem eigenen kleinen 3D-Bild
func _vorschau(d: Dictionary) -> SubViewportContainer:
	var box := SubViewportContainer.new()
	box.stretch = true
	box.custom_minimum_size = Vector2(380, 250)
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = false
	box.add_child(vp)
	var welt := Node3D.new()
	vp.add_child(welt)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.42, 0.58, 0.32)
	env.environment.ambient_light_color = Color(0.7, 0.72, 0.75)
	env.environment.ambient_light_energy = 0.6
	env.environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	welt.add_child(env)
	var licht := DirectionalLight3D.new()
	licht.rotation = Vector3(-0.8, 0.6, 0)
	licht.light_energy = 1.6
	welt.add_child(licht)
	var dreh := Node3D.new()
	welt.add_child(dreh)
	var modell := PferdModell.new(d)
	modell.ready.connect(func(): modell.animieren("stehen", 0.0))
	dreh.add_child(modell)
	var cam := Camera3D.new()
	cam.fov = 35.0
	welt.add_child(cam)
	cam.look_at_from_position(Vector3(4.6, 1.6, 0.4), Vector3(0, 0.95, 0))
	dreh.rotation.y = -0.5
	var t := create_tween().set_loops()
	t.tween_property(dreh, "rotation:y", -0.5 + TAU, 16.0).from(-0.5)
	return box


func _thema_bauen() -> void:
	var rahmen := StyleBoxFlat.new()
	rahmen.bg_color = GRUND
	rahmen.set_corner_radius_all(14)
	rahmen.set_content_margin_all(24)
	rahmen.border_color = Color(0.45, 0.35, 0.22)
	rahmen.set_border_width_all(2)
	_thema.set_stylebox("panel", "PanelContainer", rahmen)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.24, 0.19, 0.14)
	normal.set_corner_radius_all(8)
	normal.content_margin_left = 16
	normal.content_margin_right = 16
	var fokus := normal.duplicate()
	fokus.bg_color = Color(0.42, 0.32, 0.18)
	fokus.border_color = GOLD
	fokus.set_border_width_all(3)
	var aus := normal.duplicate()
	aus.bg_color = Color(0.18, 0.15, 0.12, 0.7)
	for art in ["normal", "pressed"]:
		_thema.set_stylebox(art, "Button", normal)
	_thema.set_stylebox("hover", "Button", fokus)
	_thema.set_stylebox("focus", "Button", fokus)
	_thema.set_stylebox("disabled", "Button", aus)
	_thema.set_font_size("font_size", "Button", 22)
	_thema.set_color("font_color", "Button", TEXT)
	_thema.set_color("font_focus_color", "Button", GOLD)
	_thema.set_color("font_hover_color", "Button", GOLD)
	_thema.set_color("font_disabled_color", "Button", Color(0.5, 0.45, 0.4))


## Balken wie in der Hoofy-Info: Fähigkeit = Gen (gold) + Training (grün) bis zum Max-Potenzial
## (roter Strich); Zustand = ein Balken, rot bei Warnung.
class Balken extends Control:
	var wert := 0.0
	var maximum := 100.0
	var gen := -1.0
	var potenzial := -1.0
	var warnung := false
	var ideal := -1.0
	var zahl_farbe := TEXT

	static func faehigkeit(d: Dictionary, key: String) -> Balken:
		var b := Balken.new()
		b.wert = HoofyDaten.stat(d, key)
		b.gen = minf(d.gen[key], b.wert)
		b.potenzial = d.pot[key]
		b.zahl_farbe = GEN
		return b

	static func zustand(v: float, m: float, warn: bool) -> Balken:
		var b := Balken.new()
		b.wert = v
		b.maximum = m
		b.warnung = warn
		b.zahl_farbe = ROT if warn else ZUSTAND
		return b

	func _draw() -> void:
		var w := size.x
		var h := size.y
		draw_rect(Rect2(0, 0, w, h), Color(0, 0, 0, 0.45))
		var x := func(v: float) -> float: return clampf(v / maximum, 0.0, 1.0) * w
		if gen >= 0.0:
			draw_rect(Rect2(0, 0, x.call(potenzial), h), Color(1, 1, 1, 0.08))
			draw_rect(Rect2(0, 3, x.call(gen), h - 6), GEN)
			draw_rect(Rect2(x.call(gen), 3, x.call(wert) - x.call(gen), h - 6), TRAINING)
			draw_rect(Rect2(x.call(potenzial) - 1.5, 0, 3, h), POTENZIAL)
		else:
			draw_rect(Rect2(0, 3, x.call(wert), h - 6), ROT if warnung else ZUSTAND)
		if ideal >= 0.0:
			draw_rect(Rect2(x.call(ideal) - 1, -2, 2, h + 4), TEXT)
