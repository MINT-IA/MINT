"""
Connaissances cantonales spécifiques — RAG v2.

Fournit des données fiscales, immobilières et de caisses de pension
pour les 11 principaux cantons suisses (+ données partielles pour les autres).

Sources:
    - Administration fédérale des contributions — Charge fiscale 2024
    - Statistique suisse des loyers — OFS 2024
    - Répertoire des institutions de prévoyance — OFS 2024
    - FINMA — liste des caisses de pension enregistrées
    - Publications cantonales officielles 2025

Sprint S67 — RAG v2 Knowledge Pipeline.
"""

from __future__ import annotations

from typing import Optional

# ---------------------------------------------------------------------------
# Compliance constants
# ---------------------------------------------------------------------------

DISCLAIMER = (
    "Données cantonales approximatives — estimations basées sur les données "
    "publiques cantonales 2024/2025. "
    "Pour une planification précise, consulte les publications "
    "de ton canton ou un·e spécialiste fiscal·e. "
    "Outil éducatif — ne constitue pas un conseil (LSFin)."
)

SOURCES = [
    "Administration fédérale des contributions — Charge fiscale en Suisse 2024",
    "Statistique suisse des loyers OFS 2024",
    "Répertoire des institutions de prévoyance OFS 2024",
    "LHID art. 1 (harmonisation fiscale)",
]

# ---------------------------------------------------------------------------
# Tax specifics by canton
# ---------------------------------------------------------------------------

# Combined cantonal+communal marginal rate (approximate, main city, 2025)
# Rates are effective marginal rates for a single person earning 100k CHF
_TAX_SPECIFICS: dict[str, dict] = {
    "ZH": {
        "canton": "ZH",
        "name": "Zurich",
        "marginal_rate_pct": 32.5,
        "capital_gains_tax": False,
        "wealth_tax_rate_permille": 2.5,
        "inheritance_tax_direct_heirs": False,
        "gift_tax_direct_heirs": False,
        "notable_deductions": ["Frais de transport jusqu'à 5'000 CHF", "3a jusqu'à CHF 7'258"],
        "source": "StG ZH § 16 ss, Charge fiscale AFC 2024",
        "rank_income_tax": 12,  # rank among 26 cantons, 1=lowest
    },
    "BE": {
        "canton": "BE",
        "name": "Berne",
        "marginal_rate_pct": 41.5,
        "capital_gains_tax": False,
        "wealth_tax_rate_permille": 4.5,
        "inheritance_tax_direct_heirs": False,
        "gift_tax_direct_heirs": False,
        "notable_deductions": ["Déduction enfants", "3a jusqu'à CHF 7'258"],
        "source": "StG BE art. 1 ss, Charge fiscale AFC 2024",
        "rank_income_tax": 22,
    },
    "VD": {
        "canton": "VD",
        "name": "Vaud",
        "marginal_rate_pct": 41.5,
        "capital_gains_tax": False,
        "wealth_tax_rate_permille": 3.5,
        "inheritance_tax_direct_heirs": False,
        "gift_tax_direct_heirs": False,
        "notable_deductions": ["Abattements pour enfants", "3a jusqu'à CHF 7'258"],
        "source": "LI VD art. 1 ss, Charge fiscale AFC 2024",
        "rank_income_tax": 21,
    },
    "GE": {
        "canton": "GE",
        "name": "Genève",
        "marginal_rate_pct": 44.0,
        "capital_gains_tax": False,
        "wealth_tax_rate_permille": 4.5,
        "inheritance_tax_direct_heirs": False,
        "gift_tax_direct_heirs": False,
        "notable_deductions": ["Assurance maladie déductible", "3a jusqu'à CHF 7'258"],
        "source": "LIPM GE art. 1 ss, Charge fiscale AFC 2024",
        "rank_income_tax": 25,
    },
    "VS": {
        "canton": "VS",
        "name": "Valais",
        "marginal_rate_pct": 36.0,
        "capital_gains_tax": False,
        "wealth_tax_rate_permille": 2.5,
        "inheritance_tax_direct_heirs": False,
        "gift_tax_direct_heirs": False,
        "notable_deductions": ["Déduction hypothèque", "3a jusqu'à CHF 7'258"],
        "source": "LF VS art. 1 ss, Charge fiscale AFC 2024",
        "rank_income_tax": 15,
    },
    "TI": {
        "canton": "TI",
        "name": "Tessin",
        "marginal_rate_pct": 33.5,
        "capital_gains_tax": False,
        "wealth_tax_rate_permille": 2.0,
        "inheritance_tax_direct_heirs": False,
        "gift_tax_direct_heirs": False,
        "notable_deductions": ["Déductions spéciales Lugano", "3a jusqu'à CHF 7'258"],
        "source": "LIFD TI art. 1 ss, Charge fiscale AFC 2024",
        "rank_income_tax": 14,
    },
    "ZG": {
        "canton": "ZG",
        "name": "Zoug",
        "marginal_rate_pct": 22.5,
        "capital_gains_tax": False,
        "wealth_tax_rate_permille": 0.75,
        "inheritance_tax_direct_heirs": False,
        "gift_tax_direct_heirs": False,
        "notable_deductions": ["Taux cantonal très bas", "3a jusqu'à CHF 7'258"],
        "source": "StG ZG § 1 ss, Charge fiscale AFC 2024",
        "rank_income_tax": 1,  # lowest in Switzerland
    },
    "BS": {
        "canton": "BS",
        "name": "Bâle-Ville",
        "marginal_rate_pct": 36.5,
        "capital_gains_tax": False,
        "wealth_tax_rate_permille": 3.5,
        "inheritance_tax_direct_heirs": False,
        "gift_tax_direct_heirs": False,
        "notable_deductions": ["Déduction mobilité", "3a jusqu'à CHF 7'258"],
        "source": "StG BS § 1 ss, Charge fiscale AFC 2024",
        "rank_income_tax": 17,
    },
    "LU": {
        "canton": "LU",
        "name": "Lucerne",
        "marginal_rate_pct": 31.5,
        "capital_gains_tax": False,
        "wealth_tax_rate_permille": 2.0,
        "inheritance_tax_direct_heirs": False,
        "gift_tax_direct_heirs": False,
        "notable_deductions": ["Déductions famille", "3a jusqu'à CHF 7'258"],
        "source": "StG LU § 1 ss, Charge fiscale AFC 2024",
        "rank_income_tax": 9,
    },
    "AG": {
        "canton": "AG",
        "name": "Argovie",
        "marginal_rate_pct": 35.0,
        "capital_gains_tax": False,
        "wealth_tax_rate_permille": 2.5,
        "inheritance_tax_direct_heirs": False,
        "gift_tax_direct_heirs": False,
        "notable_deductions": ["Déductions standard", "3a jusqu'à CHF 7'258"],
        "source": "StG AG § 1 ss, Charge fiscale AFC 2024",
        "rank_income_tax": 13,
    },
    "SG": {
        "canton": "SG",
        "name": "Saint-Gall",
        "marginal_rate_pct": 33.0,
        "capital_gains_tax": False,
        "wealth_tax_rate_permille": 2.0,
        "inheritance_tax_direct_heirs": False,
        "gift_tax_direct_heirs": False,
        "notable_deductions": ["Déductions standard", "3a jusqu'à CHF 7'258"],
        "source": "StG SG art. 1 ss, Charge fiscale AFC 2024",
        "rank_income_tax": 10,
    },
}

