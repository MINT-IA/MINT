"""
Affordability simulator (Tragbarkeitsrechnung) for Swiss mortgage.

Calculates whether a household can afford a given property based on
Swiss bank lending rules (ASB directives, FINMA circular 2017/5):
- Minimum equity: 20% of purchase price (max 10% from 2nd pillar)
- Maximum housing costs: 33% of gross annual income
- Theoretical costs = 5% interest + 1% amortization + 1% ancillary costs

Sources:
    - Circulaire FINMA 2017/5 (hypotheques residentielles)
    - Directives ASB sur le calcul de la charge hypothecaire
    - OPP2 art. 5 (EPL: fonds propres immobiliers)

Sprint S17 — Mortgage & Real Estate.
"""

from dataclasses import dataclass, field
from typing import List

from app.constants.social_insurance import (
    HYPOTHEQUE_TAUX_THEORIQUE,
    HYPOTHEQUE_TAUX_AMORTISSEMENT,
    HYPOTHEQUE_TAUX_FRAIS_ACCESSOIRES,
    HYPOTHEQUE_RATIO_CHARGES_MAX,
    HYPOTHEQUE_FONDS_PROPRES_MIN,
    HYPOTHEQUE_PART_2E_PILIER_MAX,
)


DISCLAIMER = (
    "Estimation a titre indicatif. MINT est un outil educatif et ne constitue "
    "pas un conseil en financement immobilier au sens de la LSFin. "
    "Les conditions d'octroi varient selon les etablissements. "
    "Consultez un ou une specialiste hypothecaire pour une analyse personnalisee."
)

# Aliases for backward compatibility within this module
TAUX_THEORIQUE = HYPOTHEQUE_TAUX_THEORIQUE
TAUX_AMORTISSEMENT = HYPOTHEQUE_TAUX_AMORTISSEMENT
TAUX_FRAIS_ACCESSOIRES = HYPOTHEQUE_TAUX_FRAIS_ACCESSOIRES
RATIO_CHARGES_MAX = HYPOTHEQUE_RATIO_CHARGES_MAX
FONDS_PROPRES_MIN_PCT = HYPOTHEQUE_FONDS_PROPRES_MIN
PART_2E_PILIER_MAX = HYPOTHEQUE_PART_2E_PILIER_MAX


@dataclass
class DecompositionCharges:
    """Breakdown of theoretical monthly housing costs."""
    interets: float        # Theoretical interest (5% of mortgage / 12)
    amortissement: float   # Amortization (1% of mortgage / 12)
    frais_accessoires: float  # Ancillary costs (1% of purchase price / 12)


@dataclass
class PremierEclairage:
    """Shock figure with amount and explanatory text."""
    montant: float
    texte: str


@dataclass
class AffordabilityResult:
    """Complete result of the affordability simulation."""

    # Max affordable price based on income
    prix_max_accessible: float

    # Equity
    fonds_propres_total: float
    fonds_propres_suffisants: bool
    detail_fonds_propres: dict  # {epargne, avoir_3a, avoir_lpp, total}

    # Monthly costs
    charges_mensuelles_theoriques: float
    ratio_charges: float
    capacite_ok: bool

    # Breakdown
    decomposition_charges: DecompositionCharges

    # Mortgage amount
    montant_hypothecaire: float

    # Shock figure
    premier_eclairage: PremierEclairage

    # Metadata
    prix_achat: float
    revenu_brut_annuel: float
    canton: str

    # Compliance
    checklist: List[str] = field(default_factory=list)
    alertes: List[str] = field(default_factory=list)
    sources: List[str] = field(default_factory=list)
    disclaimer: str = DISCLAIMER


