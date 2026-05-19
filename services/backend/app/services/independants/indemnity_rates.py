"""S18 single source of truth for IJM/LAA indemnity estimate rates.

Promoted from `app/services/independant_service.py:60-64` per Phase
mint-data-architecture-v1-02 W0 Plan 02-01 (D-08 composition pattern).

These are MARKET-DATA estimates (not legal constants from LAVS / LAMal /
LAA), so they don't live in `app/constants/`. They DO need a single
canonical home so the S12 façade (`IndependantService.estimate_*`) and
the S18 functional API (`app.services.independants.*`) consume the same
values — otherwise a calculator drift between the two surfaces would
silently re-emerge.

Used by :
    * `app/services/independant_service.py::IndependantService.estimate_ijm_cost`
    * `app/services/independant_service.py::IndependantService.estimate_laa_cost`
    * (Future S18 callers in `app/services/independants/*` will import from here.)

Sources :
    IJM (indemnite journaliere maladie) : LAMal art. 67-77 — facultative,
        typical market rate 1-3% of insured salary for 720 days. 2% is the
        middle estimate ; calibrate against actual quotes if available.
    LAA (assurance accident non-professionnel) : LAA art. 4 — facultative for
        independants, typical market rate 1-2% of insured salary. 1.5% is
        the middle estimate.

Phase 02 D-08 composition contract :
    * The S12 IndependantService keeps its public signature (no API break).
    * Calculator primitives delegate to `app.services.independants.*`.
    * Indemnity-rate constants live HERE — single source of truth.
"""
from __future__ import annotations

# IJM estimated cost as a fraction of insured salary.
# Typical market range : 1-3% for 720 days coverage. Middle estimate = 2%.
IJM_ESTIMATE_RATE: float = 0.02

# LAA non-professional estimated cost as a fraction of insured salary.
# Typical market range : 1-2%. Middle estimate = 1.5%.
LAA_ESTIMATE_RATE: float = 0.015
