"""
Donation Service — Donation entre vifs.

Simulates the financial and legal impact of a donation (inter vivos gift)
in Switzerland, including cantonal donation tax, reserve hereditaire
(protected shares for heirs), quotite disponible, and avancement d'hoirie.

Sources:
    - CC art. 239-252 (donation entre vifs)
    - CC art. 457-466 (ordre des heritiers legaux)
    - CC art. 470-471 (reserves hereditaires, reforme 2023)
    - CC art. 626 (rapport des donations / avancement d'hoirie)
    - CC art. 527 (reduction des donations excessives)
    - Lois cantonales sur l'impot sur les donations
    - CO art. 243-244 (forme de la donation)

Key changes in 2023 revision (reserves):
    - Descendants reserve: reduced from 3/4 to 1/2 of legal share
    - Parents reserve: COMPLETELY REMOVED
    - Quotite disponible: increased accordingly

Ethical requirements:
    - Gender-neutral: no assumptions based on gender
    - Educational tone, never prescriptive
    - No banned terms: garanti, certain, assure, sans risque, optimal, meilleur, parfait
"""

from dataclasses import dataclass
from typing import List, Dict


# ══════════════════════════════════════════════════════════════════════════════
# Constants
# ══════════════════════════════════════════════════════════════════════════════

DISCLAIMER: str = (
    "Cet outil educatif fournit une estimation indicative et ne constitue "
    "pas un conseil financier, fiscal ou juridique au sens de la LSFin. "
    "Les taux d'imposition sur les donations varient selon le canton, "
    "le lien de parente et le montant. Consulte un·e specialiste "
    "(notaire, avocat·e en droit successoral) pour ta situation concrete."
)

SOURCES: List[str] = [
    "CC art. 239-252 (donation entre vifs)",
    "CC art. 470-471 (reserves hereditaires, revision 2023)",
    "CC art. 626 (rapport des donations / avancement d'hoirie)",
    "CC art. 527 (reduction des donations excessives)",
    "CO art. 243-244 (forme de la donation)",
    "Lois cantonales sur l'impot sur les donations",
]

# Tax rates on donations by canton and relationship.
# Many cantons exempt spouse and direct descendants.
# Concubins and third parties pay the highest rates.
TAUX_DONATION_CANTONAL: Dict[str, Dict[str, float]] = {
    "ZH": {
        "conjoint": 0.0, "descendant": 0.0, "parent": 0.0,
        "fratrie": 0.06, "concubin": 0.18, "tiers": 0.24,
    },
    "BE": {
        "conjoint": 0.0, "descendant": 0.0, "parent": 0.0,
        "fratrie": 0.06, "concubin": 0.18, "tiers": 0.24,
    },
    "VD": {
        "conjoint": 0.0, "descendant": 0.0, "parent": 0.05,
        "fratrie": 0.07, "concubin": 0.25, "tiers": 0.25,
    },
    "GE": {
        "conjoint": 0.0, "descendant": 0.0, "parent": 0.0,
        "fratrie": 0.10, "concubin": 0.24, "tiers": 0.30,
    },
    "LU": {
        "conjoint": 0.0, "descendant": 0.0, "parent": 0.0,
        "fratrie": 0.08, "concubin": 0.20, "tiers": 0.25,
    },
    "BS": {
        "conjoint": 0.0, "descendant": 0.0, "parent": 0.0,
        "fratrie": 0.08, "concubin": 0.22, "tiers": 0.28,
    },
    "SZ": {
        "conjoint": 0.0, "descendant": 0.0, "parent": 0.0,
        "fratrie": 0.0, "concubin": 0.0, "tiers": 0.0,
    },
    "OW": {
        "conjoint": 0.0, "descendant": 0.0, "parent": 0.0,
        "fratrie": 0.0, "concubin": 0.0, "tiers": 0.0,
    },
}

# Default rates for cantons not explicitly listed
TAUX_DONATION_DEFAULT: Dict[str, float] = {
    "conjoint": 0.0, "descendant": 0.0, "parent": 0.02,
    "fratrie": 0.08, "concubin": 0.20, "tiers": 0.25,
}

# Reserve hereditaire rates (CC art. 470-471, revision 2023)
# These are the fraction of the LEGAL share that is protected.
RESERVES_2023: Dict[str, float] = {
    "descendant": 0.50,    # 50% of legal share (was 75% before 2023)
    "conjoint": 0.50,      # 50% of legal share (unchanged)
    "parent": 0.0,         # NO reserve since 2023 (was 50% before)
}


# ══════════════════════════════════════════════════════════════════════════════
# Data classes
# ══════════════════════════════════════════════════════════════════════════════

