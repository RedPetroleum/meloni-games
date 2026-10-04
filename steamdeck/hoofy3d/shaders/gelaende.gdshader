// Gelände: flache Kacheln, Höhe aus der Höhentextur. Gras, Waldboden, Erde (Wege, Ufer) und
// Fels (Hänge) werden nach Maske, Höhe und Steilheit gemischt. Gegen sichtbare Kachelmuster
// wird jede Textur in zwei Maßstäben gelesen.
shader_type spatial;

uniform sampler2D hoehen : filter_linear, repeat_disable;
uniform sampler2D masken : filter_linear, repeat_disable;
uniform sampler2D wege : filter_linear, repeat_disable;
uniform sampler2D makro : filter_linear_mipmap, repeat_enable;
uniform float groesse = 1024.0;
uniform float punkte = 513.0;
uniform float raster = 2.0;

uniform sampler2D gras_diff : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D gras_nor : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D gras_arm : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D erde_diff : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D erde_nor : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D erde_arm : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D wald_diff : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D wald_nor : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D wald_arm : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D fels_diff : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D fels_nor : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D fels_arm : filter_linear_mipmap_anisotropic, repeat_enable;

varying vec3 welt;
varying vec3 welt_normale;

vec2 karte(vec2 xz) {
	// Texelmitten treffen: Punkt i liegt bei (i + 0.5) / punkte
	return (xz + groesse * 0.5) / raster / punkte + 0.5 / punkte;
}

float h_an(vec2 xz) {
	return textureLod(hoehen, karte(xz), 0.0).r;
}

void vertex() {
	vec2 xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
	VERTEX.y = h_an(xz);
	float l = h_an(xz - vec2(raster, 0.0));
	float r = h_an(xz + vec2(raster, 0.0));
	float d = h_an(xz - vec2(0.0, raster));
	float u = h_an(xz + vec2(0.0, raster));
	NORMAL = normalize(vec3(l - r, 2.0 * raster, d - u));
	TANGENT = normalize(vec3(1.0, 0.0, 0.0) - NORMAL * NORMAL.x);
	BINORMAL = normalize(cross(TANGENT, NORMAL));
	welt = vec3(xz.x, VERTEX.y, xz.y);
	welt_normale = NORMAL;
}

// Liest eine Bodenart in zwei Maßstäben; m mischt sie, damit sich nichts wiederholt
void boden(sampler2D diff, sampler2D nor, sampler2D arm, vec2 uv, float m,
		out vec3 c, out vec3 n, out vec3 a) {
	vec2 uv2 = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * uv * 0.37;
	c = mix(texture(diff, uv).rgb, texture(diff, uv2).rgb, m);
	n = mix(texture(nor, uv).rgb, texture(nor, uv2).rgb, m);
	a = mix(texture(arm, uv).rgb, texture(arm, uv2).rgb, m);
}

void fragment() {
	vec2 uv = welt.xz / 3.5;
	float m1 = texture(makro, welt.xz / 90.0).r;
	float m2 = texture(makro, welt.xz / 23.0).r;
	float m = smoothstep(0.3, 0.7, m1);

	vec3 gc, gn, ga, ec, en, ea, wc, wn, wa, fc, fn, fa;
	boden(gras_diff, gras_nor, gras_arm, uv, m, gc, gn, ga);
	boden(erde_diff, erde_nor, erde_arm, uv * 1.3, m, ec, en, ea);
	boden(wald_diff, wald_nor, wald_arm, uv * 1.1, m, wc, wn, wa);
	boden(fels_diff, fels_nor, fels_arm, uv * 0.5, m, fc, fn, fa);

	// Wiese mit leichten Farbwolken (trockener/satter)
	gc = mix(gc * vec3(0.75, 0.95, 0.55), vec3(0.17, 0.24, 0.07), 0.35) * mix(0.9, 1.1, m2);

	vec2 kuv = karte(welt.xz);
	vec4 mk = texture(masken, kuv);
	float steil = 1.0 - welt_normale.y;
	float w_wald = smoothstep(0.2, 0.6, mk.g + (m2 - 0.5) * 0.4);
	float w_weg = smoothstep(0.35, 0.75, texture(wege, (welt.xz + groesse * 0.5) / groesse).r + (m2 - 0.5) * 0.5);
	float w_ufer = smoothstep(1.4, 0.4, welt.y + (m2 - 0.5) * 0.8);
	float w_fels = smoothstep(0.22, 0.36, steil + (m1 - 0.5) * 0.12);
	// oben in den Bergen mehr Fels, auch auf flacheren Stellen
	w_fels = max(w_fels, smoothstep(70.0, 110.0, welt.y + m1 * 25.0));

	vec3 c = gc; vec3 n = gn; vec3 a = ga;
	c = mix(c, wc, w_wald); n = mix(n, wn, w_wald); a = mix(a, wa, w_wald);
	float w_erde = max(w_weg, w_ufer);
	c = mix(c, ec, w_erde); n = mix(n, en, w_erde); a = mix(a, ea, w_erde);
	c = mix(c, fc, w_fels); n = mix(n, fn, w_fels); a = mix(a, fa, w_fels);
	// Unter Wasser dunkel und nass
	float nass = smoothstep(0.3, -0.5, welt.y);
	c *= mix(1.0, 0.55, nass);

	ALBEDO = c;
	NORMAL_MAP = n;
	NORMAL_MAP_DEPTH = 1.2;
	AO = a.r;
	AO_LIGHT_AFFECT = 0.4;
	ROUGHNESS = mix(a.g, 0.25, nass);
	METALLIC = 0.0;
	SPECULAR = 0.35;
}
