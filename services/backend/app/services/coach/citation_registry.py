"""Phase 94 Wave 0 — closed-world citation source registry.

Per CONTEXT D-05/D-06 : pure Python module exposing a frozen
`CITATION_REGISTRY: Mapping[str, CitationSource]` plus a `resolve()`
function that looks up the value at runtime.

Phase 95 (DAG-INVALIDATION) will replace this module with the
`GroundingPack` JSON contract ; Phase 94 keeps it minimal — Wave 0 seeds
the v1 baseline of 18 keys (union of pillar3a + lpp + tax + mortgage
bundle `citation_allowlist`s, sourced from `bundles/*.py` Wave 2 fattening).

Design notes :
- 5 D-05 source kinds : `profile | reasoning | tool_call_id | adr | spec`.
- `extra=forbid` + `frozen=True` per Pydantic v2 — schema drift fails fast
  at import time (threat T-94-02).
- No `description_fr` value contains `{{cite:` (defensive non-recursion ;
  enforced by `tests/test_citation_gate/test_registry_contract.py::
  test_no_recursive_keys`).
- Subset invariant : every key here MUST also appear in at least one
  bundle's `citation_allowlist`. Enforced by
  `test_registry_subset_of_bundle_allowlists`.

Wave 0 `resolve()` is a thin placeholder : returns `description_fr` if
the key exists, else `None`. Plan 94-02 will dispatch per `source_kind`
(profile read, financial_core call, ADR/spec lookup) ; Phase 95 replaces
the whole module with the structured `GroundingPack` JSON.
"""
from __future__ import annotations

from types import MappingProxyType
from typing import Literal, Mapping, Optional

from pydantic import BaseModel, ConfigDict


class CitationSource(BaseModel):
    """One entry in the closed-world citation registry.

    Per D-05/D-06 :
    - `key` — short stable identifier emitted by the narrator inside
      `{{cite:<key>}}` placeholders.
    - `source_kind` — one of 5 D-05 categories that determines how the
      citation resolves at runtime (Plan 94-02 dispatcher).
    - `source_ref` — opaque identifier inside the kind (e.g.
      `spec:OPP3#art_7_alinea_1_lit_a`, `adr:2026-05-09-calc-first#r3a_ceiling_2026`).
    - `description_fr` — short FR description used by `resolve()` Wave 0
      stub and by future provenance/dashboard surfaces. MUST NOT contain
      `{{cite:` (threat T-94-02).
    """

    model_config = ConfigDict(frozen=True, extra="forbid")

    key: str
    source_kind: Literal["profile", "reasoning", "tool_call_id", "adr", "spec"]
    source_ref: str
    description_fr: str


# ---------------------------------------------------------------------------
# v1 baseline — union of bundle citation_allowlists (18 keys).
# Source : services/backend/app/services/coach/bundles/{pillar3a,lpp,tax,mortgage}*.py
# Sync : 2026-05-10 (Phase 94 Plan 94-01 Task 1).
# ---------------------------------------------------------------------------