@dataclass
class DonationInput:
    """Input data for donation simulation."""
    montant: float                                     # Donation amount
    donateur_age: int                                  # Donor age
    lien_parente: str                                  # Relationship to donor
    canton: str                                        # Canton code
    type_donation: str = "especes"                     # "especes", "immobilier", "titres"
    valeur_immobiliere: float = 0.0                    # Property value if real estate
    avancement_hoirie: bool = True                     # Advance on inheritance? (default for descendants)
    nb_enfants: int = 0                                # Number of donor's children
    fortune_totale_donateur: float = 0.0               # Total estate of donor
    regime_matrimonial: str = "participation_acquets"   # Matrimonial regime
    has_spouse: bool = False                            # Whether donor has a spouse
    has_parents: bool = False                           # Whether donor's parents are alive


@dataclass
class DonationResult:
    """Result of donation simulation."""
    montant_donation: float                            # Donation amount
    taux_imposition: float                             # Tax rate
    impot_donation: float                              # Tax amount
    reserve_hereditaire_totale: float                  # Total reserved shares
    quotite_disponible: float                          # Freely disposable share
    donation_depasse_quotite: bool                     # Whether donation exceeds quotite
    montant_depassement: float                         # Excess amount
    impact_succession: str                             # Impact description
    checklist: List[str]                               # Action items
    alerts: List[str]                                  # Warning messages
    disclaimer: str                                    # Legal disclaimer
    sources: List[str]                                 # Legal references
    chiffre_choc: dict                                 # Impact number


# ══════════════════════════════════════════════════════════════════════════════
# Service
# ══════════════════════════════════════════════════════════════════════════════

