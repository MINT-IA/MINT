"""Phase 93.5 — Skill bundle authoring layer (compile-time, NOT runtime topology).

Adopts Anthropic financial-services *patterns* (skill-as-bundle, doctrine-by-domain,
citation_allowlist contract) per audit
`.planning/audit/codebase-audit-2026-05-10/anthropic-financial-services-agents.md`
§7.1 Proposal A. Does NOT adopt runtime multi-agent topology.

CONTEXT decision lock :
- D-08 : `BundleBase` shared base class with frozen + extra=forbid config.
- D-09 : 2 always-on bundles (`compliance-narrator`, `life-event-router`).
- D-10 : 4 intent-driven bundles (`pillar3a-optimizer`, `lpp-projector`,
         `tax-explainer`, `mortgage-stressor`).
- D-20 : `allowed_tools` MUST come from the canonical 6-name registry at
         `coach_tools.py:637-730` (verified by `test_bundle_allowed_tools_subset_of_narrator_registry`).

The compiler in Plan 93.5-02 consumes `ALL_BUNDLE_CLASSES` and
`{always-on, intent-driven}` lists to build the per-request bundle set.
"""
from __future__ import annotations

from app.services.coach.bundles._base import BundleBase
from app.services.coach.bundles.citation_grammar import CitationGrammarBundle
from app.services.coach.bundles.compliance_narrator import ComplianceNarratorBundle
from app.services.coach.bundles.independent_tax_bundle import IndependentTaxBundle
from app.services.coach.bundles.life_event_router import LifeEventRouterBundle
from app.services.coach.bundles.lpp_projector import LppProjectorBundle
from app.services.coach.bundles.mortgage_stressor import MortgageStressorBundle
from app.services.coach.bundles.pillar3a_optimizer import Pillar3aOptimizerBundle
from app.services.coach.bundles.succession_divorce_bundle import SuccessionDivorceBundle
from app.services.coach.bundles.tax_explainer import TaxExplainerBundle


# Canonical 6-bundle registry. Order matches CONTEXT D-09 (always-on first,
# then intent-driven), which is also the priority order the compiler will
# use when applying token-budget drop priority (D-13).
#
# `CitationGrammarBundle` (Phase 94.1, flag-conditional) is intentionally
# NOT in this list — it is registered per-call inside `compile_bundles`
# when `settings.COACH_CITATION_GATE_ENABLED=True`. Keeping it out of
# `ALL_BUNDLE_CLASSES` preserves the canonical 6-bundle invariant pinned
# by `tests/bundles/test_bundle_contract.py::test_all_bundles_importable`
# (`len(ALL_BUNDLE_CLASSES) == 6`) AND the subset invariant pinned by
# `tests/test_citation_gate/test_registry_contract.py::
# test_registry_subset_of_bundle_allowlists` (the grammar bundle has
# empty `citation_allowlist=[]` so it would not contribute to the
# allowlist union anyway).
ALL_BUNDLE_CLASSES: list[type[BundleBase]] = [
    ComplianceNarratorBundle,   # always-on (D-09)
    LifeEventRouterBundle,      # always-on (D-09)
    Pillar3aOptimizerBundle,    # intent-driven (D-10)
    LppProjectorBundle,         # intent-driven (D-10)
    TaxExplainerBundle,         # intent-driven (D-10)
    MortgageStressorBundle,     # intent-driven (D-10)
]


__all__ = [
    "BundleBase",
    "CitationGrammarBundle",
    "ComplianceNarratorBundle",
    "IndependentTaxBundle",
    "LifeEventRouterBundle",
    "Pillar3aOptimizerBundle",
    "LppProjectorBundle",
    "SuccessionDivorceBundle",
    "TaxExplainerBundle",
    "MortgageStressorBundle",
    "ALL_BUNDLE_CLASSES",
]
