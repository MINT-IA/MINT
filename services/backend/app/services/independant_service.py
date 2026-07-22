"""
Independant (Self-Employed Worker) Service.

S12 « segments sociologiques » service — kept as canonical alongside the S18
`app.services.independants` package. **This module is NOT a deprecated shim**
despite W0-AUDIT-MATRIX row 32 misclassification (corrected 2026-05-16 via
Plan 11 mint-calc-engine-v1 scope correction).

This module exposes the monolithic `IndependantService.analyze(IndependantInput)
-> IndependantResult` API consumed by `app.api.v1.endpoints.segments`
(/api/v1/segments/independant/simulate). The S18 package
`app.services.independants` exposes a separate **functional** API
(5 `calculer_*` functions + 5 `*Result` dataclasses, no class).
Both surfaces are correct for their respective callers — they are
**sister services**, not duplicates.

API consolidation (monolithic class vs functional split) is deferred —
see `.planning/deferred-items.md` entry « S12-API-consolidation ».

Provides analysis of social security coverage, contribution calculations,
and protection gap identification for self-employed workers in Switzerland.

Sources:
    - LAVS art. 8 (cotisations independants: ~10.6%, bareme degressif)
    - LAVS art. 9 (revenu determinant)
    - OPP3 art. 7 (3a grand plafond: 20% du revenu net, max 36'288 CHF)
    - LPP art. 4 (affiliation volontaire pour independants)
    - LAA art. 4 (assurance accident obligatoire salaries, facultative independants)
    - LCA (assurance IJM: perte de gain maladie, pas d'obligation legale)
    - LAPG art. 1a (allocations perte de gain: service militaire, maternite)

Ethical requirements:
    - Gender-neutral language throughout
    - NEVER use "garanti", "assure" (sens de garantie), "certain"
    - All recommendations include a source reference
    - Mandatory disclaimer on every response
"""

from dataclasses import dataclass
from typing import List

from app.services.independants.avs_cotisations_service import (  # noqa: F401
    calculer_cotisation_avs,
)
from app.constants.social_insurance import (
    AVS_AGE_REFERENCE_HOMME as RETIREMENT_AGE,
    PILIER_3A_PLAFOND_AVEC_LPP as PLAFOND_3A_SALARIE,
    PILIER_3A_PLAFOND_SANS_LPP as PLAFOND_3A_INDEPENDANT_MAX,
    PILIER_3A_TAUX_REVENU_SANS_LPP as PLAFOND_3A_INDEPENDANT_TAUX,
)


# ---------------------------------------------------------------------------
# Phase mint-data-architecture-v1-02 W0 Plan 02-01 (D-08 composition pattern)
# ---------------------------------------------------------------------------
# IJM/LAA market-estimate rates moved to the S18 single source of truth
# `app.services.independants.indemnity_rates`. The S12 `IndependantService`
# kept here is the canonical façade per the W0-AUDIT-MATRIX row 32 correction
# (2026-05-16, Plan 11 mint-calc-engine-v1 scope correction) — calculator
# primitives delegate to S18, but the S12 monolithic API surface remains.
# The re-exports below preserve the public surface of this module so any
# `from app.services.independant_service import IJM_ESTIMATE_RATE` caller
# stays green.
from app.services.independants.indemnity_rates import (  # noqa: E402
    IJM_ESTIMATE_RATE,
    LAA_ESTIMATE_RATE,
)

# AVS: the duplicated local bracket table (audit T02-F17, MINT_nosync-iy5)
# was a stale pre-2020 scale diverging from the official one by up to +21%.
# calculate_avs_contribution now delegates to the S18 single source
# `calculer_cotisation_avs` (RAVS art. 21 scale in social_insurance.py).


# ---------------------------------------------------------------------------
# Data classes
# ---------------------------------------------------------------------------

@dataclass
class IndependantInput:
    """Input data for self-employed worker analysis."""
    revenu_net: float              # Net income from self-employment
    age: int
    a_lpp_volontaire: bool         # Has voluntary LPP affiliation
    a_3a: bool                     # Has a 3a account
    a_ijm: bool                    # Has IJM (income protection insurance)
    a_laa: bool                    # Has LAA (accident insurance)
    canton: str                    # Canton code


@dataclass
class IndependantResult:
    """Result of self-employed worker analysis."""
    cotisations_avs: float
    plafond_3a_grand: float
    cout_protection_totale: float
    lacunes_couverture: List[dict]
    recommandations: List[dict]
    urgences: List[dict]
    checklist: List[dict]
    disclaimer: str


# ---------------------------------------------------------------------------
# Disclaimer
# ---------------------------------------------------------------------------

DISCLAIMER = (
    "Outil educatif — ne constitue pas un conseil (LSFin). "
    "Cette analyse est indicative et basee sur des taux moyens. "
    "Les cotisations AVS exactes dependent de votre caisse de compensation. "
    "Les primes IJM et LAA varient selon l'assureur et votre activite. "
    "Consultez votre caisse de compensation et un·e specialiste en assurances "
    "pour des montants precis."
)


