#!/usr/bin/env python3
"""Hoofy: KATALOG.md -> games/hoofy/data/*.lua (one module per catalog section).

    tools/hoofy_katalog.py                         games/hoofy/KATALOG.md -> games/hoofy/data/
    tools/hoofy_katalog.py --katalog K.md --out D  other files (e.g. to try out a change)

make test, run, shot and dist call it first; files are only written when their content changed.
The catalog is written for people, so every value is looked up with a pattern. If the catalog's
wording changes so that a pattern no longer matches, the generator stops with a message naming
the section and the pattern: adjust the pattern here, never the numbers.
"""
import argparse
import os
import re
import sys

HEADER = "-- Erzeugt von tools/hoofy_katalog.py aus KATALOG.md %s, nicht von Hand ändern.\n"

NUM = r"[+−-]?\d+(?: \d{3})*(?:,\d+)?"


class KatalogError(Exception):
    pass


# ---- reading ----

def num(text):
    """'1 200' -> 1200, '+20' -> 20, '×1,3' -> 1.3, '40 %' -> 40, '−3' -> -3, '–' -> 0."""
    t = text.strip().replace("×", "").replace("%", "").replace("~", "").strip()
    if t in ("–", "-", ""):
        return 0
    t = t.replace("−", "-").replace("+", "")
    m = re.match(r"^-?\d[\d ]*(?:,\d+)?", t)
    if not m:
        raise KatalogError("keine Zahl: %r" % text)
    t = m.group(0).replace(" ", "").replace(",", ".")
    v = float(t)
    return int(v) if v == int(v) and "." not in t else v


def slug(name):
    s = name.strip().lower()
    for a, b in (("ä", "ae"), ("ö", "oe"), ("ü", "ue"), ("ß", "ss")):
        s = s.replace(a, b)
    s = re.sub(r"[^a-z0-9]+", "_", s).strip("_")
    return s


def listing(cell):
    """'Brauner, Fuchs' -> ['Brauner', 'Fuchs'], '–' -> []"""
    cell = cell.strip()
    if cell in ("–", "-", ""):
        return []
    return [c.strip() for c in cell.split(",")]


def sections(md):
    """{'3': (title, text)} for every '## 3. Title' (the number is the key)."""
    out = {}
    parts = re.split(r"^## ", md, flags=re.M)
    for p in parts[1:]:
        title, _, body = p.partition("\n")
        m = re.match(r"(\d+)\.\s*(.*)", title)
        if m:
            out[m.group(1)] = (m.group(2).strip(), body)
    return out


def tables(text):
    """All markdown tables in text: list of (header, rows), cells as stripped strings."""
    result, lines, i = [], text.split("\n"), 0
    while i < len(lines):
        if lines[i].startswith("|") and i + 1 < len(lines) and re.match(r"^\|[-| ]+\|$", lines[i + 1]):
            header = [c.strip() for c in lines[i].strip().strip("|").split("|")]
            rows, i = [], i + 2
            while i < len(lines) and lines[i].startswith("|"):
                rows.append([c.strip() for c in lines[i].strip().strip("|").split("|")])
                i += 1
            result.append((header, rows))
        else:
            i += 1
    return result


class Section:
    def __init__(self, key, title, text):
        self.key, self.title, self.text = key, title, text
        self.tables = tables(text)

    def where(self):
        return "§%s %s" % (self.key, self.title)

    def find(self, pattern, text=None, cast=num, group=1):
        """First match of pattern in text (default: whole section), cast to a number."""
        m = re.search(pattern, self.text if text is None else text)
        if not m:
            raise KatalogError("%s: Muster %r nicht gefunden%s" % (
                self.where(), pattern, "" if text is None else " in %r" % text))
        return cast(m.group(group)) if cast else m

    def table(self, first_header):
        """The table whose first column header is first_header, as a list of dicts."""
        for header, rows in self.tables:
            if header[0] == first_header:
                return [dict(zip(header, r)) for r in rows]
        raise KatalogError("%s: Tabelle mit Spalte %r fehlt" % (self.where(), first_header))

    def row(self, rows, col, value):
        for r in rows:
            if r[col] == value:
                return r
        raise KatalogError("%s: Zeile %r fehlt" % (self.where(), value))


