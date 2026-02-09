"""
Professional help resources for debt prevention.

Provides links and contact information for debt counseling services
by canton. All resources are public, free, and confidential.

Sources:
    - Dettes Conseils Suisse (organisation faitiere nationale)
    - Caritas Suisse (conseil en desendettement)
    - Services cantonaux de conseil en desendettement

Sprint S16 — Gap G6: Prevention dette.
"""

from dataclasses import dataclass, field
from typing import List, Optional


DISCLAIMER = (
    "Estimation a titre indicatif. MINT est un outil educatif et ne constitue "
    "pas un avis juridique. Les ressources listees sont des organismes publics "
    "ou associatifs reconnus. Consultez un ou une specialiste pour un "
    "accompagnement personnalise."
)


@dataclass
class HelpResource:
    """A single help resource."""
    nom: str
    description: str
    url: Optional[str]
    telephone: Optional[str]
    canton: Optional[str]        # None if national
    gratuit: bool
    confidentiel: bool
    type_aide: str               # "conseil", "juridique", "urgence", "prevention"


@dataclass
class HelpResourcesResult:
    """Complete result of help resources lookup."""
    resources: List[HelpResource]
    canton: str
    situation: str

    # Compliance
    chiffre_choc: str
    sources: List[str] = field(default_factory=list)
    disclaimer: str = DISCLAIMER


# National resources (available everywhere in Switzerland)
_NATIONAL_RESOURCES = [
    HelpResource(
        nom="Dettes Conseils Suisse",
        description=(
            "Organisation faitiere nationale de conseil en desendettement. "
            "Regroupe les services cantonaux et offre un premier contact gratuit."
        ),
        url="https://www.dettes.ch",
        telephone="0800 40 40 40",
        canton=None,
        gratuit=True,
        confidentiel=True,
        type_aide="conseil",
    ),
    HelpResource(
        nom="Caritas Suisse — Conseil en desendettement",
        description=(
            "Service de conseil social et en desendettement. "
            "Accompagnement gratuit et confidentiel pour les personnes en difficulte financiere."
        ),
        url="https://www.caritas.ch/dettes",
        telephone=None,
        canton=None,
        gratuit=True,
        confidentiel=True,
        type_aide="conseil",
    ),
    HelpResource(
        nom="La Main Tendue (Tel 143)",
        description=(
            "Ecoute anonyme 24h/24 pour les personnes en detresse, "
            "y compris stress financier et surendettement."
        ),
        url="https://www.143.ch",
        telephone="143",
        canton=None,
        gratuit=True,
        confidentiel=True,
        type_aide="urgence",
    ),
]


