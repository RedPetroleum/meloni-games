extends Node
## Tastenbelegung (Steam-Deck-Tasten und Tastatur/Maus) und Grafikstufe.
##
## Steam Deck / Gamepad        Tastatur/Maus
## linker Stick  Richtung      WASD
## rechter Stick Kamera        Maus
## A             Antreiben     Shift (tippen = schneller, halten = Tempo halten)
## B             Zügeln        Strg
## X             Springen      Leertaste
## Y             Interagieren  E
## L3            Kamera hinter das Pferd   Mittlere Maustaste
## Start         Pause/Menü    Esc

enum Stufe { DECK, HOCH }

var stufe := Stufe.HOCH
var ist_deck := false

## Je Aktion: ["t", Taste], ["k", Gamepad-Knopf], ["a", Achse, Richtung], ["m", Maustaste]
const BELEGUNG := {
	"links": [["t", KEY_A], ["a", JOY_AXIS_LEFT_X, -1.0]],
	"rechts": [["t", KEY_D], ["a", JOY_AXIS_LEFT_X, 1.0]],
	"vor": [["t", KEY_W], ["a", JOY_AXIS_LEFT_Y, -1.0]],
	"zurueck": [["t", KEY_S], ["a", JOY_AXIS_LEFT_Y, 1.0]],
	"kamera_links": [["a", JOY_AXIS_RIGHT_X, -1.0]],
	"kamera_rechts": [["a", JOY_AXIS_RIGHT_X, 1.0]],
	"kamera_hoch": [["a", JOY_AXIS_RIGHT_Y, -1.0]],
	"kamera_runter": [["a", JOY_AXIS_RIGHT_Y, 1.0]],
	"antreiben": [["t", KEY_SHIFT], ["k", JOY_BUTTON_A]],
	"zuegeln": [["t", KEY_CTRL], ["k", JOY_BUTTON_B]],
	"springen": [["t", KEY_SPACE], ["k", JOY_BUTTON_X]],
	"interagieren": [["t", KEY_E], ["k", JOY_BUTTON_Y]],
	"kamera_zentrieren": [["m", MOUSE_BUTTON_MIDDLE], ["k", JOY_BUTTON_LEFT_STICK]],
	"pause": [["t", KEY_ESCAPE], ["k", JOY_BUTTON_START]],
	"leistung": [["t", KEY_F3]],
}


func _ready() -> void:
	for aktion in BELEGUNG:
		if not InputMap.has_action(aktion):
			InputMap.add_action(aktion, 0.2)
		for e in BELEGUNG[aktion]:
			InputMap.action_add_event(aktion, _ereignis(e))
	# Das Steam Deck setzt SteamDeck=1, im Desktop-Modus hilft die Bildschirmgröße
	ist_deck = OS.get_environment("SteamDeck") == "1" or (OS.get_name() == "Linux" and DisplayServer.screen_get_size() == Vector2i(1280, 800))
	stufe = Stufe.DECK if ist_deck or "--deck" in OS.get_cmdline_user_args() else Stufe.HOCH


func _ereignis(e: Array) -> InputEvent:
	match e[0]:
		"a":
			var a := InputEventJoypadMotion.new()
			a.axis = e[1]
			a.axis_value = e[2]
			return a
		"k":
			var k := InputEventJoypadButton.new()
			k.button_index = e[1]
			return k
		"m":
			var m := InputEventMouseButton.new()
			m.button_index = e[1]
			return m
	var t := InputEventKey.new()
	t.physical_keycode = e[1]
	return t


## Grafik an das Gerät anpassen. Das Steam Deck schafft 30–40 fps mit FSR und ohne
## Volumennebel; am PC alles an.
func anwenden(vp: Viewport, env: Environment, sonne: DirectionalLight3D) -> void:
	if stufe == Stufe.DECK:
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR
		vp.scaling_3d_scale = 0.77
		vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
		env.volumetric_fog_enabled = false
		env.ssao_enabled = true
		env.ssao_detail = 0.5
		env.ssil_enabled = false
		sonne.directional_shadow_max_distance = 110.0
		RenderingServer.directional_shadow_atlas_set_size(2048, true)
		Engine.max_fps = 40 if not Testlauf.ist_aktiv() else 0
	else:
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
		vp.scaling_3d_scale = 1.0
		vp.use_taa = true
		env.volumetric_fog_enabled = true
		env.ssil_enabled = true