EFFECT_KEYS = {
    "Hunger": "hunger", "Energie": "energie", "Bindung": "bindung", "Sauberkeit": "sauberkeit",
    "Gewicht": "gewicht", "Tempo": "tempo", "Schönheit": "schoenheit", "Stärke": "staerke",
    "Ausdauer": "ausdauer", "Max-Potenzial": "potenzial",
}


def effects(text):
    """'Hunger −40, Energie +15' -> {'hunger': -40, 'energie': 15}"""
    out = {}
    for name, value in re.findall(r"(%s) ([+−-]\d+(?:,\d+)?)" % "|".join(map(re.escape, EFFECT_KEYS)), text):
        out[EFFECT_KEYS[name]] = num(value)
    return out


def expand(name, *cells):
    """Rows like 'Stall S / M / L / XL | 300 / 900 / … | 2 / 4 / … Plätze' -> one tuple per item."""
    names = [n.strip() for n in name.split(" / ")]
    k = len(names)
    if k == 1:
        return [(name,) + cells]
    first = names[0]
    if " " in first and len(first.rsplit(" ", 1)[1]) <= 3 and all(" " not in n and len(n) <= 3 for n in names[1:]):
        prefix = first.rsplit(" ", 1)[0] + " "
        names = [first] + [prefix + n for n in names[1:]]
    shared = re.search(r"\s*\(([^)]*)\)$", names[-1])
    out = []
    for i, n in enumerate(names):
        row = [n]
        for c in cells:
            parts = c.split(" / ")
            if len(parts) == k and not re.search(r"\d / [+−-]?\d", c):
                row.append(parts[i].strip())
            else:
                def pick(m):
                    parts = m.group(0).split(" / ")
                    return parts[i].strip() if len(parts) == k else m.group(0)
                row.append(re.sub(NUM + r"(?: / " + NUM + r")+", pick, c))
        out.append(tuple(row))
    # "Weg / Boden (je Kachel)" with one price: the note belongs to all of them
    if shared and all(len(c.split(" / ")) == 1 for c in cells[:1]):
        out = [(o[0] if "(" in o[0] else o[0] + " (" + shared.group(1) + ")",) + o[1:] for o in out]
    return out


def plain(name):
    return re.sub(r"\s*\(.*\)$", "", name).strip()


# ---- the sections ----

def zeit(s):
    rows = s.table("Wert")
    v = {r["Wert"]: r["Vorschlag"] for r in rows}
    wild = s.find(r"alle (\d+) Tage (\d+)–(\d+)", v["Wildpferde wechseln"], cast=None)
    return {
        "tag_min": s.find(r"(\d+) min echt", v["1 Spieltag"]),
        "hell_min": s.find(r"(\d+) min Tag", v["1 Spieltag"]),
        "dunkel_min": s.find(r"(\d+) min Nacht", v["1 Spieltag"]),
        "fohlen_tage": s.find(r"(\d+) Tage", v["Fohlen → ausgewachsen"]),
        "traechtig_tage": s.find(r"(\d+) Tage, danach", v["Trächtigkeit"]),
        "stute_pause_tage": s.find(r"danach (\d+) Tage Pause", v["Trächtigkeit"]),
        "wild_wechsel_tage": num(wild.group(1)),
        "wild_wechsel_min": num(wild.group(2)),
        "wild_wechsel_max": num(wild.group(3)),
    }


