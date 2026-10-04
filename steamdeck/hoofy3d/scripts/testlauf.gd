extends Node
## Automatischer Testlauf wie `make shot` bei den Konsolenspielen:
##
##   godot --path . -- --frames=600 --input="60-400:vor+antreiben" --shots=200,400 --zeit=17.5
##
## --input   Drehbuch FRAME[-FRAME]:AKTION[+AKTION],…  (60 Frames = 1 s, Aktionen aus Einstellungen)
## --shots   Screenshots nach diesen Frames, gespeichert in --out (Standard: ../../build/hoofy3d)
## --frames  danach beenden; gibt die mittlere Bildrate aus
## --zeit    Uhrzeit beim Start (Stunden)
## --pos     Startpunkt x,z
## --deck    Grafikstufe des Steam Decks erzwingen

var optionen := {}
var _drehbuch := []       # [von, bis, [aktionen]]
var _shots := []
var _ende := -1
var _gedrueckt := {}
var _fps_summe := 0.0
var _fps_n := 0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--") and "=" in arg:
			var teile := arg.substr(2).split("=", true, 1)
			optionen[teile[0]] = teile[1]
		elif arg.begins_with("--"):
			optionen[arg.substr(2)] = "1"
	if optionen.is_empty():
		set_physics_process(false)
		return
	# Messen ohne Bildschirmtakt, sonst klebt alles bei 60 fps
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	for teil: String in optionen.get("input", "").split(",", false):
		var zeit_aktion: PackedStringArray = teil.split(":")
		var bereich: PackedStringArray = zeit_aktion[0].split("-")
		_drehbuch.append([int(bereich[0]), int(bereich[-1]), zeit_aktion[1].split("+")])
	for s in optionen.get("shots", "").split(",", false):
		_shots.append(int(s))
	_ende = int(optionen.get("frames", "-1"))
	if _ende < 0 and _shots:
		_ende = _shots.max() + 1


func ist_aktiv() -> bool:
	return not optionen.is_empty()


func _physics_process(_delta: float) -> void:
	var f := Engine.get_physics_frames()
	var jetzt := {}
	for e in _drehbuch:
		if f >= e[0] and f <= e[1]:
			for a in e[2]:
				jetzt[a] = true
	# Jeden Frame drücken: verliert das Fenster den Fokus, lässt Godot alle Tasten los
	for a in jetzt:
		Input.action_press(a)
	for a in _gedrueckt:
		if not jetzt.has(a):
			Input.action_release(a)
	_gedrueckt = jetzt
	if f > 90:
		_fps_summe += Engine.get_frames_per_second()
		_fps_n += 1
	if f in _shots:
		_foto(f)
	if _ende >= 0 and f >= _ende:
		if _fps_n:
			print("Testlauf: %d Frames, im Mittel %.1f fps, %d Dreiecke, %d Draw Calls, %d MB Grafikspeicher" % [f, _fps_summe / _fps_n,
				Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
				Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
				Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576])
		get_tree().quit()


func _foto(f: int) -> void:
	await RenderingServer.frame_post_draw
	var ordner: String = optionen.get("out", ProjectSettings.globalize_path("res://").path_join("../../build/hoofy3d"))
	DirAccess.make_dir_recursive_absolute(ordner)
	var pfad := ordner.path_join("shot_%04d.png" % f)
	get_viewport().get_texture().get_image().save_png(pfad)
	print("Screenshot: ", pfad.simplify_path())
