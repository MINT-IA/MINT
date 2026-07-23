"""Parité croisée du modèle capital v2 — côté backend (beads -2i2).

Pendant mobile : apps/mobile/test/services/financial_core/
capital_tax_parity_fixture_test.dart. Le modèle v2 est DISPONIBLE mais les
consommateurs ne sont PAS encore basculés (PR de bascule dédiée) — cette
fixture gèle la parité dès maintenant.
"""

import json
from pathlib import Path

import pytest

from app.services.fiscal.cantonal_comparator import (
    estimate_capital_withdrawal_tax,
)

FIXTURE = (
    Path(__file__).resolve().parents[2].parent
    / "tools"
    / "fixtures"
    / "capital_tax_parity_v1.json"
)
_DATA = json.loads(FIXTURE.read_text(encoding="utf-8"))


@pytest.mark.parametrize(
    "case", _DATA["cases"], ids=[f"{c['canton']}_{c['amount']}" for c in _DATA["cases"]]
)
def test_capital_tax_v2_matches_goldens(case):
    val = estimate_capital_withdrawal_tax(
        case["amount"], case["canton"], is_married=case["is_married"]
    )
    assert abs(val - case["expected"]) <= _DATA["tolerance_chf"]
    if case["estv_reference"] is not None:
        assert abs(val - case["estv_reference"]) <= 1.0, (
            "le modèle doit reproduire le point ESTV officiel à 1 CHF près"
        )
