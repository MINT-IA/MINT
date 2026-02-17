"""
Next Steps Service — Recommandations de simulateurs et evenements de vie.

Recommends relevant simulators and life events based on user profile,
prioritized by urgency and relevance. Pure educational recommendations,
never prescriptive.

Sources:
    - LIFD (Loi sur l'impot federal direct)
    - LPP (Loi sur la prevoyance professionnelle)
    - LAVS (Loi sur l'AVS)
    - CC art. 457ss (droit successoral)
    - LSFin art. 3 (distinction conseil / information)

Ethical requirements:
    - Gender-neutral: no assumptions based on gender
    - Educational tone, never prescriptive
    - No banned terms: garanti, certain, assure, sans risque, optimal, meilleur, parfait
"""

from dataclasses import dataclass
from typing import List


# ══════════════════════════════════════════════════════════════════════════════
# Constants
# ══════════════════════════════════════════════════════════════════════════════

DISCLAIMER: str = (
    "Suggestions educatives basees sur ton profil. Ne constitue pas un "
    "conseil financier personnalise au sens de la LSFin."
)

SOURCES: List[str] = [
    "LIFD",
    "LPP",
    "LAVS",
    "CC art. 457ss",
    "LSFin art. 3",
]

MAX_STEPS: int = 5

# Life events enum (18 types — definitive)
LIFE_EVENTS = {
    "marriage", "divorce", "birth", "concubinage", "deathOfRelative",
    "firstJob", "newJob", "selfEmployment", "jobLoss", "retirement",
    "housingPurchase", "housingSale", "inheritance", "donation",
    "disability", "cantonMove", "countryMove", "debtCrisis",
}

# Route mapping (must match Flutter routes exactly)
ROUTE_MAP = {
    "marriage": "/mariage",
    "divorce": "/life-event/divorce",
    "birth": "/naissance",
    "concubinage": "/concubinage",
    "deathOfRelative": "/life-event/succession",
    "firstJob": "/first-job",
    "newJob": "/simulator/job-comparison",
    "selfEmployment": "/segments/independant",
    "jobLoss": "/unemployment",
    "retirement": "/retirement",
    "housingPurchase": "/mortgage/affordability",
    "housingSale": "/life-event/housing-sale",
    "inheritance": "/life-event/succession",
    "donation": "/life-event/donation",
    "disability": "/simulator/disability-gap",
    "cantonMove": "/fiscal",
    "countryMove": "/expatriation",
    "debtCrisis": "/check/debt",
}

# Icon mapping
ICON_MAP = {
    "marriage": "favorite",
    "divorce": "heart_broken",
    "birth": "child_care",
    "concubinage": "people",
    "deathOfRelative": "local_florist",
    "firstJob": "work_outline",
    "newJob": "swap_horiz",
    "selfEmployment": "storefront",
    "jobLoss": "work_off",
    "retirement": "elderly",
    "housingPurchase": "home",
    "housingSale": "sell",
    "inheritance": "account_balance",
    "donation": "volunteer_activism",
    "disability": "health_and_safety",
    "cantonMove": "map",
    "countryMove": "flight",
    "debtCrisis": "warning",
}

# High-tax cantons
HIGH_TAX_CANTONS = {"GE", "VD", "NE", "JU", "BE", "BS"}

# Valid civil statuses
VALID_CIVIL_STATUSES = {
    "single", "married", "divorced", "widowed",
    "registered_partnership", "concubinage",
}

# Valid employment statuses
VALID_EMPLOYMENT_STATUSES = {
    "employee", "independent", "unemployed", "inactive",
}


# ══════════════════════════════════════════════════════════════════════════════
# Data classes
# ══════════════════════════════════════════════════════════════════════════════

@dataclass
class NextStepsInput:
    """Input data for next steps recommendation."""
    age: int
    civil_status: str
    children_count: int
    employment_status: str
    monthly_net_income: float
    canton: str
    has_3a: bool = False
    has_pension_fund: bool = False
    has_debt: bool = False
    has_real_estate: bool = False
    has_investments: bool = False


@dataclass
class NextStep:
    """A single recommended next step."""
    life_event: str
    title: str
    reason: str
    priority: int
    route: str
    icon_name: str


