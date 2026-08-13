#!/usr/bin/env python3
"""Construit le registre officiel des communes suisses embarqué dans l'app.

Source : Office fédéral de la statistique (OFS), répertoire officiel des
communes de Suisse, point de terminaison « snapshot » :

    https://www.agvchapp.bfs.admin.ch/api/communes/snapshot?date=JJ-MM-AAAA

C'est le registre fédéral lui-même, pas un intermédiaire. Deux propriétés le
rendent utilisable comme identité d'un fait « domicile » :

  * le numéro OFS (BfsCode) identifie la commune indépendamment de son nom —
    un nom change, fusionne, se traduit ; le numéro reste la clé engagée ;
  * chaque ligne porte sa date de validité, donc le registre est daté et non
    « le monde tel qu'il est aujourd'hui ».

Le numéro CHANGE lors d'un transfert de canton : Moutier valait BE 700 jusqu'au
31.12.2025 puis JU 6831 au 01.01.2026. Un instantané pris à une date donnée est
donc vrai À CETTE DATE et le fichier produit porte cette date en tête.

Vérification croisée effectuée le 2026-08-13 : l'API tierce OpenPLZ renvoyait
encore « Moutier BE 700 » alors que le registre fédéral renvoie « JU 6831 ». La
source officielle est la seule retenue.

Homonymes : quand deux communes partagent un nom, le registre fédéral porte
lui-même le suffixe cantonal dans le nom officiel — « Rickenbach (ZH) » face à
« Rickenbach (LU) ». Mesuré sur l'instantané du 2026-08-13 : 35 noms nus
partagés par 77 communes, et zéro cas où le suffixe officiel ne suffit pas à
distinguer. Aucune convention d'affichage n'est donc à inventer.

Usage :
    python3 tools/data/build_commune_registry.py            # date du jour
    python3 tools/data/build_commune_registry.py --date 01-01-2026
    python3 tools/data/build_commune_registry.py --check    # sans réseau
"""

from __future__ import annotations

import argparse
import csv
import io
import re
import sys
import urllib.request
from collections import defaultdict
from datetime import date
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
ASSET = REPO / "apps/mobile/assets/data/commune_registry.txt"
API = "https://www.agvchapp.bfs.admin.ch/api/communes/snapshot?date={d}"

LEVEL_CANTON, LEVEL_DISTRICT, LEVEL_COMMUNE = "1", "2", "3"

# Exonymes vérifiés — le registre fédéral ne porte qu'UN nom officiel par
# commune, sans forme localisée. Quelqu'un de romand cherchant « Morat » ne
# trouverait rien puisque le nom officiel est « Murten ». Ces alias servent
# UNIQUEMENT à la recherche, jamais à l'affichage : le nom montré reste le nom
# officiel. Source : .claude/agent-memory-local/mint-swiss-brain/
# reference_bfs_commune_mutations_datasources.md (faits vérifiés 2026-08).
VERIFIED_ALIASES: dict[int, tuple[str, ...]] = {
    2275: ("Morat",),           # Murten (FR)
    2196: ("Freiburg",),        # Fribourg (FR)
    2701: ("Bâle", "Basilea"),  # Basel (BS)
    351: ("Berne", "Berna"),    # Bern (BE)
    6711: ("Delsberg",),        # Delémont (JU)
    6248: ("Siders",),          # Sierre (VS)
    6266: ("Sitten",),          # Sion (VS)
    2233: ("Guin",),            # Düdingen (FR)
    2258: ("Chiètres",),        # Kerzers (FR)
    3901: ("Coire", "Coira"),   # Chur (GR)
    5192: ("Lauis",),           # Lugano (TI)
}


def fetch(snapshot: str) -> list[dict[str, str]]:
    url = API.format(d=snapshot)
    with urllib.request.urlopen(url, timeout=120) as response:
        payload = response.read().decode("utf-8-sig")
    rows = list(csv.DictReader(io.StringIO(payload)))
    if not rows:
        raise SystemExit(f"registre vide renvoyé par {url}")
    return rows


def build(rows: list[dict[str, str]]) -> list[dict]:
    cantons = {r["HistoricalCode"]: r["ShortName"] for r in rows if r["Level"] == LEVEL_CANTON}
    districts = {r["HistoricalCode"]: r["Parent"] for r in rows if r["Level"] == LEVEL_DISTRICT}

    communes: list[dict] = []
    for row in rows:
        if row["Level"] != LEVEL_COMMUNE:
            continue
        # Certains cantons n'ont pas d'échelon district : le parent d'une
        # commune est alors directement le canton.
        parent = row["Parent"]
        canton = cantons.get(districts.get(parent, parent))
        if canton is None:
            raise SystemExit(f"canton introuvable pour la commune {row['Name']} (parent {parent})")
        bfs = int(row["BfsCode"])
        communes.append(
            {
                "bfs": bfs,
                "name": row["Name"].strip(),
                "canton": canton,
                "valid_from": row["ValidFrom"].strip(),
                "aliases": VERIFIED_ALIASES.get(bfs, ()) + _split_aliases(row["Name"]),
            }
        )
    communes.sort(key=lambda c: (_sort_key(c["name"]), c["canton"]))
    return communes


