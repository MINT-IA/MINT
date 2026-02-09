"""
Libre passage (vested benefits) advisor.

When a person changes jobs, leaves Switzerland, or stops working, their LPP
savings are transferred to a "libre passage" (vested benefits) account.
This service advises on the correct procedure and alerts on common pitfalls.

Sources:
    - LFLP art. 2-4 (libre passage: principes et transfert)
    - LPP art. 25e-25f (maintien de la prevoyance)
    - OLP art. 8-10 (fondations de libre passage)
    - LFLP art. 5 (depart de Suisse: regles EU/AELE vs hors-EU)

Sprint S15 — Chantier 4: LPP approfondi.
"""

from dataclasses import dataclass, field
from typing import List, Optional
from enum import Enum


DISCLAIMER = (
    "MINT est un outil educatif. Ce service ne constitue pas un conseil "
    "en prevoyance au sens de la LSFin. Les delais et procedures "
    "peuvent varier selon les caisses de pension. Consultez un ou une specialiste "
    "pour une analyse personnalisee de votre situation."
)


class StatutLibrePassage(str, Enum):
    """Reason for entering the libre passage system."""
    changement_emploi = "changement_emploi"
    depart_suisse = "depart_suisse"
    cessation_activite = "cessation_activite"


class DestinationDepart(str, Enum):
    """Destination country type for departure from Switzerland."""
    eu_aele = "eu_aele"
    hors_eu = "hors_eu"


@dataclass
class ActionItem:
    """A single action item in the checklist."""
    description: str
    delai: Optional[str] = None     # Deadline or timeframe
    priorite: str = "haute"         # haute, moyenne, basse
    source_legale: Optional[str] = None


@dataclass
class AlerteLibrePassage:
    """An alert for the user."""
    niveau: str     # "critique", "important", "info"
    message: str
    source_legale: Optional[str] = None


@dataclass
class RecommandationLP:
    """A recommendation for the user."""
    titre: str
    description: str
    source_legale: Optional[str] = None


@dataclass
class LibrePassageResult:
    """Complete result of the libre passage analysis."""

    statut: str
    checklist: List[ActionItem]
    alertes: List[AlerteLibrePassage]
    recommandations: List[RecommandationLP]
    peut_retirer_capital: bool
    montant_retirable: float
    montant_bloque: float
    sources: List[str] = field(default_factory=list)
    disclaimer: str = DISCLAIMER