def stats(s):
    gen = {r["Wert"]: r["Formel"] for r in s.table("Wert")}
    zst = None
    for header, rows in s.tables:
        if header[:2] == ["Wert", "Start"]:
            zst = {r[0]: dict(zip(header, r)) for r in rows}
    if not zst:
        raise KatalogError("%s: Tabelle Zustände fehlt" % s.where())
    b, h, g, sa, e = zst["Bindung"], zst["Hunger"], zst["Gewicht"], zst["Sauberkeit"], zst["Energie"]
    unter = {slug(r["Ort"]): r for r in s.table("Ort")}
    out = {
        "gen_sigma": s.find(r"σ = (\d+)", gen["Gen-Stat (Wildpferd)"]),
        "gen_min": s.find(r"(\d+)–\d+ \(Ausdauer", gen["Gen-Stat (Wildpferd)"]),
        "gen_max": s.find(r"\d+–(\d+) \(Ausdauer", gen["Gen-Stat (Wildpferd)"]),
        "ausdauer_min": s.find(r"Ausdauer (\d+)–\d+", gen["Gen-Stat (Wildpferd)"]),
        "ausdauer_max": s.find(r"Ausdauer \d+–(\d+)", gen["Gen-Stat (Wildpferd)"]),
        "potenzial_sigma": s.find(r"σ = (\d+)", gen["Max-Potenzial"]),
        "potenzial_max": s.find(r"höchstens (\d+)", gen["Max-Potenzial"]),
        "fohlen_sigma": s.find(r"σ = (\d+)", gen["Gen-Stat (Fohlen)"]),
        "training_bonus_max": s.find(r"bis ×(\d+(?:,\d+)?)", gen["Trainingszuwachs"]),
        "bindung": {
            "streicheln": s.find(r"\+(\d+) Streicheln", b["Pro Tag"]),
            "fuettern": s.find(r"\+(\d+) je Fütterung", b["Pro Tag"]),
            "reiten_min": s.find(r"\+(\d+) je Min\. Reiten", b["Pro Tag"]),
            "hunger_malus": s.find(r"−(\d+) bei Hunger", b["Pro Tag"]),
            "hunger_grenze": s.find(r"bei Hunger > (\d+)", b["Pro Tag"]),
            "schmutz_malus": s.find(r"−(\d+) bei Sauberkeit", b["Pro Tag"]),
            "schmutz_grenze": s.find(r"bei Sauberkeit < (\d+)", b["Pro Tag"]),
            "zickig": s.find(r"< (\d+) zickig", b["Wirkung"]),
            "zickig_verweigert": s.find(r"verweigert Reiten zu (\d+) %", b["Wirkung"]),
            "reitbar": s.find(r"≥ (\d+) reitbar", b["Wirkung"]),
            "folgt": s.find(r"≥ (\d+) folgt ohne Leine", b["Wirkung"]),
            "pfiff": s.find(r"≥ (\d+) kommt auf Pfiff", b["Wirkung"]),
        },
        "hunger": {
            "start": num(h["Start"]),
            "pro_tag": s.find(r"\+(\d+)", h["Pro Tag"]),
            "pro_tag_verfressen": s.find(r"verfressen \+(\d+)", h["Pro Tag"]),
            "zu_hoch": s.find(r"> (\d+)", h["Wirkung"]),
            "satt": s.find(r"< (\d+) über", h["Wirkung"]),
            "satt_tage": s.find(r"über (\d+) Tage", h["Wirkung"]),
        },
        "gewicht": {
            "start": num(g["Start"]),
            "ueberfuettert": s.find(r"überfüttert \+(\d+)", g["Pro Tag"]),
            "hunger": s.find(r"Hunger > \d+ (−\d+)", g["Pro Tag"]),
            "toleranz": s.find(r"Abweichung > (\d+)", g["Wirkung"]),
            "malus_prozent": s.find(r"um (\d+) % je Punkt", g["Wirkung"]),
        },
        "sauberkeit": {
            "start": num(sa["Start"]),
            "stall": s.find(r"Stall (−\d+)", sa["Pro Tag"]),
            "weide": s.find(r"Weide (−\d+)", sa["Pro Tag"]),
            "frei": s.find(r"frei (−\d+)", sa["Pro Tag"]),
            "regen": s.find(r"Regen (−\d+)", sa["Pro Tag"]),
            "schmutzig": s.find(r"< (\d+)", sa["Wirkung"]),
        },
        "energie": {
            "reiten": s.find(r"Reiten (\d+) je", e["Wirkung"]),
            "reiten_sek": s.find(r"je (\d+) s", e["Wirkung"]),
            "sprung": s.find(r"Sprung (\d+)", e["Wirkung"]),
            "job": s.find(r"Job (\d+)", e["Wirkung"]),
        },
        "unterbringung": {},
        "leine": {
            "teiler": s.find(r"\(100 − Bindung\) / (\d+) %"),
            "sek": s.find(r"Ausreiß-Chance je (\d+) s"),
            "sprinten": s.find(r"Sprinten ×(\d+(?:,\d+)?)"),
            "reiten": s.find(r"Reiten ×(\d+(?:,\d+)?)"),
        },
    }
    for key, r in unter.items():
        loss = r["Verlust Trainings-Stats pro Tag"]
        u = {"verlust": 0 if loss.strip() == "0" else s.find(r"^(\d+) × \(1 − Stärke/100\)", loss),
             "sauberkeit": num(r["Sauberkeit"])}
        if "nur ab" in loss:
            u["min_staerke"] = s.find(r"Stärke (\d+)", loss)
            u["min_bindung"] = s.find(r"Bindung (\d+)", loss)
        out["unterbringung"][key] = u
    return out


