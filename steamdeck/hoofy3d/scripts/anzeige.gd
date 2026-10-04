class_name Anzeige
extends CanvasLayer
## Bildschirmanzeige, zurückhaltend wie in Red Dead: unten links das Pferd (Name, Rasse, Farbe,
## Gangart, Energie), oben rechts die Uhrzeit, unten in der Mitte Hinweise. Schriftgrößen für
## den 7-Zoll-Bildschirm des Steam Decks.

var pferd: Pferd
var himmel: Himmel
var wildpferde: Wildpferde

var _name := Label.new()
var _info := Label.new()
var _gang := Label.new()
var _energie := ProgressBar.new()
var _uhr := Label.new()
var _hinweis := Label.new()
var _hilfe := Label.new()
var _leistung := Label.new()
var _hilfe_zeit := 14.0


func _ready() -> void:
	var kasten := PanelContainer.new()
	kasten.add_theme_stylebox_override("panel", _stil(Color(0, 0, 0, 0.35)))
	kasten.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 24)
	kasten.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var spalte := VBoxContainer.new()
	spalte.add_theme_constant_override("separation", 2)
	kasten.add_child(spalte)
	for l in [_name, _info, _gang]:
		spalte.add_child(l)
		_schrift(l, 19)
	_schrift(_name, 26)
	_info.modulate = Color(1, 1, 1, 0.8)
	_energie.custom_minimum_size = Vector2(260, 10)
	_energie.show_percentage = false
	_energie.add_theme_stylebox_override("background", _stil(Color(1, 1, 1, 0.15), 3))
	_energie.add_theme_stylebox_override("fill", _stil(Color(0.92, 0.85, 0.6, 0.9), 3))
	spalte.add_child(_energie)
	add_child(kasten)

	_schrift(_uhr, 22)
	_uhr.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 24)
	_uhr.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	add_child(_uhr)

	_schrift(_hinweis, 22)
	_hinweis.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hinweis.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 40)
	_hinweis.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hinweis.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(_hinweis)

	_schrift(_hilfe, 18)
	_hilfe.text = "Linker Stick / WASD: reiten\nA / Shift: antreiben (tippen = schneller)\nB / Strg: zügeln\nX / Leertaste: springen\nRechter Stick / Maus: Kamera"
	_hilfe.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT, Control.PRESET_MODE_MINSIZE, 24)
	add_child(_hilfe)

	_schrift(_leistung, 16)
	_leistung.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 24)
	_leistung.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_leistung.position.y += 40
	_leistung.visible = false
	add_child(_leistung)


func _process(delta: float) -> void:
	_name.text = pferd.daten.name
	_info.text = HoofyDaten.beschreibung(pferd.daten)
	_gang.text = pferd.gang_name() + ("  · erschöpft" if pferd.energie < 1.0 else "")
	_energie.max_value = pferd.energie_max
	_energie.value = pferd.energie
	_uhr.text = himmel.uhrzeit_text()

	var w := wildpferde.naechstes(pferd.global_position, 35.0) if wildpferde else null
	if w:
		var stufe := HoofyDaten.farbe_stufe(w.daten.farbe)
		_hinweis.text = "Wildpferd: %s%s" % [HoofyDaten.beschreibung(w.daten), "  (%s)" % stufe if stufe != "häufig" else ""]
	else:
		_hinweis.text = ""

	_hilfe_zeit -= delta
	_hilfe.modulate.a = clampf(_hilfe_zeit / 2.0, 0.0, 1.0)
	if Input.is_action_just_pressed("leistung"):
		_leistung.visible = not _leistung.visible
	if _leistung.visible:
		_leistung.text = "%d fps · %.1f Mio. Dreiecke · %d Draw Calls" % [Engine.get_frames_per_second(),
			Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1e6,
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)]


func _schrift(l: Label, groesse: int) -> void:
	l.add_theme_font_size_override("font_size", groesse)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 2)


func _stil(farbe: Color, rund := 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = farbe
	s.set_corner_radius_all(rund)
	s.set_content_margin_all(12 if rund > 5 else 0)
	return s
