class_name Fohlenform
extends SkeletonModifier3D
## Macht aus dem Skelett des erwachsenen Pferds ein Fohlen. Ein Fohlen ist kein kleines Pferd:
## Die Beine sind im Verhältnis zum Rumpf viel länger, der Hals ist kürzer, der Kopf (mit Ohren
## und Augen) wirkt groß, Mähne und Schweif sind kurz. Die Faktoren gelten für Neugeborene und
## gehen mit dem Alter (0 → 1, in 4 Tagen) auf 1 zurück. Skaliert wird gleichmäßig je Knochen,
## damit die Haut nicht verzerrt; Kinder erben den Faktor ihres Elternknochens, deshalb stehen hier
## die Verhältnisse zum Elternknochen: Oberarm × Unterarm = ×1,45 für Unterarm, Fessel, Huf.
## Die Gesamtgröße setzt PferdModell (Stockmaß × Alter), die Faktoren sind relativ zum Rumpf.

const NEUGEBOREN := {
	"BN_L_UpperArm_039_040": 1.15, "BN_R_UpperArm_044_046": 1.15,     # Vorderbein
	"BN_l_Forearm_040_041": 1.26, "BN_R_Forearm_045_047": 1.26,
	"BN_L_Thing_051_054": 1.15, "BN_R_Thing_056_060": 1.15,           # Hinterbein
	"BN_L_Calf_052_055": 1.26, "BN_R_Calf_057_061": 1.26,
	"BN_Neck_00_06_06": 0.9,                                          # Hals etwas kürzer
	"BN_Head_00_016_015": 1.5,                                        # Kopf netto ×1,35
	"BN_Pelvis_060_066": 0.8,                                         # Schweif kurz
}

var alter := 0.0


func _process_modification_with_delta(_delta: float) -> void:
	var sk := get_skeleton()
	if sk:
		anwenden(sk, alter)


## Setzt die Knochengrößen für dieses Alter (alter ≥ 1: alles wieder auf 1)
static func anwenden(sk: Skeleton3D, jetzt: float) -> void:
	var t := clampf(1.0 - jetzt, 0.0, 1.0)
	for name in NEUGEBOREN:
		var i := sk.find_bone(name)
		if i >= 0:
			sk.set_bone_pose_scale(i, Vector3.ONE * lerpf(1.0, NEUGEBOREN[name], t))