def rassen(s):
    out = []
    for r in s.table("Rasse"):
        out.append({
            "id": slug(r["Rasse"]), "name": r["Rasse"], "koerper": slug(r["Körper"]),
            "gebiet": num(r["ab Gebiet"]), "tempo": num(r["Tempo"]), "staerke": num(r["Stärke"]),
            "spuer": num(r["Spür"]), "ausdauer": num(r["Ausdauer"]), "bindung": num(r["Bindung Start"]),
            "spanne": num(r["Spanne"]), "grundwert": num(r["Grundwert"]),
        })
    return {"liste": out}


def farben(s):
    stufen, alle = [], []
    for r in s.table("Stufe"):
        fs = [slug(f) for f in listing(r["Farben"])]
        stufen.append({"id": slug(r["Stufe"]), "name": r["Stufe"], "anteil": num(r["Anteil (Gebiet 1)"]),
                       "faktor": num(r["Wertfaktor"]), "farben": fs})
        for f in listing(r["Farben"]):
            alle.append({"id": slug(f), "name": f, "stufe": len(stufen)})
    matrix = {}
    for r in s.table("Rasse"):
        matrix[slug(r["Rasse"])] = [[slug(f) for f in listing(r[st["name"]])] for st in stufen]
    known = {f["id"] for f in alle}
    for rasse, per in matrix.items():
        for fs in per:
            for f in fs:
                if f not in known:
                    raise KatalogError("%s: Farbe %r bei %s steht in keiner Stufe" % (s.where(), f, rasse))
    ver = {r["Farbe"]: num(r["Chance"]) for r in s.table("Farbe")}
    return {
        "stufen": stufen, "liste": alle, "matrix": matrix,
        "gebiet_verschiebung": s.find(r"verschieben sich (\d+) Prozentpunkte"),
        "vererbung": {
            "vater_sichtbar": ver["sichtbare vom Vater"], "vater_versteckt": ver["versteckte vom Vater"],
            "mutter_sichtbar": ver["sichtbare von der Mutter"], "mutter_versteckt": ver["versteckte von der Mutter"],
            "sichtbar": s.find(r"\((\d+) % sichtbar"),
            "mutation": s.find(r"(\d+) % Mutation"),
        },
        "rasse_vater": s.find(r"(\d+) % Vater"),
        "inzucht": {
            "eltern": s.find(r"Eltern/Geschwister −(\d+) %"),
            "halb": s.find(r"Halbgeschwister/Großeltern −(\d+) %"),
            "cousins": s.find(r"Cousins −(\d+) %"),
        },
    }


def charakter(s):
    rows = {slug(r["Zug"]): r for r in s.table("Zug")}
    spec = {
        "verfressen": {"hunger_pro_tag": r"Hunger \+(\d+) statt"},
        "schreckhaft": {"ausreiss_faktor": r"Ausreiß-Chance ×(\d+(?:,\d+)?)"},
        "faul": {"training_malus": r"Trainingszuwachs −(\d+) %"},
        "eitel": {"sauberkeit_faktor": r"wirkt (doppelt)"},
        "nachteule": {"nacht_energie": r"nachts \+(\d+) Energie", "morgen_energie": r"morgens (−\d+)"},
    }
    out = {}
    for key, pats in spec.items():
        r = rows.get(key)
        if not r:
            raise KatalogError("%s: Charakterzug %r fehlt" % (s.where(), key))
        e = {"name": r["Zug"], "emoji": r["Emoji-Thema"], "text": r["Effekt"]}
        for field, pat in pats.items():
            e[field] = s.find(pat, r["Effekt"], cast=lambda v: 2 if v == "doppelt" else num(v))
        if "flieht vor Tieren" in r["Effekt"]:
            e["flieht"] = True
        out[key] = e
    return out


