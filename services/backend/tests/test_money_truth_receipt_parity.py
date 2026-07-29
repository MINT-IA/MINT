"""Parité croisée MoneyTruthReceipt v1 — côté backend (Tranche firstJob PR-B).

La fixture partagée ``tools/fixtures/money_truth_receipt_v1.json`` est gelée
depuis ce producteur (onboarding_service.build_first_job_net_salary_receipt).
Ce test garde contre toute dérive du producteur backend ; le miroir Dart
(``first_job_service.dart::buildNetSalaryReceipt``) pine LES MÊMES valeurs dans
``apps/mobile/test/services/financial_core/money_truth_receipt_parity_test.dart``.

Contrat (SPEC §4.1 / §4.4) : pour les MÊMES inputs, py ET dart produisent le
MÊME ``inputsHash`` (octet pour octet) ET le MÊME net après arrondi au 1 CHF.
Les deux suites asseoient les MÊMES ``expectedInputsHash`` +
``expectedNetRounded`` -> la parité py<->dart est transitive.
"""
from __future__ import annotations

import json
from decimal import Decimal, ROUND_HALF_UP
from pathlib import Path

import pytest

from app.services.first_job.onboarding_service import (
    build_first_job_net_salary_receipt,
)

FIXTURE = (
    Path(__file__).resolve().parents[2].parent
    / "tools"
    / "fixtures"
    / "money_truth_receipt_v1.json"
)


def _load():
    data = json.loads(FIXTURE.read_text(encoding="utf-8"))
    return data["cases"]


CASES = _load()


def _round_half_up(v: float) -> int:
    return int(Decimal(str(v)).quantize(Decimal("1"), rounding=ROUND_HALF_UP))


def test_fixture_has_at_least_10_cross_language_cases():
    assert len(CASES) >= 10


@pytest.mark.parametrize("case", CASES, ids=[c["id"] for c in CASES])
def test_backend_matches_shared_goldens(case):
    inp = case["inputs"]
    r = build_first_job_net_salary_receipt(
        salaire_brut_mensuel=inp["salaireBrutMensuel"],
        canton=inp["canton"],
        age=inp["age"],
        etat_civil=inp["etatCivil"],
        taux_activite=inp["tauxActivite"],
        receipt_id="fixed",
        computed_at="2026-07-29T00:00:00+00:00",
    )
    # 1. inputsHash byte-identique au golden gelé (== côté dart).
    assert r.inputs_hash == case["expectedInputsHash"], (
        f"{case['id']}: inputsHash {r.inputs_hash} != {case['expectedInputsHash']}"
    )
    # 2. même net après arrondi au 1 CHF (== côté dart).
    assert _round_half_up(r.value) == case["expectedNetRounded"], (
        f"{case['id']}: net arrondi {_round_half_up(r.value)} != "
        f"{case['expectedNetRounded']} (net brut {r.value})"
    )
