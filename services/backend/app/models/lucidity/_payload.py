"""Phase mint-calc-engine-v1 Plan 04 — D-CE-15 typed lucidity payloads.

Pydantic v2 discriminated union over `level` for the 4-level lucidité
framework :

  - L1 Chiffrer  : « Ta rente AVS projetée à 65 ans est X CHF/mois »
  - L2 Comparer  : « Voici les 3 scénarios chiffrés : A=X, B=Y, C=Z »
  - L3 Éclairer  : « Si tu choisis A, ça change ton 3a, ton impôt … dans 5 ans »
  - L4 Surfacer  : « Quel que soit le scénario, plafond 33% (Directives ASB) »

D-CE-15 schema-impossibility (the structural counterpart to D-CE-16(b)
lint + D-CE-16(c) runtime gate) :

  * `extra="forbid"` on `_LucidityBase` rejects ANY unknown field at
    `model_validate` time. The field `recommended_option` (and its 5
    paraphrase variants `best_choice` / `top_pick` / `preferred` /
    `optimal_choice` / `winning_scenario`) cannot exist on
    `L2ComparePayload` / `L3EclairePayload` — paraphrase cannot evade
    because there is NO FIELD NAME to populate.

  * `frozen=True` prevents post-construction mutation
    (no calc-side value tampering after the schema validates).

  * `@model_validator(mode="after")` on `L2ComparePayload.scenarios`
    enforces ±15% character-count parity across all scenarios. A
    200/50/50-word triple is de facto ranking (LSFin art. 8 risk) ;
    the parity validator raises BEFORE the payload leaves the calculator.

References
----------
- mint-calc-engine-v1-CONTEXT.md §D-CE-15 + Finding 6 + 4-level table.
- mint-calc-engine-v1-RESEARCH.md §Q-C (Pydantic v2 discriminated union
  patterns, lines 469-597).
- threat T-mint-calc-04-01 (LSFin ranking creep mitigation).
- CLAUDE.md §5 NEVER #5 (LSFin banned terms) + §1 rule 1.

Note on banned-term enforcement at schema level
------------------------------------------------
The schema does NOT scan `narrative_fr` / `condition_text_fr` for banned
LSFin verbs (see `tools/checks/banned_terms_python.py` _WORD_BOUNDARY_BANNED
tuple for the full list). That layer is D-CE-16(b) lint-time +
D-CE-16(c) runtime gate, both shipped in W4 plans. Schema impossibility
kills FIELD NAMES ; runtime gate kills VERBS in free text. Both required
(D-CE-16 triple defense). Documented per threat T-mint-calc-04-02 (« accept »
disposition at schema level).
"""
from __future__ import annotations

from enum import Enum
from typing import Annotated, Any, Dict, List, Literal, Union

from pydantic import (
    BaseModel,
    ConfigDict,
    Field,
    RootModel,
    model_validator,
)


# ---------------------------------------------------------------------------
# Lucidity level enum — string-valued (Python 3.9 compatibility, no StrEnum).
# ---------------------------------------------------------------------------


class LucidityLevel(str, Enum):
    """The 4 lucidité levels (CONTEXT.md §4-level lucidité framework table).

    String-valued via `(str, Enum)` mixin for Python 3.9 compatibility
    (`enum.StrEnum` is 3.11+).
    """

    L1 = "L1"
    L2 = "L2"
    L3 = "L3"
    L4 = "L4"


# ---------------------------------------------------------------------------
# Shared base : extra=forbid + frozen=True
# ---------------------------------------------------------------------------


class _LucidityBase(BaseModel):
    """D-CE-15 shared config : forbid extras + immutable after construction.

    `extra="forbid"` is the structural enforcement that makes ranking
    fields like `recommended_option` impossible to embed in L2/L3 payloads.
    `frozen=True` prevents post-construction value tampering.
    """

    model_config = ConfigDict(extra="forbid", frozen=True)


# ---------------------------------------------------------------------------
# L1 Chiffrer — atomic value with French unit + citation chip.
# ---------------------------------------------------------------------------


class L1ChiffrePayload(_LucidityBase):
    """L1 « Chiffrer » : a single atomic value emitted by a calculator.

    Example : « Ta rente AVS projetée à 65 ans est 2'300 CHF/mois ».

    Constraint : every L1 carries a `citation_key` (Phase 94 chip vocabulary
    binding) so the narrator's `{{cite:<key>}}` placeholder can resolve.
    """

    level: Literal[LucidityLevel.L1] = LucidityLevel.L1
    value: float
    unit_fr: str = Field(..., min_length=1)
    citation_key: str = Field(..., min_length=1)


# ---------------------------------------------------------------------------
# L2 Comparer — scenario tuple (NO recommended_option field — by design).
# ---------------------------------------------------------------------------


class _Scenario(_LucidityBase):
    """A single scenario inside an `L2ComparePayload`.

    `narrative_fr` is the human-readable per-scenario explanation. Its length
    is parity-validated across all scenarios by `L2ComparePayload`'s
    `_enforce_narrative_length_parity` validator (D-CE-15 narrative parity).
    """

    label_fr: str = Field(..., min_length=1)
    value: float
    narrative_fr: str = Field(..., min_length=1)
    citation_key: str = Field(..., min_length=1)


