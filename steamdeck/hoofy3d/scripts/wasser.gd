class_name Wasser
extends MeshInstance3D
## Seefläche auf Höhe Gelaende.WASSER über der Mulde des Sees.

func _ready() -> void:
	var netz := PlaneMesh.new()
	netz.size = Vector2(260, 260)
	mesh = netz
	position = Vector3(Gelaende.SEE.x, Gelaende.WASSER, Gelaende.SEE.y)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/wasser.gdshader")
	for name in ["wellen_a", "wellen_b"]:
		var t := NoiseTexture2D.new()
		t.seamless = true
		t.as_normal_map = true
		t.bump_strength = 6.0 if name == "wellen_a" else 3.0
		t.width = 512
		t.height = 512
		t.generate_mipmaps = true
		t.noise = FastNoiseLite.new()
		t.noise.seed = 11 if name == "wellen_a" else 12
		t.noise.frequency = 0.02 if name == "wellen_a" else 0.04
		t.noise.fractal_octaves = 3
		mat.set_shader_parameter(name, t)
	material_override = mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
