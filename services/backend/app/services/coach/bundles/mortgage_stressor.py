"""MortgageStressorBundle — intent-driven mortgage / debt-stress doctrine.

Phase 93.5 Wave 2 (Plan 93.5-03 Task 2). Activated when `intents` contains
`housing` or `debt` (CONTEXT D-02). Wave 2 fattens the Wave 0 stub into a
full FR doctrine fragment ≥800 chars, replaces hardcoded CHF amounts /
percentages with `{{cite:<key>}}` placeholders, and annotates every
`citation_allowlist` entry with a `# TODO Phase 95 — pending GroundingPack
registry` inline comment per H8 fix.

allowed_tools per CONTEXT D-20 :
`[get_budget_status, get_cap_status, get_regulatory_constant]`. The fattening
ENRICHES the prompt fragment ; the tool registry is unchanged (C1 lock).

The fragment INCLUDES the `{safe_mode_protocol}` slot. `_build_prompt`
(`claude_coach_service.py:788-796`) interpolates `_SAFE_MODE_PROTOCOL`
when `ctx.has_debt is True`, otherwise the slot becomes the empty string.
This keeps the bundle inert when no debt stress is detected.

CLAUDE.md §1 — `_PROMPT_FRAGMENT` MUST NOT re-implement calculations or
hard-code amounts. The numeric values (taux calculatoire FINMA, plafond
LTV, etc.) are referenced via `{{cite:<key>}}` Phase-94 placeholders. The
tools `get_budget_status` / `get_cap_status` / `get_regulatory_constant`
are the source of truth for runtime numbers.
"""
from __future__ import annotations

from typing import Literal

from app.services.coach.bundles._base import BundleBase


_PROMPT_FRAGMENT = """\
## DOCTRINE HYPOTHÈQUE — TENABILITÉ FINMA / LCB (Tragbarkeit)

Trois règles non-négociables tirées de l'autorégulation bancaire FINMA
(Lignes directrices ASB sur la tenabilité — Tragbarkeit) :

**Règle des 33% (Tragbarkeit)** : la charge théorique mensuelle ne doit
pas dépasser 33% du revenu brut du ménage. La charge additionne intérêt
calculatoire FINMA (taux long-terme prudentiel, voir
{{cite:finma_taux_calculatoire}}), amortissement obligatoire jusqu'à 65%
LTV en 15 ans (voir {{cite:amortissement_taux_2026}}), et frais
d'entretien forfaitaires (~1% de la valeur du bien). Au-delà,
la banque refuse — c'est la règle mécanique, pas MINT qui décide.

**Règle LTV (Loan-to-Value)** : la dette hypothécaire ne peut excéder 80%
de la valeur du bien. Le client apporte au minimum 20% de fonds propres,
dont au moins 10% en cash « dur » hors avoirs LPP. Le solde peut venir
du 2e ou 3e pilier (nantissement ou retrait EPL).

**Nantissement 3a / LPP** : mobilise les avoirs prévoyance sans les
retirer. Avantage — pas d'impôt de retrait, le filet retraite reste
intact. Inconvénient — l'établissement bloque les avoirs en gage tant
que le crédit court.

**Retrait anticipé EPL** (LPP art. 30c) : permis depuis le 3a et la part
LPP obligatoire. Imposé à barème séparé (LIFD art. 38, taux ÷ 5 dans
plusieurs cantons). Si un rachat LPP volontaire a eu lieu dans les 3
dernières années, l'EPL est BLOQUÉ (LPP art. 79b al. 3) — vérifie le
certificat de prévoyance avant de proposer ce levier.

**Tonalité narrateur** : tu poses les chiffres, tu n'évalues PAS de
banque. Tu ne calcules JAMAIS un montant directement. Tu invoques
`get_budget_status`, `get_cap_status`, `get_regulatory_constant`. Pour
la signature, tu renvoies à un·e spécialiste — irréversible = passage
de main.

{safe_mode_protocol}
"""


class MortgageStressorBundle(BundleBase):
    """Intent-driven mortgage doctrine bundle (CONTEXT D-02, D-10, D-20)."""

    name: Literal["mortgage-stressor"] = "mortgage-stressor"
    prompt_fragment: str = _PROMPT_FRAGMENT
    # C1 lock per CONTEXT D-20 — only the 3 real names from coach_tools.py:637-730.
    allowed_tools: list[str] = [
        "get_budget_status",
        "get_cap_status",
        "get_regulatory_constant",
    ]
    citation_allowlist: list[str] = [
        "finma_taux_calculatoire",        # TODO Phase 95 — pending GroundingPack registry
        "amortissement_taux_2026",        # TODO Phase 95 — pending GroundingPack registry
        "finma_lcb_tragbarkeit",          # TODO Phase 95 — pending GroundingPack registry
        "ltv_max_residence_principale",   # TODO Phase 95 — pending GroundingPack registry
        "ratio_endettement_max_33pct",    # TODO Phase 95 — pending GroundingPack registry
    ]


__all__ = ["MortgageStressorBundle"]