class L2ComparePayload(_LucidityBase):
    """L2 « Comparer » : 2-4 scenarios with parity-enforced narrative budgets.

    Schema-impossibility (D-CE-15 core, threat T-mint-calc-04-01) :

      * `extra="forbid"` (via `_LucidityBase`) rejects any unknown field at
        `model_validate` time. The forbidden field names
        `recommended_option` / `best_choice` / `top_pick` / `preferred` /
        `optimal_choice` / `winning_scenario` CANNOT exist on this model.

      * Narrative-length parity validator : all `scenarios[*].narrative_fr`
        must be within ±15% of the mean character count. A 200/50/50
        char triple is de facto ranking — the validator raises ValueError
        before the payload leaves the calculator.

    `scenarios` cardinality : 2 to 4 (panel verdict — fewer = no comparison,
    more = cognitive overload).
    """

    level: Literal[LucidityLevel.L2] = LucidityLevel.L2
    scenarios: List[_Scenario] = Field(..., min_length=2, max_length=4)

    @model_validator(mode="after")
    def _enforce_narrative_length_parity(self) -> "L2ComparePayload":
        """All scenarios' narrative_fr must be within ±15% of the mean char count.

        Raises
        ------
        ValueError
            If any scenario's `narrative_fr` length deviates more than 15%
            from the mean across all scenarios.

        Rationale
        ---------
        LSFin art. 8 ranking risk : a 200-word scenario next to two 50-word
        scenarios is structurally a recommendation (« we wrote more about A
        because A is the answer »). The parity validator kills this AT TYPE
        LEVEL — before the payload leaves the calculator.
        """
        lengths = [len(s.narrative_fr) for s in self.scenarios]
        if not lengths:
            return self
        avg = sum(lengths) / len(lengths)
        threshold = 0.15 * avg
        for i, ln in enumerate(lengths):
            if abs(ln - avg) > threshold:
                raise ValueError(
                    f"L2 narrative length parity violated : scenario[{i}] = "
                    f"{ln} chars, avg = {avg:.0f}, max delta = "
                    f"{threshold:.0f}. All scenarios must be within ±15% of "
                    f"avg character count (D-CE-15 narrative parity validator)."
                )
        return self


# ---------------------------------------------------------------------------
# L3 Éclairer — primary choice + cascade effects across the user's domains.
# ---------------------------------------------------------------------------


class L3EclairePayload(_LucidityBase):
    """L3 « Éclairer l'arbitrage caché » : show downstream cascade effects.

    Example : « Si tu choisis A, ça change ton 3a, ton impôt et ta dette
    dans 5 ans » — a deterministic projection of the cross-domain effects
    of the user's primary choice.

    Same D-CE-15 schema-impossibility as L2 : `extra="forbid"` rejects any
    ranking field. The narrator may not embed « tu devrais X » directly in
    `primary_choice_fr` — that's the D-CE-16(c) runtime gate's job.

    `cascade_effects` is intentionally a list of dicts (open-shape) for
    Wave-2 calculators to populate ; each dict typically carries
    {`domain_fr: str`, `delta_value: float`, `narrative_fr: str`,
    `citation_key: str`}. A typed `_CascadeEffect` may be introduced in a
    follow-up plan once Wave 2 calculators agree on the shape.
    """

    level: Literal[LucidityLevel.L3] = LucidityLevel.L3
    primary_choice_fr: str = Field(..., min_length=1)
    cascade_effects: List[Dict[str, Any]]
    horizon_years: int = Field(..., ge=1, le=99)


# ---------------------------------------------------------------------------
# L4 Surfacer — invariant + legal article ref (« the thing nobody tells you »).
# ---------------------------------------------------------------------------


class L4InvariantPayload(_LucidityBase):
    """L4 « Surfacer les invariants » : information générale + legal article ref.

    Finding 5 of CONTEXT.md : « L4 is MINT's strongest LSFin moat + highest
    user-value surface ». Pure information générale (no user-profile data),
    no ranking, no recommendation — just the regulatory invariant the user
    needs to know.

    Example payload (the « 33% Tragbarkeit plafond » wedge invariant for
    Finding 5). NB : the 33% charge-to-income cap is a FINMA/ASB mortgage
    self-regulation rule — the LCC (consumer credit) explicitly EXCLUDES
    mortgage credit, so the citable source is the ASB directives, not the LCC :

      L4InvariantPayload(
          legal_article_ref="Directives ASB (FINMA)",
          condition_text_fr=(
              "Quel que soit le scénario, ta capacité d'emprunt "
              "hypothécaire reste plafonnée à 33% de tes revenus bruts "
              "annuels selon les Directives ASB (FINMA)."
          ),
      )

    Constraints :
      - `legal_article_ref` min_length=5 to ensure a citable source
        (e.g. « Directives ASB (FINMA) », « CC art. 122 »).
      - `condition_text_fr` min_length=20 to prevent trivial invariants
        (« plafond 33% » alone is not an invariant — it needs context).
    """

    level: Literal[LucidityLevel.L4] = LucidityLevel.L4
    legal_article_ref: str = Field(..., min_length=5)
    condition_text_fr: str = Field(..., min_length=20)


# ---------------------------------------------------------------------------
# Discriminated union — `LucidityPayload` RootModel keyed on `level`.
# ---------------------------------------------------------------------------


LucidityPayload = RootModel[
    Annotated[
        Union[
            L1ChiffrePayload,
            L2ComparePayload,
            L3EclairePayload,
            L4InvariantPayload,
        ],
        Field(discriminator="level"),
    ]
]
"""Discriminated union over `level`. Use `LucidityPayload.model_validate({...})`
to route an arbitrary lucidity dict to its typed payload class. W2 compute
services emit `data["lucidity"] = <Payload>.model_dump()` inside the
`CoachToolOk.data` envelope (per D-CE-04 inheritance from Wave 1c-A3).
"""