def wert(s):
    k = {r["Käufer"]: r for r in s.table("Käufer")}
    sam, rei, zue, sch, bes = (k["Reiche Sammlerin"], k["Netter Reithof"], k["Züchter"],
                               k["Schlachter"], k["Bestellung"])
    return {
        "leistung_teiler": s.find(r"\*\*Leistung\*\* = .*\) / (\d+)"),
        "ausdauer_basis": s.find(r"\(Ausdauer − (\d+)\) × \d+"),
        "ausdauer_faktor": s.find(r"\(Ausdauer − \d+\) × (\d+)"),
        "leistung_basis": s.find(r"× \((\d+(?:,\d+)?) \+ Leistung\)"),
        "fohlen_faktor": s.find(r"Fohlen ×(\d+(?:,\d+)?)"),
        "kauf_faktor": s.find(r"Kaufen beim Händler: Wert × (\d+(?:,\d+)?)"),
        "kaeufer": {
            "sammlerin": {"faktor": s.find(r"Farbfaktor × (\d+(?:,\d+)?)", sam["Zahlt"]),
                          "min_sauberkeit": s.find(r"ab Sauberkeit (\d+)", sam["Bedingung / Folge"])},
            "reithof": {"faktor": s.find(r"Wert × (\d+(?:,\d+)?)", rei["Zahlt"]),
                        "basis": s.find(r"\((\d+(?:,\d+)?) \+ Bindung", rei["Zahlt"]),
                        "teiler": s.find(r"Bindung/(\d+)", rei["Zahlt"]),
                        "bindung_andere": s.find(r"(\+\d+) Bindung", rei["Bedingung / Folge"])},
            "zuechter": {"teiler": s.find(r"\)/(\d+)\)", zue["Zahlt"]),
                         "hengst": s.find(r"Hengst ×(\d+(?:,\d+)?)", zue["Zahlt"]),
                         "bindung_andere": s.find(r"(−\d+) Bindung", zue["Bedingung / Folge"])},
            "schlachter": {"faktor": s.find(r"^(\d+) × Gewicht²", sch["Zahlt"]),
                           "teiler": s.find(r"Gewicht² / (\d+)", sch["Zahlt"]),
                           "grundwert": s.find(r"Grundwert × (\d+(?:,\d+)?)", sch["Zahlt"]),
                           "bindung_andere": s.find(r"(−\d+) Bindung", sch["Bedingung / Folge"])},
            "bestellung": {"faktor": s.find(r"Wert × (\d+(?:,\d+)?)", bes["Zahlt"]),
                           "alle_tage": s.find(r"alle (\d+) Tage", bes["Bedingung / Folge"]),
                           "frist_min": s.find(r"Frist (\d+)–", bes["Bedingung / Folge"]),
                           "frist_max": s.find(r"Frist \d+–(\d+)", bes["Bedingung / Folge"])},
        },
    }


def futter(s):
    kaufen = []
    for r in s.table("Artikel"):
        e = {"id": slug(r["Artikel"]), "name": r["Artikel"], "preis": num(r["Preis"]),
             "text": r["Wirkung"], "wirkung": effects(r["Wirkung"])}
        if "Fohlen:" in r["Wirkung"]:
            e["fohlen_potenzial"] = e["wirkung"].pop("potenzial")
            e["fohlen_potenzial_max"] = s.find(r"bis \+(\d+)", r["Wirkung"])
        if "einmalig" in r["Preis"]:
            e["einmalig"] = True
        kaufen.append(e)
    anbau = []
    for r in s.table("Pflanze"):
        name = plain(r["Pflanze"])
        platz = r["Platz"]
        w = h = 1
        m = re.match(r"(\d+)×(\d+)", platz)
        if m:
            w, h = int(m.group(1)), int(m.group(2))
        e = {"id": slug(name), "name": name, "ertrag_name": r["Pflanze"], "samen": num(r["Samen"]),
             "gebiet": num(r["ab Gebiet"]), "w": w, "h": h,
             "reif": s.find(r"^(\d+) /", r["reif nach / dann alle"]),
             "dann": s.find(r"/ (\d+) Tag", r["reif nach / dann alle"]),
             "ertrag": num(r["Ertrag"]), "text": r["Wirkung je Stück"], "wirkung": effects(r["Wirkung je Stück"])}
        t = r["Wirkung je Stück"]
        if "Fohlen:" in t:
            e["fohlen_potenzial"] = e["wirkung"].pop("potenzial")
        m = re.search(r"Training ×(\d+)", t)
        if m:
            e["training_faktor"] = int(m.group(1))
        m = re.search(r"\(eitel ×(\d+)\)", t)
        if m:
            e["eitel_faktor"] = int(m.group(1))
        if "Deko" in t:
            e["deko"] = True
        anbau.append(e)
    return {"kaufen": kaufen, "anbau": anbau,
            "beet_preis": s.find(r"Beete und Felder kosten (\d+) je Kachel")}


