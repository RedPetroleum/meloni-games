class_name Handel
## Pferdemarkt und Käufer wie im 2D-Hoofy (game/market.lua, game/buyers.lua, game/fortschritt.lua;
## KATALOG §6; E39, E40, E65).
## Markt: immer offen, 4 Pferde, alle 3 Tage neu (aus Seed und Zyklus), Preis = Wert × 1,5.
## Käufer: täglich einer im Dorf, jeder mit eigener Formel, Bedingungen, Sprüchen und Folgen.

const MARKT_PLAETZE := 4
const MARKT_ZYKLUS := 3
const MAX_HERDE := 24
const WELT_SAAT := 2040

const TYPEN := ["sammlerin", "reithof", "zuechter", "schlachter"]
const INFO := {
	"sammlerin": {"name": "Reiche Sammlerin", "kurz": "Sammlerin", "sie": true},
	"reithof": {"name": "Netter Reithof", "kurz": "Reithof"},
	"zuechter": {"name": "Züchter", "kurz": "Züchter"},
	"schlachter": {"name": "Schlachter", "kurz": "Schlachter"},
}

## Freischalten im Spielverlauf (fortschritt.lua): ab diesem Tag
const AB := {"bestellungen": 4, "kaeufer": 5, "turnier": 7, "sammlerin": 9, "tauschen": 9, "zeitung": 10, "hunde": 16}
const NEU_TEXT := {
	"bestellungen": "Neu: Kunden bestellen Pferde (Pause → Kunden).",
	"kaeufer": "Neu: Im Dorf wartet tagsüber ein Käufer mit ❗.",
	"turnier": "Neu: Der Turnierplatz im Dorf hat geöffnet.",
	"sammlerin": "Neu: Auch eine Sammlerin kommt jetzt ins Dorf. Tauschen im Pausenmenü.",
	"zeitung": "Neu: Die Zeitung erscheint (Pause → Zeitung).",
}

## {sie|er} bzw. {die Stute|der Hengst|das Fohlen}: Form passend zum Pferd
const SPRUECHE := {
	"sammlerin": {
		"selten": ["Diese Farbe! Die fehlt mir noch in der Sammlung.", "Ach, wie außergewöhnlich. {Die|Den} muss ich haben.", "Darling, dieses Fell ist ein Gedicht."],
		"schmutzig": ["Also bitte, {die Stute|der Hengst|das Fohlen} ist ja völlig verdreckt.", "So kann ich {sie|ihn} nicht mitnehmen. Striegeln Sie {sie|ihn} erst!"],
		"fohlen": ["Ein Fohlen! Wie süß. {Sie|Er} wächst ja noch.", "Hach, so klein. Und trotzdem mit Stammbaum?"],
		"hengst": ["Ein stattlicher Hengst. Er passt zu meinem Salon.", "Ein Hengst mit Haltung. Sehr schön."],
		"stute": ["Eine elegante Dame. Ich bin entzückt.", "Die Stute hat Stil. Gut, gut."],
		"normal": ["Nett. Nicht aufregend, aber nett.", "Hm, ich hatte mir etwas Bunteres vorgestellt."],
	},
	"reithof": {
		"zahm": ["Ach, {die|der} ist ja richtig zutraulich. Das ist genau das, was unsere Kinder brauchen.", "So ein braves Pferd! {Die|Den} nehmen wir."],
		"scheu": ["{Die|Der} ist ein bisschen scheu, oder? Na, wir haben Geduld.", "Ein bisschen {zickig|bockig}, aber wir kriegen das hin."],
		"fohlen": ["Ein Fohlen? Das können die Kinder gleich mit aufziehen.", "Noch klein, aber sehr lieb. Wir kümmern uns um {sie|ihn}."],
		"hengst": ["Ein Hengst? Na, wir haben einen Extra-Paddock.", "Hoffentlich ist er verträglich."],
		"stute": ["Eine nette Stute, sie passt zu unserer Herde.", "Die Mädels im Stall freuen sich schon."],
		"normal": ["Ordentliches Pferd, danke.", "Das nehmen wir gern für den Reitunterricht."],
	},
	"zuechter": {
		"schnell": ["Was für Beine! Mit der Geschwindigkeit gewinnt man Rennen.", "Schnell. Sehr schnell. {Die|Den} merke ich mir."],
		"stark": ["{Kräftige Stute|Kräftiger Hengst|Kräftiges Fohlen}. Die Linie lässt sich sehen.", "{Die|Der} hat Muskeln! Damit züchte ich Zugpferde."],
		"fohlen": ["Ein Fohlen mit Potenzial, das schaue ich mir an.", "Jung, aber gute Anlagen."],
		"hengst": ["Ein Hengst! Den brauche ich für meine Stuten.", "Endlich ein Deckhengst mit Qualität."],
		"stute": ["Eine Stute mit guten Werten. Nicht schlecht.", "Die bringt solide Fohlen."],
		"normal": ["Hm. Durchschnitt. Aber für die Zucht tut es das.", "Keine Wunder, aber verwertbar."],
	},
	"schlachter": {
		"dick": ["Ordentlich Substanz! So ein Gewicht sieht man selten.", "Schwer, schwer. Das lohnt sich."],
		"duenn": ["Da ist ja nichts dran. Mager, mager.", "{Die|Der} ist ja ein Hungerhaken."],
		"fohlen": ["Zu jung. Aber ich nehme es, wenn der Preis stimmt.", "Hm, klein. Naja, Kleinvieh macht auch Mist."],
		"hengst": ["Ein Hengst, sehr kräftig. Mein Metzger freut sich.", "Kräftig gebaut. Abgemacht."],
		"stute": ["Eine kräftige Stute. Ich nehme sie.", "Ordentlicher Körperbau, ja."],
		"normal": ["Ich sag mal: geht so.", "Ein bisschen Fleisch ist dran. Passt."],
	},
}
const REIHENFOLGE := {
	"sammlerin": ["schmutzig", "selten", "fohlen", "hengst", "stute"],
	"reithof": ["zahm", "scheu", "fohlen", "hengst", "stute"],
	"zuechter": ["fohlen", "schnell", "stark", "hengst", "stute"],
	"schlachter": ["dick", "duenn", "fohlen", "hengst", "stute"],
}


