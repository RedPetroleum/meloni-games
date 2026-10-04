// See: Farbe nach Wassertiefe (aus dem Tiefenpuffer), Wellen aus zwei wandernden
// Rauschtexturen, Lichtbrechung über das Bild darunter, Spiegelung über Fresnel.
shader_type spatial;
render_mode cull_disabled, depth_draw_always;

uniform sampler2D tiefe_tex : hint_depth_texture, filter_linear;
uniform sampler2D bild_tex : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D wellen_a : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D wellen_b : hint_normal, filter_linear_mipmap, repeat_enable;
uniform vec3 flach : source_color = vec3(0.16, 0.26, 0.22);
uniform vec3 tief : source_color = vec3(0.02, 0.06, 0.08);
uniform float klarheit = 2.2;     // Meter, bis das Wasser undurchsichtig ist
uniform bool fluss = false;       // Wellen strömen entlang UV.y (Fließrichtung)

varying vec3 welt;

void vertex() {
	welt = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv1 = welt.xz / 9.0 + TIME * vec2(0.012, 0.008);
	vec2 uv2 = welt.xz / 3.7 - TIME * vec2(0.01, -0.014);
	if (fluss) {
		uv1 = vec2(UV.x * 1.2, UV.y * 1.3 - TIME * 0.09);
		uv2 = vec2(UV.x * 2.6 + 0.3, UV.y * 3.0 - TIME * 0.16);
	}
	vec3 n = normalize(mix(texture(wellen_a, uv1).rgb, texture(wellen_b, uv2).rgb, 0.5) * 2.0 - 1.0);
	NORMAL_MAP = vec3(n.xy * 0.5 + 0.5, 1.0);
	NORMAL_MAP_DEPTH = 0.5;

	// Wassertiefe: Abstand zwischen Wasseroberfläche und dem Boden dahinter
	float tiefe_roh = texture(tiefe_tex, SCREEN_UV).r;
	vec4 boden = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, tiefe_roh, 1.0);
	boden.xyz /= boden.w;
	float dicke = clamp((VERTEX.z - boden.z) / klarheit, 0.0, 1.0);

	vec2 versatz = n.xy * 0.02 * dicke;
	vec3 darunter = textureLod(bild_tex, SCREEN_UV + versatz, 0.0).rgb;
	vec3 farbe = mix(flach, tief, dicke);
	ALBEDO = vec3(0.0);
	EMISSION = mix(darunter * flach * 3.0, farbe * 0.25, smoothstep(0.0, 0.8, dicke));
	ROUGHNESS = 0.04;
	METALLIC = 0.0;
	SPECULAR = 0.6;
	// Uferkante weich auslaufen lassen
	ALPHA = smoothstep(0.0, 0.08, dicke);
}
