#!/usr/bin/env python3
"""Interdit d'ajouter une NOUVELLE table de taux indexée par canton.

POURQUOI CE LINT EXISTE

Le 2026-07-27, l'écran de recommandations affichait « Économisez CHF X/an
d'impôts » sur un chiffre surestimé de 25 à 77 %. La cause n'était pas un
barème périmé : c'était une table de taux marginaux par canton dont la source
déclarée était « swiss-brain estimates », c'est-à-dire le projet lui-même.

Le dépôt en portait HUIT, qui donnaient pour Zurich 0.30, 0.28, 0.28, 0.34,
0.25 et 0.129. Deux surfaces du même produit pouvaient donc répondre
différemment à la même question — et c'est arrivé : un audit antérieur a
documenté des conclusions bloc/étalé INVERSÉES entre le coach et l'écran sur
le rachat LPP.

La leçon n'est pas « corriger les huit ». C'est que **rien n'empêchait d'en
écrire une neuvième**, et c'est exactement comme ça qu'il y en a eu huit.

CE QUE CE LINT REFUSE

Toute affectation d'un dictionnaire dont les clés sont des codes cantonaux et
les valeurs numériques, hors liste d'autorisation. Les tables de NOMS, de
liens ou d'échéances ne sont pas visées : le problème est le chiffre non
sourcé, pas l'indexation par canton.

LA LISTE D'AUTORISATION NE PEUT QUE RÉTRÉCIR

Chaque entrée est soit un étalon assumé (calibré sur une source primaire avec
sa date de collecte), soit une dette héritée en cours de résorption. Ajouter
une entrée revient à déclarer qu'on crée une neuvième table — ce que ce lint
existe pour empêcher. Retirer une entrée est le sens normal de l'histoire.

Usage : `python3 tools/checks/no_cantonal_rate_table.py [--self-test]`
"""
from __future__ import annotations

import argparse
import ast
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

CANTONS = frozenset(
    "AG AI AR BE BL BS FR GE GL GR JU LU NE NW OW SG SH SO SZ TG TI UR VD VS ZG ZH".split()
)

SCAN_ROOTS = ("services/backend/app",)

# ── Liste d'autorisation — DÉCROISSANTE UNIQUEMENT ───────────────────────────
#
# Format : "chemin/relatif.py::NOM_DE_LA_TABLE".
ALLOWED = {
    # ÉTALONS — calibrés sur l'API officielle ESTV, collecte datée, méthode de
    # vérification écrite (identité cantonal+communal+IFD sur 130 points).
    "services/backend/app/services/fiscal/cantonal_comparator.py::CANTONAL_COMMUNAL_TAX_CHF",
    "services/backend/app/services/fiscal/cantonal_comparator.py::CANTONAL_CAPITAL_TAX_CHF",
    # ÉTALON — socle succession/donation (ADR 2026-07-28 P4). Source primaire :
    # ESTV, dossier successions/donations, état 1.1.2025, archivé 2026-07-28
    # sous .planning/audit-etat-des-lieux-2026-07/constants-audit/
    # succession_donation_2025/socle_extraction.json. Méthode de vérification :
    # parité champ par champ module ↔ archive
    # (tests/test_succession_donation_socle.py). Ce ne sont pas des taux plats :
    # statuts, franchises, multiplicateurs et plafonds de classe sourcés.
    "services/backend/app/services/fiscal/succession_donation_socle.py::SOCLE_CANTONS",
    # NON-BARÈME — indexé par canton, mais ne porte aucun taux. Les valeurs
    # sont des dates d'échéance (mois, jour) issues des administrations
    # cantonales : un fait de calendrier, pas un chiffre financier dérivable.
    "services/backend/app/services/coaching_engine.py::CANTON_TAX_DEADLINES",
    # DETTE HÉRITÉE — à résorber, chacune retirée de cette liste par la PR qui
    # la supprime ou la recalibre. Ne rien ajouter ici.
    "services/backend/app/services/coaching_engine.py::CANTON_MARGINAL_TAX_RATES",
    "services/backend/app/services/lpp_deep/rachat_echelonne_service.py::TAUX_MARGINAUX_PAR_CANTON",
    "services/backend/app/services/fiscal/church_tax_service.py::CHURCH_TAX_RATES",
    "services/backend/app/services/fiscal/wealth_tax_service.py::EFFECTIVE_WEALTH_TAX_RATES_500K",
    "services/backend/app/services/fiscal/wealth_tax_service.py::WEALTH_TAX_EXEMPTIONS",
    "services/backend/app/services/expat/frontalier_service.py::CANTON_SOURCE_TAX_RATES",
    "services/backend/app/services/expat/frontalier_service.py::LAMAL_PRIMES_MENSUELLES",
    "services/backend/app/services/expat/expat_service.py::TAUX_IMPOSITION_CAPITAL_PREVOYANCE",
    "services/backend/app/services/expat/expat_service.py::FORFAIT_FISCAL_BASE_CANTONALE",
    "services/backend/app/services/expat/expat_service.py::FORFAIT_TAUX_ESTIMES",
    "services/backend/app/services/first_job/onboarding_service.py::CANTONAL_TAX_RATE_ESTIMATES",
    "services/backend/app/services/mortgage/imputed_rental_service.py::TAUX_VALEUR_LOCATIVE",
    "services/backend/app/services/onboarding/minimal_profile_service.py::effective_rates_100k",
    "services/backend/app/services/divorce_simulator.py::CANTON_TAX_RATES",
}


