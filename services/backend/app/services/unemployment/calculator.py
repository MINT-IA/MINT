"""
Unemployment benefits calculator (LACI / OAC).

Calculates LACI unemployment benefits: daily/monthly indemnities,
duration, eligibility, timeline and checklist for job loss situations.

The insured gain is capped at CHF 12'350/month (LACI art. 23 al. 1).
The indemnity rate is 70% (standard) or 80% (children, disability,
or low salary below CHF 3'797/month — LACI art. 22).

Duration depends on age and contribution months (LACI art. 27):
    - Under 25, 12+ months: 200 indemnities
    - 25-54, 12-17 months: 200 indemnities
    - 25-54, 18+ months: 260 indemnities (18 months effective, can be up to 400 with special conditions)
    - 55-59, 22+ months: 400 indemnities
    - 60+, 22+ months: 520 indemnities

Sources:
    - LACI art. 8 (droit a l'indemnite)
    - LACI art. 13 (periode de cotisation: 12 mois sur 2 ans)
    - LACI art. 22 (montant: 70% ou 80%)
    - LACI art. 23 al. 1 (gain assure max: 148'200/an = 12'350/mois)
    - LACI art. 27 (nombre maximum d'indemnites journalieres)
    - OAC art. 37 (delai d'attente: 5 jours standard)

Sprint S19 — Chomage (LACI) + Premier emploi.
"""

from typing import List, Optional, Tuple


# ---------------------------------------------------------------------------
# Constants — LACI / OAC 2025/2026
# ---------------------------------------------------------------------------

UNEMPLOYMENT_RATE_BASE = 0.70
UNEMPLOYMENT_RATE_ENHANCED = 0.80
GAIN_ASSURE_MAX = 12_350.0  # CHF/month (LACI art. 23 al. 1)
SALARY_THRESHOLD_ENHANCED = 3_797.0  # Below this -> 80% (LACI art. 22 al. 2)
DELAI_CARENCE_STANDARD = 5  # days (OAC art. 37)
WORKING_DAYS_PER_MONTH = 21.75
MIN_COTISATION_MONTHS = 12  # Minimum 12 months in 2 years (LACI art. 13)

# Duration table (LACI art. 27)
# Format: (min_age, max_age, min_months_cotisation, nombre_indemnites)
# Ordered from most generous to least — we walk and find the best match
DURATION_TABLE: List[Tuple[int, int, int, int]] = [
    # 60+: 520 if 22+ months
    (60, 99, 22, 520),
    # 55-59: 400 if 22+ months
    (55, 59, 22, 400),
    # 25-54: 400 if 22+ months (long cotisation)
    (25, 54, 18, 400),
    # 25-54: 260 if 18+ months (standard long)
    # Actually LACI art. 27 al. 2: 18+ months -> 400 for 25-54
    # Corrected: 25-54 with 18+ -> 400, 12-17 -> 260
    # Let's re-check: LACI art. 27:
    #   al. 1: 260 indemnites (standard with 18+ months, age 25-54)
    #   al. 2: 400 for 55+
    #   al. 3: 520 for 60+
    #   al. 4: Under 25 -> 200
    # So: 25-54, 12-17 months -> 200, 18+ -> 260 (not 400)
    # 55-59, 22+ -> 400
    # 60+, 22+ -> 520
]

# Clean duration table based on actual LACI art. 27 al. 2
# CRITICAL: 25-54 with 22+ months = 400 days (lit. c), NOT 260.
# 260 is for 12-21 months cotisation only.
DURATION_RULES: List[Tuple[int, int, int, int]] = [
    # (min_age, max_age, min_months_cotisation, nombre_indemnites)
    # Under 25: 200 if 12+ months (LACI art. 27 al. 2 lit. a)
    (16, 24, 12, 200),
    # 25-54: 200 if 12-17 months
    (25, 54, 12, 200),
    # 25-54: 260 if 18-21 months (LACI art. 27 al. 2 lit. b)
    (25, 54, 18, 260),
    # 25-54: 400 if 22+ months (LACI art. 27 al. 2 lit. c)
    (25, 54, 22, 400),
    # 55+: 520 if 22+ months (LACI art. 27 al. 2 lit. d)
    (55, 99, 22, 520),
]