static func offen(was: String, tag: int) -> bool:
	return tag >= int(AB[was])


## Meldungen für das, was genau an diesem Tag neu dazukommt
static func neu_am(tag: int) -> Array:
	var aus := []
	for was in ["bestellungen", "kaeufer", "turnier", "sammlerin", "zeitung"]:
		if int(AB[was]) == tag:
			aus.append(NEU_TEXT[was])
	return aus


## Fester Zufall 0–1 aus ein paar Zahlen (wie U.hash)
static func zufall(a: int, b: int, c: int) -> float:
	return float(hash([a, b, c]) % 100000) / 100000.0


## Text passend zum Pferd: {sie|er} für Stute/Hengst, drittes Wort für Fohlen (H.gtext)
static func gtext(d: Dictionary, s: String) -> String:
	var m: bool = d.get("sex") == "m"
	var fohlen := float(d.get("alter", 1)) < 1.0
	var re := RegEx.create_from_string("\\{([^|}]*)\\|([^|}]*)\\|?([^}]*)\\}")
	var aus := s
	for treffer in re.search_all(s):
		var ersatz: String = treffer.get_string(2) if m else treffer.get_string(1)
		if fohlen and treffer.get_string(3) != "":
			ersatz = treffer.get_string(3)
		aus = aus.replace(treffer.get_string(0), ersatz)
	return aus


# --- Markt ---

static func markt_zyklus(tag: int) -> int:
	return int((tag - 1) / MARKT_ZYKLUS)


