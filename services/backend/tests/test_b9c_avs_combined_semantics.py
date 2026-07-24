"""Sémantique des taux AVS combinés (beads MINT_nosync-b9c, verdict A -zaw).

``avs.contribution_rate_employee`` (5.3%) et ``_total`` (10.6%) sont des
taux COMBINÉS AVS+AI+APG (LAVS art. 5 + LAI art. 3 + LAPG art. 27) — et
des clés ``ai.*`` / ``apg.*`` séparées existent aussi dans le registre :
les additionner double-compterait. Ce module fige l'identité arithmétique
qui encode la sémantique et exige les notes anti-mésusage croisées.
"""

import pytest

from app.services.regulatory.registry import RegulatoryRegistry

# AVS pur : 8.7% paritaire (LAVS art. 5) -> 4.35% part salarié.
_AVS_PURE_EMPLOYEE = 0.0435


@pytest.fixture(scope="module")
def reg():
    return RegulatoryRegistry.instance()


def test_combined_identity_employee(reg):
    """5.3% == AVS pur 4.35% + AI 0.7% + APG 0.25% — au 1e-9 près."""
    avs = reg.get("avs.contribution_rate_employee").value
    ai = reg.get("ai.contribution_rate_employee").value
    apg = reg.get("apg.contribution_rate_employee").value
    assert avs == pytest.approx(_AVS_PURE_EMPLOYEE + ai + apg, abs=1e-9), (
        "la clé avs.* est le taux COMBINÉ — si cette identité casse, "
        "la sémantique du registre a changé (revoir les notes -b9c)"
    )


def test_total_is_twice_employee(reg):
    total = reg.get("avs.contribution_rate_total").value
    employee = reg.get("avs.contribution_rate_employee").value
    assert total == pytest.approx(2 * employee, abs=1e-9), "paritaire"


@pytest.mark.parametrize(
    "key,fragment",
    [
        ("avs.contribution_rate_employee", "Ne JAMAIS additionner"),
        ("avs.contribution_rate_total", "Ne JAMAIS additionner"),
        ("ai.contribution_rate_employee", "Déjà INCLUS"),
        ("apg.contribution_rate_employee", "Déjà INCLUS"),
    ],
)
def test_anti_misuse_notes_present(reg, key, fragment):
    """Chaque clé du groupe porte la note croisée anti-double-comptage."""
    assert fragment in reg.get(key).notes, key