def _is_numeric_payload(node: ast.AST) -> bool:
    """La valeur porte-t-elle un nombre ? Directement, ou dans un conteneur."""
    if isinstance(node, ast.Constant):
        return isinstance(node.value, (int, float)) and not isinstance(
            node.value, bool
        )
    if isinstance(node, ast.UnaryOp):
        return _is_numeric_payload(node.operand)
    if isinstance(node, (ast.Tuple, ast.List)):
        return any(_is_numeric_payload(e) for e in node.elts)
    if isinstance(node, ast.Dict):
        return any(_is_numeric_payload(v) for v in node.values)
    return False


def find_tables(root: Path) -> list[tuple[str, int, str]]:
    """(chemin relatif, ligne, nom) de chaque table canton -> nombre."""
    out: list[tuple[str, int, str]] = []
    for path in sorted(root.rglob("*.py")):
        try:
            tree = ast.parse(path.read_text(encoding="utf-8"))
        except (OSError, SyntaxError):
            continue
        rel = path.relative_to(ROOT).as_posix()
        for node in ast.walk(tree):
            if not isinstance(node, ast.Assign) or not isinstance(node.value, ast.Dict):
                continue
            keys = [
                k.value
                for k in node.value.keys
                if isinstance(k, ast.Constant) and isinstance(k.value, str)
            ]
            # ≥ 3 clés, toutes cantonales : en dessous, c'est un cas
            # particulier nommé (« GE a un régime spécial »), pas un barème.
            if len(keys) < 3 or not set(keys) <= CANTONS:
                continue
            if not any(_is_numeric_payload(v) for v in node.value.values):
                continue
            target = node.targets[0]
            name = target.id if isinstance(target, ast.Name) else "<?>"
            out.append((rel, node.lineno, name))
    return out


def _self_test() -> int:
    """Prouve que le lint distingue encore un barème d'une table de noms."""
    import tempfile
    import textwrap

    cases = [
        ("table de taux -> détectée", 'X = {"ZH": 0.30, "GE": 0.41, "VD": 0.39}', True),
        ("table de noms -> ignorée", 'X = {"ZH": "Zurich", "GE": "Genève", "VD": "Vaud"}', False),
        (
            "taux imbriqués -> détectés",
            'X = {"ZH": {"base": 4.5}, "GE": {"base": 4.5}, "VD": {"base": 4.5}}',
            True,
        ),
        (
            "deux cantons seulement -> ignorée (cas particulier nommé)",
            'X = {"ZH": 0.30, "GE": 0.41}',
            False,
        ),
        (
            "clé non cantonale -> ignorée",
            'X = {"ZH": 0.30, "GE": 0.41, "FR_FRONTALIER": 0.2}',
            False,
        ),
    ]
    failures = 0
    with tempfile.TemporaryDirectory() as d:
        root = Path(d)
        for label, src, should_find in cases:
            f = root / "probe.py"
            f.write_text(textwrap.dedent(src) + "\n", encoding="utf-8")
            # find_tables calcule un chemin relatif à ROOT ; on isole ici.
            tree = ast.parse(f.read_text(encoding="utf-8"))
            found = False
            for node in ast.walk(tree):
                if not isinstance(node, ast.Assign) or not isinstance(
                    node.value, ast.Dict
                ):
                    continue
                keys = [
                    k.value
                    for k in node.value.keys
                    if isinstance(k, ast.Constant) and isinstance(k.value, str)
                ]
                if len(keys) < 3 or not set(keys) <= CANTONS:
                    continue
                if any(_is_numeric_payload(v) for v in node.value.values):
                    found = True
            if found != should_find:
                print(
                    f"no_cantonal_rate_table self-test FAIL [{label}] : "
                    f"attendu {should_find}, obtenu {found}",
                    file=sys.stderr,
                )
                failures += 1
    if failures:
        return 1
    print(f"no_cantonal_rate_table self-test OK ({len(cases)} cas)")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--self-test", action="store_true")
    args = ap.parse_args()
    if args.self_test:
        return _self_test()

    found = []
    for scope in SCAN_ROOTS:
        root = ROOT / scope
        if root.exists():
            found.extend(find_tables(root))

    new = [(f, l, n) for f, l, n in found if f"{f}::{n}" not in ALLOWED]
    stale = ALLOWED - {f"{f}::{n}" for f, _, n in found}

    if stale:
        print(
            "no_cantonal_rate_table : entrées d'autorisation devenues inutiles — "
            "retire-les, la liste ne doit que rétrécir :",
            file=sys.stderr,
        )
        for s in sorted(stale):
            print(f"  {s}", file=sys.stderr)
        return 1

    if new:
        print(
            f"no_cantonal_rate_table : {len(new)} table(s) de taux par canton "
            "hors autorisation.",
            file=sys.stderr,
        )
        for f, l, n in new:
            print(f"  {f}:{l}  {n}", file=sys.stderr)
        print(
            "\nUn taux par canton n'est pas une donnée, c'est une DÉRIVÉE du "
            "modèle fiscal calibré. Emploie "
            "`fiscal.cantonal_comparator.estimate_marginal_rate` ou "
            "`estimate_tax_saving`. Si tu ajoutes vraiment un barème, il lui "
            "faut une source primaire, sa date de collecte et sa méthode de "
            "vérification — puis une entrée ici.",
            file=sys.stderr,
        )
        return 1

    print(f"OK no_cantonal_rate_table : {len(found)} table(s) connue(s), 0 nouvelle.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