# ---------------------------------------------------------------------------
# Pension funds (caisses de pension) by canton
# ---------------------------------------------------------------------------

_PENSION_FUNDS: dict[str, list[str]] = {
    "ZH": ["BVK (Beamtenversicherungskasse ZH)", "Migros Pensionskasse", "Swisscom Pension Fund",
           "Zürich Versicherungsgruppe Pensionskasse", "PK SBB", "Novartis Pensionskasse"],
    "BE": ["BPK (Bernische Pensionskasse)", "Publica (fédéral)", "Allianz Suisse PK",
           "PK Post", "Helvetia PK"],
    "VD": ["CPEV (Caisse de pensions de l'Etat de Vaud)", "Nestlé Pension Fund",
           "Helvetia PK", "BCV Caisse de retraite", "CIEPP"],
    "GE": ["CAP (Caisse de prévoyance du canton GE)", "Fondation de prévoyance Pictet",
           "UBS Pension Fund", "Rolex Prévoyance", "SGGK"],
    "VS": ["CPE (Caisse de pensions de l'Etat du Valais)", "HOTELA",
           "Raiffeisen Pensionskasse", "Zurich PK"],
    "TI": ["CPPCT (Cassa pensioni Cantone Ticino)", "Cornèr Pensionskasse",
           "Banca Stato PK", "Helvetia PK"],
    "ZG": ["Zuger Pensionskasse", "V-ZUG Pensionskasse",
           "Roche Pensionskasse", "Siemens Schweiz PK"],
    "BS": ["Pensionskasse BS (PKBS)", "Novartis Pensionskasse", "Roche Pensionskasse",
           "Bank BIS PK", "Helvetia PK"],
    "LU": ["Luzerner Pensionskasse (LUPK)", "Swisscom PK",
           "Schweizerische Mobiliar PK", "Raiffeisen PK"],
    "AG": ["Aargauische Pensionskasse (APK)", "ABB Pensionskasse",
           "Allianz Suisse PK", "ASGA Pensionskasse"],
    "SG": ["PKSG (Pensionskasse SG)", "Helvetia PK",
           "ASGA Pensionskasse", "Swiss Re PK"],
    "FR": ["CPEF (Caisse de pension canton FR)", "Groupe Mutuel PK", "Helvetia PK"],
    "SO": ["Pensionskasse Kanton Solothurn", "Allianz Suisse PK"],
    "GR": ["Pensionskasse Graubünden (PKGR)", "Engadiner PK"],
    "NE": ["CPEV-NE", "Helvetia PK", "Retraites Populaires"],
    "JU": ["Caisse canton JU", "Helvetia PK"],
    "UR": ["Pensionskasse Uri", "Kantonale Verwaltung UR"],
    "SZ": ["Pensionskasse Kanton Schwyz", "Roche PK"],
    "NW": ["Pensionskasse Nidwalden", "Kantonalbank NW PK"],
    "OW": ["Pensionskasse Obwalden"],
    "GL": ["Pensionskasse Glarus"],
    "AR": ["Pensionskasse AR"],
    "AI": ["Pensionskasse AI"],
    "SH": ["Pensionskasse SH"],
    "TG": ["Pensionskasse Thurgau (PKTG)"],
}