def ausruestung(s):
    out = []
    for r in s.table("Artikel"):
        for name, preis, text in expand(r["Artikel"], r["Preis"], r["Wirkung"]):
            e = {"id": slug(name), "name": name, "preis": num(preis), "text": text, "wirkung": effects(text)}
            m = re.search(r"(\d+) Plätze?", text)
            if m:
                e["plaetze"] = int(m.group(1))
            if re.search(r"sattel$", name, re.I):
                e["sattel"] = True
            if "Satteltaschen möglich" in text:
                e["taschen_moeglich"] = True
            if "Sicht nachts" in text:
                e["licht"] = True
            out.append(e)
    return {"liste": out}


def bau(s):
    out = []
    for r in s.table("Element"):
        for name, preis, text in expand(r["Element"], r["Preis"], r["Wirkung"]):
            e = {"id": slug(plain(name)), "name": plain(name), "text": text, "wirkung": effects(text)}
            if "je Kachel" in name:
                e["je_kachel"] = True
            if preis.strip() == "Start":
                e["preis"], e["start"] = 0, True
            else:
                e["preis"] = num(preis)
            m = re.search(r"jedes weitere \+(\d+)", preis)
            if m:
                e["preis_plus"] = int(m.group(1))
            m = re.search(r"\((\d+)×(\d+) Kacheln\)", name)
            if m:
                e["groesse"] = int(m.group(1))
            m = re.search(r"(\d+) Plätze", text)
            if m:
                e["plaetze"] = int(m.group(1))
            m = re.search(r"(\d+) Bindung pro Tag", text)
            if m:
                e["bindung_tag"] = int(m.group(1))
            if "schlafen" in text:
                e["schlafen"] = True
            if "Geld pro Tag" in text:
                e["geld_pferd"] = s.find(r"(\d+) Geld pro Tag", text)
                e["min_staerke"] = s.find(r"Stärke ≥ (\d+)", text)
                e["energie"] = s.find(r"(\d+) Energie", text)
            if e["id"] in ("schuppen", "garage", "hangar"):
                e["fahrzeuge"] = [slug(f) for f in text.split("+")]
            out.append(e)
    stufen = s.find(r"Ab ([\d /]+) bekommen", cast=lambda v: [num(x) for x in v.split("/")])
    bonus = s.find(r"alle Pferde ([+\d /]+) Bindung", cast=lambda v: [num(x) for x in v.split("/")])
    return {"liste": out, "schoenheit_stufen": stufen, "schoenheit_bindung": bonus}