# Cantonal debt counseling services
_CANTONAL_RESOURCES = {
    "ZH": HelpResource(
        nom="Schuldenberatung Kanton Zurich",
        description="Service cantonal zurichois de conseil en desendettement.",
        url="https://www.schuldeninfo.ch",
        telephone="044 272 42 42",
        canton="ZH",
        gratuit=True,
        confidentiel=True,
        type_aide="conseil",
    ),
    "BE": HelpResource(
        nom="Berner Schuldenberatung",
        description="Service bernois de conseil en desendettement.",
        url="https://www.schuldenberatung-be.ch",
        telephone="031 372 30 32",
        canton="BE",
        gratuit=True,
        confidentiel=True,
        type_aide="conseil",
    ),
    "VD": HelpResource(
        nom="Centre Social Protestant (CSP) — Desendettement VD",
        description="Service vaudois de conseil en desendettement du CSP.",
        url="https://www.csp-vd.ch",
        telephone="021 560 60 60",
        canton="VD",
        gratuit=True,
        confidentiel=True,
        type_aide="conseil",
    ),
    "GE": HelpResource(
        nom="Caritas Geneve — Service desendettement",
        description="Service genevois de conseil en desendettement Caritas.",
        url="https://www.caritas-geneve.ch",
        telephone="022 708 04 44",
        canton="GE",
        gratuit=True,
        confidentiel=True,
        type_aide="conseil",
    ),
    "LU": HelpResource(
        nom="Schuldenberatung Luzern",
        description="Service lucernois de conseil en desendettement.",
        url="https://www.schuldenberatung-lu.ch",
        telephone="041 211 00 34",
        canton="LU",
        gratuit=True,
        confidentiel=True,
        type_aide="conseil",
    ),
    "BS": HelpResource(
        nom="Plusminus Basel — Budget- und Schuldenberatung",
        description="Service balois de conseil budgetaire et en desendettement.",
        url="https://www.plusminus.ch",
        telephone="061 695 88 22",
        canton="BS",
        gratuit=True,
        confidentiel=True,
        type_aide="conseil",
    ),
    "AG": HelpResource(
        nom="Schuldenberatung Aargau-Solothurn",
        description="Service argovien de conseil en desendettement.",
        url="https://www.schuldenberatung-ag-so.ch",
        telephone="062 822 94 09",
        canton="AG",
        gratuit=True,
        confidentiel=True,
        type_aide="conseil",
    ),
    "SG": HelpResource(
        nom="Schuldenberatung St. Gallen",
        description="Service saint-gallois de conseil en desendettement.",
        url="https://www.schuldenberatung-sg.ch",
        telephone="071 228 13 20",
        canton="SG",
        gratuit=True,
        confidentiel=True,
        type_aide="conseil",
    ),
    "TI": HelpResource(
        nom="ACSI — Consulenza debiti Ticino",
        description="Service tessinois de conseil en desendettement.",
        url="https://www.acsi.ch",
        telephone="091 922 97 55",
        canton="TI",
        gratuit=True,
        confidentiel=True,
        type_aide="conseil",
    ),
    "VS": HelpResource(
        nom="Caritas Valais — Conseil en desendettement",
        description="Service valaisan de conseil en desendettement.",
        url="https://www.caritas-valais.ch",
        telephone="027 323 03 17",
        canton="VS",
        gratuit=True,
        confidentiel=True,
        type_aide="conseil",
    ),
    "FR": HelpResource(
        nom="Caritas Fribourg — Consultation dettes",
        description="Service fribourgeois de consultation en desendettement.",
        url="https://www.caritas-fribourg.ch",
        telephone="026 321 16 16",
        canton="FR",
        gratuit=True,
        confidentiel=True,
        type_aide="conseil",
    ),
    "NE": HelpResource(
        nom="CSP Neuchatel — Desendettement",
        description="Service neuchatelois de conseil en desendettement du CSP.",
        url="https://www.csp-ne.ch",
        telephone="032 886 80 80",
        canton="NE",
        gratuit=True,
        confidentiel=True,
        type_aide="conseil",
    ),
    "JU": HelpResource(
        nom="Caritas Jura — Conseil social",
        description="Service jurassien de conseil social et en desendettement.",
        url="https://www.caritas-jura.ch",
        telephone="032 421 11 66",
        canton="JU",
        gratuit=True,
        confidentiel=True,
        type_aide="conseil",
    ),
    "SO": HelpResource(
        nom="Schuldenberatung Aargau-Solothurn",
        description="Service soleurois de conseil en desendettement.",
        url="https://www.schuldenberatung-ag-so.ch",
        telephone="062 822 94 09",
        canton="SO",
        gratuit=True,
        confidentiel=True,
        type_aide="conseil",
    ),
    "BL": HelpResource(
        nom="Schuldenberatung Basel-Landschaft",
        description="Service de Bale-Campagne de conseil en desendettement.",
        url="https://www.schuldenberatung-bl.ch",
        telephone="061 927 67 67",
        canton="BL",
        gratuit=True,
        confidentiel=True,
        type_aide="conseil",
    ),
    "GR": HelpResource(
        nom="Schuldenberatung Graubunden",
        description="Service grison de conseil en desendettement.",
        url="https://www.schuldenberatung-gr.ch",
        telephone="081 258 36 37",
        canton="GR",
        gratuit=True,
        confidentiel=True,
        type_aide="conseil",
    ),
    "TG": HelpResource(
        nom="Schuldenberatung Thurgau",
        description="Service thurgovien de conseil en desendettement.",
        url="https://www.perspektive-tg.ch",
        telephone="071 626 02 02",
        canton="TG",
        gratuit=True,
        confidentiel=True,
        type_aide="conseil",
    ),
    "SZ": HelpResource(
        nom="Sozialberatung Schwyz",
        description="Service schwyzois de conseil social et en desendettement.",
        url="https://www.sozialberatung-sz.ch",
        telephone="041 818 42 00",
        canton="SZ",
        gratuit=True,
        confidentiel=True,
        type_aide="conseil",
    ),
    "ZG": HelpResource(
        nom="Budgetberatung Zug",
        description="Service zougois de conseil budgetaire et en desendettement.",
        url="https://www.budgetberatung-zug.ch",
        telephone="041 725 26 10",
        canton="ZG",
        gratuit=True,
        confidentiel=True,
        type_aide="conseil",
    ),
    "NW": HelpResource(
        nom="Sozialberatung Nidwalden",
        description="Service nidwaldien de conseil social.",
        url="https://www.nw.ch",
        telephone="041 618 76 00",
        canton="NW",
        gratuit=True,
        confidentiel=True,
        type_aide="conseil",
    ),
    "OW": HelpResource(
        nom="Sozialberatung Obwalden",
        description="Service obwaldien de conseil social.",
        url="https://www.ow.ch",
        telephone="041 666 63 00",
        canton="OW",
        gratuit=True,
        confidentiel=True,
        type_aide="conseil",
    ),
    "UR": HelpResource(
        nom="Sozialberatung Uri",
        description="Service uranais de conseil social.",
        url="https://www.ur.ch",
        telephone="041 875 20 50",
        canton="UR",
        gratuit=True,
        confidentiel=True,
        type_aide="conseil",
    ),
    "SH": HelpResource(
        nom="Schuldenberatung Schaffhausen",
        description="Service schaffhousois de conseil en desendettement.",
        url="https://www.schuldenberatung-sh.ch",
        telephone="052 620 18 18",
        canton="SH",
        gratuit=True,
        confidentiel=True,
        type_aide="conseil",
    ),
    "AR": HelpResource(
        nom="Schuldenberatung Appenzell A.Rh.",
        description="Service appenzellois (Rhodes-Exterieures) de conseil.",
        url="https://www.ar.ch",
        telephone="071 353 61 11",
        canton="AR",
        gratuit=True,
        confidentiel=True,
        type_aide="conseil",
    ),
    "AI": HelpResource(
        nom="Sozialberatung Appenzell I.Rh.",
        description="Service appenzellois (Rhodes-Interieures) de conseil social.",
        url="https://www.ai.ch",
        telephone="071 788 93 70",
        canton="AI",
        gratuit=True,
        confidentiel=True,
        type_aide="conseil",
    ),
    "GL": HelpResource(
        nom="Sozialberatung Glarus",
        description="Service glaronnais de conseil social.",
        url="https://www.gl.ch",
        telephone="055 646 67 30",
        canton="GL",
        gratuit=True,
        confidentiel=True,
        type_aide="conseil",
    ),
}


