class_name Anzeige
extends CanvasLayer
## Bildschirmanzeige wie im 2D-Hoofy (E9, E82; game/world.lua draw_hud): oben eine schmale Leiste
## mit Sonne/Mond und Tagesbalken, Gebietsname in der Mitte, Geld rechts; unten nur beim Reiten die
## Energie des Pferdes (rot unter 15). Beginnt ein Tag, steht „Tag N“ 2,5 s groß in der Mitte.
## Schriftgrößen für den 7-Zoll-Bildschirm des Steam Decks.

const GOLD := Color(0.95, 0.8, 0.35)
const BLASS := Color(0.75, 0.72, 0.65)
const ROT := Color(0.9, 0.3, 0.25)

var pferd: Pferd                   # nur beim Reiten
var spieler: Node3D
var himmel: Himmel
var wildpferde: Wildpferde
var siedlung: Siedlung
var gebiet := "Heimattal"

var _symbol := Symbol.new()
var _tagesbalken := ProgressBar.new()
var _gebiet := Label.new()
var _geld := Label.new()
var _energie_kasten := HBoxContainer.new()
var _energie := ProgressBar.new()
var _tag := Label.new()
var _tag_zeit := 0.0
var _hilfe := Label.new()
var _hilfe_zeit := 14.0
var _leistung := Label.new()
var _meldung := Label.new()
var _meldung_zeit := 0.0
var _zaehmen := ProgressBar.new()


## Sonne oder Mond als kleines Symbol
class Symbol extends Control:
	var sonne := true

	func _draw() -> void:
		var m := size * 0.5
		if sonne:
			draw_circle(m, 7.0, GOLD)
			for i in 8:
				var r := Vector2.from_angle(TAU * i / 8.0)
				draw_line(m + r * 9.5, m + r * 12.0, GOLD, 2.0)
		else:
			draw_circle(m, 8.0, BLASS)
			draw_circle(m + Vector2(4, -3), 7.0, Color(0.12, 0.12, 0.16, 1))


func _ready() -> void:
	add_to_group("anzeige")
	var leiste := PanelContainer.new()
	leiste.add_theme_stylebox_override("panel", _stil(Color(0.08, 0.07, 0.06, 0.55), 0, Vector2(16, 6)))
	leiste.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	var zeile := HBoxContainer.new()
	zeile.add_theme_constant_override("separation", 10)
	leiste.add_child(zeile)
	_symbol.custom_minimum_size = Vector2(26, 26)
	zeile.add_child(_symbol)
	_tagesbalken.custom_minimum_size = Vector2(120, 8)
	_tagesbalken.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_tagesbalken.show_percentage = false
	_tagesbalken.max_value = 1.0
	_tagesbalken.add_theme_stylebox_override("background", _stil(Color(1, 1, 1, 0.15), 3))
	zeile.add_child(_tagesbalken)
	_gebiet.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_gebiet.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_schrift(_gebiet, 18, BLASS)
	zeile.add_child(_gebiet)
	_schrift(_geld, 20, GOLD)
	zeile.add_child(_geld)
	add_child(leiste)

	_energie_kasten.add_theme_constant_override("separation", 10)
	_energie_kasten.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 24)
	_energie_kasten.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_energie.custom_minimum_size = Vector2(220, 12)
	_energie.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_energie.show_percentage = false
	_energie.add_theme_stylebox_override("background", _stil(Color(0, 0, 0, 0.45), 3))
	_energie_kasten.add_child(_energie)
	var e_text := Label.new()
	e_text.text = "Energie"
	_schrift(e_text, 18, Color(1, 1, 1, 0.9))
	_energie_kasten.add_child(e_text)
	add_child(_energie_kasten)

	_schrift(_tag, 54, GOLD)
	_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tag.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_tag.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_tag.grow_vertical = Control.GROW_DIRECTION_BOTH
	_tag.position.y -= 80
	_tag.visible = false
	add_child(_tag)
	himmel.neuer_tag.connect(func(n: int) -> void:
		_tag.text = "Tag %d" % n
		_tag_zeit = 2.5)

	# Meldungen unten in der Mitte (Hoofy: Toast)
	_schrift(_meldung, 20, Color(1, 1, 1))
	_meldung.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_meldung.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_meldung.custom_minimum_size = Vector2(760, 0)
	_meldung.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 70)
	_meldung.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_meldung.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_meldung.add_theme_stylebox_override("normal", _stil(Color(0.08, 0.07, 0.06, 0.6), 8, Vector2(14, 8)))
	_meldung.visible = false
	add_child(_meldung)
	if wildpferde:
		wildpferde.meldung.connect(meldung)
	# Zähmen: Balken füllt sich, solange man die Taste hält und stillsteht
	_zaehmen.custom_minimum_size = Vector2(260, 14)
	_zaehmen.show_percentage = false
	_zaehmen.max_value = 1.0
	_zaehmen.add_theme_stylebox_override("background", _stil(Color(0, 0, 0, 0.5), 4))
	_zaehmen.add_theme_stylebox_override("fill", _stil(Color(1.0, 0.45, 0.55), 4))
	_zaehmen.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_zaehmen.position.y += 90
	_zaehmen.visible = false
	add_child(_zaehmen)

	_schrift(_hilfe, 18, Color(1, 1, 1, 0.95))
	_hilfe.text = "Linker Stick / WASD: laufen   ·   A / Shift halten: rennen\nB / Strg: schleichen   ·   X / Leertaste: springen\nY / E: Aktion (halten: Wildpferd zähmen)\nBeim Reiten: A antreiben, B zügeln, Y halten absteigen\nStart / Esc: Pause   ·   Rechter Stick / Maus: Kamera"
	_hilfe.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT, Control.PRESET_MODE_MINSIZE, 24)
	_hilfe.position.y += 44
	add_child(_hilfe)

	_schrift(_leistung, 16, Color(1, 1, 1, 0.9))
	_leistung.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 24)
	_leistung.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_leistung.position.y += 44
	_leistung.visible = false
	add_child(_leistung)


