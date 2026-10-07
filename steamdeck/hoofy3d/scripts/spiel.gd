extends Node
## Spielstand wie im 2D-Hoofy (ctx.herd, ctx.money, Namen; E35): Geld, eigene Pferde, vergebene
## Namen, Tag und Uhrzeit. Gespeichert wird über das Pausenmenü (später auch beim Schlafen und
## Beenden). Nicht gespeichert: Wildpferde (werden aus dem Seed neu gewürfelt), Sprechblasen.

const DATEI := "user://hoofy3d.json"
const VERSION := 1

var geld := 300                    # Startgeld (KATALOG §15)
var herde: Array = []              # Daten der eigenen Pferde (Felder wie H.wild)
var namen: Array = []              # jemals vergebene Namen (H.claim_name)
var inv := {"heu": 3, "karotte": 2, "hafer": 0, "premiumfutter": 0, "buerste": 0}   # Start (stage.lua, E70)
var markt := {}                   # {zyklus, pferde} (E39), wird mitgespeichert
var kaeufer := {}                 # Käufer des Tages {typ, tag, verkauft} (E40)
var max_gebiet := 1               # weitestes erreichbares Gebiet (Fahrzeug)
var tag := 1
var uhrzeit := 7.0
var geladen := false


func hat_spielstand() -> bool:
	return FileAccess.file_exists(DATEI)


func speichern(himmel: Himmel) -> void:
	if Testlauf.ist_aktiv() and not Testlauf.optionen.has("speichern"):
		return                     # Test-Szenarien speichern nie (E35)
	tag = himmel.tag
	uhrzeit = himmel.uhrzeit
	var stand := {"version": VERSION, "geld": geld, "herde": herde, "namen": namen, "inv": inv, "tag": tag, "uhrzeit": uhrzeit,
		"markt": markt, "kaeufer": kaeufer, "max_gebiet": max_gebiet}
	var f := FileAccess.open(DATEI, FileAccess.WRITE)
	f.store_string(JSON.stringify(stand, " "))


func laden() -> bool:
	if not hat_spielstand():
		return false
	var stand = JSON.parse_string(FileAccess.get_file_as_string(DATEI))
	if typeof(stand) != TYPE_DICTIONARY:
		return false
	geld = int(stand.get("geld", 300))
	herde = stand.get("herde", [])
	namen = stand.get("namen", [])
	for k in stand.get("inv", {}):
		inv[k] = int(stand.inv[k])
	tag = int(stand.get("tag", 1))
	markt = stand.get("markt", {})
	kaeufer = stand.get("kaeufer", {})
	max_gebiet = int(stand.get("max_gebiet", 1))
	uhrzeit = float(stand.get("uhrzeit", 7.0))
	# JSON kennt nur Gleitkommazahlen: ganze Werte wieder zu int
	for d in herde:
		for k in d:
			if d[k] is float and d[k] == floorf(d[k]):
				d[k] = int(d[k])
		for gruppe in ["gen", "train", "pot"]:
			for k in d[gruppe]:
				d[gruppe][k] = int(d[gruppe][k])
	geladen = true
	return true
