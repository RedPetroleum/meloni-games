#!/usr/bin/env python3
"""Lädt die Grafik für Hoofy 3D herunter (nicht im Git, zu groß).

    python3 tools/assets.py          # fehlende Dateien laden
    python3 tools/assets.py --neu    # alles neu laden

Quellen:
- Poly Haven (CC0): Boden- und Rindentexturen, Farne, Blumen, Felsen, Totholz
  (Bäume, Büsche und Gras erzeugt das Spiel selbst: die Poly-Haven-Bäume sind zu schwer fürs Deck)
- Platzhalter-Pferd: Horse.glb aus den three.js-Beispielen (Galopp als Morph-Animation).
  Ein realistisches Pferd mit Schritt/Trab/Galopp ersetzt es später, siehe README.md.
"""
import json
import pathlib
import sys
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parent.parent
ZIEL = ROOT / "assets" / "download"
AUFLOESUNG = "1k"  # reicht für 1280×800 auf dem Steam Deck

TEXTUREN = {
    "boden_gras": "aerial_grass_rock",
    "boden_erde": "brown_mud_dry",
    "boden_wald": "forrest_ground_01",
    "boden_fels": "rocky_terrain_02",
    "rinde_laub": "bark_brown_02",
    "rinde_nadel": "pine_bark",
    "holz_bruecke": "weathered_planks",
}
# Kleine Modelle: viele Exemplare per MultiMesh, das Steam Deck muss sie zeichnen können.
MODELLE = [
    "fern_02", "celandine_01",
    "boulder_01", "rock_moss_set_01", "rock_moss_set_02",
    "dead_tree_trunk_02",
]
# Sketchfab (CC-BY): braucht einen API-Token in ~/.sketchfab_token (sketchfab.com → Settings →
# Password & API). Ohne Token werden diese Modelle übersprungen.
SKETCHFAB = {
    "pferd/horse_henry7.glb": "a6f860e43e364619bccb174a1ac7d0c9",  # „Horse“ von henry_7
}
PFERD = "https://raw.githubusercontent.com/mrdoob/three.js/dev/examples/models/gltf/Horse.glb"

NEU = "--neu" in sys.argv
KOPF = {"User-Agent": "hoofy3d-assets/1.0"}  # Poly Haven lehnt den urllib-Standard ab


def hole(url: str):
    return urllib.request.urlopen(urllib.request.Request(url, headers=KOPF))


def lade(url: str, datei: pathlib.Path) -> None:
    if datei.exists() and not NEU:
        return
    datei.parent.mkdir(parents=True, exist_ok=True)
    print("  ", datei.relative_to(ROOT))
    with hole(url) as r:
        datei.write_bytes(r.read())


def api(asset: str) -> dict:
    with hole(f"https://api.polyhaven.com/files/{asset}") as r:
        return json.load(r)


def main() -> None:
    print("Texturen")
    for name, asset in TEXTUREN.items():
        d = api(asset)
        for art, schluessel in (("diff", "Diffuse"), ("nor", "nor_gl"), ("arm", "arm")):
            url = d[schluessel][AUFLOESUNG]["jpg"]["url"]
            lade(url, ZIEL / "texturen" / f"{name}_{art}.jpg")

    print("Modelle")
    for asset in MODELLE:
        g = api(asset)["gltf"][AUFLOESUNG]["gltf"]
        ordner = ZIEL / "modelle" / asset
        lade(g["url"], ordner / f"{asset}.gltf")
        for pfad, info in g["include"].items():
            lade(info["url"], ordner / pfad)

    import_einstellungen()
    print("Pferd")
    lade(PFERD, ZIEL / "pferd" / "pferd.glb")
    sketchfab()
    print("fertig")


def sketchfab() -> None:
    token_datei = pathlib.Path.home() / ".sketchfab_token"
    if not token_datei.exists():
        print("Sketchfab: kein ~/.sketchfab_token, Modelle übersprungen")
        return
    token = token_datei.read_text().strip()
    print("Sketchfab")
    for ziel, uid in SKETCHFAB.items():
        datei = ZIEL / ziel
        if datei.exists() and not NEU:
            continue
        anfrage = urllib.request.Request(f"https://api.sketchfab.com/v3/models/{uid}/download",
                                         headers={**KOPF, "Authorization": f"Token {token}"})
        with urllib.request.urlopen(anfrage) as r:
            url = json.load(r)["glb"]["url"]
        # Die Download-Adresse ist vorab signiert: ohne Token-Kopf abrufen
        lade(url, datei)


def import_einstellungen() -> None:
    """Godot importiert Bilder sonst ohne Mipmaps und unkomprimiert (flimmert in der Ferne,
    braucht viel Grafikspeicher). Gilt auch für die Texturen der Modelle."""
    for bild in ZIEL.rglob("*.jpg"):
        normal = "_nor" in bild.name
        datei = bild.with_name(bild.name + ".import")
        alt = datei.read_text() if datei.exists() else ""
        if "mipmaps/generate=true" in alt and not NEU:
            continue
        datei.write_text(
            '[remap]\n\nimporter="texture"\ntype="CompressedTexture2D"\n\n[params]\n\n'
            "compress/mode=2\n"
            f"compress/normal_map={1 if normal else 2}\n"
            "mipmaps/generate=true\n"
            "detect_3d/compress_to=0\n"
        )


if __name__ == "__main__":
    main()
