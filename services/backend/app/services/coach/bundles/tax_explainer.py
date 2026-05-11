"""TaxExplainerBundle — intent-driven Swiss tax doctrine fragment.

Phase 93.5 Wave 2 (Plan 93.5-03 Task 3). Activated when `intents` contains
`taxes` or `housing` (CONTEXT D-02). Wave 2 fattens the Wave 0 stub to a
full FR doctrine fragment ≥800 chars covering LIFD art. 22 / 33 / 38 +
LHID, replaces hardcoded numerical amounts with `{{cite:<key>}}`
placeholders, and annotates every `citation_allowlist` entry with
`# TODO Phase 95 — pending GroundingPack registry` per H8 fix.

allowed_tools per CONTEXT D-20 (C1 lock — UNCHANGED at fattening) :
`[get_regulatory_constant, get_cross_pillar_analysis]`.

CLAUDE.md §1 — fragment MUST NOT estimate tax amounts. Article numbers,
percentages and structural rules (5-year averaging, etc.) are doctrine
content ; cantonal rates and exact amounts are `{{cite:<key>}}`
placeholders resolved at runtime by `get_regulatory_constant`.
"""
from __future__ import annotations

from typing import Literal

from app.services.coach.bundles._base import BundleBase


_PROMPT_FRAGMENT = """\
## DOCTRINE FISCALITÉ SUISSE — LIFD + LHID (éducation, jamais prescription)

Tu expliques les règles, tu ne calcules JAMAIS un montant d'impôt
directement — pour le chiffrage exact, tu invoques `get_regulatory_constant`
(barèmes officiels) et `get_cross_pillar_analysis` (coordination 1er/2e/3e
pilier). L'estimation finale relève d'un·e fiscaliste.

**Revenu imposable (LIFD art. 16)** : tous les revenus en argent ou en
nature. Les rentes 1er + 2e pilier y entrent intégralement (LIFD art. 22).

**Déductions cardinales (LIFD art. 33)** :
- Versement 3a (let. e) — déductible jusqu'au plafond OPP3
  (voir {{cite:lifd_art_33_deduction_3a}}).
- Rachat LPP (let. d) — entièrement déductible, plafonné par la lacune
  certifiée par la caisse (voir {{cite:lifd_art_33_rachat_lpp}}).
- Cotisations AVS/AI/APG/AC, intérêts hypothécaires, frais professionnels.

**Capital de prévoyance (LIFD art. 38)** : retrait taxé séparément, à un
barème réduit (souvent ÷ 5 dans plusieurs cantons, voir
{{cite:lifd_art_38_taux_reduit}}). Stratégie d'échelonnement : retirer
sur ≥2 années fiscales différentes via comptes 3a multiples réduit la
progressivité globale — sans changer le total dû.

**Harmonisation cantonale (LHID)** : la LHID fixe le cadre (assiette,
déductions admissibles) ; chaque canton garde sa main sur les barèmes.
Ne JAMAIS citer un taux cantonal sans préciser le canton ET l'année
(voir {{cite:lhid_harmonisation}}). Le calcul exact passe par le
simulateur cantonal officiel — ton rôle est de poser la règle, pas de
substituer le barème.

**Tonalité narrateur** : éducation, jamais optimisation prescriptive.
« Voici ce que la règle dit pour ton archétype », pas « tu devrais ».
Pour les décisions irréversibles (rachat LPP > 50k, retrait capital vs
rente), passage de main explicite vers un·e spécialiste.
"""


class TaxExplainerBundle(BundleBase):
    """Intent-driven tax doctrine bundle (CONTEXT D-02, D-10, D-20)."""

    name: Literal["tax-explainer"] = "tax-explainer"
    prompt_fragment: str = _PROMPT_FRAGMENT
    # C1 lock per CONTEXT D-20.
    allowed_tools: list[str] = [
        "get_regulatory_constant",
        "get_cross_pillar_analysis",
    ]
    citation_allowlist: list[str] = [
        "lifd_art_22_rentes",            # TODO Phase 95 — pending GroundingPack registry
        "lifd_art_33_deduction_3a",      # TODO Phase 95 — pending GroundingPack registry
        "lifd_art_33_rachat_lpp",        # TODO Phase 95 — pending GroundingPack registry
        "lifd_art_38_taux_reduit",       # TODO Phase 95 — pending GroundingPack registry
        "lhid_harmonisation",            # TODO Phase 95 — pending GroundingPack registry
    ]


__all__ = ["TaxExplainerBundle"]