# ORP links per canton
ORP_LINKS = {
    "ZH": "https://awa.zh.ch",
    "BE": "https://www.beco.be.ch",
    "VD": "https://www.vd.ch/themes/economie/emploi",
    "GE": "https://www.ge.ch/oce",
    "LU": "https://daw.lu.ch",
    "BS": "https://www.awa.bs.ch",
    "SG": "https://www.sg.ch/wirtschaft-arbeit",
    "AG": "https://www.ag.ch/awa",
    "TI": "https://www.ti.ch/lavoro",
    "FR": "https://www.fr.ch/travail",
    "NE": "https://www.ne.ch/emploi",
    "VS": "https://www.vs.ch/emploi",
    "JU": "https://www.jura.ch/emploi",
    "SO": "https://www.so.ch/verwaltung/volkswirtschaftsdepartement/amt-fuer-wirtschaft-und-arbeit/",
    "TG": "https://awa.tg.ch",
    "BL": "https://www.awa.bl.ch",
    "GR": "https://www.gr.ch/DE/institutionen/verwaltung/dvs/awa",
    "SZ": "https://www.sz.ch/awa",
    "ZG": "https://www.zg.ch/behoerden/volkswirtschaftsdirektion/kontaktstelle-wirtschaft",
    "SH": "https://sh.ch/CMS/Webseite/Kanton-Schaffhausen/Beh-rde/Verwaltung/Volkswirtschaftsdepartement/Arbeitsinspektorat-und-Arbeitsmarkt-1078179-DE.html",
    "AR": "https://www.ar.ch/verwaltung/departement-volkswirtschaft-und-soziales",
    "AI": "https://www.ai.ch",
    "GL": "https://www.gl.ch",
    "NW": "https://www.nw.ch",
    "OW": "https://www.ow.ch",
    "UR": "https://www.ur.ch",
}

DISCLAIMER = (
    "MINT est un outil educatif. Ce simulateur ne constitue pas un conseil "
    "en matiere de droit du travail ou d'assurances sociales au sens de la LSFin. "
    "Les montants exacts dependent de ta caisse de chomage et de ton ORP cantonal. "
    "Consulte un ou une specialiste en droit social pour une analyse personnalisee."
)

SOURCES = [
    "LACI art. 8 (droit a l'indemnite de chomage)",
    "LACI art. 13 (periode de cotisation: 12 mois sur 2 ans)",
    "LACI art. 22 (montant de l'indemnite: 70% ou 80%)",
    "LACI art. 23 al. 1 (gain assure max: 148'200 CHF/an)",
    "LACI art. 27 (nombre maximum d'indemnites journalieres)",
    "OAC art. 37 (delai d'attente general: 5 jours)",
]


# ---------------------------------------------------------------------------
# Calculator class
# ---------------------------------------------------------------------------

