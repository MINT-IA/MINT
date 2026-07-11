"""
Unemployment benefits calculator (LACI / OACI).

Calculates LACI unemployment benefits: daily/monthly indemnities,
duration, eligibility, timeline and checklist for job loss situations.

The insured gain is capped at CHF 12'350/month (LACI art. 23 al. 1).
The indemnity rate is 70% (standard) or 80% (children, disability,
or low salary below CHF 3'797/month — LACI art. 22).

Duration depends on age and contribution months (LACI art. 27):
    - Under 25 without maintenance duty, 12-24 months: 200 indemnities
    - 12-17 months, from age 25 or with maintenance duty: 260 indemnities
    - 18-24 months: 400 indemnities
    - 22-24 months with age 55+ or disability pension >= 40%: 520 indemnities

Sources:
    - LACI art. 8 (droit a l'indemnite)
    - LACI art. 13 (periode de cotisation: 12 mois sur 2 ans)
    - LACI art. 22 (montant: 70% ou 80%)
    - LACI art. 23 al. 1 (gain assure max: 148'200/an = 12'350/mois)
    - LACI art. 27 (nombre maximum d'indemnites journalieres)
    - OACI art. 6a / LACI art. 18 (delai d'attente general, variable selon revenu)

Sprint S19 — Chomage (LACI) + Premier emploi.
"""

from typing import List, Optional


# ---------------------------------------------------------------------------
# Constants — LACI / OACI 2025/2026
# ---------------------------------------------------------------------------

UNEMPLOYMENT_RATE_BASE = 0.70
UNEMPLOYMENT_RATE_ENHANCED = 0.80
GAIN_ASSURE_MAX = 12_350.0  # CHF/month (LACI art. 23 al. 1)
SALARY_THRESHOLD_ENHANCED = 3_797.0  # Below this -> 80% (LACI art. 22 al. 2)
WORKING_DAYS_PER_MONTH = 21.7
MIN_COTISATION_MONTHS = 12  # Minimum 12 months in 2 years (LACI art. 13)

# Duration bands (LACI art. 27 / SECO "Etre au chomage").
UNDER_25_NO_MAINTENANCE_DAYS = 200
MIN_DURATION_DAYS = 260
STANDARD_DURATION_DAYS = 400
SENIOR_OR_DISABILITY_DAYS = 520

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
    "juridique ni une decision d'assurance sociale. "
    "Les montants exacts dependent de ta caisse de chomage et de ton ORP cantonal. "
    "Consulte un ou une spécialiste en droit social pour une analyse personnalisee."
)