class LibrePassageService:
    """Advise on vested benefits (libre passage) procedures.

    The main scenarios:
    1. Job change within Switzerland: transfer to new employer's fund
    2. Leaving Switzerland: partial or full withdrawal depending on destination
    3. Stopping work (unemployment, sabbatical): libre passage foundation

    Key rules:
    - Transfer to new employer within 6 months (ideally 30 days)
    - If no new employer: libre passage foundation (compte or titres)
    - EU/AELE departure: only surobligatoire can be withdrawn
    - Non-EU departure: full withdrawal possible
    - Age 58-65: retirement withdrawal possible
    - Centrale du 2e pilier (sfbvg.ch) to find forgotten assets
    """

    DELAI_TRANSFERT_MAX_JOURS = 180  # 6 months
    DELAI_TRANSFERT_IDEAL_JOURS = 30
    AGE_RETRAITE_MIN = 58
    AGE_RETRAITE_MAX = 65
    CENTRALE_2E_PILIER_URL = "https://www.sfbvg.ch/"

    def analyze(
        self,
        statut: str,
        avoir_libre_passage: float,
        age: int,
        a_nouveau_employeur: bool = False,
        delai_jours: Optional[int] = None,
        destination: Optional[str] = None,
        avoir_obligatoire: Optional[float] = None,
        avoir_surobligatoire: Optional[float] = None,
    ) -> LibrePassageResult:
        """Analyze a libre passage situation and produce recommendations.

        Args:
            statut: Reason ("changement_emploi", "depart_suisse", "cessation_activite").
            avoir_libre_passage: Total vested benefits amount (CHF).
            age: Person's current age.
            a_nouveau_employeur: Whether the person has a new employer.
            delai_jours: Days since leaving previous employer.
            destination: Destination for departure ("eu_aele" or "hors_eu").
            avoir_obligatoire: Mandatory LPP portion (CHF), if known.
            avoir_surobligatoire: Super-mandatory portion (CHF), if known.

        Returns:
            LibrePassageResult with checklist, alerts, and recommendations.
        """
        avoir_libre_passage = max(0.0, avoir_libre_passage)
        age = max(18, min(70, age))

        checklist: List[ActionItem] = []
        alertes: List[AlerteLibrePassage] = []
        recommandations: List[RecommandationLP] = []

        peut_retirer = False
        montant_retirable = 0.0
        montant_bloque = avoir_libre_passage

        if statut == StatutLibrePassage.changement_emploi.value:
            self._handle_changement_emploi(
                checklist, alertes, recommandations,
                avoir_libre_passage, age, a_nouveau_employeur, delai_jours,
            )
            if a_nouveau_employeur:
                montant_bloque = avoir_libre_passage
            elif self.AGE_RETRAITE_MIN <= age <= self.AGE_RETRAITE_MAX:
                peut_retirer = True
                montant_retirable = avoir_libre_passage
                montant_bloque = 0.0

        elif statut == StatutLibrePassage.depart_suisse.value:
            result_retrait = self._handle_depart_suisse(
                checklist, alertes, recommandations,
                avoir_libre_passage, age, destination,
                avoir_obligatoire, avoir_surobligatoire,
            )
            peut_retirer = result_retrait["peut_retirer"]
            montant_retirable = result_retrait["montant_retirable"]
            montant_bloque = result_retrait["montant_bloque"]

        elif statut == StatutLibrePassage.cessation_activite.value:
            self._handle_cessation_activite(
                checklist, alertes, recommandations,
                avoir_libre_passage, age,
            )
            if self.AGE_RETRAITE_MIN <= age <= self.AGE_RETRAITE_MAX:
                peut_retirer = True
                montant_retirable = avoir_libre_passage
                montant_bloque = 0.0

        # Universal items
        self._add_universal_items(checklist, alertes, recommandations, avoir_libre_passage)

        sources = [
            "LFLP art. 2-4 (libre passage: principes et transfert)",
            "LPP art. 25e-25f (maintien de la prevoyance)",
            "OLP art. 8-10 (fondations de libre passage)",
            "LFLP art. 5 (depart de Suisse: regles EU/AELE vs hors-EU)",
        ]

        return LibrePassageResult(
            statut=statut,
            checklist=checklist,
            alertes=alertes,
            recommandations=recommandations,
            peut_retirer_capital=peut_retirer,
            montant_retirable=round(montant_retirable, 2),
            montant_bloque=round(montant_bloque, 2),
            sources=sources,
            disclaimer=DISCLAIMER,
        )

    def _handle_changement_emploi(
        self,
        checklist: List[ActionItem],
        alertes: List[AlerteLibrePassage],
        recommandations: List[RecommandationLP],
        avoir: float,
        age: int,
        a_nouveau_employeur: bool,
        delai_jours: Optional[int],
    ) -> None:
        """Handle job change scenario."""

        if a_nouveau_employeur:
            checklist.append(ActionItem(
                description=(
                    "Demander a l'ancien employeur de transferer les avoirs de libre passage "
                    "vers la caisse de pension du nouvel employeur."
                ),
                delai="Idealement sous 30 jours, maximum 6 mois (LFLP art. 4)",
                priorite="haute",
                source_legale="LFLP art. 4",
            ))
            checklist.append(ActionItem(
                description="Obtenir la confirmation de transfert de la nouvelle caisse de pension.",
                delai="Sous 30 jours apres le transfert",
                priorite="haute",
                source_legale="LFLP art. 2",
            ))
            checklist.append(ActionItem(
                description="Verifier le nouveau certificat de prevoyance (montant transfere correct).",
                delai="Des reception du certificat",
                priorite="haute",
                source_legale="LFLP art. 2",
            ))

            if delai_jours is not None and delai_jours > self.DELAI_TRANSFERT_IDEAL_JOURS:
                alertes.append(AlerteLibrePassage(
                    niveau="important",
                    message=(
                        f"Transfert en attente depuis {delai_jours} jours. "
                        f"Le delai ideal est de 30 jours, le delai legal maximum est "
                        f"de 6 mois (LFLP art. 4). Relancez votre ancienne caisse."
                    ),
                    source_legale="LFLP art. 4",
                ))

            if delai_jours is not None and delai_jours > self.DELAI_TRANSFERT_MAX_JOURS:
                alertes.append(AlerteLibrePassage(
                    niveau="critique",
                    message=(
                        f"Le delai de 6 mois est depasse ({delai_jours} jours). "
                        f"Vos avoirs sont peut-etre deja aupres de la Fondation institution "
                        f"suppletive. Contactez la Centrale du 2e pilier: {self.CENTRALE_2E_PILIER_URL}"
                    ),
                    source_legale="LFLP art. 4, OLP art. 10",
                ))

        else:
            # No new employer yet
            checklist.append(ActionItem(
                description=(
                    "Ouvrir un compte de libre passage aupres d'une fondation "
                    "(banque ou assurance). Comparer les frais et les options de placement."
                ),
                delai="Sous 6 mois apres la fin du contrat (LFLP art. 4)",
                priorite="haute",
                source_legale="LFLP art. 4, OLP art. 8-10",
            ))
            checklist.append(ActionItem(
                description=(
                    "Choisir entre un compte (taux d'interet) et un depot de titres "
                    "(placement en fonds). Pour un horizon long, les titres offrent "
                    "potentiellement un meilleur rendement."
                ),
                delai="Avant le transfert",
                priorite="moyenne",
                source_legale="OLP art. 10",
            ))

            recommandations.append(RecommandationLP(
                titre="Deux comptes de libre passage pour la strategie de retrait",
                description=(
                    "Vous pouvez ouvrir 2 comptes de libre passage (maximum legal). "
                    "Cela permet de retirer les avoirs en deux etapes sur deux annees "
                    "fiscales differentes, reduisant l'impot sur le retrait."
                ),
                source_legale="OLP art. 12, LIFD art. 38",
            ))

            if self.AGE_RETRAITE_MIN <= age <= self.AGE_RETRAITE_MAX:
                recommandations.append(RecommandationLP(
                    titre="Retrait anticipe possible (age de retraite)",
                    description=(
                        f"A {age} ans, vous etes dans la tranche de retraite anticipee "
                        f"(58-65 ans). Vous pouvez retirer votre capital de libre passage. "
                        f"Evaluez la fiscalite du retrait avec un ou une specialiste."
                    ),
                    source_legale="LPP art. 13 al. 2, OLP art. 16",
                ))

    def _handle_depart_suisse(
        self,
        checklist: List[ActionItem],
        alertes: List[AlerteLibrePassage],
        recommandations: List[RecommandationLP],
        avoir: float,
        age: int,
        destination: Optional[str],
        avoir_obligatoire: Optional[float],
        avoir_surobligatoire: Optional[float],
    ) -> dict:
        """Handle departure from Switzerland scenario."""

        peut_retirer = False
        montant_retirable = 0.0
        montant_bloque = avoir

        checklist.append(ActionItem(
            description="Annoncer le depart a la caisse de pension ou a la fondation de libre passage.",
            delai="Avant le depart de Suisse",
            priorite="haute",
            source_legale="LFLP art. 5",
        ))
        checklist.append(ActionItem(
            description="Se desinscrire de l'AVS/AI et de l'assurance maladie obligatoire.",
            delai="Avant le depart",
            priorite="haute",
        ))

        if destination == DestinationDepart.eu_aele.value:
            # EU/AELE: only surobligatoire can be withdrawn
            peut_retirer = True

            if avoir_surobligatoire is not None:
                montant_retirable = avoir_surobligatoire
                montant_bloque = avoir - avoir_surobligatoire
            else:
                # Estimate: typically 30-50% is surobligatoire for higher salaries
                montant_retirable = 0.0  # Cannot estimate without data
                montant_bloque = avoir

            alertes.append(AlerteLibrePassage(
                niveau="critique",
                message=(
                    "Depart vers un pays EU/AELE: seule la part surobligatoire "
                    "peut etre retiree. La part obligatoire reste bloquee en Suisse "
                    "sur un compte de libre passage (LFLP art. 5, accord bilateraux CH-UE)."
                ),
                source_legale="LFLP art. 5, accord bilateraux CH-UE",
            ))

            checklist.append(ActionItem(
                description=(
                    "Demander a la caisse de pension le detail obligatoire/surobligatoire "
                    "pour connaitre le montant exactement retirable."
                ),
                delai="Avant le depart",
                priorite="haute",
                source_legale="LFLP art. 5",
            ))
            checklist.append(ActionItem(
                description=(
                    "Ouvrir un compte de libre passage en Suisse pour la part obligatoire "
                    "(qui ne peut pas etre retiree vers l'EU/AELE)."
                ),
                delai="Avant le depart",
                priorite="haute",
                source_legale="LFLP art. 5, OLP art. 10",
            ))

            recommandations.append(RecommandationLP(
                titre="Placement de la part obligatoire bloquee",
                description=(
                    "La part obligatoire qui reste en Suisse peut etre placee en titres "
                    "aupres de la fondation de libre passage. Pour un horizon long "
                    "(jusqu'a la retraite), un placement en fonds peut etre adapte."
                ),
                source_legale="OLP art. 10",
            ))

        elif destination == DestinationDepart.hors_eu.value:
            # Non-EU: full withdrawal possible
            peut_retirer = True
            montant_retirable = avoir
            montant_bloque = 0.0

            alertes.append(AlerteLibrePassage(
                niveau="important",
                message=(
                    "Depart hors EU/AELE: le retrait integral est possible. "
                    "Un impot a la source sera preleve sur le retrait "
                    "(taux reduit, varie selon le canton du dernier domicile)."
                ),
                source_legale="LFLP art. 5, LIFD art. 38",
            ))

            checklist.append(ActionItem(
                description=(
                    "Fournir une attestation de depart (radiation du registre des habitants) "
                    "et une confirmation d'inscription dans le pays de destination."
                ),
                delai="Lors de la demande de retrait",
                priorite="haute",
                source_legale="LFLP art. 5",
            ))

            recommandations.append(RecommandationLP(
                titre="Verifier la convention de double imposition",
                description=(
                    "Selon le pays de destination, une convention de double imposition "
                    "peut permettre de recuperer l'impot a la source suisse. "
                    "Renseignez-vous aupres de l'administration fiscale."
                ),
                source_legale="CDI (conventions de double imposition)",
            ))

        else:
            # Unknown destination
            checklist.append(ActionItem(
                description=(
                    "Preciser le pays de destination: les regles de retrait different "
                    "selon que le pays est dans l'EU/AELE ou non."
                ),
                delai="Avant toute demarche",
                priorite="haute",
                source_legale="LFLP art. 5",
            ))

        return {
            "peut_retirer": peut_retirer,
            "montant_retirable": montant_retirable,
            "montant_bloque": montant_bloque,
        }

    def _handle_cessation_activite(
        self,
        checklist: List[ActionItem],
        alertes: List[AlerteLibrePassage],
        recommandations: List[RecommandationLP],
        avoir: float,
        age: int,
    ) -> None:
        """Handle cessation of activity scenario."""

        checklist.append(ActionItem(
            description=(
                "Ouvrir un compte de libre passage aupres d'une fondation "
                "(banque ou assurance) pour recevoir vos avoirs LPP."
            ),
            delai="Sous 6 mois apres la fin du contrat (LFLP art. 4)",
            priorite="haute",
            source_legale="LFLP art. 4, OLP art. 8-10",
        ))

        if age < self.AGE_RETRAITE_MIN:
            alertes.append(AlerteLibrePassage(
                niveau="important",
                message=(
                    f"A {age} ans, vos avoirs restent bloques jusqu'a la retraite "
                    f"anticipee (58 ans minimum). Vous pouvez les retirer uniquement "
                    f"pour l'achat de votre residence principale (EPL, LPP art. 30a)."
                ),
                source_legale="LPP art. 13 al. 2, LPP art. 30a",
            ))
        else:
            recommandations.append(RecommandationLP(
                titre="Retrait du capital de libre passage",
                description=(
                    f"A {age} ans, vous pouvez retirer votre capital de libre passage. "
                    f"Comparez l'imposition du retrait entre les cantons si vous "
                    f"envisagez un demenagement avant le retrait."
                ),
                source_legale="LPP art. 13 al. 2, OLP art. 16",
            ))

        checklist.append(ActionItem(
            description=(
                "S'inscrire a l'assurance chomage si applicable "
                "(pour maintenir les droits LPP pendant le chomage)."
            ),
            delai="Des la cessation d'activite",
            priorite="haute",
            source_legale="LACI art. 2e pilier",
        ))

        recommandations.append(RecommandationLP(
            titre="Verifier la couverture risque",
            description=(
                "En quittant l'emploi, la couverture deces et invalidite LPP "
                "cesse apres un delai (generalement 30 jours). "
                "Verifiez si une couverture transitoire est necessaire."
            ),
            source_legale="LPP art. 10 al. 3",
        ))

    def _add_universal_items(
        self,
        checklist: List[ActionItem],
        alertes: List[AlerteLibrePassage],
        recommandations: List[RecommandationLP],
        avoir: float,
    ) -> None:
        """Add items common to all scenarios."""

        # Centrale du 2e pilier
        recommandations.append(RecommandationLP(
            titre="Verifier les avoirs oublies",
            description=(
                "La Centrale du 2e pilier (sfbvg.ch) permet de rechercher "
                "des avoirs de libre passage oublies. En Suisse, plus de "
                "10 milliards de CHF d'avoirs sont non reclames."
            ),
            source_legale="LFLP art. 24a-24f",
        ))

        checklist.append(ActionItem(
            description=(
                f"Rechercher d'eventuels avoirs oublies sur {self.CENTRALE_2E_PILIER_URL}"
            ),
            delai="A tout moment",
            priorite="moyenne",
            source_legale="LFLP art. 24a-24f",
        ))

        # Tax planning
        if avoir > 50000:
            recommandations.append(RecommandationLP(
                titre="Planification fiscale du retrait",
                description=(
                    f"Avec {avoir:.0f} CHF d'avoirs, la planification fiscale du retrait "
                    f"est importante. Le retrait en capital est impose a un taux reduit "
                    f"qui varie selon le canton. Un echelonnement sur 2 ans (via 2 comptes "
                    f"de libre passage) peut reduire l'imposition."
                ),
                source_legale="LIFD art. 38, OLP art. 12",
            ))
