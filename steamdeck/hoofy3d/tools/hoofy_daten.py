#!/usr/bin/env python3
"""Übernimmt Rassen, Farben und Charakterzüge aus dem 2D-Hoofy (games/hoofy/data/*.lua)
nach data/hoofy.json, damit beide Spiele dieselben Werte haben.

    python3 tools/hoofy_daten.py
"""
import json
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parent.parent
HOOFY = ROOT.parent.parent / "games" / "hoofy" / "data"
DATEIEN = ["rassen", "farben", "charakter", "stats"]

TOKEN = re.compile(r'\s*(?:(--[^\n]*)|("(?:[^"\\]|\\.)*")|([A-Za-z_]\w*)|(-?\d+(?:\.\d+)?)|(.))')


def tokens(text: str):
    for kommentar, s, name, zahl, zeichen in TOKEN.findall(text):
        if kommentar:
            continue
        if s:
            yield ("str", json.loads(s))
        elif name:
            yield ("name", name)
        elif zahl:
            yield ("num", float(zahl) if "." in zahl else int(zahl))
        elif zeichen.strip():
            yield ("sym", zeichen)


def lua_literal(text: str):
    """Liest `return { ... }` mit Zahlen, Strings, true/false und verschachtelten Tabellen."""
    t = list(tokens(text))
    pos = 0

    def wert():
        nonlocal pos
        art, v = t[pos]
        pos += 1
        if art == "sym" and v == "{":
            return tabelle()
        if art == "name" and v in ("true", "false"):
            return v == "true"
        if art == "name" and v == "nil":
            return None
        return v

    def tabelle():
        nonlocal pos
        felder, liste = {}, []
        while t[pos] != ("sym", "}"):
            if t[pos][0] == "name" and t[pos + 1] == ("sym", "="):
                schluessel = t[pos][1]
                pos += 2
                felder[schluessel] = wert()
            elif t[pos] == ("sym", "["):
                pos += 1
                schluessel = wert()
                pos += 2  # ] =
                felder[str(schluessel)] = wert()
            else:
                liste.append(wert())
            if t[pos] in (("sym", ","), ("sym", ";")):
                pos += 1
        pos += 1
        return felder if felder else liste

    while t[pos] != ("name", "return"):
        pos += 1
    pos += 1
    return wert()


def main() -> None:
    daten = {name: lua_literal((HOOFY / f"{name}.lua").read_text()) for name in DATEIEN}
    ziel = ROOT / "data" / "hoofy.json"
    ziel.write_text(json.dumps(daten, ensure_ascii=False, indent=1) + "\n")
    print(ziel.relative_to(ROOT), {k: len(v.get("liste", v)) for k, v in daten.items()})


if __name__ == "__main__":
    main()
