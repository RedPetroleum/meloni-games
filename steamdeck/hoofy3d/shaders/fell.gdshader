// Pferdefell: Grundfarbe, dunkle Beine, Muster (Schecke, Tupfen, Streifen, Äpfel, Stichel,
// Regenbogen) im Modellraum, damit es ohne UVs und für jedes Pferdemodell funktioniert.
shader_type spatial;

uniform vec3 fell : source_color = vec3(0.33, 0.17, 0.08);
uniform vec3 beine : source_color = vec3(0.33, 0.17, 0.08);
uniform vec3 abzeichen : source_color = vec3(0.92, 0.9, 0.86);
uniform int muster = 0;          // HoofyDaten.Muster
uniform float glanz = 0.0;       // 1 = metallisch (Gold)
uniform float tupfen = 0.08;     // Tupfengröße in Metern
uniform float einheit = 1.0;     // Modelleinheiten → Meter
uniform float boden = 0.0;       // Huf-Höhe in Modelleinheiten
uniform float hoehe = 1.0;       // Gesamthöhe in Modelleinheiten
uniform float saat = 0.0;        // jedes Pferd ein eigenes Muster
uniform float schmutz = 0.0;     // Hoofy-Sauberkeit: 0 sauber, 1 schlammig
uniform bool flache_normalen = false; // Modell ohne Normalen: aus der Geometrie berechnen

varying vec3 p_m;    // Position in Metern
varying float h01;   // 0 = Huf, 1 = Ohren

vec3 hash3(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.xxy + p.yxx) * p.zyx);
}

float rauschen(vec3 p) {
	vec3 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash3(i).x, hash3(i + vec3(1,0,0)).x, f.x),
	               mix(hash3(i + vec3(0,1,0)).x, hash3(i + vec3(1,1,0)).x, f.x), f.y),
	           mix(mix(hash3(i + vec3(0,0,1)).x, hash3(i + vec3(1,0,1)).x, f.x),
	               mix(hash3(i + vec3(0,1,1)).x, hash3(i + vec3(1,1,1)).x, f.x), f.y), f.z);
}

float fbm(vec3 p) {
	return rauschen(p) * 0.55 + rauschen(p * 2.1) * 0.3 + rauschen(p * 4.3) * 0.15;
}

// Abstand zum nächsten Zellpunkt (Worley) für Tupfen und Äpfel
float zellen(vec3 p) {
	vec3 i = floor(p), f = fract(p);
	float d = 9.0;
	for (int x = -1; x <= 1; x++) for (int y = -1; y <= 1; y++) for (int z = -1; z <= 1; z++) {
		vec3 o = vec3(float(x), float(y), float(z));
		d = min(d, length(o + hash3(i + o) - f));
	}
	return d;
}

void vertex() {
	p_m = VERTEX * einheit + vec3(saat * 7.31, 0.0, saat * 3.17);
	h01 = (VERTEX.y - boden) / hoehe;
}

void fragment() {
	if (flache_normalen) {
		NORMAL = normalize(cross(dFdy(VERTEX), dFdx(VERTEX)));
	}
	vec3 c = fell;
	// Fell ist nie ganz einfarbig: leichte Wolken, Bauch etwas heller, Rücken dunkler
	c *= 0.9 + 0.2 * fbm(p_m * 2.5);
	c *= mix(1.08, 0.94, smoothstep(0.35, 0.7, h01));
	// Beine unten dunkel (Braune, Falben) bzw. Beinfarbe
	c = mix(beine, c, smoothstep(0.17, 0.27, h01 + (fbm(p_m * 6.0) - 0.5) * 0.04));

	float m = 0.0;
	if (muster == 1) {        // Schecke: große weiße Platten
		m = smoothstep(0.52, 0.56, fbm(p_m * 1.1) + (0.3 - h01) * 0.35);
		c = mix(c, abzeichen, m);
	} else if (muster == 2) { // Tupfen
		m = 1.0 - smoothstep(0.35, 0.45, zellen(p_m / tupfen));
		c = mix(c, abzeichen, m);
	} else if (muster == 3) { // Zebrastreifen, mit Rauschen verbogen
		float s = sin((p_m.z + (fbm(p_m * 1.7) - 0.5) * 0.6) * 22.0);
		m = smoothstep(0.1, 0.25, s);
		c = mix(c, abzeichen, m);
	} else if (muster == 4) { // Äpfel: helle Ringe auf dunklerem Grund
		m = smoothstep(0.25, 0.55, zellen(p_m * 9.0));
		c = mix(abzeichen, c, m);
	} else if (muster == 5) { // Stichelhaar: feine weiße Haare
		m = step(0.55, rauschen(p_m * 140.0));
		c = mix(c, abzeichen, m * 0.6);
	} else if (muster == 6) { // Regenbogen
		float t = p_m.z * 0.8 + h01 * 0.6;
		c = 0.55 + 0.45 * cos(6.2831 * (t + vec3(0.0, 0.33, 0.67)));
	}

	// Schlamm von unten nach oben
	float dreck = schmutz * smoothstep(0.55, 0.1, h01 + (fbm(p_m * 3.0) - 0.5) * 0.3);
	c = mix(c, vec3(0.16, 0.11, 0.07), dreck);

	ALBEDO = c;
	ROUGHNESS = mix(mix(0.5, 0.25, glanz), 0.95, dreck);
	METALLIC = glanz * 0.6;
	SPECULAR = 0.35;
	// Kurzes Fell streut Licht an den Kanten (Fake-Sheen)
	float rand = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = c * rand * 0.06;
	BACKLIGHT = c * 0.08;
}