class UnemploymentCalculator:
    """Calculates LACI unemployment benefits."""

    def calculate(
        self,
        gain_assure_mensuel: float,
        age: int,
        annees_cotisation: int,
        has_children: bool = False,
        has_disability: bool = False,
        canton: str = "ZH",
        date_licenciement: Optional[str] = None,
    ) -> dict:
        """Calculate unemployment benefits based on LACI rules.

        Args:
            gain_assure_mensuel: Monthly insured earnings (last salary), CHF.
            age: Current age.
            annees_cotisation: Months of contributions in the last 2 years (0-24).
            has_children: Has dependent children.
            has_disability: Has disability.
            canton: Canton code (2 letters).
            date_licenciement: Dismissal date (ISO 8601, optional).

        Returns:
            Dict with all response fields for UnemploymentBenefitsResponse.
        """
        alertes: List[str] = []

        # Validate gain
        if gain_assure_mensuel <= 0:
            return self._build_ineligible_response(
                raison="Le gain assure mensuel doit etre superieur a 0 CHF.",
                alertes=["Verifie le montant de ton dernier salaire."],
            )

        # 1. Check eligibility (LACI art. 13: min 12 months in 2 years)
        if annees_cotisation < MIN_COTISATION_MONTHS:
            return self._build_ineligible_response(
                raison=(
                    f"Periode de cotisation insuffisante: {annees_cotisation} mois "
                    f"(minimum requis: {MIN_COTISATION_MONTHS} mois sur les 2 dernieres annees, "
                    f"LACI art. 13)."
                ),
                alertes=[
                    "Tu pourrais avoir droit a des indemnites de chomage speciales "
                    "(liberation des conditions de cotisation) dans certains cas: "
                    "fin de formation, retour de l'etranger, etc. Renseigne-toi aupres de ton ORP.",
                ],
            )

        # 2. Cap gain assuré at 12'350
        gain_retenu = min(gain_assure_mensuel, GAIN_ASSURE_MAX)
        if gain_assure_mensuel > GAIN_ASSURE_MAX:
            alertes.append(
                f"Ton salaire ({gain_assure_mensuel:,.0f} CHF) depasse le gain assure "
                f"maximum de {GAIN_ASSURE_MAX:,.0f} CHF/mois. L'indemnite est calculee "
                f"sur {GAIN_ASSURE_MAX:,.0f} CHF."
            )

        # 3. Determine rate (LACI art. 22)
        taux = self._determine_rate(gain_retenu, has_children, has_disability)

        # 4. Calculate daily benefit
        indemnite_journaliere = round(gain_retenu * taux / WORKING_DAYS_PER_MONTH, 2)

        # 5. Calculate monthly benefit
        indemnite_mensuelle = round(indemnite_journaliere * WORKING_DAYS_PER_MONTH, 2)

        # 6. Calculate number of indemnities from table (LACI art. 27)
        nombre_indemnites = self._calculate_duration(age, annees_cotisation)

        # 7. Estimate duration in months
        duree_mois = round(nombre_indemnites / WORKING_DAYS_PER_MONTH, 1)

        # 8. Build timeline
        timeline = self._build_timeline(canton)

        # 9. Generate checklist
        checklist = self._build_checklist()

        # 10. Alerts
        if age >= 55:
            alertes.append(
                "A 55 ans et plus, tu beneficies d'un nombre d'indemnites plus eleve "
                "(400 ou 520). Cependant, la reinsertion professionnelle peut etre "
                "plus difficile. Profite des mesures de formation proposees par l'ORP."
            )

        if taux == UNEMPLOYMENT_RATE_BASE:
            alertes.append(
                "Tu recois 70% de ton gain assure. Si ta situation change (enfants, "
                "handicap), ton taux pourrait passer a 80%."
            )

        # 11. Chiffre choc
        perte_mensuelle = round(gain_retenu - indemnite_mensuelle, 2)
        premier_eclairage = (
            f"Ton revenu baisse de {perte_mensuelle:,.0f} CHF/mois "
            f"(de {gain_retenu:,.0f} a {indemnite_mensuelle:,.0f} CHF). "
            f"Adapte ton budget des maintenant."
        )

        return {
            "taux_indemnite": taux,
            "gain_assure_retenu": gain_retenu,
            "indemnite_journaliere": indemnite_journaliere,
            "indemnite_mensuelle": indemnite_mensuelle,
            "nombre_indemnites": nombre_indemnites,
            "duree_mois": duree_mois,
            "delai_carence_jours": DELAI_CARENCE_STANDARD,
            "eligible": True,
            "raison_non_eligible": None,
            "timeline": timeline,
            "checklist": checklist,
            "alertes": alertes,
            "premier_eclairage": premier_eclairage,
            "disclaimer": DISCLAIMER,
            "sources": list(SOURCES),
        }

    def _determine_rate(
        self,
        gain: float,
        has_children: bool,
        has_disability: bool,
    ) -> float:
        """Determine indemnity rate (LACI art. 22).

        80% if: children, disability, or salary below 3'797 CHF/month.
        70% otherwise.
        """
        if has_children or has_disability or gain < SALARY_THRESHOLD_ENHANCED:
            return UNEMPLOYMENT_RATE_ENHANCED
        return UNEMPLOYMENT_RATE_BASE

    def _calculate_duration(self, age: int, months_cotisation: int) -> int:
        """Calculate number of daily indemnities (LACI art. 27).

        Walks the duration rules and returns the best (highest) matching count.
        """
        best = 0
        for min_age, max_age, min_months, nombre in DURATION_RULES:
            if min_age <= age <= max_age and months_cotisation >= min_months:
                best = max(best, nombre)
        # Fallback: if eligible but no rule matched (shouldn't happen), use 200
        return best if best > 0 else 200

    def _build_timeline(self, canton: str) -> List[dict]:
        """Build the post-job-loss timeline with ordered steps."""
        canton_upper = canton.upper()
        orp_link = ORP_LINKS.get(canton_upper, "https://www.arbeit.swiss")

        return [
            {
                "jour": 0,
                "action": "Inscription ORP",
                "description": (
                    f"S'inscrire a l'Office regional de placement de ton canton "
                    f"({canton_upper}). Lien: {orp_link}"
                ),
                "urgence": "immediate",
            },
            {
                "jour": 1,
                "action": "Demande d'indemnites",
                "description": (
                    "Deposer le dossier aupres de la caisse de chomage. "
                    "Documents necessaires: contrat de travail, certificat de salaire, "
                    "lettre de licenciement, pieces d'identite."
                ),
                "urgence": "immediate",
            },
            {
                "jour": 5,
                "action": "Fin delai de carence",
                "description": (
                    "Les 5 premiers jours ne sont pas indemnises (delai de carence "
                    "general, OAC art. 37)."
                ),
                "urgence": "semaine1",
            },
            {
                "jour": 7,
                "action": "Bilan budgetaire",
                "description": (
                    "Adapter ton budget au nouveau revenu (70-80% du salaire). "
                    "Identifie les depenses compressibles."
                ),
                "urgence": "semaine1",
            },
            {
                "jour": 30,
                "action": "Transfert LPP",
                "description": (
                    "Transferer ton avoir LPP sur un compte de libre passage. "
                    "Tu as 6 mois pour choisir une institution, sinon la caisse "
                    "transfere d'office."
                ),
                "urgence": "mois1",
            },
            {
                "jour": 30,
                "action": "Pause 3a",
                "description": (
                    "Aucune cotisation 3a possible sans revenu lucratif. "
                    "Ne verse plus de cotisations tant que tu n'as pas retrouve un emploi."
                ),
                "urgence": "mois1",
            },
            {
                "jour": 60,
                "action": "Revision LAMal",
                "description": (
                    "Verifier si tu as droit a une reduction de prime LAMal (subsides). "
                    "Ton revenu a baisse: tu pourrais etre eligible."
                ),
                "urgence": "mois3",
            },
            {
                "jour": 90,
                "action": "Premier bilan ORP",
                "description": (
                    "Bilan avec ton ou ta spécialiste ORP. "
                    "Recherches d'emploi requises: minimum 8-12 postulations/mois."
                ),
                "urgence": "mois3",
            },
        ]

    def _build_checklist(self) -> List[str]:
        """Build the action checklist for unemployment."""
        return [
            "S'inscrire a l'ORP le plus rapidement possible (idealement avant la fin du contrat)",
            "Rassembler les documents: contrat, certificat de salaire, lettre de licenciement",
            "Ouvrir un dossier aupres de la caisse de chomage cantonale",
            "Verifier le droit aux subsides LAMal (baisse de revenu)",
            "Adapter le budget au nouveau revenu (70-80% du salaire)",
            "Transferer l'avoir LPP sur un compte de libre passage",
            "Suspendre les versements 3a tant qu'il n'y a pas de revenu lucratif",
            "Commencer les recherches d'emploi et documenter chaque postulation",
            "Se renseigner sur les mesures de formation proposees par l'ORP",
            "Verifier si l'assurance protection juridique couvre le droit du travail",
        ]

    def _build_ineligible_response(
        self,
        raison: str,
        alertes: Optional[List[str]] = None,
    ) -> dict:
        """Build a response for an ineligible person."""
        return {
            "taux_indemnite": 0.0,
            "gain_assure_retenu": 0.0,
            "indemnite_journaliere": 0.0,
            "indemnite_mensuelle": 0.0,
            "nombre_indemnites": 0,
            "duree_mois": 0.0,
            "delai_carence_jours": DELAI_CARENCE_STANDARD,
            "eligible": False,
            "raison_non_eligible": raison,
            "timeline": [],
            "checklist": [],
            "alertes": alertes or [],
            "premier_eclairage": "Tu n'es pas eligible aux indemnites de chomage dans cette configuration.",
            "disclaimer": DISCLAIMER,
            "sources": list(SOURCES),
        }