## Die Auswahl eines Zyklus, deterministisch aus Seed und Zyklus (bleibt nach dem Laden gleich)
static func markt_bestand(zyklus: int, max_gebiet: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = WELT_SAAT * 131 + zyklus * 7 + 5
	var pferde := []
	for i in MARKT_PLAETZE:
		var d := HoofyDaten.wildpferd(rng, rng.randi_range(1, max_gebiet), "", Spiel.namen)
		d.erase("wild")
		d.preis = HoofyDaten.kaufpreis(d)
		pferde.append(d)
	return {"zyklus": zyklus, "pferde": pferde}


## Sorgt dafür, dass der Markt zum Tag passt
static func markt(tag: int) -> Dictionary:
	var z := markt_zyklus(tag)
	if Spiel.markt.is_empty() or int(Spiel.markt.zyklus) != z:
		Spiel.markt = markt_bestand(z, Spiel.max_gebiet)
	return Spiel.markt


## Pferd i kaufen. Gibt die Daten oder einen Grund zurück ("Geld", "voll", "weg").
static func markt_kaufen(i: int):
	var liste: Array = Spiel.markt.get("pferde", [])
	if i >= liste.size():
		return "weg"
	if Spiel.herde.size() >= MAX_HERDE:
		return "voll"
	var d: Dictionary = liste[i]
	if Spiel.geld < int(d.preis):
		return "Geld"
	Spiel.geld -= int(d.preis)
	liste.remove_at(i)
	d.erase("preis")
	Spiel.namen.append(d.name)
	Spiel.herde.append(d)
	return d


# --- Käufer ---

## Der Käufer des Tages (deterministisch aus Seed und Tag), vor Tag 5 keiner, die Sammlerin ab Tag 9
static func besuch(tag: int) -> Dictionary:
	if not offen("kaeufer", tag):
		return {}
	var rng := RandomNumberGenerator.new()
	rng.seed = WELT_SAAT * 977 + tag * 13 + 3
	var typ: String = TYPEN[rng.randi_range(0, TYPEN.size() - 1)]
	if typ == "sammlerin" and not offen("sammlerin", tag):
		typ = TYPEN[rng.randi_range(1, TYPEN.size() - 1)]
	return {"typ": typ, "tag": tag, "verkauft": false}


static func laune(tag: int) -> float:
	var c: Dictionary = HoofyDaten.daten().wert.kaeufer.sammlerin
	return float(c.laune_min) + (float(c.laune_max) - float(c.laune_min)) * zufall(tag, 7, 31)


static func _stufe(d: Dictionary) -> int:
	for f in HoofyDaten.daten().farben.liste:
		if f.id == d.farbe:
			return int(f.stufe)
	return 1


## Preis, den der Käufer zahlt, oder der Grund als Text, warum er das Pferd nicht nimmt
static func angebot(typ: String, d: Dictionary, tag: int):
	var w: Dictionary = HoofyDaten.daten().wert.kaeufer
	match typ:
		"sammlerin":
			var c: Dictionary = w.sammlerin
			if int(d.sauberkeit) <= int(c.min_sauberkeit):
				return "zu schmutzig (über %d)" % c.min_sauberkeit
			if _stufe(d) < int(c.min_stufe):
				return "Farbe zu gewöhnlich"
			var neutral := HoofyDaten.wert_roh(d, float(HoofyDaten.rasse(d.rasse).bindung))
			return roundi(neutral * (1.0 + (HoofyDaten.farbfaktor(d) - 1.0) * float(c.farbe)) * laune(tag))
		"reithof":
			var c: Dictionary = w.reithof
			if int(d.bindung) <= int(c.min_bindung):
				return "zu wenig Bindung (über %d)" % c.min_bindung
			if int(d.sauberkeit) <= int(c.min_sauberkeit):
				return "zu schmutzig (über %d)" % c.min_sauberkeit
			if int(d.hunger) >= int(c.max_hunger):
				return "zu hungrig (Hunger unter %d)" % c.max_hunger
			return roundi(HoofyDaten.wert_roh(d) * (float(c.basis) + (float(d.bindung) - float(c.bindung_ab)) / float(c.teiler)))
		"zuechter":
			var c: Dictionary = w.zuechter
			if int(d.bindung) <= int(c.min_bindung):
				return "zu wenig Bindung (über %d)" % c.min_bindung
			if int(d.sauberkeit) <= int(c.min_sauberkeit):
				return "zu schmutzig (über %d)" % c.min_sauberkeit
			var geschlecht: float = c.hengst if d.sex == "m" else c.stute
			return roundi(HoofyDaten.wert_roh(d) * (1.0 + HoofyDaten.stammbaum(d) / 100.0) * geschlecht)
		"schlachter":
			var c: Dictionary = w.schlachter
			if int(d.gewicht) <= int(c.min_gewicht):
				return "zu leicht (über %d)" % c.min_gewicht
			var neutral := HoofyDaten.wert_roh(d, float(HoofyDaten.rasse(d.rasse).bindung))
			return roundi(neutral * (1.0 + (float(d.gewicht) - float(c.gewicht_basis)) / float(c.gewicht_teiler))
				* (float(c.staerke_basis) + HoofyDaten.stat(d, "staerke") / float(c.staerke_teiler)))
	return "unbekannter Käufer"


static func pronomen(typ: String, gross := false) -> String:
	var p := "sie" if INFO[typ].get("sie", false) else "er"
	return p.capitalize() if gross else p


## Bindungsänderung der übrigen Pferde nach einem Verkauf (Schlachter: −20)
static func folge(typ: String) -> int:
	return int(HoofyDaten.daten().wert.kaeufer.schlachter.bindung_andere) if typ == "schlachter" else 0


static func spruch(typ: String, d: Dictionary, tag: int) -> String:
	var pruefung := {
		"schmutzig": int(d.sauberkeit) < 70, "selten": _stufe(d) >= 3, "fohlen": float(d.get("alter", 1)) < 1.0,
		"hengst": d.sex == "m", "stute": d.sex == "w", "zahm": int(d.bindung) >= 60, "scheu": int(d.bindung) < 30,
		"schnell": HoofyDaten.stat(d, "tempo") >= 55, "stark": HoofyDaten.stat(d, "staerke") >= 55,
		"dick": int(d.gewicht) >= 60, "duenn": int(d.gewicht) <= 40,
	}
	var art := "normal"
	for c in REIHENFOLGE[typ]:
		if pruefung[c]:
			art = c
			break
	var liste: Array = SPRUECHE[typ][art]
	var i := int(zufall(d.name.length(), HoofyDaten.stat(d, "tempo") + HoofyDaten.stat(d, "staerke"), tag + 17) * liste.size())
	return gtext(d, liste[i])


## Verkauf: zahlt, Ausrüstung bleibt beim Spieler, Folgen für die übrigen Pferde.
## Gibt den Preis zurück (oder den Grund als Text).
static func verkaufen(typ: String, d: Dictionary, tag: int):
	var preis = angebot(typ, d, tag)
	if preis is String:
		return preis
	Spiel.herde.erase(d)
	Wirtschaft.abziehen(d)
	Spiel.geld += int(preis)
	var delta := folge(typ)
	for e in Spiel.herde:
		e.bindung = clampi(int(e.bindung) + delta, 0, 100)
	Spiel.kaeufer.verkauft = true
	return int(preis)