class AffordabilityService:
    """Swiss mortgage affordability calculator.

    Implements the standard Swiss bank affordability check
    (Tragbarkeitsrechnung) according to FINMA/ASB rules.

    Key formulas:
    - Mortgage = purchase_price - equity
    - Theoretical costs = mortgage * 5% + mortgage * 1% + price * 1%
    - Affordability OK if costs <= 33% of gross income
    - Max price = gross_income / (5% + 1%) * 0.80 + equity  [simplified]

    Sources:
        - Circulaire FINMA 2017/5
        - Directives ASB
    """

    def calculate_affordability(
        self,
        revenu_brut_annuel: float,
        epargne_disponible: float,
        avoir_3a: float = 0.0,
        avoir_lpp: float = 0.0,
        prix_achat: float = 0.0,
        canton: str = "ZH",
    ) -> AffordabilityResult:
        """Calculate mortgage affordability.

        Args:
            revenu_brut_annuel: Gross annual income (CHF).
            epargne_disponible: Available savings / cash equity (CHF).
            avoir_3a: Pillar 3a assets available for EPL (CHF).
            avoir_lpp: LPP assets available for EPL (CHF).
            prix_achat: Target purchase price (CHF). If 0, only max price is computed.
            canton: Canton code (for context, not used in base calculation).

        Returns:
            AffordabilityResult with complete analysis.
        """
        # Sanitize inputs
        revenu_brut_annuel = max(0.0, revenu_brut_annuel)
        epargne_disponible = max(0.0, epargne_disponible)
        avoir_3a = max(0.0, avoir_3a)
        avoir_lpp = max(0.0, avoir_lpp)
        prix_achat = max(0.0, prix_achat)
        canton = (canton.upper() if canton else "ZH")[:2]

        # 1. Non-LPP equity (hard equity)
        fp_base = epargne_disponible + avoir_3a

        # 2. Max affordable price: solve LPP circular dependency algebraically.
        #    LPP can contribute max 10% of purchase price as equity.
        #    Total equity = fp_base + min(avoir_lpp, prix_max * 10%).
        #    Required equity = prix_max * 20%.
        #
        #    Case A: LPP >= prix_max * 10% (LPP covers full 2nd-rank equity)
        #      => fp_total = fp_base + prix_max * 0.10
        #      => prix_max = fp_total / 0.20 = (fp_base + prix_max * 0.10) / 0.20
        #      => prix_max * 0.20 = fp_base + prix_max * 0.10
        #      => prix_max * 0.10 = fp_base
        #      => prix_max = fp_base / 0.10
        #
        #    Case B: LPP < prix_max * 10% (all LPP is used but not enough)
        #      => fp_total = fp_base + avoir_lpp
        #      => prix_max = fp_total / 0.20 = (fp_base + avoir_lpp) / 0.20

        # Solve for max price from equity constraint
        if FONDS_PROPRES_MIN_PCT > 0:
            # Case A: assumes LPP covers full 10% contribution
            denominator = FONDS_PROPRES_MIN_PCT - PART_2E_PILIER_MAX
            if denominator <= 0:
                prix_max_case_a = 0.0  # Safety: impossible equity split
            else:
                prix_max_case_a = fp_base / denominator  # fp_base / 0.10
            # Check if LPP actually covers 10% at this price
            if avoir_lpp >= prix_max_case_a * PART_2E_PILIER_MAX:
                prix_max_equity = prix_max_case_a
            else:
                # Case B: all LPP is used
                prix_max_equity = (fp_base + avoir_lpp) / FONDS_PROPRES_MIN_PCT
        else:
            prix_max_equity = 0.0

        # Compute the effective fonds propres at prix_max_equity
        lpp_at_max = min(avoir_lpp, prix_max_equity * PART_2E_PILIER_MAX)
        fonds_propres_total = fp_base + lpp_at_max

        # 3. Max affordable price based on income (capacity constraint)
        #    Theoretical annual costs = mortgage * (5% + 1%) + price * 1%
        #    = (price - equity) * 6% + price * 1%
        #    = price * 7% - equity * 6%
        #    Max costs = income * 33.33%
        #    => price <= (income * 33.33% + equity * 6%) / 7%
        if revenu_brut_annuel > 0:
            prix_max_income = (revenu_brut_annuel * RATIO_CHARGES_MAX
                               + fonds_propres_total * (TAUX_THEORIQUE + TAUX_AMORTISSEMENT)) / (
                TAUX_THEORIQUE + TAUX_AMORTISSEMENT + TAUX_FRAIS_ACCESSOIRES
            )
            prix_max_income = round(prix_max_income, 2)
        else:
            prix_max_income = 0.0

        prix_max = round(min(prix_max_income, prix_max_equity), 2)

        # 4. If a target price is given, calculate specifics
        if prix_achat > 0:
            # 2nd pillar cap: max 10% of purchase price
            lpp_utilisable = min(avoir_lpp, prix_achat * PART_2E_PILIER_MAX)
            fonds_propres_effectifs = fp_base + lpp_utilisable
            fonds_propres_total = fonds_propres_effectifs

            fonds_propres_requis = prix_achat * FONDS_PROPRES_MIN_PCT
            fonds_propres_suffisants = fonds_propres_total >= fonds_propres_requis

            montant_hypothecaire = max(0.0, prix_achat - fonds_propres_effectifs)
        else:
            # No target price: use max price
            prix_achat_calc = prix_max
            lpp_utilisable = min(avoir_lpp, prix_achat_calc * PART_2E_PILIER_MAX)
            fonds_propres_effectifs = fp_base + lpp_utilisable
            fonds_propres_total = fonds_propres_effectifs

            fonds_propres_requis = prix_achat_calc * FONDS_PROPRES_MIN_PCT
            fonds_propres_suffisants = fonds_propres_total >= fonds_propres_requis
            montant_hypothecaire = max(0.0, prix_achat_calc - fonds_propres_effectifs)

        # 4. Theoretical monthly costs
        interets_annuels = montant_hypothecaire * TAUX_THEORIQUE
        amortissement_annuel = montant_hypothecaire * TAUX_AMORTISSEMENT
        frais_accessoires_annuels = (prix_achat if prix_achat > 0 else prix_max) * TAUX_FRAIS_ACCESSOIRES

        charges_annuelles = interets_annuels + amortissement_annuel + frais_accessoires_annuels
        charges_mensuelles = round(charges_annuelles / 12, 2)

        decomposition = DecompositionCharges(
            interets=round(interets_annuels / 12, 2),
            amortissement=round(amortissement_annuel / 12, 2),
            frais_accessoires=round(frais_accessoires_annuels / 12, 2),
        )

        # 5. Ratio
        if revenu_brut_annuel > 0:
            ratio_charges = round(charges_annuelles / revenu_brut_annuel, 4)
        else:
            ratio_charges = 1.0 if charges_annuelles > 0 else 0.0

        capacite_ok = ratio_charges <= RATIO_CHARGES_MAX

        # 6. Chiffre choc
        if prix_achat > 0:
            if capacite_ok and fonds_propres_suffisants:
                gap_ou_marge = round(
                    (revenu_brut_annuel * RATIO_CHARGES_MAX - charges_annuelles) / 12, 2
                )
                premier_eclairage = PremierEclairage(
                    montant=gap_ou_marge,
                    texte=(
                        f"Bonne nouvelle : il te reste {gap_ou_marge:.0f} CHF/mois "
                        f"de marge apres les charges hypothecaires theoriques."
                    ),
                )
            else:
                if not fonds_propres_suffisants:
                    gap_fp = round(fonds_propres_requis - fonds_propres_total, 2)
                    premier_eclairage = PremierEclairage(
                        montant=gap_fp,
                        texte=(
                            f"Il te manque {gap_fp:.0f} CHF de fonds propres "
                            f"pour atteindre les 20% requis."
                        ),
                    )
                else:
                    revenu_requis = round(charges_annuelles / RATIO_CHARGES_MAX, 2)
                    gap_revenu = round(revenu_requis - revenu_brut_annuel, 2)
                    premier_eclairage = PremierEclairage(
                        montant=gap_revenu,
                        texte=(
                            f"Il te faudrait {gap_revenu:.0f} CHF de revenu brut "
                            f"supplementaire par an pour que la capacite soit validee."
                        ),
                    )
        else:
            premier_eclairage = PremierEclairage(
                montant=prix_max,
                texte=(
                    f"Avec ton revenu et tes fonds propres, tu peux viser un bien "
                    f"jusqu'a {prix_max:,.0f} CHF."
                ),
            )

        # 7. Checklist
        checklist = self._generate_checklist(
            prix_achat, fonds_propres_suffisants, capacite_ok, avoir_lpp > 0
        )

        # 8. Alertes
        alertes = self._generate_alertes(
            prix_achat, fonds_propres_total, fonds_propres_requis if prix_achat > 0 else 0,
            ratio_charges, capacite_ok, fonds_propres_suffisants,
            avoir_lpp, lpp_utilisable,
        )

        # 9. Sources
        sources = [
            "Circulaire FINMA 2017/5 (hypotheques residentielles)",
            "Directives ASB sur l'octroi hypothecaire",
            "OPP2 art. 5 (EPL: fonds propres immobiliers)",
            "Taux theorique de 5% utilise pour le calcul de capacite (pratique bancaire suisse)",
        ]

        return AffordabilityResult(
            prix_max_accessible=prix_max,
            fonds_propres_total=round(fonds_propres_total, 2),
            fonds_propres_suffisants=fonds_propres_suffisants,
            detail_fonds_propres={
                "epargne": round(epargne_disponible, 2),
                "avoir_3a": round(avoir_3a, 2),
                "avoir_lpp": round(lpp_utilisable, 2),
                "total": round(fonds_propres_effectifs, 2),
            },
            charges_mensuelles_theoriques=charges_mensuelles,
            ratio_charges=ratio_charges,
            capacite_ok=capacite_ok,
            decomposition_charges=decomposition,
            montant_hypothecaire=round(montant_hypothecaire, 2),
            premier_eclairage=premier_eclairage,
            prix_achat=prix_achat if prix_achat > 0 else prix_max,
            revenu_brut_annuel=revenu_brut_annuel,
            canton=canton,
            checklist=checklist,
            alertes=alertes,
            sources=sources,
            disclaimer=DISCLAIMER,
        )

    def _generate_checklist(
        self,
        prix_achat: float,
        fonds_propres_ok: bool,
        capacite_ok: bool,
        utilise_lpp: bool,
    ) -> List[str]:
        """Generate the affordability checklist."""
        items: List[str] = []

        items.append(
            "Verifier que les fonds propres couvrent au moins 20% du prix d'achat "
            "(directives ASB)."
        )
        items.append(
            "S'assurer que les charges hypothecaires theoriques (taux 5%) "
            "ne depassent pas 33% du revenu brut."
        )

        if utilise_lpp:
            items.append(
                "Attention : le 2e pilier (LPP) ne peut couvrir que max 10% "
                "du prix d'achat en fonds propres (OPP2 art. 5)."
            )
            items.append(
                "Un retrait EPL du 2e pilier reduit les prestations de risque "
                "(deces, invalidite). Envisager une assurance complementaire."
            )

        items.append(
            "Comparer au moins 3 offres d'etablissements differents "
            "(banques, assurances, caisses de pension)."
        )

        items.append(
            "Prevoir une reserve de liquidites apres l'achat "
            "(recommandation : 3-6 mois de charges)."
        )

        if not fonds_propres_ok:
            items.append(
                "Explorer les possibilites d'augmenter les fonds propres : "
                "epargne supplementaire, retrait 3a, avance d'hoirie, donation."
            )

        if not capacite_ok:
            items.append(
                "La capacite est insuffisante. Options : prix d'achat inferieur, "
                "augmenter les fonds propres, augmenter le revenu du menage."
            )

        return items

    def _generate_alertes(
        self,
        prix_achat: float,
        fonds_propres_total: float,
        fonds_propres_requis: float,
        ratio_charges: float,
        capacite_ok: bool,
        fonds_propres_ok: bool,
        avoir_lpp: float,
        lpp_utilisable: float,
    ) -> List[str]:
        """Generate alerts for the affordability simulation."""
        alertes: List[str] = []

        if prix_achat > 0 and not fonds_propres_ok:
            gap = round(fonds_propres_requis - fonds_propres_total, 2)
            alertes.append(
                f"Fonds propres insuffisants : il manque {gap:,.0f} CHF "
                f"pour atteindre les 20% requis ({fonds_propres_requis:,.0f} CHF)."
            )

        if not capacite_ok:
            alertes.append(
                f"Capacite depassee : le ratio de charges est de "
                f"{ratio_charges * 100:.1f}% (max 33.3%). "
                f"Les banques refuseront probablement le financement."
            )

        if avoir_lpp > 0 and avoir_lpp > lpp_utilisable:
            alertes.append(
                f"Seuls {lpp_utilisable:,.0f} CHF du 2e pilier sont utilisables "
                f"comme fonds propres (max 10% du prix d'achat). "
                f"Le solde de {avoir_lpp - lpp_utilisable:,.0f} CHF ne peut "
                f"pas etre compte."
            )

        if ratio_charges > 0.30 and capacite_ok:
            alertes.append(
                f"Attention : le ratio de charges ({ratio_charges * 100:.1f}%) "
                f"est proche du maximum de 33.3%. Peu de marge de securite."
            )

        return alertes