@dataclass
class NextStepsResult:
    """Result of next steps recommendation."""
    steps: List[NextStep]
    disclaimer: str
    sources: List[str]


# ══════════════════════════════════════════════════════════════════════════════
# Service
# ══════════════════════════════════════════════════════════════════════════════

class NextStepsService:
    """Recommend relevant simulators and life events based on user profile.

    Generates a prioritized list of up to 5 next steps, each linked to a
    specific life event simulator. Recommendations are purely educational
    and never prescriptive.

    Compliance: NEVER use "garanti", "assure", "certain", "sans risque",
    "optimal", "meilleur", "parfait", "conseiller".
    """

    def calculate(self, input_data: NextStepsInput) -> NextStepsResult:
        """Generate personalized next steps recommendations.

        Args:
            input_data: NextStepsInput with user profile data.

        Returns:
            NextStepsResult with up to 5 prioritized steps.
        """
        candidates: List[NextStep] = []

        # Rule 1: Debt always first
        if input_data.has_debt:
            candidates.append(self._make_step(
                life_event="debtCrisis",
                title="Fais le point sur tes dettes",
                reason=(
                    "Tu as indique avoir des dettes. Il est important de "
                    "comprendre ta situation d'endettement et les options "
                    "a ta disposition pour t'en sortir."
                ),
                priority=1,
            ))

        # Rule 6: Unemployed always urgent
        if input_data.employment_status == "unemployed":
            candidates.append(self._make_step(
                life_event="jobLoss",
                title="Tes droits au chomage",
                reason=(
                    "En tant que demandeur·euse d'emploi, il est essentiel "
                    "de connaitre tes droits aux indemnites de chomage et "
                    "les demarches a entreprendre."
                ),
                priority=1,
            ))

        # Rule 7: Near retirement
        if input_data.age >= 55:
            candidates.append(self._make_step(
                life_event="retirement",
                title="Prepare ta retraite",
                reason=(
                    "A partir de 55 ans, il est judicieux de planifier ta "
                    "retraite : coordination AVS/LPP, rente ou capital, "
                    "et fiscalite du retrait."
                ),
                priority=1,
            ))

        # Rule 2: Young employee
        if input_data.age <= 28 and input_data.employment_status == "employee":
            candidates.append(self._make_step(
                life_event="firstJob",
                title="Bien demarrer dans la vie active",
                reason=(
                    "En debut de carriere, quelques reflexes financiers "
                    "peuvent faire une grande difference : 3e pilier, "
                    "prevoyance, budget."
                ),
                priority=2,
            ))

        # Rule 3: Concubinage
        if input_data.civil_status == "concubinage":
            candidates.append(self._make_step(
                life_event="concubinage",
                title="Protege ton couple en concubinage",
                reason=(
                    "Le concubinage n'offre aucune protection legale "
                    "automatique en Suisse. Decouvre les demarches pour "
                    "proteger ton·ta partenaire (testament, assurance, "
                    "convention de concubinage)."
                ),
                priority=2,
            ))

        # Rule 5: Independent worker
        if input_data.employment_status == "independent":
            candidates.append(self._make_step(
                life_event="selfEmployment",
                title="Ta prevoyance d'independant·e",
                reason=(
                    "En tant qu'independant·e, tu n'es pas affilie·e "
                    "automatiquement au 2e pilier. Decouvre les solutions "
                    "pour ta prevoyance et ta fiscalite."
                ),
                priority=2,
            ))

        # Rule 8: Donation/inheritance for older parents
        if input_data.age >= 50 and input_data.children_count > 0:
            candidates.append(self._make_step(
                life_event="inheritance",
                title="Anticipe ta succession",
                reason=(
                    "Avec des enfants, il est utile d'anticiper ta "
                    "succession : reserves hereditaires, testament, "
                    "avancement d'hoirie (CC art. 457ss)."
                ),
                priority=3,
            ))

        # Rule 9: Housing purchase for non-owners with sufficient income
        if not input_data.has_real_estate and input_data.monthly_net_income >= 5000:
            candidates.append(self._make_step(
                life_event="housingPurchase",
                title="Simule ta capacite d'achat immobilier",
                reason=(
                    "Avec ton revenu, tu pourrais envisager l'achat d'un "
                    "bien immobilier. Simule ta capacite d'emprunt et les "
                    "fonds propres necessaires."
                ),
                priority=3,
            ))

        # Rule 15: Disability coverage
        if input_data.children_count > 0 or input_data.monthly_net_income > 6000:
            candidates.append(self._make_step(
                life_event="disability",
                title="Verifie ta couverture invalidite",
                reason=(
                    "Avec des responsabilites financieres, il est important "
                    "de connaitre ta couverture en cas d'incapacite de travail "
                    "(AI, LPP, assurance perte de gain)."
                ),
                priority=3,
            ))

        # Rule 10: Housing sale for owners
        if input_data.has_real_estate:
            candidates.append(self._make_step(
                life_event="housingSale",
                title="Simule une vente immobiliere",
                reason=(
                    "En tant que proprietaire, decouvre l'impact fiscal "
                    "d'une vente : impot sur la plus-value, remboursement "
                    "EPL, et produit net."
                ),
                priority=4,
            ))

        # Rule 4: Single and 25+
        if input_data.civil_status == "single" and input_data.age >= 25:
            candidates.append(self._make_step(
                life_event="marriage",
                title="Mariage : impact financier",
                reason=(
                    "Decouvre l'impact fiscal et patrimonial du mariage "
                    "en Suisse : imposition commune, regime matrimonial, "
                    "prevoyance."
                ),
                priority=4,
            ))

        # Rule 12: Married without children
        if input_data.children_count == 0 and input_data.civil_status == "married":
            candidates.append(self._make_step(
                life_event="birth",
                title="Naissance : ce qui change financierement",
                reason=(
                    "Si tu envisages d'avoir un enfant, decouvre les "
                    "impacts financiers : allocations familiales, "
                    "deductions fiscales, prevoyance."
                ),
                priority=4,
            ))

        # Rule 13: High-tax cantons
        if input_data.canton.upper() in HIGH_TAX_CANTONS:
            candidates.append(self._make_step(
                life_event="cantonMove",
                title="Compare la fiscalite entre cantons",
                reason=(
                    f"Tu resides dans le canton de {input_data.canton.upper()}, "
                    f"qui fait partie des cantons a fiscalite elevee. "
                    f"Compare l'impact d'un demenagement intercantonal."
                ),
                priority=4,
            ))

        # Rule 14: Experienced employee
        if input_data.age >= 30 and input_data.employment_status == "employee":
            candidates.append(self._make_step(
                life_event="newJob",
                title="Compare un changement d'emploi",
                reason=(
                    "Apres quelques annees d'experience, un changement "
                    "d'emploi peut avoir un impact significatif sur ta "
                    "prevoyance LPP et ton salaire net."
                ),
                priority=4,
            ))

        # Sort by priority (ascending: 1 = highest), then deduplicate
        candidates = self._deduplicate(candidates)
        candidates.sort(key=lambda s: s.priority)

        # Keep max 5
        steps = candidates[:MAX_STEPS]

        return NextStepsResult(
            steps=steps,
            disclaimer=DISCLAIMER,
            sources=SOURCES,
        )

    # ------------------------------------------------------------------
    # Private helpers
    # ------------------------------------------------------------------

    def _make_step(
        self,
        life_event: str,
        title: str,
        reason: str,
        priority: int,
    ) -> NextStep:
        """Create a NextStep with route and icon from mappings.

        Args:
            life_event: One of the 18 life event types.
            title: French title for the recommendation.
            reason: French explanation of relevance.
            priority: 1-5 (1 = highest).

        Returns:
            NextStep dataclass instance.
        """
        return NextStep(
            life_event=life_event,
            title=title,
            reason=reason,
            priority=max(1, min(5, priority)),
            route=ROUTE_MAP.get(life_event, "/"),
            icon_name=ICON_MAP.get(life_event, "info"),
        )

    def _deduplicate(self, candidates: List[NextStep]) -> List[NextStep]:
        """Remove duplicate life events, keeping the one with highest priority.

        Args:
            candidates: List of NextStep candidates.

        Returns:
            Deduplicated list.
        """
        seen = {}
        for step in candidates:
            if step.life_event not in seen:
                seen[step.life_event] = step
            else:
                # Keep the one with higher priority (lower number)
                if step.priority < seen[step.life_event].priority:
                    seen[step.life_event] = step
        return list(seen.values())
