"""
Precision Models — Dataclasses for guided precision entry.

Sprint S41 — Guided Precision Entry.

These models define the contracts for:
- FieldHelp: contextual help per financial field (where to find, document name, DE name)
- CrossValidationAlert: coherence alert after data entry
- SmartDefault: contextual estimation when user doesn't know
- PrecisionPrompt: precision request at the right moment
- PrecisionResult: aggregated result of all precision checks

Sources:
    - LPP art. 7, 8, 15-16 (seuil, coordination, bonifications)
    - LAVS art. 29ter, 34 (duree cotisation, rente maximale)
    - OPP3 art. 7 (plafond 3a)
    - LIFD art. 38 (imposition du capital de prevoyance)
"""

from dataclasses import dataclass, field
from typing import List


@dataclass
class FieldHelp:
    """Aide contextuelle pour un champ financier.

    Indique a l'utilisateur ou trouver le chiffre exact,
    sur quel document, son nom en allemand (pour les bilingues),
    et une estimation de repli si la valeur est inconnue.
    """

    field_name: str
    where_to_find: str
    document_name: str
    german_name: str
    fallback_estimation: str


@dataclass
class CrossValidationAlert:
    """Alerte de coherence apres saisie de donnees.

    Detecte les incoherences entre champs (ex: LPP trop bas pour
    l'age et le salaire, salaire brut vs net incohérent, etc.).

    severity: "warning" (valeur inhabituelle) ou "error" (incoherence forte).
    message: texte en francais, tutoiement informel.
    suggestion: action recommandee pour corriger.
    """

    field_name: str
    severity: str  # "warning" | "error"
    message: str
    suggestion: str


@dataclass
class SmartDefault:
    """Estimation contextuelle quand l'utilisateur ne connait pas une valeur.

    L'estimation prend en compte l'archetype, l'age, le salaire et le canton
    pour fournir une valeur plus precise qu'une valeur generique.

    confidence: 0.0 a 1.0, indique la fiabilite de l'estimation.
    source: explication transparente de la methode d'estimation.
    """

    field_name: str
    value: float
    source: str
    confidence: float


@dataclass
class PrecisionPrompt:
    """Demande de precision au moment opportun.

    Declenchee quand l'utilisateur accede a un module qui necessite
    un champ specifique actuellement estime (pas renseigne).

    trigger: contexte declencheur (ex: "rente_vs_capital_opened")
    field_needed: champ necessaire pour la precision
    prompt_text: texte affiche a l'utilisateur (francais, tutoiement)
    impact_text: gain de precision si le champ est renseigne
    """

    trigger: str
    field_needed: str
    prompt_text: str
    impact_text: str


@dataclass
class PrecisionResult:
    """Resultat global d'une analyse de precision.

    Aggrege les alertes de coherence, les estimations contextuelles,
    et les demandes de precision pour un profil donne.
    """

    alerts: List[CrossValidationAlert] = field(default_factory=list)
    smart_defaults: List[SmartDefault] = field(default_factory=list)
    prompts: List[PrecisionPrompt] = field(default_factory=list)
