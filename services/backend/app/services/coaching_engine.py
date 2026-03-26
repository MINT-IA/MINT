"""
Proactive Coaching Engine Service.

Generates personalized, contextual financial coaching tips based on a user's
profile and the current date. All tips are grounded in Swiss law and best
practices, with source references.

Sources:
    - LIFD art. 33 (deductions 3a)
    - OPP3 art. 7 (plafond 3a salarie / independant)
    - LPP art. 79b (rachat volontaire LPP)
    - LPP art. 15-16 (cotisations selon age)
    - LPP art. 8 (deduction de coordination)
    - LPP art. 4 (independants)
    - LIFD art. 124 (declaration fiscale)
    - FINMA (ratio dettes / revenus)

Ethical requirements:
    - Gender-neutral language throughout
    - NEVER use "garanti", "assure", "certain"
    - All tips include a source reference
    - Disclaimer on every response
"""

from dataclasses import dataclass
from datetime import date
from typing import List, Optional

from app.constants.social_insurance import (
    LPP_DEDUCTION_COORDINATION,
    PILIER_3A_PLAFOND_AVEC_LPP,
    PILIER_3A_PLAFOND_SANS_LPP,
)


# ---------------------------------------------------------------------------
# Data classes
# ---------------------------------------------------------------------------

@dataclass
class CoachingProfile:
    """User profile data for coaching tip generation."""
    age: int
    canton: str
    revenu_annuel: float
    has_3a: bool
    montant_3a: float
    has_lpp: bool
    avoir_lpp: float
    lacune_lpp: float
    taux_activite: float              # 0-100 (percentage)
    charges_fixes_mensuelles: float
    epargne_disponible: float
    dette_totale: float
    has_budget: bool
    employment_status: str            # "salarie" | "independant" | "retraite"
    etat_civil: str                   # "celibataire" | "marie" | "divorce" | "veuf"


@dataclass
class CoachingTip:
    """A single coaching tip."""
    id: str
    category: str
    priority: str                     # "haute" | "moyenne" | "basse"
    title: str
    message: str
    action: str
    estimated_impact_chf: Optional[float]
    source: str
    icon: str


# ---------------------------------------------------------------------------
# Coaching Engine
# ---------------------------------------------------------------------------