func _process(delta: float) -> void:
	var sonne := not himmel.ist_nacht()
	if _symbol.sonne != sonne:
		_symbol.sonne = sonne
		_symbol.queue_redraw()
	_tagesbalken.value = himmel.abschnitt()
	_tagesbalken.add_theme_stylebox_override("fill", _stil(GOLD if sonne else BLASS, 3))
	# Auf dem eigenen Grundstück steht „Dein Hof“ (wie im 2D-Hoofy)
	_gebiet.text = "Dein Hof" if siedlung and spieler and siedlung.auf_grundstueck(spieler.global_position) else gebiet
	_geld.text = "%d G" % Spiel.geld

	# Energie nur beim Reiten (später: nur wenn die Spielfigur im Sattel sitzt)
	_energie_kasten.visible = pferd != null
	if pferd:
		_energie.max_value = pferd.energie_max
		_energie.value = pferd.energie
		_energie.add_theme_stylebox_override("fill", _stil(ROT if pferd.energie < 15.0 else GOLD, 3))

	_meldung_zeit -= delta
	_meldung.visible = _meldung_zeit > 0.0
	if wildpferde:
		_zaehmen.visible = wildpferde.zaehmen != null
		_zaehmen.value = wildpferde.zaehm_fortschritt

	_tag_zeit -= delta
	_tag.visible = _tag_zeit > 0.0
	_tag.modulate.a = clampf(_tag_zeit / 0.5, 0.0, 1.0)

	_hilfe_zeit -= delta
	_hilfe.modulate.a = clampf(_hilfe_zeit / 2.0, 0.0, 1.0)
	if Input.is_action_just_pressed("leistung"):
		_leistung.visible = not _leistung.visible
	if _leistung.visible:
		_leistung.text = "%d fps · %.1f Mio. Dreiecke · %d Draw Calls" % [Engine.get_frames_per_second(),
			Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1e6,
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)]


var _schwarz: ColorRect


## Bild schwarz werden lassen (Schlafen) und wieder aufhellen
func abblenden() -> void:
	if _schwarz == null:
		_schwarz = ColorRect.new()
		_schwarz.color = Color(0, 0, 0, 0)
		_schwarz.set_anchors_preset(Control.PRESET_FULL_RECT)
		_schwarz.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_schwarz)
		move_child(_schwarz, 0)
	var t := create_tween()
	t.tween_property(_schwarz, "color:a", 1.0, 0.8)
	await t.finished


func aufblenden() -> void:
	await get_tree().create_timer(0.6).timeout
	var t := create_tween()
	t.tween_property(_schwarz, "color:a", 0.0, 1.0)
	await t.finished


func meldung(text: String, sekunden: float) -> void:
	_meldung.text = text
	_meldung_zeit = sekunden


func _schrift(l: Label, groesse: int, farbe: Color) -> void:
	l.add_theme_font_size_override("font_size", groesse)
	l.add_theme_color_override("font_color", farbe)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 2)


func _stil(farbe: Color, rund := 10, rand := Vector2.ZERO) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = farbe
	s.set_corner_radius_all(rund)
	s.content_margin_left = rand.x
	s.content_margin_right = rand.x
	s.content_margin_top = rand.y
	s.content_margin_bottom = rand.y
	return s