def welt(s):
    fz = []
    for r in s.table("Zugfahrzeug"):
        fz.append({"id": slug(r["Zugfahrzeug"]), "name": r["Zugfahrzeug"], "preis": num(r["Preis"]),
                   "gebiete": num(r["Gebiete bis"]), "fahrtkosten": num(r["Fahrtkosten je Gebiet Entfernung"])})
    anh = []
    for header, rows in s.tables:
        if header[0] == "Anhänger":
            for i, h in enumerate(header[1:], 1):
                anh.append({"plaetze": s.find(r"(\d+) Pl", h), "preis": num(rows[0][i])})
    if not anh:
        raise KatalogError("%s: Tabelle Anhänger fehlt" % s.where())
    geb = []
    for r in s.table("Gebiet"):
        m = s.find(r"^(\d+) (.+)$", r["Gebiet"], cast=None)
        gm = s.find(r"(\d+) × (\d+)", r["Größe (Kacheln)"], cast=None)
        geb.append({"nr": int(m.group(1)), "name": m.group(2), "palette": r["Palette"],
                    "w": int(gm.group(1)), "h": int(gm.group(2)),
                    "wildpferde": num(r["Wildpferde gleichzeitig"]),
                    "rassen": [slug(x) for x in listing(r["Neue Rassen"])]})
    return {"fahrzeuge": fz, "anhaenger": anh, "gebiete": geb,
            "block": s.find(r"Blöcken zu (\d+) × \d+ Kacheln"),
            "kachel": s.find(r"Kachel (\d+) px")}


def schaetze(s):
    f = {r["Wert"]: r["Formel"] for r in s.table("Wert")}
    funde = []
    for r in s.table("Fund"):
        name = plain(r["Fund"])
        e = {"id": slug(name), "name": name, "wert": num(r["Wert"]), "haeufigkeit": r["Häufigkeit"].split(",")[0]}
        m = re.search(r"ab Gebiet (\d+)", r["Häufigkeit"])
        if m:
            e["gebiet"] = int(m.group(1))
        if "Samen" in name:
            e["samen"] = True
        funde.append(e)
    return {
        "radius_basis": s.find(r"^(\d+) \+ Aufspürung", f["Spür-Radius"]),
        "radius_teiler": s.find(r"Aufspürung / (\d+) Kacheln", f["Spür-Radius"]),
        "chance_teiler": s.find(r"Aufspürung / (\d+) %", f["Chance je Sekunde im Radius"]),
        "fund_training": s.find(r"Aufspürung \+(\d+) je Fund"),
        "funde": funde,
    }


def jobs(s):
    out = []
    for r in s.table("Job"):
        req = r["ab"].split()
        lohn = s.find(r"^(\d+) \+ (\w+) / (\d+)", r["Lohn"], cast=None)
        out.append({"id": slug(r["Job"]), "name": r["Job"], "braucht": slug(req[0]), "braucht_wert": num(req[1]),
                    "lohn_basis": int(lohn.group(1)), "lohn_stat": slug(lohn.group(2)),
                    "lohn_teiler": int(lohn.group(3)), "training": effects(r["Training"]),
                    "energie": num(r["Energie"])})
    return {"liste": out, "pro_tag": s.find(r"Je Pferd (ein) Job pro Tag", cast=lambda v: 1)}


def turniere(s):
    klassen = []
    for r in s.table("Klasse"):
        klassen.append({"id": slug(r["Klasse"]), "name": r["Klasse"],
                        "fahrzeug": "" if r["braucht"] in ("–", "-") else slug(r["braucht"]),
                        "gebuehr": num(r["Startgebühr"]),
                        "preise": [num(x) for x in r["1. / 2. / 3. Preis"].split(" / ")]})
    wett = [{"id": slug(plain(r["Wettbewerb"])), "name": r["Wettbewerb"], "text": r["zählt"]}
            for r in s.table("Wettbewerb")]
    return {"klassen": klassen, "wettbewerbe": wett,
            "rotation_tage": s.find(r"Nach (\d+) Tagen gibt es neue"),
            "wertung_basis": s.find(r"× \((\d+(?:,\d+)?) \+ Bindung / \d+\)"),
            "wertung_teiler": s.find(r"Bindung / (\d+)\)")}


