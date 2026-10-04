// Grashalme um den Spieler: ein festes Gitter aus Büscheln (MultiMesh), das mit dem Pferd
// mitwandert. Höhe, Dichte und Farbe kommen aus den Gelände-Texturen, damit das Gras genau auf
// dem Boden steht und farblich zum Boden passt. Wind und Ausweichen vor dem Pferd im Shader.
shader_type spatial;
render_mode cull_disabled, skip_vertex_transform;

uniform sampler2D hoehen : filter_linear, repeat_disable;
uniform sampler2D masken : filter_linear, repeat_disable;
uniform sampler2D wege : filter_linear, repeat_disable;
uniform sampler2D gras_diff : source_color, filter_linear_mipmap, repeat_enable;
uniform float groesse = 1024.0;
uniform float punkte = 513.0;
uniform float raster = 2.0;
uniform float abstand = 0.4;      // Gitterabstand der Büschel
uniform float radius = 40.0;      // Sichtweite des Grases
uniform vec3 spieler;             // Pferd: Halme weichen aus

varying float spitze;
varying vec3 farbe;

vec2 karte(vec2 xz) { return (xz + groesse * 0.5) / raster / punkte + 0.5 / punkte; }
float h_an(vec2 xz) { return textureLod(hoehen, karte(xz), 0.0).r; }
vec2 hash2(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return fract(sin(p) * 43758.5453);
}

void vertex() {
	vec3 o = MODEL_MATRIX[3].xyz;
	vec2 zufall = hash2(floor(o.xz / abstand + 0.5));
	o.xz += (zufall - 0.5) * abstand * 1.6;
	o.y = h_an(o.xz);

	// Dichte: kein Gras auf Wegen, Fels, unter Wasser; im Wald nur wenig
	vec3 n = normalize(vec3(h_an(o.xz - vec2(raster, 0)) - h_an(o.xz + vec2(raster, 0)), 2.0 * raster,
		h_an(o.xz - vec2(0, raster)) - h_an(o.xz + vec2(0, raster))));
	vec4 mk = textureLod(masken, karte(o.xz), 0.0);
	float weg = textureLod(wege, (o.xz + groesse * 0.5) / groesse, 0.0).r;
	float dichte = (1.0 - smoothstep(0.2, 0.32, 1.0 - n.y)) * (1.0 - smoothstep(0.15, 0.5, weg))
		* smoothstep(0.2, 0.9, o.y) * mix(1.0, 0.3, mk.g);
	float d = length(o.xz - CAMERA_POSITION_WORLD.xz);
	float rand = 1.0 - smoothstep(radius * 0.55, radius, d);
	float hoehe = mix(0.22, 0.55, zufall.y) * mix(1.0, 1.4, mk.b) * step(zufall.x * 0.7 + 0.15, dichte) * rand;

	float winkel = zufall.x * 6.2831;
	vec3 v = VERTEX;
	spitze = v.y;
	v = vec3(v.x * cos(winkel) - v.z * sin(winkel), v.y * hoehe, v.x * sin(winkel) + v.z * cos(winkel));
	// Wind: große Böen und kleines Zittern, stärker an der Spitze
	float boe = sin(TIME * 1.3 + o.x * 0.12 + o.z * 0.08) * 0.5 + 0.5;
	vec2 wind = vec2(0.8, 0.4) * (boe * 0.25 + 0.05 * sin(TIME * 4.0 + zufall.y * 20.0));
	// Pferd drückt das Gras zur Seite
	vec2 weg_vom_pferd = o.xz - spieler.xz;
	float nah = 1.0 - smoothstep(0.4, 1.6, length(weg_vom_pferd));
	wind += normalize(weg_vom_pferd + 0.001) * nah * 0.9;
	v.xz += wind * spitze * spitze * hoehe;
	v.y -= length(wind) * spitze * spitze * hoehe * 0.3;

	vec3 welt = o + v;
	VERTEX = (VIEW_MATRIX * vec4(welt, 1.0)).xyz;
	// Normale zur Hälfte nach oben: Gras wirkt dann wie eine Fläche und nicht wie Striche
	NORMAL = normalize((VIEW_MATRIX * vec4(mix(n, vec3(cos(winkel), 0.0, sin(winkel)), 0.35), 0.0)).xyz);
	vec3 boden = textureLod(gras_diff, o.xz / 3.5, 3.0).rgb;
	vec3 gruen = mix(vec3(0.13, 0.22, 0.05), vec3(0.27, 0.32, 0.09), zufall.y);
	farbe = mix(gruen, boden * vec3(0.8, 1.0, 0.6), 0.35);
}

void fragment() {
	ALBEDO = farbe * mix(0.45, 1.15, spitze);
	ROUGHNESS = 0.85;
	SPECULAR = 0.2;
	BACKLIGHT = farbe * 0.35;
	AO = mix(0.35, 1.0, spitze);
	AO_LIGHT_AFFECT = 0.6;
}