# ---------------------------------------------------------------------------
# Convenience function (functional style, like other modules)
# ---------------------------------------------------------------------------

def calculer_chomage(
    gain_assure_mensuel: float,
    age: int,
    annees_cotisation: int,
    has_children: bool = False,
    has_disability: bool = False,
    canton: str = "ZH",
    date_licenciement: Optional[str] = None,
) -> dict:
    """Convenience wrapper around UnemploymentCalculator.calculate()."""
    calculator = UnemploymentCalculator()
    return calculator.calculate(
        gain_assure_mensuel=gain_assure_mensuel,
        age=age,
        annees_cotisation=annees_cotisation,
        has_children=has_children,
        has_disability=has_disability,
        canton=canton,
        date_licenciement=date_licenciement,
    )


def get_orp_link(canton: str) -> dict:
    """Get the ORP link for a given canton."""
    canton_upper = canton.upper()
    return {
        "canton": canton_upper,
        "url": ORP_LINKS.get(canton_upper, "https://www.arbeit.swiss"),
    }


def get_unemployment_checklist() -> dict:
    """Get the generic unemployment checklist and timeline."""
    calculator = UnemploymentCalculator()
    return {
        "checklist": calculator._build_checklist(),
        "timeline": calculator._build_timeline("ZH"),
    }