def reformen(s):
    out = []
    for r in s.table("Reform"):
        name = plain(r["Reform"])
        t, full = r["Wirkung"], r["Reform"]
        e = {"id": slug(name), "name": name, "text": t}
        m = re.search(r"Stärke ≥ (\d+)", t)
        if m:
            e["abwehr_staerke"] = int(m.group(1))
        if name.endswith("frei"):
            e["tiere"] = True
            e["tagsueber"] = "tagsüber" in t
            if "zerstören Deko" in t or "wie Hunde" in t:
                e["zerstoert_deko"] = True
        m = re.search(r"ab (\d+) Tage nach Erreichen von Gebiet (\d+)", full)
        if m:
            e["tage_nach"], e["gebiet"] = int(m.group(1)), int(m.group(2))
        m = re.search(r"^(\d+)–(\d+) pro Pferd", t)
        if m:
            e["steuer_min"], e["steuer_max"] = int(m.group(1)), int(m.group(2))
        m = re.search(r"Futter \+(\d+) %", t)
        if m:
            e["futter_aufschlag"] = int(m.group(1))
        m = re.search(r"Generator ×(\d+)", t)
        if m:
            e["generator_faktor"] = int(m.group(1))
        out.append(e)
    return {"liste": out, "alle_tage": s.find(r"Alle (\d+) Tage eine neue"),
            "dauer_min": s.find(r"Dauer (\d+)–"), "dauer_max": s.find(r"Dauer \d+–(\d+) Tage")}


def wirtschaft(s):
    phasen = []
    for r in s.table("Phase"):
        if not r["Phase"].strip():
            continue
        phasen.append({"nr": num(r["Phase"]), "ziel": r["Ziel"], "kosten": num(r["Kosten"]),
                       "einnahmen": s.find(r"~([\d ]+)", r["Einnahmen/Tag (netto)"]),
                       "tage": num(r["Tage"])})
    return {"startgeld": s.find(r"Startgeld \*\*(\d+)\*\*"),
            "kosten_pferd": s.find(r"= \*\*(\d+)\*\*"),
            "kosten_pferd_anbau": s.find(r"Anbau etwa \*\*(\d+)\*\*"),
            "phasen": phasen}


MODULES = [
    ("1", "zeit", zeit), ("2", "stats", stats), ("3", "rassen", rassen), ("4", "farben", farben),
    ("5", "charakter", charakter), ("6", "wert", wert), ("7", "futter", futter),
    ("8", "ausruestung", ausruestung), ("9", "bau", bau), ("10", "welt", welt),
    ("11", "schaetze", schaetze), ("12", "jobs", jobs), ("13", "turniere", turniere),
    ("14", "reformen", reformen), ("15", "wirtschaft", wirtschaft),
]


# ---- writing ----

def lua(v, indent=""):
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return repr(v)
    if isinstance(v, str):
        return '"' + v.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n") + '"'
    inner = indent + "  "
    if isinstance(v, list):
        if not v:
            return "{}"
        if all(not isinstance(x, (dict, list)) for x in v):
            return "{" + ", ".join(lua(x) for x in v) + "}"
        return "{\n" + "".join(inner + lua(x, inner) + ",\n" for x in v) + indent + "}"
    if isinstance(v, dict):
        if not v:
            return "{}"
        parts = []
        for k, x in v.items():
            key = k if re.match(r"^[a-z_][a-z0-9_]*$", k) else "[" + lua(k) + "]"
            parts.append(inner + key + " = " + lua(x, inner) + ",\n")
        return "{\n" + "".join(parts) + indent + "}"
    raise TypeError(v)


def generate(katalog, out_dir):
    with open(katalog, encoding="utf-8") as f:
        secs = sections(f.read())
    written = []
    os.makedirs(out_dir, exist_ok=True)
    for key, name, fn in MODULES:
        if key not in secs:
            raise KatalogError("Abschnitt §%s fehlt in %s" % (key, katalog))
        title, text = secs[key]
        data = fn(Section(key, title, text))
        src = HEADER % ("§%s %s" % (key, title)) + "return " + lua(data) + "\n"
        path = os.path.join(out_dir, name + ".lua")
        old = open(path, encoding="utf-8").read() if os.path.exists(path) else None
        if old != src:
            with open(path, "w", encoding="utf-8") as f:
                f.write(src)
            written.append(name)
    return written


def main():
    root = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--katalog", default=os.path.join(root, "games/hoofy/KATALOG.md"))
    ap.add_argument("--out", default=os.path.join(root, "games/hoofy/data"))
    a = ap.parse_args()
    try:
        written = generate(a.katalog, a.out)
    except KatalogError as e:
        sys.exit("hoofy_katalog: " + str(e))
    if written:
        print("hoofy_katalog: KATALOG.md -> data/%s.lua" % ",".join(written))


if __name__ == "__main__":
    main()
