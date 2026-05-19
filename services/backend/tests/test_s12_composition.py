"""Phase mint-data-architecture-v1-02 W0 Plan 02-01 (D-08) — S18 IJM/LAA promotion identity tests.

Asserts that :
  (a) `IndependantService.estimate_ijm_cost` + `.estimate_laa_cost` still produce
      the correct numerical output post-relocation.
  (b) `IJM_ESTIMATE_RATE` + `LAA_ESTIMATE_RATE` imported from BOTH
      `app.services.independants.indemnity_rates` AND
      `app.services.independant_service` resolve to the SAME object (identity,
      not equality) — proves the relocation didn't duplicate the constants.
"""
from __future__ import annotations

import pytest


def test_s12_independant_estimate_ijm_correct():
    """Numerical correctness preserved post-D-08 relocation."""
    from app.services.independant_service import IndependantService
    svc = IndependantService()
    # 10000 × IJM_ESTIMATE_RATE (=0.02) = 200.0
    assert svc.estimate_ijm_cost(10_000) == 200.0


def test_s12_independant_estimate_laa_correct():
    """Numerical correctness preserved post-D-08 relocation."""
    from app.services.independant_service import IndependantService
    svc = IndependantService()
    # 10000 × LAA_ESTIMATE_RATE (=0.015) = 150.0
    assert svc.estimate_laa_cost(10_000) == 150.0


def test_ijm_rate_identity_single_source_of_truth():
    """The IJM_ESTIMATE_RATE imported from S12 façade must be the SAME object
    as the one in the S18 canonical home — proves no duplication after D-08.
    """
    from app.services.independants.indemnity_rates import IJM_ESTIMATE_RATE as s18_rate
    from app.services.independant_service import IJM_ESTIMATE_RATE as s12_rate
    assert s12_rate is s18_rate, (
        "S12 IJM_ESTIMATE_RATE must be the SAME object as S18 — D-08 violation otherwise."
    )


def test_laa_rate_identity_single_source_of_truth():
    """LAA_ESTIMATE_RATE single source of truth (D-08)."""
    from app.services.independants.indemnity_rates import LAA_ESTIMATE_RATE as s18_rate
    from app.services.independant_service import LAA_ESTIMATE_RATE as s12_rate
    assert s12_rate is s18_rate, (
        "S12 LAA_ESTIMATE_RATE must be the SAME object as S18 — D-08 violation otherwise."
    )


def test_independants_package_exports_rates():
    """`from app.services.independants import IJM_ESTIMATE_RATE, LAA_ESTIMATE_RATE` works."""
    from app.services.independants import IJM_ESTIMATE_RATE, LAA_ESTIMATE_RATE
    assert IJM_ESTIMATE_RATE == 0.02
    assert LAA_ESTIMATE_RATE == 0.015