def _split_aliases(name: str) -> tuple[str, ...]:
    """Les 11 noms officiels à barre oblique portent deux formes réelles.

    « Biel/Bienne » doit se trouver en tapant « Bienne » ; le nom officiel
    complet reste le seul affiché.
    """
    if "/" not in name:
        return ()
    return tuple(part.strip() for part in name.split("/") if part.strip())


def _bare(name: str) -> str:
    return re.sub(r"\s*\((?:[A-Z]{2})\)$", "", name)


def _sort_key(name: str) -> str:
    return _bare(name).lower()


def audit(communes: list[dict]) -> list[str]:
    """Contrôles d'intégrité — un registre incohérent ne doit pas être écrit."""
    problems: list[str] = []

    seen: dict[int, str] = {}
    for c in communes:
        if c["bfs"] in seen:
            problems.append(f"numéro OFS {c['bfs']} en double : {seen[c['bfs']]} et {c['name']}")
        seen[c["bfs"]] = c["name"]

    homonyms = defaultdict(list)
    for c in communes:
        homonyms[_bare(c["name"])].append(c)
    for bare_name, group in homonyms.items():
        if len(group) < 2:
            continue
        # Le suffixe cantonal officiel doit suffire à distinguer chaque
        # homonyme — sinon deux entrées seraient indiscernables à l'écran.
        if len({c["name"] for c in group}) < len(group):
            problems.append(
                f"homonyme « {bare_name} » non distingué par le suffixe officiel : "
                + ", ".join(f"{c['name']} [{c['canton']}/{c['bfs']}]" for c in group)
            )

    if len(communes) < 1900 or len(communes) > 2400:
        problems.append(f"nombre de communes hors plage plausible : {len(communes)}")

    cantons = {c["canton"] for c in communes}
    if len(cantons) != 26:
        problems.append(f"{len(cantons)} cantons couverts au lieu de 26 : {sorted(cantons)}")

    for c in communes:
        if "|" in c["name"] or any("|" in a for a in c["aliases"]):
            problems.append(f"séparateur présent dans un nom : {c['name']}")

    return problems


def render(communes: list[dict], snapshot: str) -> str:
    lines = [
        "# Registre officiel des communes suisses — asset généré, ne pas éditer à la main.",
        "# Régénérer : python3 tools/data/build_commune_registry.py --date " + snapshot,
        "# Source : OFS, https://www.agvchapp.bfs.admin.ch/api/communes/snapshot",
        f"# Instantané : {snapshot}",
        f"# Communes : {len(communes)}",
        "# Le numéro OFS est l'identité engagée ; il change lors d'un transfert de canton.",
        "# Format : numéro OFS|nom officiel|canton|valide depuis|alias de recherche",
        "#",
    ]
    for c in communes:
        aliases = ",".join(dict.fromkeys(a for a in c["aliases"] if a != c["name"]))
        lines.append(f"{c['bfs']}|{c['name']}|{c['canton']}|{c['valid_from']}|{aliases}")
    return "\n".join(lines) + "\n"


def parse_asset(text: str) -> tuple[dict[str, str], list[dict]]:
    meta: dict[str, str] = {}
    communes: list[dict] = []
    for line in text.splitlines():
        if line.startswith("#"):
            if ":" in line:
                key, _, value = line[1:].partition(":")
                meta[key.strip()] = value.strip()
            continue
        if not line.strip():
            continue
        bfs, name, canton, valid_from, aliases = line.split("|")
        communes.append(
            {
                "bfs": int(bfs),
                "name": name,
                "canton": canton,
                "valid_from": valid_from,
                "aliases": tuple(a for a in aliases.split(",") if a),
            }
        )
    return meta, communes


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--date", default=date.today().strftime("%d-%m-%Y"))
    parser.add_argument(
        "--check",
        action="store_true",
        help="revérifie l'asset déjà écrit, sans accès réseau",
    )
    args = parser.parse_args()

    if args.check:
        if not ASSET.exists():
            print(f"ÉCHEC — asset absent : {ASSET}")
            return 1
        meta, communes = parse_asset(ASSET.read_text(encoding="utf-8"))
        problems = audit(communes)
        if int(meta.get("Communes", "0")) != len(communes):
            problems.append(
                f"en-tête annonce {meta.get('Communes')} communes, le fichier en contient {len(communes)}"
            )
        for problem in problems:
            print("ÉCHEC —", problem)
        if problems:
            return 1
        print(f"OK build_commune_registry — {len(communes)} communes, instantané {meta.get('Instantané')}")
        return 0

    communes = build(fetch(args.date))
    problems = audit(communes)
    for problem in problems:
        print("ÉCHEC —", problem)
    if problems:
        return 1

    ASSET.parent.mkdir(parents=True, exist_ok=True)
    ASSET.write_text(render(communes, args.date), encoding="utf-8")
    size = ASSET.stat().st_size
    print(f"écrit {ASSET.relative_to(REPO)} — {len(communes)} communes, {size / 1024:.1f} Ko")
    return 0


if __name__ == "__main__":
    sys.exit(main())