# Situation-specific resources
_SITUATION_RESOURCES = {
    "surendettement": HelpResource(
        nom="Dettes Conseils Suisse — Programme de desendettement",
        description=(
            "Accompagnement complet pour elaborer un plan de desendettement. "
            "Negociation avec les creanciers, plan de paiement echelonne."
        ),
        url="https://www.dettes.ch/desendettement",
        telephone="0800 40 40 40",
        canton=None,
        gratuit=True,
        confidentiel=True,
        type_aide="conseil",
    ),
    "poursuites": HelpResource(
        nom="Office des poursuites — Information",
        description=(
            "Information sur vos droits en cas de poursuite. "
            "Le minimum vital (LP art. 93) est insaisissable."
        ),
        url="https://www.bj.admin.ch/bj/fr/home/wirtschaft/schkg.html",
        telephone=None,
        canton=None,
        gratuit=True,
        confidentiel=False,
        type_aide="juridique",
    ),
    "acte_defaut_biens": HelpResource(
        nom="Aide juridique — Acte de defaut de biens",
        description=(
            "Un acte de defaut de biens reste valable 20 ans. "
            "Vous pouvez negocier un rachat a un montant reduit. "
            "Contactez un service de conseil en desendettement."
        ),
        url="https://www.dettes.ch/acte-defaut-biens",
        telephone="0800 40 40 40",
        canton=None,
        gratuit=True,
        confidentiel=True,
        type_aide="juridique",
    ),
    "prevention": HelpResource(
        nom="Budget-conseil Suisse",
        description=(
            "Conseil budgetaire preventif. Etablissement d'un budget realiste "
            "et gestion proactive des finances. Fiches de budget type par "
            "situation familiale disponibles gratuitement."
        ),
        url="https://www.budgetberatung.ch",
        telephone=None,
        canton=None,
        gratuit=True,
        confidentiel=True,
        type_aide="prevention",
    ),
}


class ResourcesService:
    """Provide links to professional debt counseling resources.

    All resources are:
    - Public (no hidden services)
    - Free (or clearly marked if not)
    - Confidential
    - Available in the user's canton

    Sources:
        - Dettes Conseils Suisse (organisation faitiere)
        - Caritas Suisse
        - Services cantonaux
    """

    def get_help_resources(
        self,
        canton: str,
        situation: str = "prevention",
    ) -> HelpResourcesResult:
        """Get help resources for a specific canton and situation.

        Args:
            canton: Canton code (e.g. "VD", "ZH", "GE").
            situation: One of "surendettement", "poursuites",
                      "acte_defaut_biens", "prevention".

        Returns:
            HelpResourcesResult with relevant resources.
        """
        canton_upper = canton.upper() if canton else "ZH"

        if situation not in _SITUATION_RESOURCES:
            situation = "prevention"

        resources: List[HelpResource] = []

        # 1. National resources (always included)
        resources.extend(_NATIONAL_RESOURCES)

        # 2. Situation-specific resource
        if situation in _SITUATION_RESOURCES:
            resources.append(_SITUATION_RESOURCES[situation])

        # 3. Cantonal resource
        if canton_upper in _CANTONAL_RESOURCES:
            resources.append(_CANTONAL_RESOURCES[canton_upper])

        # 4. Chiffre choc
        nb_cantons = len(_CANTONAL_RESOURCES)
        chiffre_choc = (
            f"Gratuit et confidentiel — {nb_cantons} services cantonaux a ton service"
        )

        # 5. Sources
        sources = [
            "Dettes Conseils Suisse (organisation faitiere nationale)",
            "Caritas Suisse (conseil en desendettement)",
            "LP art. 93 (minimum vital insaisissable)",
        ]

        return HelpResourcesResult(
            resources=resources,
            canton=canton_upper,
            situation=situation,
            chiffre_choc=chiffre_choc,
            sources=sources,
            disclaimer=DISCLAIMER,
        )
