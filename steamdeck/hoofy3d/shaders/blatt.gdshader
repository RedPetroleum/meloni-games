// Laub und Nadeln: Blattkarten mit Alpha-Schnitt, Wind, durchscheinendem Gegenlicht.
// Für Bäume und Büsche aus Baumbauer.gd (MultiMesh: jede Instanz schwingt etwas anders).
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

uniform sampler2D textur : source_color, filter_linear_mipmap_anisotropic;
uniform vec3 farbe : source_color = vec3(1.0);
uniform float wind = 1.0;

varying float zufall;

void vertex() {
	vec3 ursprung = MODEL_MATRIX[3].xyz;
	zufall = fract(sin(dot(ursprung.xz, vec2(12.9898, 78.233))) * 43758.5453);
	// Je höher und weiter außen, desto mehr Bewegung
	float h = max(VERTEX.y, 0.0);
	float boe = sin(TIME * 0.9 + ursprung.x * 0.05) * 0.5 + 0.5;
	float s = sin(TIME * 2.3 + zufall * 6.28 + VERTEX.x * 0.6 + VERTEX.z * 0.5);
	VERTEX.xz += vec2(s, cos(TIME * 1.9 + zufall * 5.0)) * 0.035 * h * wind * (0.5 + boe);
	VERTEX.y += s * 0.02 * h * wind;
}

void fragment() {
	vec4 t = texture(textur, UV);
	// In der Ferne mittelt die Mipmap Blätter und Lücken zu halbem Alpha: ohne Ausgleich
	// verschwände das Laub ganz. Je kleiner die Textur auf dem Bild, desto mehr Alpha.
	vec2 ableitung = max(abs(dFdx(UV)), abs(dFdy(UV))) * 512.0;
	float mip = max(log2(max(ableitung.x, ableitung.y)), 0.0);
	t.a *= 1.0 + mip * 0.45;
	if (t.a < 0.5) {
		discard;
	}
	vec3 c = t.rgb * farbe * mix(0.85, 1.15, zufall);
	ALBEDO = c;
	ROUGHNESS = 0.75;
	SPECULAR = 0.25;
	// Normalen zeigen von der Kronenmitte weg, auch auf Rückseiten: das gibt weiches Licht
	BACKLIGHT = c * 0.6;
}
