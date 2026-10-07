class_name Reitsitz
extends SkeletonModifier3D
## Biegt die Spielfigur in den Reitsitz. Zwei-Knochen-IK: Füße in die Steigbügel (Knie nach vorn),
## Hände an die Zügel tief über dem Widerrist (Ellbogen angewinkelt nach hinten-unten, nah am
## Körper, wie in der Reitlehre: Ellbogen–Hand–Pferdemaul in einer Linie). Wirkt nach der Animation.
## Mixamo-Knochen zeigen entlang ihrer lokalen +Y-Achse. Skelettraum: Y oben, +Z vorne, +X links.

const P := "mixamorig6_"
## Ohne Steigbügel (z. B. Platzhalter-Pferd): feste Biegung
const BIEGUNG := [
	["LeftUpLeg", Vector3.RIGHT, -78.0], ["LeftUpLeg", Vector3.UP, 22.0],
	["RightUpLeg", Vector3.RIGHT, -78.0], ["RightUpLeg", Vector3.UP, -22.0],
	["LeftLeg", Vector3.RIGHT, 80.0], ["RightLeg", Vector3.RIGHT, 80.0],
]
const ARME := [
	["LeftArm", Vector3.RIGHT, -40.0], ["RightArm", Vector3.RIGHT, -40.0],
	["LeftForeArm", Vector3.RIGHT, -55.0], ["RightForeArm", Vector3.RIGHT, -55.0],
]

var ziele: Array = []          # Steigbügel [links, rechts] in Weltkoordinaten
var haende: Array = []         # Zügelhände [links, rechts] in Weltkoordinaten
var knie: Array = []           # Knie [links, rechts] in Weltkoordinaten (außen am Sattelblatt)


func _process_modification_with_delta(_delta: float) -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	var welt_zu_skelett := sk.global_transform.affine_inverse()
	if ziele.size() == 2 and knie.size() == 2:
		# Oberschenkel zum Knie, Unterschenkel zum Steigbügel
		for i in 2:
			var s: String = ["Left", "Right"][i]
			_zeigen(sk, sk.find_bone(P + s + "UpLeg"), welt_zu_skelett * (knie[i] as Vector3) - sk.get_bone_global_pose(sk.find_bone(P + s + "UpLeg")).origin)
			var k := sk.get_bone_global_pose(sk.find_bone(P + s + "Leg")).origin
			_zeigen(sk, sk.find_bone(P + s + "Leg"), welt_zu_skelett * (ziele[i] as Vector3) - k)
	elif ziele.size() == 2:
		# Knie nach vorn und außen (+Z, links +X), damit die Oberschenkel um den Pferdebauch gehen
		_ik(sk, "LeftUpLeg", "LeftLeg", "LeftFoot", welt_zu_skelett * (ziele[0] as Vector3), Vector3(0.7, 0.0, 1.0))
		_ik(sk, "RightUpLeg", "RightLeg", "RightFoot", welt_zu_skelett * (ziele[1] as Vector3), Vector3(-0.7, 0.0, 1.0))
	else:
		for b in BIEGUNG:
			_drehen(sk, sk.find_bone(P + b[0]), Basis(b[1], deg_to_rad(b[2])))
	if haende.size() == 2:
		# Ellbogen nach hinten-unten, leicht nach außen
		_ik(sk, "LeftArm", "LeftForeArm", "LeftHand", welt_zu_skelett * (haende[0] as Vector3), Vector3(0.3, -0.6, -1.0))
		_ik(sk, "RightArm", "RightForeArm", "RightHand", welt_zu_skelett * (haende[1] as Vector3), Vector3(-0.3, -0.6, -1.0))
	else:
		for b in ARME:
			_drehen(sk, sk.find_bone(P + b[0]), Basis(b[1], deg_to_rad(b[2])))


## Zwei-Knochen-IK: oberen und mittleren Knochen so drehen, dass das Ende beim Ziel ist; das
## Gelenk dazwischen (Knie, Ellbogen) zeigt in Richtung pol (Skelettraum)
func _ik(sk: Skeleton3D, oben: String, mitte: String, ende: String, ziel: Vector3, pol: Vector3) -> void:
	var o := sk.find_bone(P + oben)
	var u := sk.find_bone(P + mitte)
	var f := sk.find_bone(P + ende)
	if o < 0 or u < 0 or f < 0:
		return
	var huefte := sk.get_bone_global_pose(o).origin
	var knie := sk.get_bone_global_pose(u).origin
	var fuss := sk.get_bone_global_pose(f).origin
	var a := huefte.distance_to(knie)
	var b := knie.distance_to(fuss)
	var weg := ziel - huefte
	var c := clampf(weg.length(), absf(a - b) + 0.01, a + b - 0.01)
	var richtung := weg.normalized()
	var p := pol.normalized()
	var vor := (p - richtung * p.dot(richtung)).normalized()
	var winkel := acos(clampf((a * a + c * c - b * b) / (2.0 * a * c), -1.0, 1.0))
	var knie_neu := huefte + richtung * a * cos(winkel) + vor * a * sin(winkel)
	var fuss_neu := huefte + richtung * c
	_zeigen(sk, o, knie_neu - huefte)
	_zeigen(sk, u, fuss_neu - knie_neu)


## Knochen so drehen, dass seine +Y-Achse in diese Richtung (Skelettraum) zeigt
func _zeigen(sk: Skeleton3D, i: int, richtung: Vector3) -> void:
	var g := sk.get_bone_global_pose(i)
	var q := Quaternion(g.basis.y.normalized(), richtung.normalized())
	_setzen(sk, i, Basis(q) * g.basis)


func _drehen(sk: Skeleton3D, i: int, drehung: Basis) -> void:
	if i < 0:
		return
	_setzen(sk, i, drehung * sk.get_bone_global_pose(i).basis)


func _setzen(sk: Skeleton3D, i: int, global_basis_neu: Basis) -> void:
	var eltern := sk.get_bone_parent(i)
	var pg := sk.get_bone_global_pose(eltern).basis if eltern >= 0 else Basis()
	sk.set_bone_pose_rotation(i, (pg.inverse() * global_basis_neu).get_rotation_quaternion())
	sk.force_update_bone_child_transform(i)
