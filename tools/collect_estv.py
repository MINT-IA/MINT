#!/usr/bin/env python3
"""Collecte ESTV — le script versionné de la méthode d'archivage fiscal.

Il n'existait AUCUN script de collecte versionné : la collecte du 2026-07-23
(4 lots, API ESTV swisstaxcalculator) n'avait laissé que ses réponses brutes
sous `.planning/audit-etat-des-lieux-2026-07/constants-audit/effective_rates_2026/`
avec la méthode décrite en texte dans `meta.méthode`. Ce script la reprend :

    POST API_calculateSimpleTaxes (swisstaxcalculator.estv.admin.ch)
    TaxYear par canton (2026 ; 2025 pour SG/TI, MaxYear vérifié via
    API_getTaxYearRangeCanton) · Relationship=1 (célibataire) ·
    Confession1=5 (sans confession, impôt d'église = 0) ·
    fortune imposable = 0 · revenu saisi = revenu IMPOSABLE (cantonal =
    fédéral) · lieu = chef-lieu (TaxLocationID par canton).
    Convention : cantonal_communal = cantonal + communal (chef-lieu)
    + taxe personnelle éventuelle ; total = cantonal_communal + IFD.

Modes :
  --dry-run   AUCUN appel réseau. Rend la valeur `cantonal_communal`
              archivée pour (canton, revenu, fortune=0) et vérifie
              l'intégrité de l'archive au passage : consolidated.json
              doit égaler le lot, et le détail du lot doit sommer.
  (réseau)    REFUSÉ (exit 2). La régénération d'une table de constantes
              réglementaires est sous ASK FIRST (rules.md), et les
              paramètres — points de fortune, revenu de référence,
              tolérance — ne sont pas tranchés (hand-off 2026-07-27
              §3.2 🔴). `build_payload` encode déjà la requête pour ce
              jour-là.

Codes de sortie : 0 valeur rendue et archive cohérente · 1 incohérence
d'archive ou point absent · 2 usage refusé (réseau, ou fortune ≠ 0).
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ARCHIVE_DIR = (
    ROOT
    / ".planning/audit-etat-des-lieux-2026-07/constants-audit/effective_rates_2026"
)
# L'archive documente l'hôte et l'opération, pas la route HTTP complète —
# elle sera capturée à la prochaine collecte réelle, pas inventée ici.
API_HOST = "swisstaxcalculator.estv.admin.ch"
API_OPERATION = "API_calculateSimpleTaxes"


def _load_archive() -> tuple[dict, dict[str, dict]]:
    """(consolidated, canton -> bloc de lot) depuis l'archive du 2026-07-23."""
    consolidated = json.loads((ARCHIVE_DIR / "consolidated.json").read_text())
    by_canton: dict[str, dict] = {}
    for lot in sorted(ARCHIVE_DIR.glob("lot*.json")):
        data = json.loads(lot.read_text())
        for canton, bloc in data["cantons"].items():
            by_canton[canton] = bloc
    return consolidated, by_canton


def _tax_location_id(bloc: dict) -> int | None:
    """TaxLocationID du chef-lieu — champ structuré (lot 1) ou source_note."""
    if "estv_tax_location_id" in bloc:
        return int(bloc["estv_tax_location_id"])
    m = re.search(r"TaxLocationID (\d+)", bloc.get("source_note", ""))
    return int(m.group(1)) if m else None


def build_payload(canton: str, revenu: int, bloc: dict, tax_year: int) -> dict:
    """Requête API_calculateSimpleTaxes conforme à meta.méthode (2026-07-23)."""
    location = _tax_location_id(bloc)
    if location is None:
        raise ValueError(
            f"{canton}: TaxLocationID absent de l'archive (ni champ structuré, "
            "ni source_note) — à récupérer via API_searchLocation avant toute "
            "re-collecte."
        )
    return {
        "TaxYear": tax_year,
        "TaxLocationID": location,
        "Relationship": 1,
        "Confession1": 5,
        "TaxableIncomeCanton": revenu,
        "TaxableIncomeFed": revenu,
        "TaxableFortune": 0,
    }


def dry_run(canton: str, revenu: int) -> int:
    consolidated, by_canton = _load_archive()
    points = consolidated["points_chf"].get(canton)
    bloc = by_canton.get(canton)
    if points is None or bloc is None:
        print(f"collect_estv: canton inconnu de l'archive: {canton}", file=sys.stderr)
        return 1
    key = str(revenu)
    if key not in points:
        print(
            f"collect_estv: revenu {revenu} absent de l'archive pour {canton} "
            f"(points archivés: {', '.join(sorted(points, key=int))})",
            file=sys.stderr,
        )
        return 1

    valeur = float(points[key])
    lot_point = bloc["points"][key]
    lot_cc = float(lot_point["cantonal_communal"])
    if lot_cc != valeur:
        print(
            f"collect_estv: INCOHÉRENCE {canton}/{key} — consolidated {valeur} "
            f"≠ lot {lot_cc}",
            file=sys.stderr,
        )
        return 1
    detail = lot_point.get("détail")
    if detail is not None:
        somme = sum(float(v) for v in detail.values())
        if somme != lot_cc:
            print(
                f"collect_estv: INCOHÉRENCE {canton}/{key} — détail somme "
                f"{somme} ≠ cantonal_communal {lot_cc}",
                file=sys.stderr,
            )
            return 1

    print(valeur)
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(
        description=(
            "Collecte ESTV (API swisstaxcalculator). Seul --dry-run est "
            "actif : il rend la valeur archivée du 2026-07-23 sans réseau."
        )
    )
    ap.add_argument("--canton", required=True, help="Code canton (ZH, GE, …)")
    ap.add_argument("--revenu", required=True, type=int, help="Revenu imposable CHF")
    ap.add_argument("--fortune", required=True, type=int, help="Fortune imposable CHF")
    ap.add_argument(
        "--dry-run",
        action="store_true",
        help="Comparer à l'archive, aucun appel réseau",
    )
    args = ap.parse_args()

    canton = args.canton.upper()
    if args.fortune != 0:
        print(
            "collect_estv: l'archive du 2026-07-23 ne couvre que fortune "
            "imposable = 0 ; les points de fortune font partie des paramètres "
            "à trancher (hand-off 2026-07-27 §3.2 🔴).",
            file=sys.stderr,
        )
        return 2
    if not args.dry_run:
        print(
            "collect_estv: mode réseau REFUSÉ — régénérer une table de "
            "constantes réglementaires est sous ASK FIRST (rules.md), et les "
            "paramètres (points de fortune, revenu de référence, tolérance) "
            "ne sont pas tranchés (hand-off 2026-07-27 §3.2 🔴). "
            "Employer --dry-run.",
            file=sys.stderr,
        )
        return 2
    return dry_run(canton, args.revenu)


if __name__ == "__main__":
    sys.exit(main())