# ---------------------------------------------------------------------------
# Housing market by canton
# ---------------------------------------------------------------------------

_HOUSING_MARKET: dict[str, dict] = {
    "ZH": {
        "canton": "ZH",
        "median_rent_4pce_chf": 2_400,
        "median_price_per_sqm_buy_chf": 12_500,
        "avg_mortgage_rate_pct": 1.8,
        "rental_vacancy_rate_pct": 0.8,
        "market_pressure": "très élevé",
        "comment": "Marché zurichois très tendu, surtout ville de Zurich et lac.",
        "source": "OFS Statistique des loyers 2024, SNB Bulletin 2024",
    },
    "BE": {
        "canton": "BE",
        "median_rent_4pce_chf": 1_650,
        "median_price_per_sqm_buy_chf": 7_200,
        "avg_mortgage_rate_pct": 1.8,
        "rental_vacancy_rate_pct": 1.5,
        "market_pressure": "modéré",
        "comment": "Berne plus abordable que ZH/GE. Disparités ville/campagne.",
        "source": "OFS Statistique des loyers 2024",
    },
    "VD": {
        "canton": "VD",
        "median_rent_4pce_chf": 2_100,
        "median_price_per_sqm_buy_chf": 10_000,
        "avg_mortgage_rate_pct": 1.8,
        "rental_vacancy_rate_pct": 0.9,
        "market_pressure": "élevé",
        "comment": "Lausanne et Riviera parmi les plus chers de Romandie.",
        "source": "OFS Statistique des loyers 2024",
    },
    "GE": {
        "canton": "GE",
        "median_rent_4pce_chf": 2_800,
        "median_price_per_sqm_buy_chf": 14_000,
        "avg_mortgage_rate_pct": 1.8,
        "rental_vacancy_rate_pct": 0.4,
        "market_pressure": "extrêmement élevé",
        "comment": "Genève = loyer médian le plus élevé de Suisse. Vacance quasi nulle.",
        "source": "OFS Statistique des loyers 2024",
    },
    "VS": {
        "canton": "VS",
        "median_rent_4pce_chf": 1_450,
        "median_price_per_sqm_buy_chf": 6_000,
        "avg_mortgage_rate_pct": 1.8,
        "rental_vacancy_rate_pct": 2.2,
        "market_pressure": "modéré",
        "comment": "Valais plus abordable, sauf stations ski (Verbier, Crans-Montana).",
        "source": "OFS Statistique des loyers 2024",
    },
    "TI": {
        "canton": "TI",
        "median_rent_4pce_chf": 1_600,
        "median_price_per_sqm_buy_chf": 7_500,
        "avg_mortgage_rate_pct": 1.8,
        "rental_vacancy_rate_pct": 1.8,
        "market_pressure": "modéré",
        "comment": "Lugano plus tendu que le reste du canton.",
        "source": "OFS Statistique des loyers 2024",
    },
    "ZG": {
        "canton": "ZG",
        "median_rent_4pce_chf": 2_350,
        "median_price_per_sqm_buy_chf": 13_000,
        "avg_mortgage_rate_pct": 1.8,
        "rental_vacancy_rate_pct": 0.7,
        "market_pressure": "très élevé",
        "comment": "Zoug parmi les plus chers de Suisse centrale. Attractivité fiscale.",
        "source": "OFS Statistique des loyers 2024",
    },
    "BS": {
        "canton": "BS",
        "median_rent_4pce_chf": 1_900,
        "median_price_per_sqm_buy_chf": 9_500,
        "avg_mortgage_rate_pct": 1.8,
        "rental_vacancy_rate_pct": 1.1,
        "market_pressure": "élevé",
        "comment": "Bâle-Ville dense, pression immobilière forte.",
        "source": "OFS Statistique des loyers 2024",
    },
    "LU": {
        "canton": "LU",
        "median_rent_4pce_chf": 1_750,
        "median_price_per_sqm_buy_chf": 8_200,
        "avg_mortgage_rate_pct": 1.8,
        "rental_vacancy_rate_pct": 1.4,
        "market_pressure": "modéré",
        "comment": "Lucerne bien situé, légèrement sous la moyenne nationale.",
        "source": "OFS Statistique des loyers 2024",
    },
    "AG": {
        "canton": "AG",
        "median_rent_4pce_chf": 1_650,
        "median_price_per_sqm_buy_chf": 7_800,
        "avg_mortgage_rate_pct": 1.8,
        "rental_vacancy_rate_pct": 2.0,
        "market_pressure": "modéré",
        "comment": "Argovie relativement abordable, notamment hors zones ZH.",
        "source": "OFS Statistique des loyers 2024",
    },
    "SG": {
        "canton": "SG",
        "median_rent_4pce_chf": 1_600,
        "median_price_per_sqm_buy_chf": 7_200,
        "avg_mortgage_rate_pct": 1.8,
        "rental_vacancy_rate_pct": 2.1,
        "market_pressure": "modéré",
        "comment": "Saint-Gall accessible, surtout hors ville.",
        "source": "OFS Statistique des loyers 2024",
    },
}


