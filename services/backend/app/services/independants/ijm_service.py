"""
IJM (Indemnites journalieres maladie) — income loss insurance for self-employed.

Self-employed workers have NO legal right to salary continuation (CO art. 324a
applies only to employees). They must take voluntary IJM insurance to cover
income loss during illness.

Sources:
    - LAMal art. 67-77 (IJM facultative selon la LAMal)
    - CO art. 324a (continuation du salaire — NE S'APPLIQUE PAS aux independants)
    - LCA (assurance perte de gain privee)

Sprint S18 — Module Independants complet.
"""

from dataclasses import dataclass, field
from typing import List, Optional, Tuple


# ---------------------------------------------------------------------------
# Constants — approximate market rates (2025/2026)
# ---------------------------------------------------------------------------

# Premium per CHF 1'000 of monthly insured income, by age band and waiting period
# Format: {(age_min, age_max): {delai_carence_jours: prime_mensuelle_pour_1000_CHF}}
IJM_PRIMES: dict[Tuple[int, int], dict[int, float]] = {
    (18, 30): {30: 3.50, 60: 2.80, 90: 2.20},
    (31, 40): {30: 5.00, 60: 4.00, 90: 3.20},
    (41, 50): {30: 8.00, 60: 6.50, 90: 5.20},
    (51, 60): {30: 14.00, 60: 11.50, 90: 9.50},
    (61, 65): {30: 22.00, 60: 18.00, 90: 15.00},
}

TAUX_COUVERTURE = 0.80  # 80% of income
DELAIS_VALIDES = (30, 60, 90)
JOURS_OUVRABLES_PAR_MOIS = 21.75  # Average working days per month

DISCLAIMER = (
    "MINT est un outil educatif. Ce simulateur ne constitue pas un conseil "
    "en assurance au sens de la LSFin. Les primes IJM varient selon "
    "l'assureur, votre etat de sante et votre activite professionnelle. "
    "Consultez un ou une specialiste en assurances pour une offre personnalisee."
)

SOURCES = [
    "LAMal art. 67-77 (IJM facultative selon la LAMal)",
    "CO art. 324a (continuation du salaire — ne s'applique PAS aux independants)",
    "LCA (assurance perte de gain privee)",
]


# ---------------------------------------------------------------------------
# Data classes
# ---------------------------------------------------------------------------

@dataclass
class IjmResult:
    """Result of IJM simulation for a self-employed person."""
    indemnite_journaliere: float
    prime_mensuelle: float
    prime_annuelle: float
    cout_sans_couverture: float
    chiffre_choc: str
    alertes: List[str] = field(default_factory=list)
    disclaimer: str = DISCLAIMER
    sources: List[str] = field(default_factory=list)


# ---------------------------------------------------------------------------
# Pure functions
# ---------------------------------------------------------------------------

def _get_age_band(age: int) -> Optional[Tuple[int, int]]:
    """Find the age band for the given age."""
    for band in IJM_PRIMES:
        if band[0] <= age <= band[1]:
            return band
    return None


def _get_prime_rate(age: int, delai_carence: int) -> Optional[float]:
    """Get the premium rate per CHF 1'000 of monthly insured income."""
    band = _get_age_band(age)
    if band is None:
        return None
    rates = IJM_PRIMES.get(band, {})
    return rates.get(delai_carence)


def simuler_ijm(
    revenu_mensuel: float,
    age: int,
    delai_carence: int = 30,
) -> IjmResult:
    """Simulate IJM (income loss insurance) for a self-employed person.

    Args:
        revenu_mensuel: Monthly income (CHF).
        age: Age of the person.
        delai_carence: Waiting period in days (30, 60, or 90).

    Returns:
        IjmResult with premium estimate, daily allowance, and alerts.
    """
    alertes: List[str] = []

    # Validate waiting period
    if delai_carence not in DELAIS_VALIDES:
        delai_carence = 30
        alertes.append(
            f"Delai de carence invalide. Valeurs acceptees: {DELAIS_VALIDES}. "
            f"Valeur par defaut utilisee: 30 jours."
        )

    # Handle edge cases
    if revenu_mensuel <= 0:
        return IjmResult(
            indemnite_journaliere=0.0,
            prime_mensuelle=0.0,
            prime_annuelle=0.0,
            cout_sans_couverture=0.0,
            chiffre_choc="Avec un revenu nul, l'IJM n'est pas applicable.",
            alertes=alertes,
            disclaimer=DISCLAIMER,
            sources=list(SOURCES),
        )

    # Daily allowance: 80% of daily income
    revenu_journalier = revenu_mensuel / JOURS_OUVRABLES_PAR_MOIS
    indemnite_journaliere = round(revenu_journalier * TAUX_COUVERTURE, 2)

    # Premium calculation
    prime_rate = _get_prime_rate(age, delai_carence)
    if prime_rate is None:
        # Age outside known bands
        alertes.append(
            f"Age {age} en dehors des tranches connues (18-65). "
            f"Estimation impossible. Contactez un assureur."
        )
        prime_mensuelle = 0.0
        prime_annuelle = 0.0
    else:
        # Rate is per CHF 1'000 of monthly insured income
        revenu_assure_mensuel = revenu_mensuel * TAUX_COUVERTURE
        unites_1000 = revenu_assure_mensuel / 1000.0
        prime_mensuelle = round(unites_1000 * prime_rate, 2)
        prime_annuelle = round(prime_mensuelle * 12, 2)

    # Cost without coverage: income lost during the waiting period
    cout_sans_couverture = round(revenu_journalier * delai_carence, 2)

    # Alerts
    if age >= 51:
        alertes.append(
            f"A {age} ans, les primes IJM sont significativement plus elevees. "
            f"Envisagez un delai de carence plus long (60 ou 90 jours) pour "
            f"reduire la prime, en constituant une reserve de tresorerie equivalente."
        )

    if prime_annuelle > revenu_mensuel * 0.5 and prime_annuelle > 0:
        alertes.append(
            f"La prime annuelle ({prime_annuelle:,.0f} CHF) represente une part "
            f"importante de votre revenu mensuel. Comparez plusieurs offres."
        )

    alertes.append(
        "Sans IJM, un-e independant-e n'a AUCUNE couverture de remplacement "
        "de revenu en cas de maladie. C'est l'une des lacunes les plus "
        "critiques du statut d'independant-e."
    )

    chiffre_choc = (
        f"Sans IJM, tu perds {cout_sans_couverture:,.0f} CHF de revenu pendant "
        f"le delai de carence de {delai_carence} jours."
    )

    return IjmResult(
        indemnite_journaliere=indemnite_journaliere,
        prime_mensuelle=prime_mensuelle,
        prime_annuelle=prime_annuelle,
        cout_sans_couverture=cout_sans_couverture,
        chiffre_choc=chiffre_choc,
        alertes=alertes,
        disclaimer=DISCLAIMER,
        sources=list(SOURCES),
    )
