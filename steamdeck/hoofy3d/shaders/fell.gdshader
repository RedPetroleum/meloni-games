// Pferdefell: Grundfarbe, dunkle Beine, Muster (Schecke, Tupfen, Streifen, Äpfel, Stichel,
// Regenbogen). Muster entstehen aus der Ruheposition (CUSTOM0, siehe PferdModell), damit sie
// beim Laufen am Fell kleben. Hat das Modell Texturen, kommen Feinheiten (Haarstruktur, Muskeln)
// aus dessen Farbtextur (nur die Helligkeitsdetails, nicht die Farbe) und Normal Map.
shader_type spatial;

uniform vec3 fell : source_color = vec3(0.33, 0.17, 0.08);
uniform vec3 beine : source_color = vec3(0.33, 0.17, 0.08);
uniform vec3 abzeichen : source_color = vec3(0.92, 0.9, 0.86);
uniform int muster = 0;          // HoofyDaten.Muster
uniform float glanz = 0.0;       // 1 = metallisch (Gold)
uniform float tupfen = 0.08;     // Tupfengröße in Metern
uniform mat3 ruhe = mat3(1.0);   // nur ohne CUSTOM0: Drehung Modellraum → aufrecht
uniform float einheit = 1.0;     // Modelleinheiten → Meter
uniform vec3 zentrum;            // Körpermitte am Boden (aufrecht, Modelleinheiten)
uniform float hoehe = 1.0;       // Widerristhöhe über dem Huf (Modelleinheiten)
uniform float laenge = 1.0;      // halbe Länge Kopf–Schweif (Modelleinheiten)
uniform bool hat_textur = false;
uniform sampler2D detail : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D normalen : hint_normal, filter_linear_mipmap_anisotropic;
uniform float saat = 0.0;        // jedes Pferd ein eigenes Muster
uniform float schmutz = 0.0;     // Hoofy-Sauberkeit: 0 sauber, 1 schlammig
uniform bool flache_normalen = false; // Modell ohne Normalen: aus der Geometrie berechnen

varying vec3 p_m;    // Position in Metern, je Pferd verschoben (für Rauschen)
varying vec3 k;      // Körperkoordinaten: x quer, y 0 = Huf … 1 = Widerrist, z -1 = Kopf … 1 = Schweif
varying float h01;

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
	// Aufrechte Ruheposition aus CUSTOM0 (fehlt das Attribut, ist es 0: dann VERTEX drehen)
	vec3 aufrecht = length(CUSTOM0.xyz) > 0.0 ? CUSTOM0.xyz : ruhe * VERTEX;
	vec3 rel = aufrecht - zentrum;
	k = vec3(rel.x / laenge, rel.y / hoehe, rel.z / laenge);
	h01 = k.y;
	p_m = rel * einheit + vec3(saat * 7.31, 0.0, saat * 3.17);
}

void fragment() {
	if (flache_normalen) {
		NORMAL = normalize(cross(dFdy(VERTEX), dFdx(VERTEX)));
	}
	vec3 c = fell;
	// Fell ist nie ganz einfarbig: leichte Wolken, Bauch etwas heller, Rücken dunkler
	c *= 0.9 + 0.2 * fbm(p_m * 2.5);
	c *= mix(1.06, 0.96, smoothstep(0.55, 1.0, h01));
	// Beine unten dunkel (Braune, Falben) bzw. Beinfarbe; h01 = 1 am Widerrist
	c = mix(beine, c, smoothstep(0.24, 0.36, h01 + (fbm(p_m * 6.0) - 0.5) * 0.05));

	float m = 0.0;
	if (muster == 1) {        // Schecke: große weiße Platten
		m = smoothstep(0.52, 0.56, fbm(p_m * 1.1) + (0.3 - h01) * 0.35);
		c = mix(c, abzeichen, m);
	} else if (muster == 2) { // Tupfen
		m = 1.0 - smoothstep(0.35, 0.45, zellen(p_m / tupfen));
		c = mix(c, abzeichen, m);
	} else if (muster == 3) { // Zebra: senkrecht an Hals und Rumpf, schräg auf der Kruppe,
		                          // Ringe an den Beinen, fein im Gesicht
		vec3 q = k * vec3(laenge, hoehe, laenge) * einheit;   // Meter, ohne Versatz
		float rumpf = q.z;
		float kruppe = q.z * 0.45 - q.y * 0.9;
		float bein = q.y * 1.3;
		float t_kruppe = smoothstep(0.35, 0.75, k.z) * smoothstep(0.35, 0.6, k.y);
		float t_bein = 1.0 - smoothstep(0.42, 0.56, k.y + max(k.z - 0.5, 0.0) * 0.2);
		float u = mix(mix(rumpf, kruppe, t_kruppe), bein, t_bein);
		float dichte = mix(46.0, 75.0, smoothstep(-0.75, -0.95, k.z)) * mix(1.0, 1.35, t_bein);
		float welle = (fbm(p_m * 2.2) - 0.5) * 2.4;
		float s = sin(u * dichte + welle);
		m = smoothstep(-0.12, 0.12, s);
		c = mix(abzeichen, c, m);
	} else if (muster == 4) { // Äpfel: helle Ringe auf dunklerem Grund
		m = smoothstep(0.25, 0.55, zellen(p_m * 9.0));
		c = mix(abzeichen, c, m);
	} else if (muster == 5) { // Stichelhaar (Rot-/Grauschimmel): weiße Haare fein eingemischt, am
		                          // Rumpf am dichtesten; Kopf und Beine bleiben in der Grundfarbe
		float rumpf = smoothstep(0.3, 0.5, k.y);
		float dichte = 0.36 * rumpf * (0.8 + 0.4 * fbm(p_m * 2.5));
		float haar = rauschen(p_m * 900.0) * 0.3;          // feines Flimmern, kein Fleckenmuster
		c = mix(c, abzeichen, clamp(dichte + (haar - 0.15) * rumpf, 0.0, 1.0));
	} else if (muster == 6) { // Regenbogen
		float t = p_m.z * 0.8 + h01 * 0.6;
		c = 0.55 + 0.45 * cos(6.2831 * (t + vec3(0.0, 0.33, 0.67)));
	}

	// Schlamm von unten nach oben
	float dreck = schmutz * smoothstep(0.55, 0.1, h01 + (fbm(p_m * 3.0) - 0.5) * 0.3);
	c = mix(c, vec3(0.16, 0.11, 0.07), dreck);

	if (hat_textur) {
		// Nur die Feinheiten der Originaltextur: Helligkeit im Verhältnis zu ihrer
		// verschwommenen Umgebung (die Flecken des Originals verschwinden so)
		float fein = dot(texture(detail, UV).rgb, vec3(0.3, 0.59, 0.11));
		float grob = dot(textureLod(detail, UV, 2.5).rgb, vec3(0.3, 0.59, 0.11));
		c *= clamp(fein / max(grob, 0.02), 0.85, 1.18);
		NORMAL_MAP = texture(normalen, UV).rgb;
		NORMAL_MAP_DEPTH = 1.0;
	}
	ALBEDO = c;
	ROUGHNESS = mix(mix(0.5, 0.25, glanz), 0.95, dreck);
	METALLIC = glanz * 0.6;
	SPECULAR = 0.35;
	// Kurzes Fell streut Licht an den Kanten (Fake-Sheen)
	float rand = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = c * rand * 0.06;
	BACKLIGHT = c * 0.08;
}