class CoachingEngine:
    """Generate personalized coaching tips based on user profile.

    All tips are in French, include law references, and use gender-neutral
    language. No banned terms ("garanti", "assure", "certain").
    """

    # 3a pillar limits (OPP3 art. 7)
    PLAFOND_3A_SALARIE = PILIER_3A_PLAFOND_AVEC_LPP
    PLAFOND_3A_INDEPENDANT = PILIER_3A_PLAFOND_SANS_LPP

    # LPP constants
    COORDINATION_DEDUCTION = LPP_DEDUCTION_COORDINATION
    # NOTE: Uses AVS_AGE_REFERENCE_HOMME (65) for all users.
    # Women born before 1964 may have transitional retirement age (64-65).
    # The profile does not currently include gender — when it does, use
    # gender-aware reference age from AVS21 reform tables.
    # TODO: Add gender-aware retirement age when CoachingProfile includes gender.
    RETIREMENT_AGE = 65
    PROJECTED_ANNUAL_RETURN = 0.015  # 1.5%

    # LPP age-based contribution rates (LPP art. 16)
    LPP_RATES = {
        (25, 34): 7.0,
        (35, 44): 10.0,
        (45, 54): 15.0,
        (55, 64): 18.0,
    }

    # Age milestones with contextual messages
    AGE_MILESTONES = {
        25: {
            "title": "Debut de la prevoyance LPP",
            "message": (
                "A 25 ans, vous commencez a cotiser pour la vieillesse dans "
                "le 2e pilier (LPP). Le taux de cotisation est de 7% du "
                "salaire coordonne. C'est le bon moment pour ouvrir un 3e "
                "pilier et profiter de l'effet des interets composes."
            ),
            "icon": "rocket",
        },
        35: {
            "title": "Hausse des cotisations LPP a 10%",
            "message": (
                "A 35 ans, votre taux de cotisation LPP passe de 7% a 10% du "
                "salaire coordonne. Votre salaire net baisse legerement, mais "
                "votre prevoyance se renforce. Pensez a verifier votre "
                "certificat de prevoyance."
            ),
            "icon": "trending_up",
        },
        45: {
            "title": "Hausse des cotisations LPP a 15%",
            "message": (
                "A 45 ans, votre taux de cotisation LPP passe a 15% du "
                "salaire coordonne. C'est souvent le moment ou un rachat LPP "
                "devient interessant fiscalement. Evaluez votre lacune de "
                "prevoyance."
            ),
            "icon": "savings",
        },
        50: {
            "title": "Planification retraite : le bon moment",
            "message": (
                "À 50 ans, il reste 15 ans avant la retraite. C'est le moment "
                "idéal pour faire un bilan complet de prévoyance : 1er, 2e et "
                "3e piliers. Vérifiez votre lacune LPP et explorez les rachats."
            ),
            "icon": "event_note",
        },
        55: {
            "title": "Hausse des cotisations LPP à 18%",
            "message": (
                "À 55 ans, votre taux de cotisation LPP atteint le maximum de "
                "18%. Votre potentiel de rachat LPP est souvent maximal à cet "
                "âge. Chaque rachat est intégralement déductible."
            ),
            "icon": "trending_up",
        },
        58: {
            "title": "Contrôle pré-retraite : 5 ans pour agir",
            "message": (
                "À 58 ans, il reste environ 5 ans avant la retraite AVS à 65 "
                "ans. C'est le dernier moment pour optimiser : rachats LPP, "
                "maximisation du 3a, et choix rente vs capital."
            ),
            "icon": "warning",
        },
        63: {
            "title": "Retraite dans 2 ans : dernières étapes",
            "message": (
                "À 63 ans, la retraite approche. Préparez-vous : demandez un "
                "calcul de rente à votre caisse de pension, évaluez l'option "
                "capital vs rente, et anticipez l'impact fiscal du retrait."
            ),
            "icon": "flag",
        },
    }

    # Cantonal tax declaration deadlines (month, day)
    # Most cantons: March 31. Some exceptions.
    CANTON_TAX_DEADLINES = {
        "GE": (3, 31),
        "VD": (3, 15),
        "ZH": (3, 31),
        "BE": (3, 15),
        "BS": (3, 31),
        "LU": (3, 31),
        "TI": (4, 30),
        "SG": (3, 31),
        "AG": (3, 31),
        "VS": (3, 31),
        "FR": (3, 31),
        "NE": (3, 31),
        "JU": (3, 31),
        "SO": (3, 31),
        "BL": (3, 31),
        "SH": (3, 31),
        "AR": (3, 31),
        "AI": (3, 31),
        "GL": (3, 31),
        "GR": (3, 31),
        "TG": (3, 31),
        "ZG": (3, 31),
        "NW": (3, 31),
        "OW": (3, 31),
        "SZ": (3, 31),
        "UR": (3, 31),
    }
    DEFAULT_TAX_DEADLINE = (3, 31)

    # Simplified marginal tax rates by canton
    # (combined: federal + cantonal + communal, ~80 kCHF income)
    # Aligned with Flutter coaching_service.dart for consistency.
    CANTON_MARGINAL_TAX_RATES = {
        "ZH": 0.34,
        "BE": 0.38,
        "LU": 0.30,
        "UR": 0.25,
        "SZ": 0.24,
        "OW": 0.25,
        "NW": 0.25,
        "GL": 0.29,
        "ZG": 0.22,
        "FR": 0.35,
        "SO": 0.35,
        "BS": 0.37,
        "BL": 0.35,
        "SH": 0.33,
        "AR": 0.30,
        "AI": 0.27,
        "SG": 0.33,
        "GR": 0.32,
        "AG": 0.33,
        "TG": 0.31,
        "TI": 0.35,
        "VD": 0.37,
        "VS": 0.32,
        "NE": 0.38,
        "GE": 0.37,
        "JU": 0.38,
    }
    DEFAULT_MARGINAL_TAX_RATE = 0.33

    # Priority ordering for sort
    PRIORITY_ORDER = {"haute": 0, "moyenne": 1, "basse": 2}

    def generate_tips(
        self,
        profile: CoachingProfile,
        today_date: Optional[date] = None,
    ) -> List[CoachingTip]:
        """Generate personalized coaching tips based on profile and date.

        Args:
            profile: User's financial profile.
            today_date: Override for current date (default: today).

        Returns:
            List of CoachingTip, sorted by priority (haute first)
            then by estimated_impact_chf (highest first).
        """
        if today_date is None:
            today_date = date.today()

        tips: List[CoachingTip] = []

        # Run all coaching triggers
        tips.extend(self._check_3a_deadline(profile, today_date))
        tips.extend(self._check_missing_3a(profile))
        tips.extend(self._check_lpp_buyback(profile))
        tips.extend(self._check_tax_deadline(profile, today_date))
        tips.extend(self._check_retirement_countdown(profile))
        tips.extend(self._check_emergency_fund(profile))
        tips.extend(self._check_debt_ratio(profile))
        tips.extend(self._check_age_milestones(profile))
        tips.extend(self._check_part_time_gap(profile))
        tips.extend(self._check_independant_alert(profile))

        # Sort: priority (haute first), then impact (highest first)
        tips.sort(
            key=lambda t: (
                self.PRIORITY_ORDER.get(t.priority, 99),
                -(t.estimated_impact_chf if t.estimated_impact_chf is not None else 0),
            )
        )

        return tips

    # ------------------------------------------------------------------
    # Helper: get marginal tax rate
    # ------------------------------------------------------------------

    def _get_marginal_rate(self, canton: str) -> float:
        """Get simplified marginal tax rate for a canton."""
        return self.CANTON_MARGINAL_TAX_RATES.get(
            canton.upper(), self.DEFAULT_MARGINAL_TAX_RATE
        )

    # ------------------------------------------------------------------
    # (a) 3a deadline (Oct 1 - Dec 31)
    # ------------------------------------------------------------------

    def _check_3a_deadline(
        self, profile: CoachingProfile, today: date
    ) -> List[CoachingTip]:
        """If between Oct 1 and Dec 31, remind about 3a maximization."""
        tips: List[CoachingTip] = []

        if today.month < 10:
            return tips

        # Determine plafond
        if profile.employment_status == "independant":
            plafond = self.PLAFOND_3A_INDEPENDANT
        else:
            plafond = self.PLAFOND_3A_SALARIE

        # Check if there's room to contribute more
        montant_restant = plafond - profile.montant_3a

        if profile.has_3a and montant_restant <= 0:
            return tips

        if profile.employment_status == "retraite":
            return tips

        if profile.age >= 65:
            return tips

        # Calculate days remaining until Dec 31
        end_of_year = date(today.year, 12, 31)
        days_remaining = (end_of_year - today).days

        # Calculate fiscal impact
        taux = self._get_marginal_rate(profile.canton)
        if profile.has_3a:
            montant_deductible = montant_restant
        else:
            montant_deductible = plafond

        economie_fiscale = montant_deductible * taux

        tips.append(CoachingTip(
            id="3a_deadline",
            category="prevoyance",
            priority="haute",
            title="Delai 3e pilier: fin d'annee",
            message=(
                f"Il vous reste {days_remaining} jours pour maximiser votre "
                f"3e pilier {today.year}. Montant deductible restant: "
                f"CHF {montant_deductible:,.0f}. "
                f"Economie fiscale estimee: CHF {economie_fiscale:,.0f}. "
                f"Ce montant depend de votre situation fiscale individuelle."
            ),
            action=(
                "Versez le montant restant sur votre compte 3a avant "
                "le 31 decembre."
            ),
            estimated_impact_chf=round(economie_fiscale, 2),
            source="LIFD art. 33, OPP3 art. 7",
            icon="calendar_today",
        ))

        return tips

    # ------------------------------------------------------------------
    # (b) Missing 3a
    # ------------------------------------------------------------------

    def _check_missing_3a(self, profile: CoachingProfile) -> List[CoachingTip]:
        """If user has no 3a and is not retired, suggest opening one."""
        tips: List[CoachingTip] = []

        if profile.has_3a:
            return tips

        if profile.age >= 65:
            return tips

        if profile.employment_status == "retraite":
            return tips

        # Determine plafond
        if profile.employment_status == "independant":
            plafond = self.PLAFOND_3A_INDEPENDANT
        else:
            plafond = self.PLAFOND_3A_SALARIE

        taux = self._get_marginal_rate(profile.canton)
        economie_annuelle = plafond * taux

        tips.append(CoachingTip(
            id="missing_3a",
            category="prevoyance",
            priority="haute",
            title="Pas de 3e pilier",
            message=(
                f"Vous n'avez pas de 3e pilier. En epargnant "
                f"CHF {plafond:,.0f}/an, vous pourriez economiser "
                f"environ CHF {economie_annuelle:,.0f} d'impots par an "
                f"(estimation selon votre canton). "
                f"L'impact reel depend de votre revenu imposable."
            ),
            action=(
                "Ouvrez un compte 3a aupres d'une banque ou d'une assurance "
                "et commencez a epargner des maintenant."
            ),
            estimated_impact_chf=round(economie_annuelle, 2),
            source="LIFD art. 33",
            icon="add_circle",
        ))

        return tips

    # ------------------------------------------------------------------
    # (c) LPP buyback
    # ------------------------------------------------------------------

    def _check_lpp_buyback(self, profile: CoachingProfile) -> List[CoachingTip]:
        """If user has a LPP gap, suggest voluntary buyback."""
        tips: List[CoachingTip] = []

        if profile.lacune_lpp <= 0:
            return tips

        if profile.age < 25:
            return tips

        taux = self._get_marginal_rate(profile.canton)
        # Estimate: suggest buying back up to the full gap,
        # but show impact for a reasonable yearly amount
        montant_rachat_sugere = min(profile.lacune_lpp, 20_000.0)
        economie_fiscale = montant_rachat_sugere * taux

        tips.append(CoachingTip(
            id="lpp_buyback",
            category="prevoyance",
            priority="haute" if profile.lacune_lpp > 50000 else "moyenne",
            title="Lacune LPP: rachat volontaire",
            message=(
                f"Votre lacune LPP est de CHF {profile.lacune_lpp:,.0f}. "
                f"Un rachat volontaire est intégralement déductible "
                f"fiscalement. Pour un rachat de CHF {montant_rachat_sugere:,.0f}, "
                f"l'économie fiscale estimée est de CHF {economie_fiscale:,.0f}. "
                f"L'impact réel dépend de votre situation fiscale."
            ),
            action=(
                "Demandez a votre caisse de pension le montant maximal "
                "de rachat et évaluez un rachat échelonné sur plusieurs années."
            ),
            estimated_impact_chf=round(economie_fiscale, 2),
            source="LPP art. 79b",
            icon="savings",
        ))

        return tips

    # ------------------------------------------------------------------
    # (d) Tax declaration deadline
    # ------------------------------------------------------------------

    def _check_tax_deadline(
        self, profile: CoachingProfile, today: date
    ) -> List[CoachingTip]:
        """Remind about cantonal tax declaration deadline."""
        tips: List[CoachingTip] = []

        canton = profile.canton.upper()
        month, day = self.CANTON_TAX_DEADLINES.get(
            canton, self.DEFAULT_TAX_DEADLINE
        )

        # Deadline for the current year
        try:
            deadline = date(today.year, month, day)
        except ValueError:
            deadline = date(today.year, month, 28)

        # If deadline has already passed this year, no tip
        if today > deadline:
            return tips

        days_until = (deadline - today).days

        if days_until > 60:
            return tips

        tips.append(CoachingTip(
            id="tax_deadline",
            category="fiscalite",
            priority="haute" if days_until <= 14 else "moyenne",
            title="Echeance declaration fiscale",
            message=(
                f"La date limite pour votre declaration fiscale dans le "
                f"canton de {canton} est le {deadline.strftime('%d.%m.%Y')}. "
                f"Il vous reste {days_until} jours. "
                f"Une demande de prolongation est possible dans la plupart "
                f"des cantons."
            ),
            action=(
                "Rassemblez vos documents (certificat de salaire, "
                "certificat LPP, releves 3a, attestation de dons) "
                "et completez votre declaration."
            ),
            estimated_impact_chf=None,
            source="LIFD art. 124",
            icon="description",
        ))

        return tips

    # ------------------------------------------------------------------
    # (e) Retirement countdown
    # ------------------------------------------------------------------

    def _check_retirement_countdown(
        self, profile: CoachingProfile
    ) -> List[CoachingTip]:
        """If age >= 50, show retirement countdown and projected capital."""
        tips: List[CoachingTip] = []

        if profile.age < 50:
            return tips

        years_to_retirement = max(0, self.RETIREMENT_AGE - profile.age)

        # Project LPP capital at 1.5%/year
        capital_projete = profile.avoir_lpp
        for _ in range(years_to_retirement):
            capital_projete = capital_projete * (1 + self.PROJECTED_ANNUAL_RETURN)

        capital_projete = round(capital_projete, 2)

        if years_to_retirement == 0:
            message = (
                f"Vous avez atteint l'age de la retraite. "
                f"Votre capital LPP actuel est de CHF {profile.avoir_lpp:,.0f}. "
                f"Il est temps de choisir entre rente et capital, ou une "
                f"combinaison des deux."
            )
        else:
            message = (
                f"Il vous reste {years_to_retirement} annees avant 65 ans. "
                f"Votre capital retraite LPP estime (projection a 1.5%/an): "
                f"CHF {capital_projete:,.0f}. "
                f"Cette projection est indicative et depend du taux d'interet "
                f"effectif de votre caisse de pension."
            )

        tips.append(CoachingTip(
            id="retirement_countdown",
            category="prevoyance",
            priority="haute" if years_to_retirement <= 5 else "moyenne",
            title="Horizon retraite",
            message=message,
            action=(
                "Demandez un calcul de rente a votre caisse de pension et "
                "comparez rente vs capital."
            ),
            estimated_impact_chf=capital_projete,
            source="LPP art. 15",
            icon="hourglass_bottom",
        ))

        return tips

    # ------------------------------------------------------------------
    # (f) Emergency fund
    # ------------------------------------------------------------------

    def _check_emergency_fund(
        self, profile: CoachingProfile
    ) -> List[CoachingTip]:
        """Check if emergency fund covers at least 3 months of expenses."""
        tips: List[CoachingTip] = []

        if profile.charges_fixes_mensuelles <= 0:
            return tips

        mois_couverts = profile.epargne_disponible / profile.charges_fixes_mensuelles

        if mois_couverts >= 3:
            return tips

        # Determine priority
        if mois_couverts < 1:
            priority = "haute"
        else:
            priority = "moyenne"

        objectif = profile.charges_fixes_mensuelles * 3
        manque = objectif - profile.epargne_disponible

        tips.append(CoachingTip(
            id="emergency_fund",
            category="budget",
            priority=priority,
            title="Fonds d'urgence insuffisant",
            message=(
                f"Votre fonds d'urgence couvre {mois_couverts:.1f} mois de "
                f"charges fixes. L'ideal est de 3 a 6 mois "
                f"(CHF {objectif:,.0f} a {profile.charges_fixes_mensuelles * 6:,.0f}). "
                f"Il vous manque environ CHF {manque:,.0f} pour atteindre "
                f"le minimum recommande."
            ),
            action=(
                "Mettez en place un virement automatique mensuel vers un "
                "compte epargne dedie a votre fonds d'urgence."
            ),
            estimated_impact_chf=round(manque, 2),
            source="Bonne pratique financiere",
            icon="shield",
        ))

        return tips

    # ------------------------------------------------------------------
    # (g) Debt ratio
    # ------------------------------------------------------------------

    def _check_debt_ratio(self, profile: CoachingProfile) -> List[CoachingTip]:
        """Check debt-to-income ratio."""
        tips: List[CoachingTip] = []

        if profile.dette_totale <= 0:
            return tips

        if profile.revenu_annuel <= 0:
            return tips

        ratio = profile.dette_totale / profile.revenu_annuel

        if ratio <= 0.33:
            return tips

        ratio_pct = ratio * 100

        tips.append(CoachingTip(
            id="debt_ratio",
            category="budget",
            priority="haute" if ratio > 0.5 else "moyenne",
            title="Ratio dettes/revenus eleve",
            message=(
                f"Votre ratio dettes/revenus est de {ratio_pct:.0f}%. "
                f"Le seuil prudent est de 33%. Un ratio eleve peut limiter "
                f"votre capacite d'emprunt et represente un risque financier. "
                f"L'analyse depend de la nature des dettes (hypotheque vs "
                f"credit a la consommation)."
            ),
            action=(
                "Priorisez le remboursement des dettes a taux eleve "
                "(credits a la consommation, leasing) avant toute "
                "nouvelle depense importante."
            ),
            estimated_impact_chf=round(profile.dette_totale, 2),
            source="FINMA / pratique bancaire",
            icon="warning",
        ))

        return tips

    # ------------------------------------------------------------------
    # (h) Age milestones
    # ------------------------------------------------------------------

    def _check_age_milestones(
        self, profile: CoachingProfile
    ) -> List[CoachingTip]:
        """Generate contextual tip for age milestones (+-1 year)."""
        tips: List[CoachingTip] = []

        for milestone_age, info in self.AGE_MILESTONES.items():
            if abs(profile.age - milestone_age) <= 1:
                tips.append(CoachingTip(
                    id=f"age_milestone_{milestone_age}",
                    category="prevoyance",
                    priority="moyenne",
                    title=info["title"],
                    message=info["message"],
                    action=(
                        "Vérifiez votre certificat de prévoyance LPP et "
                        "évaluez votre situation globale."
                    ),
                    estimated_impact_chf=None,
                    source="LPP art. 15-16",
                    icon=info["icon"],
                ))

        return tips

    # ------------------------------------------------------------------
    # (i) Part-time gap alert
    # ------------------------------------------------------------------

    def _check_part_time_gap(
        self, profile: CoachingProfile
    ) -> List[CoachingTip]:
        """Alert about coordination deduction for part-time workers."""
        tips: List[CoachingTip] = []

        if profile.taux_activite >= 100 or profile.taux_activite <= 0:
            return tips

        tips.append(CoachingTip(
            id="part_time_gap",
            category="prevoyance",
            priority="moyenne",
            title="Temps partiel: attention a la deduction de coordination",
            message=(
                f"En travaillant a {profile.taux_activite:.0f}%, votre "
                f"deduction de coordination ({self.COORDINATION_DEDUCTION:,.0f} CHF) "
                f"n'est pas toujours proratisee par l'employeur. "
                f"Cela peut reduire significativement votre salaire assure "
                f"LPP et donc votre rente future. "
                f"Verifiez votre certificat de prevoyance."
            ),
            action=(
                "Demandez a votre employeur si la deduction de coordination "
                "est proratisee selon votre taux d'activite."
            ),
            estimated_impact_chf=None,
            source="LPP art. 8",
            icon="schedule",
        ))

        return tips

    # ------------------------------------------------------------------
    # (j) Independent alert
    # ------------------------------------------------------------------

    def _check_independant_alert(
        self, profile: CoachingProfile
    ) -> List[CoachingTip]:
        """Alert independent workers about missing mandatory LPP."""
        tips: List[CoachingTip] = []

        if profile.employment_status != "independant":
            return tips

        tips.append(CoachingTip(
            id="independant_no_lpp",
            category="prevoyance",
            priority="haute",
            title="Independant: pas de LPP obligatoire",
            message=(
                f"En tant qu'independant, vous n'avez PAS de LPP obligatoire. "
                f"Envisagez une affiliation volontaire ou un 3a renforce "
                f"(plafond: {self.PLAFOND_3A_INDEPENDANT:,.0f} CHF). "
                f"Sans 2e pilier, votre prevoyance repose essentiellement "
                f"sur l'AVS et le 3e pilier."
            ),
            action=(
                "Renseignez-vous sur l'affiliation volontaire LPP aupres "
                "d'une fondation de prevoyance et maximisez votre 3e pilier."
            ),
            estimated_impact_chf=None,
            source="LPP art. 4",
            icon="business",
        ))

        return tips
