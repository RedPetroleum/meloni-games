class_name Jobs
## Jobs wie game/jobs.lua im 2D-Hoofy (KATALOG §12; E42): Postritt, Kutschtaxi, Pflügen. Ein Job
## pro Pferd und Tag (job_tag), jeden Job einmal am Tag (Spiel.jobs[id] = Tag). Gearbeitet wird im
## Minispiel (Jobspiel); das Ergebnis bestimmt den Lohn (40 % gibt es immer).

const STAT_NAMEN := {"bindung": "Bindung", "staerke": "Stärke", "tempo": "Tempo", "ausdauer": "Ausdauer", "spuer": "Aufspürung"}
const LOHN_SOCKEL := 0.4


static func liste() -> Array:
	return HoofyDaten.daten().jobs.liste


static func _wert(d: Dictionary, key: String) -> float:
	return float(d.bindung) if key == "bindung" else float(HoofyDaten.stat(d, key))


static func erledigt(job: Dictionary, tag: int) -> bool:
	return int(Spiel.jobs.get(job.id, -1)) == tag


## Darf Pferd d heute diesen Job machen? Gibt "" oder den Grund zurück.
static func geeignet(d: Dictionary, job: Dictionary, tag: int) -> String:
	if erledigt(job, tag):
		return "Job heute schon erledigt"
	if int(d.get("job_tag", -1)) == tag:
		return "hat heute schon gearbeitet"
	if _wert(d, job.braucht) < float(job.braucht_wert):
		return "%s %d nötig" % [STAT_NAMEN[job.braucht], job.braucht_wert]
	if float(d.energie) < float(job.energie):
		return "zu müde (Energie %d)" % job.energie
	return ""


## Lohn = Basis + Stat / Teiler; anteil (0–1) aus dem Minispiel: 40 % immer, Rest nach Ergebnis
static func lohn(d: Dictionary, job: Dictionary, anteil := 1.0) -> int:
	var voll := int(job.lohn_basis) + int(_wert(d, job.lohn_stat) / float(job.lohn_teiler))
	return roundi(voll * (LOHN_SOCKEL + (1.0 - LOHN_SOCKEL) * anteil))


## Arbeitet: Geld, Energie ab, Training. Gibt den Lohn zurück (oder -1).
static func arbeiten(job: Dictionary, d: Dictionary, tag: int, anteil: float) -> int:
	if geeignet(d, job, tag) != "":
		return -1
	var summe := lohn(d, job, anteil)
	Spiel.geld += summe
	Spiel.jobs[job.id] = tag
	d.energie = float(d.energie) - float(job.energie)
	d.job_tag = tag
	for key in job.training:
		Pflege.trainieren(d, key, float(job.training[key]))
	return summe
