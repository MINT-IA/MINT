"""ESTV oracle — INTERPOLATION fidelity matcher (CALC-03, réveillé 2026-07-28).

Ce que cet oracle valide, et ce qu'il NE valide pas
---------------------------------------------------
La table `CANTONAL_COMMUNAL_TAX_CHF` (revenu) et `CANTONAL_CAPITAL_TAX_CHF`
(capital, célibataire) sont calibrées EXACTEMENT sur des points de grille ESTV.
Re-capturer ces points de grille ne teste que la reproductibilité (déjà prouvée :
les 130 points se recalculent à 0 écart). Ce que l'utilisateur voit réellement,
c'est une valeur INTERPOLÉE ENTRE les nœuds — et c'est là que vit l'erreur.

Cet oracle capture donc des points **hors des nœuds** (revenu 55/85/125/175/225/
300k ; capital 175/350/620/880k) auprès de l'API officielle ESTV, pour les 26
chefs-lieux, et mesure l'écart entre l'étalon MINT (interpolation) et la valeur
vraie ESTV. La fixture `tests/fixtures/estv_oracle_2025.jsonl` porte, par point :
la valeur ESTV attendue, l'erreur d'interpolation mesurée à la collecte
(`measured_rel_err`), et la tolérance de dérive (`tol_rel`, juste au-dessus de
l'erreur mesurée — jamais une tolérance globale qui masquerait une région).

Portée de collecte (voir `tests/fixtures/estv_oracle.SCHEMA.md`) :
  * Pipeline vérifié : AVANT toute capture hors-nœud, le script de collecte
    reproduit les 5 nœuds committés de CHAQUE canton à ±1 CHF. Les 26 cantons
    ont passé cette porte le 2026-07-28 → les points hors-nœud font foi.
  * Revenu : comparaison sur la composante CANTONALE+COMMUNALE (la seule
    interpolée) via `estimate_income_tax_parts` ; l'IFD (exact, calculé par
    tranches) est vérifié séparément.
  * Capital célibataire : comparaison sur le TOTAL via
    `estimate_capital_withdrawal_tax` (pas de fonction « parts » capital ; ne
    PAS refactorer `estimate_capital_withdrawal_tax` — la branche capital marié
    non fusionnée y touche, éviter le couplage inter-PR). L'IFD capital est
    exact (1/5 du barème 2026) donc l'erreur du total == erreur d'interpolation
    cantonale (dénominateur plus grand).

NE re-implémente JAMAIS `_calculate_*()` : n'utilise que les fonctions
canoniques de `app/services/fiscal/cantonal_comparator.py`
(CLAUDE.md §4 NEVER #3, ADR-20260223).

Fraîcheur : `tools/checks/estv_oracle_freshness.py` lit `expected_capture_date`
(WARN à 14 mois). Ce module teste les données présentes, fraîches ou non.
"""

from __future__ import annotations

import json
from pathlib import Path

import pytest

from app.services.fiscal.cantonal_comparator import (
    estimate_capital_withdrawal_tax,
    estimate_income_tax_parts,
)

# parents[0] = tests/, [1] = backend/, [2] = services/, [3] = MINT.nosync/
REPO_ROOT = Path(__file__).resolve().parents[3]
FIXTURE_PATH = REPO_ROOT / "services/backend/tests/fixtures/estv_oracle_2025.jsonl"

# IFD (impôt fédéral direct) est calculé EXACTEMENT par tranches, jamais
# interpolé : il doit coller à ±1.5 CHF (arrondis ESTV) pour les vecteurs 2026.
# SG et TI sont collectés au barème cantonal 2025 (l'ESTV n'avait pas publié
# leur 2026) alors que FEDERAL_BRACKETS est 2026 → décalage d'indexation
# fédérale documenté jusqu'à ~10.56 CHF ; la tolérance 2025 l'absorbe tout en
# détectant une vraie dérive de barème fédéral.
IFD_ABS_TOL_2026 = 1.5
IFD_ABS_TOL_2025 = 12.0


def _load_vectors() -> list[dict]:
    if not FIXTURE_PATH.exists():
        return []
    text = FIXTURE_PATH.read_text(encoding="utf-8").strip()
    if not text:
        return []
    return [json.loads(line) for line in text.splitlines() if line.strip()]


def _rel_err(mint: float, estv: float) -> float:
    return abs(mint - estv) / estv if estv else 0.0


# Chargées à l'import pour paramétrer un test PAR vecteur (aucun skip quand la
# fixture est peuplée — c'est la différence avec le squelette dormant d'origine).
VECTORS = _load_vectors()
VECTOR_IDS = [v["id"] for v in VECTORS]