class DonationService:
    """Simulate the financial and legal impact of a donation in Switzerland.

    Covers:
    - Cantonal donation tax (by relationship and canton)
    - Reserve hereditaire (2023 law) and quotite disponible
    - Avancement d'hoirie (CC art. 626)
    - Impact on future succession
    - Real estate specific rules

    Compliance: NEVER use "garanti", "assure", "certain", "sans risque".
    """

    def calculate(self, input_data: DonationInput) -> DonationResult:
        """Run the full donation simulation.

        Args:
            input_data: DonationInput with donation and family data.

        Returns:
            DonationResult with tax, reserves, and compliance outputs.
        """
        # Tax
        taux = self._get_tax_rate(input_data.canton, input_data.lien_parente)
        impot = self._compute_tax(input_data.montant, taux)

        # Reserve and quotite disponible
        legal_shares = self._compute_legal_shares(input_data)
        reserve_totale = self._compute_reserve_totale(
            input_data, legal_shares
        )
        quotite_disponible = self._compute_quotite_disponible(
            input_data.fortune_totale_donateur, reserve_totale
        )

        # Check if donation exceeds quotite disponible
        donation_depasse, depassement = self._check_depassement(
            input_data, quotite_disponible
        )

        # Impact on succession
        impact = self._compute_impact_succession(input_data, donation_depasse)

        # Compliance outputs
        checklist = self._generate_checklist(input_data, taux)
        alerts = self._generate_alerts(
            input_data, taux, donation_depasse, depassement, quotite_disponible,
        )
        chiffre_choc = self._generate_chiffre_choc(
            input_data.montant, impot, taux, input_data.lien_parente,
        )

        return DonationResult(
            montant_donation=round(input_data.montant, 2),
            taux_imposition=taux,
            impot_donation=round(impot, 2),
            reserve_hereditaire_totale=round(reserve_totale, 2),
            quotite_disponible=round(quotite_disponible, 2),
            donation_depasse_quotite=donation_depasse,
            montant_depassement=round(depassement, 2),
            impact_succession=impact,
            checklist=checklist,
            alerts=alerts,
            disclaimer=DISCLAIMER,
            sources=SOURCES,
            chiffre_choc=chiffre_choc,
        )

    # ------------------------------------------------------------------
    # Private computation methods
    # ------------------------------------------------------------------

    def _get_tax_rate(self, canton: str, lien_parente: str) -> float:
        """Get donation tax rate for a given canton and relationship.

        Args:
            canton: Canton code (e.g. "GE", "VD", "ZH", "SZ").
            lien_parente: Relationship ("conjoint", "descendant", "parent",
                          "fratrie", "concubin", "tiers").

        Returns:
            Tax rate as decimal (e.g. 0.24 for 24%).
        """
        canton_rates = TAUX_DONATION_CANTONAL.get(canton, TAUX_DONATION_DEFAULT)
        return canton_rates.get(lien_parente, canton_rates.get("tiers", 0.25))

    def _compute_tax(self, montant: float, taux: float) -> float:
        """Compute donation tax amount.

        impot = montant * taux

        Returns:
            Tax amount (>= 0).
        """
        if montant <= 0 or taux <= 0:
            return 0.0
        return round(montant * taux, 2)

    def _compute_legal_shares(self, data: DonationInput) -> Dict[str, float]:
        """Compute legal shares (parts legales) per CC art. 457-462.

        The legal share depends on which heirs exist:
        - Spouse + children: spouse 1/2, children 1/2
        - Spouse + parents (no children): spouse 3/4, parents 1/4
        - Spouse alone: spouse 1.0
        - Children alone: children 1.0
        - Parents alone: parents 1.0

        Returns:
            dict mapping heir category to share percentage.
        """
        has_spouse = data.has_spouse
        has_children = data.nb_enfants > 0
        has_parents = data.has_parents

        if has_spouse and has_children:
            return {"conjoint": 0.50, "descendants": 0.50}
        elif has_spouse and not has_children and has_parents:
            return {"conjoint": 0.75, "parents": 0.25}
        elif has_spouse and not has_children and not has_parents:
            return {"conjoint": 1.0}
        elif not has_spouse and has_children:
            return {"descendants": 1.0}
        elif not has_spouse and not has_children and has_parents:
            return {"parents": 1.0}
        else:
            # No protected heirs
            return {}

    def _compute_reserve_totale(
        self, data: DonationInput, legal_shares: Dict[str, float]
    ) -> float:
        """Compute total reserve hereditaire (protected shares).

        NEW LAW 2023 (CC art. 470-471):
        - Descendants reserve: 1/2 of their legal share
        - Spouse reserve: 1/2 of their legal share
        - Parents reserve: REMOVED (0%)

        Returns:
            Total reserve amount in CHF.
        """
        fortune = data.fortune_totale_donateur
        if fortune <= 0:
            return 0.0

        total_reserve_pct = 0.0

        # Spouse reserve
        conjoint_legal = legal_shares.get("conjoint", 0.0)
        if conjoint_legal > 0:
            total_reserve_pct += conjoint_legal * RESERVES_2023["conjoint"]

        # Descendants reserve
        descendants_legal = legal_shares.get("descendants", 0.0)
        if descendants_legal > 0:
            total_reserve_pct += descendants_legal * RESERVES_2023["descendant"]

        # Parents reserve: REMOVED in 2023
        # parents_legal = legal_shares.get("parents", 0.0)
        # No reserve for parents since 2023

        return round(fortune * total_reserve_pct, 2)

    def _compute_quotite_disponible(
        self, fortune_totale: float, reserve_totale: float
    ) -> float:
        """Compute quotite disponible (freely disposable share).

        quotite_disponible = fortune_totale - reserve_totale

        Returns:
            Quotite disponible in CHF (>= 0).
        """
        return max(0.0, round(fortune_totale - reserve_totale, 2))

    def _check_depassement(
        self, data: DonationInput, quotite_disponible: float
    ) -> tuple:
        """Check if donation exceeds quotite disponible.

        A donation to a non-reserved heir (concubin, tiers) that exceeds
        the quotite disponible can be contested by reserved heirs
        (CC art. 527 — action en reduction).

        For donations to reserved heirs (descendants, spouse), the donation
        is counted against their reserve, so the excess check is different.

        Returns:
            (depasse: bool, montant_depassement: float)
        """
        # If no fortune data, we cannot check
        if data.fortune_totale_donateur <= 0:
            return (False, 0.0)

        # For descendants and spouse, donation is part of their share
        # For others, it comes from the quotite disponible
        if data.lien_parente in ("conjoint", "descendant"):
            # These heirs have a reserve; donation counted as advance
            # Only exceeds if > total share (not just QD)
            # Simplified: we check against QD for all
            pass

        if data.montant > quotite_disponible and quotite_disponible > 0:
            depassement = round(data.montant - quotite_disponible, 2)
            return (True, depassement)
        elif quotite_disponible <= 0 and data.montant > 0 and data.fortune_totale_donateur > 0:
            return (True, round(data.montant, 2))
        return (False, 0.0)

    def _compute_impact_succession(
        self, data: DonationInput, donation_depasse: bool
    ) -> str:
        """Compute impact description on future succession.

        Returns:
            String describing the impact in French.
        """
        parts = []

        if data.lien_parente == "descendant" and data.avancement_hoirie:
            parts.append(
                "Cette donation est presumee etre un avancement d'hoirie "
                "(CC art. 626). Elle sera rapportee (comptee) lors du partage "
                "successoral. Le donataire devra rendre l'excedent si la donation "
                "depasse sa part hereditaire."
            )
        elif data.lien_parente == "descendant" and not data.avancement_hoirie:
            parts.append(
                "Cette donation est hors part successorale (dispense de rapport). "
                "Elle s'impute sur la quotite disponible du donateur. "
                "Si elle depasse la quotite disponible, les heritiers reserves "
                "peuvent agir en reduction (CC art. 527)."
            )
        elif data.lien_parente in ("concubin", "tiers"):
            parts.append(
                "Cette donation a un tiers ou concubin s'impute sur la quotite "
                "disponible du donateur. Elle reduit d'autant la masse successorale "
                "future."
            )
        elif data.lien_parente == "conjoint":
            parts.append(
                "La donation au conjoint s'impute en principe sur sa part "
                "successorale. Le regime matrimonial peut influencer le traitement."
            )
        else:
            parts.append(
                "Cette donation reduit la masse successorale future du donateur."
            )

        if donation_depasse:
            parts.append(
                "ATTENTION : cette donation depasse la quotite disponible. "
                "Les heritiers reserves pourront agir en reduction "
                "apres le deces du donateur (CC art. 527)."
            )

        return " ".join(parts)

    # ------------------------------------------------------------------
    # Compliance outputs
    # ------------------------------------------------------------------

    def _generate_checklist(
        self, data: DonationInput, taux: float
    ) -> List[str]:
        """Generate action checklist for donation.

        Returns:
            List of actionable items in French (tu/toi).
        """
        checklist = [
            "Precise par ecrit si la donation est un avancement d'hoirie "
            "ou hors part successorale",
            "Conserve l'acte de donation pour la future declaration de succession",
            "Verifie les droits de mutation dans ton canton",
        ]

        if data.type_donation == "immobilier":
            checklist.insert(0,
                "Redige un acte de donation authentique (notaire) si immobilier"
            )
            checklist.append(
                "Fais estimer le bien par un expert agree"
            )
            checklist.append(
                "Procede a l'inscription au registre foncier (CC art. 655)"
            )

        if data.nb_enfants > 0 and data.lien_parente != "descendant":
            checklist.append(
                "Informe les autres heritiers reserves de la donation"
            )

        if data.lien_parente == "descendant" and data.nb_enfants > 1:
            checklist.append(
                "Informe les autres enfants de la donation pour eviter "
                "les conflits lors de la succession"
            )

        if data.lien_parente == "concubin":
            checklist.append(
                f"Attention : ton concubin paiera un impot de donation "
                f"eleve ({taux * 100:.0f}%) dans le canton de {data.canton}"
            )

        if data.fortune_totale_donateur > 0:
            checklist.append(
                "Verifie que la donation respecte les reserves hereditaires "
                "(CC art. 470-471)"
            )

        checklist.append(
            "Consulte un·e notaire ou un·e avocat·e specialise·e en droit "
            "successoral pour valider la structure de la donation"
        )

        return checklist

    def _generate_alerts(
        self,
        data: DonationInput,
        taux: float,
        donation_depasse: bool,
        depassement: float,
        quotite_disponible: float,
    ) -> List[str]:
        """Generate warning alerts.

        Returns:
            List of alert strings in French.
        """
        alerts: List[str] = []

        if donation_depasse:
            alerts.append(
                "ATTENTION : cette donation depasse la quotite disponible "
                "— les heritiers reserves peuvent la contester"
            )

        if data.lien_parente == "concubin" and taux > 0.15:
            alerts.append(
                f"Impot de donation eleve pour un concubin dans le canton "
                f"de {data.canton} : {taux * 100:.0f}%"
            )

        if data.type_donation == "immobilier":
            alerts.append(
                "Attention : la donation immobiliere necessite un acte notarie "
                "et l'inscription au registre foncier"
            )

        if data.donateur_age >= 70:
            alerts.append(
                "En cas de deces dans les annees suivantes, le fisc pourrait "
                "requalifier cette donation"
            )

        if data.montant > 500_000 and data.lien_parente in ("concubin", "tiers"):
            alerts.append(
                f"Donation importante a un {data.lien_parente} : l'impot "
                f"s'eleve a {round(data.montant * taux):,.0f} CHF"
            )

        return alerts

    def _generate_chiffre_choc(
        self,
        montant: float,
        impot: float,
        taux: float,
        lien_parente: str,
    ) -> dict:
        """Generate the impact number (chiffre choc).

        Returns:
            dict with montant and texte.
        """
        if impot > 0:
            net = round(montant - impot, 2)
            return {
                "montant": round(impot, 2),
                "texte": (
                    f"Impot de donation : {impot:,.0f} CHF "
                    f"(taux de {taux * 100:.0f}% pour un·e {lien_parente}). "
                    f"Le donataire recevra effectivement {net:,.0f} CHF net."
                ),
            }
        return {
            "montant": round(montant, 2),
            "texte": (
                f"Donation de {montant:,.0f} CHF exoneree d'impot "
                f"pour un·e {lien_parente} dans ce canton."
            ),
        }