# ---------------------------------------------------------------------------
# Service
# ---------------------------------------------------------------------------

class IndependantService:
    """Analyse la situation sociale et de prevoyance des independants.

    Calcule les cotisations AVS, identifie les lacunes de couverture,
    et recommande les protections necessaires. Langage neutre, aucun
    terme banni.
    """

    def calculate_avs_contribution(self, revenu_net: float) -> float:
        """Calculate AVS contribution for self-employed (LAVS art. 8).

        Delegates to the S18 single source `calculer_cotisation_avs`
        (official RAVS art. 21 scale — no local duplicate table,
        audit T02-F17 / MINT_nosync-iy5).

        Args:
            revenu_net: Annual net income from self-employment.

        Returns:
            Annual AVS/AI/APG contribution in CHF.
        """
        if revenu_net <= 0:
            return 0.0
        return calculer_cotisation_avs(revenu_net).cotisation_avs_ai_apg

    def calculate_3a_plafond(self, revenu_net: float) -> float:
        """Calculate 3a grand plafond for self-employed without LPP.

        OPP3 art. 7: 20% of net income, max 36'288 CHF.

        Args:
            revenu_net: Annual net income.

        Returns:
            Maximum 3a contribution in CHF.
        """
        if revenu_net <= 0:
            return 0.0
        plafond = revenu_net * PLAFOND_3A_INDEPENDANT_TAUX
        return round(min(plafond, PLAFOND_3A_INDEPENDANT_MAX), 2)

    def estimate_ijm_cost(self, revenu_net: float) -> float:
        """Estimate IJM (income protection) insurance cost.

        Typical range: 1-3% of insured income for 720 days coverage.
        Uses 2% as middle estimate.

        Args:
            revenu_net: Annual net income.

        Returns:
            Estimated annual IJM premium in CHF.
        """
        return round(revenu_net * IJM_ESTIMATE_RATE, 2)

    def estimate_laa_cost(self, revenu_net: float) -> float:
        """Estimate LAA (accident insurance) cost.

        Typical range: 1-2% of insured income for non-professional accident.
        Uses 1.5% as middle estimate.

        Args:
            revenu_net: Annual net income.

        Returns:
            Estimated annual LAA premium in CHF.
        """
        return round(revenu_net * LAA_ESTIMATE_RATE, 2)

    def analyze(self, input_data: IndependantInput) -> IndependantResult:
        """Run comprehensive analysis for self-employed worker.

        Args:
            input_data: IndependantInput with worker details.

        Returns:
            IndependantResult with contributions, gaps, and recommendations.
        """
        revenu = input_data.revenu_net
        age = input_data.age

        # --- AVS contribution ---
        cotisations_avs = self.calculate_avs_contribution(revenu)

        # --- 3a plafond ---
        if input_data.a_lpp_volontaire:
            # With voluntary LPP: regular 3a plafond applies
            plafond_3a = PLAFOND_3A_SALARIE
        else:
            # Without LPP: grand plafond
            plafond_3a = self.calculate_3a_plafond(revenu)

        # --- Protection cost simulator ---
        ijm_cost = self.estimate_ijm_cost(revenu)
        laa_cost = self.estimate_laa_cost(revenu)
        cout_3a = plafond_3a  # Maximum annual 3a contribution

        cout_protection_totale = round(
            cotisations_avs + ijm_cost + laa_cost + cout_3a, 2
        )

        # --- Coverage gaps ---
        lacunes: List[dict] = []

        if not input_data.a_lpp_volontaire:
            lacunes.append({
                "type": "lpp",
                "titre": "Pas de LPP (2e pilier)",
                "description": (
                    "En tant qu'independant, vous n'avez pas de LPP obligatoire. "
                    "Votre prevoyance retraite repose uniquement sur l'AVS "
                    "(1er pilier) et le 3e pilier. L'AVS seule ne couvre "
                    "qu'environ 40-60% du dernier revenu."
                ),
                "severite": "haute",
                "source": "LPP art. 4",
            })

        if not input_data.a_ijm:
            lacunes.append({
                "type": "ijm",
                "titre": "Pas d'assurance perte de gain maladie (IJM)",
                "description": (
                    "LACUNE CRITIQUE: en cas de maladie, vous n'avez aucune "
                    "couverture de remplacement de revenu. Contrairement aux "
                    "salaries, il n'y a pas d'obligation legale pour "
                    "l'employeur. Une maladie de longue duree peut avoir "
                    "des consequences financieres severes."
                ),
                "severite": "critique",
                "source": "LCA (pas d'obligation legale pour independants)",
            })

        if not input_data.a_laa:
            lacunes.append({
                "type": "laa",
                "titre": "Pas d'assurance accident (LAA)",
                "description": (
                    "En tant qu'independant, l'assurance accident n'est pas "
                    "obligatoire. Vous n'etes couvert que par votre assurance "
                    "maladie de base (LAMal) en cas d'accident, ce qui peut "
                    "etre insuffisant pour la perte de gain."
                ),
                "severite": "haute",
                "source": "LAA art. 4",
            })

        if not input_data.a_3a:
            lacunes.append({
                "type": "3a",
                "titre": "Pas de 3e pilier",
                "description": (
                    f"Vous n'avez pas de 3e pilier. En tant qu'independant "
                    f"sans LPP, le 3a est votre principal outil de "
                    f"prevoyance complementaire. Le plafond est de "
                    f"CHF {plafond_3a:,.0f}/an."
                ),
                "severite": "haute",
                "source": "OPP3 art. 7",
            })

        # --- Urgences ---
        urgences: List[dict] = []

        if not input_data.a_ijm:
            urgences.append({
                "id": "ijm_urgence",
                "titre": "Souscrire une assurance perte de gain maladie",
                "description": (
                    "PRIORITE ABSOLUE: sans IJM, une maladie de quelques "
                    "semaines peut mettre en peril votre activite et vos "
                    "finances. Souscrivez une couverture d'au moins 720 jours "
                    "avec un delai d'attente de 30-60 jours."
                ),
                "cout_estime_annuel": ijm_cost,
                "source": "LCA, bonne pratique",
                "priorite": "critique",
            })

        if not input_data.a_laa:
            urgences.append({
                "id": "laa_urgence",
                "titre": "Souscrire une assurance accident privee",
                "description": (
                    "En cas d'accident, la LAMal couvre les soins mais pas "
                    "la perte de gain. Souscrivez une assurance accident "
                    "privee pour couvrir le risque de perte de revenu."
                ),
                "cout_estime_annuel": laa_cost,
                "source": "LAA art. 4",
                "priorite": "haute",
            })

        # --- Recommendations ---
        recommandations: List[dict] = []

        if not input_data.a_lpp_volontaire:
            recommandations.append({
                "id": "lpp_volontaire",
                "titre": "Affiliation LPP volontaire",
                "description": (
                    "Envisagez une affiliation volontaire a une fondation "
                    "de prevoyance. Cela vous donne acces au 2e pilier, "
                    "avec des cotisations deductibles fiscalement et une "
                    "meilleure prevoyance retraite."
                ),
                "source": "LPP art. 4",
                "priorite": "haute",
            })

        recommandations.append({
            "id": "maximiser_3a",
            "titre": "Maximiser le 3e pilier",
            "description": (
                f"Versez le maximum annuel dans votre 3e pilier: "
                f"CHF {plafond_3a:,.0f}. "
                f"{'(grand plafond: 20% du revenu net, sans LPP)' if not input_data.a_lpp_volontaire else '(plafond salarie, avec LPP volontaire)'}. "
                f"L'economie fiscale est significative."
            ),
            "source": "OPP3 art. 7, LIFD art. 33",
            "priorite": "haute",
        })

        if age >= 40 and not input_data.a_lpp_volontaire:
            recommandations.append({
                "id": "bilan_prevoyance",
                "titre": "Bilan de prevoyance complet",
                "description": (
                    f"A {age} ans, il reste {max(0, RETIREMENT_AGE - age)} "
                    f"annees avant la retraite. Sans 2e pilier, votre "
                    f"prevoyance est limitee. Un bilan complet permet "
                    f"d'identifier les actions correctives possibles."
                ),
                "source": "LPP art. 4, LAVS art. 8",
                "priorite": "haute",
            })

        recommandations.append({
            "id": "caisse_compensation",
            "titre": "Verifier l'inscription a la caisse de compensation",
            "description": (
                "Assurez-vous d'etre inscrit aupres d'une caisse de "
                "compensation AVS. Les cotisations sont obligatoires "
                "et calculees sur votre revenu net. Un retard peut "
                "entrainer des interets moratoires."
            ),
            "source": "LAVS art. 8-9",
            "priorite": "moyenne",
        })

        # --- Checklist ---
        checklist: List[dict] = [
            {
                "item": "Inscription caisse de compensation AVS",
                "statut": "a_verifier",
                "source": "LAVS art. 8",
            },
            {
                "item": "Cotisations AVS a jour",
                "statut": "a_verifier",
                "source": "LAVS art. 8",
                "montant_estime": cotisations_avs,
            },
            {
                "item": "Assurance perte de gain maladie (IJM)",
                "statut": "ok" if input_data.a_ijm else "manquant",
                "source": "LCA",
            },
            {
                "item": "Assurance accident (LAA)",
                "statut": "ok" if input_data.a_laa else "manquant",
                "source": "LAA art. 4",
            },
            {
                "item": "2e pilier (LPP volontaire)",
                "statut": "ok" if input_data.a_lpp_volontaire else "manquant",
                "source": "LPP art. 4",
            },
            {
                "item": "3e pilier (3a)",
                "statut": "ok" if input_data.a_3a else "manquant",
                "source": "OPP3 art. 7",
                "plafond": plafond_3a,
            },
        ]

        return IndependantResult(
            cotisations_avs=cotisations_avs,
            plafond_3a_grand=plafond_3a,
            cout_protection_totale=cout_protection_totale,
            lacunes_couverture=lacunes,
            recommandations=recommandations,
            urgences=urgences,
            checklist=checklist,
            disclaimer=DISCLAIMER,
        )