def test_oracle_fixture_present_or_skip() -> None:
    """Garde-fou : skip PROPRE si la fixture est vide (jamais un faux vert).

    La fixture n'est peuplée qu'après une vraie session de capture ESTV
    (`services/backend/tests/scripts/capture_estv_oracle.py`). Si quelqu'un la
    vide, la suite skippe avec un message explicite plutôt que de passer au vert
    en silence (0-trust §9)."""
    if not VECTORS:
        pytest.skip(
            "ESTV oracle fixture empty — run "
            "`python3 -m tests.scripts.capture_estv_oracle "
            "--output tests/fixtures/estv_oracle_2025.jsonl` (from "
            "services/backend/) to populate. See tests/scripts/README.md.",
        )
    assert len(VECTORS) > 0


def test_oracle_fixture_matrice_complete() -> None:
    """La fixture porte la matrice ENTIÈRE : 26 cantons × (6 revenus + 4
    capitaux) = 260 vecteurs. Sans cette borne, une capture partielle (panne
    transitoire ESTV) réduirait la couverture en silence — les tests ne
    paramètrent que les vecteurs présents (revue Codex P1)."""
    if not VECTORS:
        pytest.skip("fixture vide — couvert par test_oracle_fixture_present_or_skip")
    assert len(VECTORS) == 260, len(VECTORS)
    par_canton: dict[str, int] = {}
    for v in VECTORS:
        par_canton[v["canton"]] = par_canton.get(v["canton"], 0) + 1
    assert len(par_canton) == 26, sorted(par_canton)
    assert all(n == 10 for n in par_canton.values()), par_canton


@pytest.mark.parametrize("v", VECTORS, ids=VECTOR_IDS)
def test_mint_matches_estv(v: dict) -> None:
    """Par vecteur hors-nœud : l'interpolation MINT reste dans la bande de
    dérive `tol_rel` autour de la valeur vraie ESTV.

    `tol_rel` est fixée juste au-dessus de l'erreur d'interpolation mesurée à la
    collecte (stockée dans `measured_rel_err`) : un test tight pour les points
    bien interpolés (bande 2 %), une bande documentée pour les points où le
    barème cantonal est fortement courbé entre deux nœuds (voir `tol_note`).
    Toute corruption d'un nœud committé ou toute dérive ESTV au refresh annuel
    déplace l'erreur HORS de la bande → FAIL."""
    engine = v["engine"]
    canton = v["canton"]
    x = float(v["input_chf"])
    tol = float(v["tol_rel"])

    if engine == "income":
        ifd_mint, cc_mint = estimate_income_tax_parts(x, canton)
        cc_estv = float(v["expected_cantonal_communal_chf"])
        rel = _rel_err(cc_mint, cc_estv)
        assert rel <= tol, (
            f"ESTV oracle — dérive d'interpolation REVENU sur {v['id']} "
            f"(segment {v['segment']}, taxable={x:.0f}, année {v['tax_year']}) : "
            f"cantonal+communal MINT={cc_mint:.2f} ESTV={cc_estv:.2f} "
            f"écart={rel * 100:.2f}% > bande {tol * 100:.2f}% "
            f"(erreur mesurée à la collecte {float(v['measured_rel_err']) * 100:.2f}%). "
            f"Cause probable : nœud CANTONAL_COMMUNAL_TAX_CHF[{canton}] corrompu "
            f"ou barème ESTV re-publié — recollecter via capture_estv_oracle.py."
        )
        # IFD exact (jamais interpolé) — garde-fou de barème fédéral.
        ifd_estv = float(v["expected_ifd_chf"])
        ifd_tol = IFD_ABS_TOL_2026 if int(v["tax_year"]) == 2026 else IFD_ABS_TOL_2025
        assert abs(ifd_mint - ifd_estv) <= ifd_tol, (
            f"ESTV oracle — dérive IFD (fédéral) sur {v['id']} : "
            f"MINT={ifd_mint:.2f} ESTV={ifd_estv:.2f} "
            f"|Δ|={abs(ifd_mint - ifd_estv):.2f} > {ifd_tol} CHF. "
            f"FEDERAL_BRACKETS a divergé du barème IFD {v['tax_year']}."
        )

    elif engine == "capital":
        total_mint = estimate_capital_withdrawal_tax(x, canton, is_married=False)
        total_estv = float(v["expected_total_chf"])
        rel = _rel_err(total_mint, total_estv)
        assert rel <= tol, (
            f"ESTV oracle — dérive d'interpolation CAPITAL sur {v['id']} "
            f"(segment {v['segment']}, montant={x:.0f}, célibataire) : "
            f"total MINT={total_mint:.2f} ESTV={total_estv:.2f} "
            f"écart={rel * 100:.2f}% > bande {tol * 100:.2f}% "
            f"(erreur mesurée à la collecte {float(v['measured_rel_err']) * 100:.2f}%, "
            f"composante cantonale {float(v.get('measured_rel_err_cantonal', 0)) * 100:.2f}%). "
            f"Cause probable : nœud CANTONAL_CAPITAL_TAX_CHF[{canton}] corrompu "
            f"ou barème ESTV re-publié — recollecter via capture_estv_oracle.py."
        )

    else:  # pragma: no cover - garde-fou schéma
        pytest.fail(f"vecteur {v['id']} : engine inconnu {engine!r}")