SOURCES = [
    "LACI art. 8 (droit a l'indemnite de chomage)",
    "LACI art. 13 (periode de cotisation: 12 mois sur 2 ans)",
    "LACI art. 22 (montant de l'indemnite: 70% ou 80%)",
    "LACI art. 23 al. 1 (gain assure max: 148'200 CHF/an)",
    "LACI art. 27 (nombre maximum d'indemnites journalieres)",
    "OACI art. 6a / LACI art. 18 (delai d'attente general)",
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
        has_reached_avs_reference_age: bool = False,
        is_within_four_years_of_avs_reference_age: bool = False,
        canton: str = "ZH",
        date_licenciement: Optional[str] = None,
    ) -> dict:
        """Calculate unemployment benefits based on LACI rules.

        Args:
            gain_assure_mensuel: Monthly insured earnings (last salary), CHF.
            age: Current age.
            annees_cotisation: Months of contributions in the last 2 years (0-24).
            has_children: Has dependent children.
            has_disability: Has a disability pension of at least 40%.
            has_reached_avs_reference_age: True once the AVS reference age is reached.
            is_within_four_years_of_avs_reference_age: True when the LACI frame
                starts within four years before the AVS reference age.
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

        # Ordinary AC entitlement ends around the AVS reference age. With only
        # integer age in this endpoint, keep the calculator conservative; the
        # 60+ bridge/transition-benefits case belongs in a dedicated scenario.
        if has_reached_avs_reference_age or age >= 65:
            return self._build_ineligible_response(
                raison=(
                    "Ce calcul LACI s'arrete a l'age de reference AVS. "
                    "Analyse plutot les prestations transitoires et la coordination "
                    "AVS/LPP avec une caisse ou un ORP."
                ),
                alertes=[
                    "Apres l'age de reference AVS, la question centrale n'est plus "
                    "l'indemnite de chomage ordinaire mais la coordination AVS, LPP, "
                    "prestations transitoires et budget de retraite."
                ],
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
        nombre_indemnites = self._calculate_duration(
            age=age,
            months_cotisation=annees_cotisation,
            has_children=has_children,
            has_disability=has_disability,
            is_within_four_years_of_avs_reference_age=(
                is_within_four_years_of_avs_reference_age
            ),
        )

        # 7. Estimate duration in months
        duree_mois = round(nombre_indemnites / WORKING_DAYS_PER_MONTH, 1)
        delai_carence = self._calculate_waiting_days(
            annual_insured_earnings=gain_retenu * 12,
            has_maintenance_duty=has_children,
        )

        # 8. Build timeline
        timeline = self._build_timeline(canton, delai_carence)

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
                "rente d'invalidite d'au moins 40%), ton taux pourrait passer a 80%."
            )

        # 11. Chiffre choc: benefits are capped by insured earnings, but the
        # user-facing drop is against the real salary passed into the scenario.
        perte_mensuelle = round(gain_assure_mensuel - indemnite_mensuelle, 2)
        premier_eclairage = (
            f"Ton revenu baisse de {perte_mensuelle:,.0f} CHF/mois "
            f"(de {gain_assure_mensuel:,.0f} a {indemnite_mensuelle:,.0f} CHF). "
            f"Adapte ton budget des maintenant."
        )

        return {
            "taux_indemnite": taux,
            "gain_assure_retenu": gain_retenu,
            "indemnite_journaliere": indemnite_journaliere,
            "indemnite_mensuelle": indemnite_mensuelle,
            "nombre_indemnites": nombre_indemnites,
            "duree_mois": duree_mois,
            "delai_carence_jours": delai_carence,
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

    def _calculate_duration(
        self,
        age: int,
        months_cotisation: int,
        has_children: bool,
        has_disability: bool,
        is_within_four_years_of_avs_reference_age: bool = False,
    ) -> int:
        """Calculate number of daily indemnities (LACI art. 27).

        The 200-day cap is only for insured people under 25 without maintenance
        duty. A disability flag here means an invalidity pension of at least 40%.
        """
        # Treat an invalidity pension >=40% as the senior-duration exception
        # before applying the under-25/no-maintenance cap.
        if months_cotisation >= 22 and (age >= 55 or has_disability):
            return self._with_near_avs_extra_days(
                SENIOR_OR_DISABILITY_DAYS,
                months_cotisation,
                is_within_four_years_of_avs_reference_age,
            )
        if age < 25 and not has_children:
            return self._with_near_avs_extra_days(
                UNDER_25_NO_MAINTENANCE_DAYS,
                months_cotisation,
                is_within_four_years_of_avs_reference_age,
            )
        if months_cotisation >= 18:
            return self._with_near_avs_extra_days(
                STANDARD_DURATION_DAYS,
                months_cotisation,
                is_within_four_years_of_avs_reference_age,
            )
        if months_cotisation >= 12:
            return self._with_near_avs_extra_days(
                MIN_DURATION_DAYS,
                months_cotisation,
                is_within_four_years_of_avs_reference_age,
            )
        return 0

    def _with_near_avs_extra_days(
        self,
        base: int,
        months_cotisation: int,
        near_avs_reference_age: bool,
    ) -> int:
        return (
            base + 120 if near_avs_reference_age and months_cotisation >= 22 else base
        )

    def _calculate_waiting_days(
        self,
        annual_insured_earnings: float,
        has_maintenance_duty: bool,
    ) -> int:
        # OACI art. 6a / LACI art. 18; SECO/arbeit.swiss Directive LACI IC C110:
        # al. 2 exempts everyone up to CHF 36k/year; al. 3 also exempts
        # CHF 36'001-60k/year when there is maintenance duty for children <25.
        # Above those exemptions, C110 applies 5/10/15/20 days; for maintenance
        # duty, C110 caps the general wait at 5 days above CHF 60k/year.
        if annual_insured_earnings <= 36_000:
            return 0
        if has_maintenance_duty:
            return 0 if annual_insured_earnings <= 60_000 else 5
        if annual_insured_earnings <= 60_000:
            return 5
        if annual_insured_earnings <= 90_000:
            return 10
        if annual_insured_earnings <= 125_000:
            return 15
        return 20

    def _build_timeline(self, canton: str, waiting_days: int = 5) -> List[dict]:
        """Build the post-job-loss timeline with ordered steps."""
        canton_upper = canton.upper()
        orp_link = ORP_LINKS.get(canton_upper, "https://www.arbeit.swiss")

        timeline = [
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
                "jour": waiting_days,
                "action": "Fin delai de carence",
                "description": (
                    "Le delai d'attente general depend du revenu assure et "
                    "de l'obligation d'entretien (OACI art. 6a / LACI art. 18)."
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
        return sorted(timeline, key=lambda step: step["jour"])

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
            "delai_carence_jours": 0,
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
    has_reached_avs_reference_age: bool = False,
    is_within_four_years_of_avs_reference_age: bool = False,
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
        has_reached_avs_reference_age=has_reached_avs_reference_age,
        is_within_four_years_of_avs_reference_age=(
            is_within_four_years_of_avs_reference_age
        ),
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