_REGISTRY: dict[str, CitationSource] = {
    # ------------------------------------------------------------------ pillar3a
    "r3a_plafond_salarie_2026": CitationSource(
        key="r3a_plafond_salarie_2026",
        source_kind="spec",
        source_ref="spec:OPP3#art_7_alinea_1_lit_a",
        description_fr="Plafond annuel 3a salarié·e affilié·e LPP, OPP3 art. 7 al. 1 let. a, année 2026.",
    ),
    "r3a_plafond_independant_2026": CitationSource(
        key="r3a_plafond_independant_2026",
        source_kind="spec",
        source_ref="spec:OPP3#art_7_alinea_1_lit_b",
        description_fr="Plafond annuel 3a indépendant·e sans LPP (20% du revenu net), OPP3 art. 7 al. 1 let. b, année 2026.",
    ),
    "lifd_art_33_deduction": CitationSource(
        key="lifd_art_33_deduction",
        source_kind="spec",
        source_ref="spec:LIFD#art_33_let_e",
        description_fr="Déduction du revenu imposable des versements 3a, LIFD art. 33 let. e.",
    ),
    "lifd_art_38_capital_taux": CitationSource(
        key="lifd_art_38_capital_taux",
        source_kind="spec",
        source_ref="spec:LIFD#art_38",
        description_fr="Imposition séparée du capital de prévoyance à barème réduit (souvent ÷ 5 selon canton), LIFD art. 38.",
    ),
    # ----------------------------------------------------------------------- lpp
    "lpp_taux_conv_obligatoire_2026": CitationSource(
        key="lpp_taux_conv_obligatoire_2026",
        source_kind="spec",
        source_ref="spec:LPP#taux_conversion_2026",
        description_fr="Taux de conversion LPP minimal légal pour la part obligatoire, année 2026.",
    ),
    "opp2_coordination_2026": CitationSource(
        key="opp2_coordination_2026",
        source_kind="spec",
        source_ref="spec:OPP2#art_3_4_seuils",
        description_fr="Seuil d'entrée et déduction de coordination LPP, OPP2 art. 3 et 4, année 2026.",
    ),
    "lpp_rente_survivant_pct": CitationSource(
        key="lpp_rente_survivant_pct",
        source_kind="spec",
        source_ref="spec:LPP#art_19_21_rentes_survivants",
        description_fr="Pourcentages de rente de conjoint·e survivant·e et d'orphelin·e, LPP art. 19-21.",
    ),
    "lavs_age_reference_2026": CitationSource(
        key="lavs_age_reference_2026",
        source_kind="spec",
        source_ref="spec:LAVS#art_21_age_reference",
        description_fr="Âge de référence AVS unifié homme/femme (transition AVS21), LAVS art. 21, année 2026.",
    ),
    # ----------------------------------------------------------------------- tax
    "lifd_art_22_rentes": CitationSource(
        key="lifd_art_22_rentes",
        source_kind="spec",
        source_ref="spec:LIFD#art_22",
        description_fr="Imposition à 100% au revenu ordinaire des rentes (AVS, LPP, 3a en rente), LIFD art. 22.",
    ),
    "lifd_art_33_deduction_3a": CitationSource(
        key="lifd_art_33_deduction_3a",
        source_kind="spec",
        source_ref="spec:LIFD#art_33_let_e",
        description_fr="Déduction du revenu imposable des versements 3a — variante intent-tax, LIFD art. 33 let. e.",
    ),
    "lifd_art_33_rachat_lpp": CitationSource(
        key="lifd_art_33_rachat_lpp",
        source_kind="spec",
        source_ref="spec:LIFD#art_33_let_d",
        description_fr="Déduction du revenu imposable des rachats LPP volontaires, LIFD art. 33 let. d.",
    ),
    "lifd_art_38_taux_reduit": CitationSource(
        key="lifd_art_38_taux_reduit",
        source_kind="spec",
        source_ref="spec:LIFD#art_38_taux_reduit",
        description_fr="Taux réduit fédéral pour le retrait du capital de prévoyance, LIFD art. 38.",
    ),
    "lhid_harmonisation": CitationSource(
        key="lhid_harmonisation",
        source_kind="spec",
        source_ref="spec:LHID#harmonisation_cantonale",
        description_fr="Harmonisation cantonale des impôts directs (canton applique son propre barème), LHID.",
    ),
    # ------------------------------------------------------------------- mortgage
    "finma_taux_calculatoire": CitationSource(
        key="finma_taux_calculatoire",
        source_kind="spec",
        source_ref="spec:FINMA#circ_2008_21_taux_calculatoire_5pct",
        description_fr="Taux calculatoire FINMA de 5% pour le test de tenue (charge théorique), FINMA Circ. 2008/21.",
    ),
    "amortissement_taux_2026": CitationSource(
        key="amortissement_taux_2026",
        source_kind="spec",
        source_ref="spec:FINMA#amortissement_2nd_rang_15_ans",
        description_fr="Amortissement obligatoire du 2e rang sur 15 ans (jusqu'à 2/3 LTV), règle FINMA, année 2026.",
    ),
    "finma_lcb_tragbarkeit": CitationSource(
        key="finma_lcb_tragbarkeit",
        source_kind="spec",
        source_ref="spec:FINMA#lcb_tragbarkeit",
        description_fr="Règle de tenue (Tragbarkeit) FINMA — charge financière théorique ≤ 1/3 du revenu brut, LCB.",
    ),
    "ltv_max_residence_principale": CitationSource(
        key="ltv_max_residence_principale",
        source_kind="spec",
        source_ref="spec:FINMA#ltv_max_residence_principale_80pct",
        description_fr="Plafond LTV (loan-to-value) de 80% pour la résidence principale, règle FINMA.",
    ),
    "ratio_endettement_max_33pct": CitationSource(
        key="ratio_endettement_max_33pct",
        source_kind="reasoning",
        source_ref="reasoning:financial_core.mortgage.tragbarkeit_threshold",
        description_fr="Ratio d'endettement maximal de 33% du revenu brut (charge financière théorique).",
    ),
}


# Frozen view — runtime mutation raises TypeError.
CITATION_REGISTRY: Mapping[str, CitationSource] = MappingProxyType(_REGISTRY)


def resolve(key: str, ctx) -> Optional[str]:
    """Resolve a citation key to its FR description.

    Wave 0 stub : returns `description_fr` if `key` is in the registry,
    else `None`. Plan 94-02 will dispatch per `source_kind` (profile read
    via `ctx`, financial_core call, ADR/spec lookup) ; Phase 95 replaces
    the whole module with the structured `GroundingPack` JSON contract.

    Args :
        key : registry key emitted by the narrator inside `{{cite:<key>}}`.
        ctx : `CoachContext` (unused in Wave 0 ; consumed by Plan 94-02).

    Returns :
        FR description if `key` ∈ `CITATION_REGISTRY`, else `None`.
    """
    src = CITATION_REGISTRY.get(key)
    if src is None:
        return None
    return src.description_fr


__all__ = ["CITATION_REGISTRY", "CitationSource", "resolve"]