# ---------------------------------------------------------------------------
# CantonalKnowledge service (pure functions)
# ---------------------------------------------------------------------------


class CantonalKnowledge:
    """Provides canton-specific financial knowledge for the RAG pipeline."""

    @staticmethod
    def tax_specifics(canton: str) -> Optional[dict]:
        """
        Return tax specifics for a given canton.

        Args:
            canton: 2-letter ISO canton code (e.g. "ZH", "GE").

        Returns:
            Dict with tax data, or None if canton not found.
        """
        return _TAX_SPECIFICS.get(canton.upper())

    @staticmethod
    def pension_funds(canton: str) -> list[str]:
        """
        Return list of major pension funds active in a canton.

        Args:
            canton: 2-letter ISO canton code.

        Returns:
            List of pension fund names, or empty list if unknown.
        """
        return list(_PENSION_FUNDS.get(canton.upper(), []))

    @staticmethod
    def housing_market(canton: str) -> Optional[dict]:
        """
        Return housing market data for a canton.

        Args:
            canton: 2-letter ISO canton code.

        Returns:
            Dict with housing data, or None if canton not found.
        """
        return _HOUSING_MARKET.get(canton.upper())

    @staticmethod
    def all_cantons() -> list[str]:
        """Return list of all cantons that have tax data."""
        return list(_TAX_SPECIFICS.keys())

    @staticmethod
    def lowest_tax_canton() -> str:
        """Return the canton with the lowest income tax rate."""
        return min(_TAX_SPECIFICS.items(), key=lambda x: x[1]["marginal_rate_pct"])[0]

    @staticmethod
    def highest_rent_canton() -> str:
        """Return the canton with the highest median rent."""
        return max(
            _HOUSING_MARKET.items(),
            key=lambda x: x[1]["median_rent_4pce_chf"],
        )[0]

    @staticmethod
    def compare_tax(canton_a: str, canton_b: str) -> Optional[dict]:
        """
        Compare tax rates between two cantons.

        Returns:
            Comparison dict, or None if either canton is missing.
        """
        a = _TAX_SPECIFICS.get(canton_a.upper())
        b = _TAX_SPECIFICS.get(canton_b.upper())
        if a is None or b is None:
            return None
        diff = a["marginal_rate_pct"] - b["marginal_rate_pct"]
        return {
            "canton_a": canton_a.upper(),
            "canton_b": canton_b.upper(),
            "rate_a": a["marginal_rate_pct"],
            "rate_b": b["marginal_rate_pct"],
            "difference_pct": round(diff, 2),
            "cheaper_canton": canton_a.upper() if diff < 0 else canton_b.upper(),
        }
