"""
Dataclasses for the Enhanced Confidence Scoring module — Sprint S46.

Defines shared types for multi-dimensional confidence measurement:
- FieldSource: provenance d'un champ de profil (source, date, valeur)
- ConfidenceBreakdown: score sur 4 axes (completeness, accuracy, freshness, understanding)
- EnrichmentPrompt: action classee par impact pour ameliorer la precision
- ConfidenceResult: resultat complet avec feature gates et compliance

La confiance globale est calculee via une moyenne geometrique sur 4 axes.

Privacy: les metadonnees de source sont internes (tracking qualite).
Elles ne sont jamais envoyees au LLM ni partagees avec des tiers.

Sources:
    - DATA_ACQUISITION_STRATEGY.md, section "Confidence Scoring Evolution"
    - LPP art. 7-8, 14-16 (prevoyance professionnelle)
    - LAVS art. 21-40 (AVS)
    - OPP3 art. 7 (3e pilier)
    - LIFD art. 38 (imposition du capital)
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Dict, List, Union

from app.services.document_parser.document_models import DataSource


@dataclass
class FieldSource:
    """Provenance d'un champ de profil utilisateur.

    Attributes:
        field_name: Identifiant du champ (ex: lpp_total, salaire_brut).
        source: Origine de la donnee (DataSource enum).
        updated_at: Date de mise a jour ISO 8601 (ex: 2026-02-24T10:30:00).
        value: Valeur du champ (montant CHF ou texte).
    """

    field_name: str
    source: DataSource
    updated_at: str  # ISO 8601 datetime
    value: Union[float, str]


@dataclass
class ConfidenceBreakdown:
    """Score de confiance sur 4 axes.

    Attributes:
        completeness: 0-100, proportion de champs remplis (pondere par importance).
        accuracy: 0-100, qualite moyenne des sources de donnees.
        freshness: 0-100, fraicheur moyenne des donnees.
        understanding: 0-100, comprehension financiere de l'utilisateur.
        overall: Score global — 4-axis geometric mean.
    """

    completeness: float  # 0-100
    accuracy: float  # 0-100
    freshness: float  # 0-100
    understanding: float  # 0-100
    overall: float  # 4-axis geometric mean


@dataclass
class EnrichmentPrompt:
    """Action recommandee pour ameliorer le score de confiance.

    Attributes:
        field_name: Champ concerne (ex: lpp_obligatoire, taux_marginal).
        action: Texte de l'action en francais (tutoiement).
        impact_points: Gain de confiance estime en points (0-100).
        method: Methode d'acquisition (document_scan, manual_entry, open_banking).
        priority: Rang de priorite (1 = plus urgent).
    """

    field_name: str
    action: str
    impact_points: float
    method: str  # document_scan, manual_entry, open_banking, avs_request
    priority: int  # 1 = most urgent


@dataclass
class ConfidenceResult:
    """Resultat complet du scoring de confiance.

    Contient le breakdown multi-dimensionnel, les actions d'enrichissement
    classees par impact, les feature gates et les champs de compliance.

    Attributes:
        breakdown: Scores de confiance sur les 4 axes + overall.
        enrichment_prompts: Actions classees par impact decroissant.
        feature_gates: Fonctionnalites debloquees selon le niveau de confiance.
        disclaimer: Mention legale obligatoire (outil educatif, LSFin).
        sources: References legales suisses.
    """

    breakdown: ConfidenceBreakdown
    enrichment_prompts: List[EnrichmentPrompt] = field(default_factory=list)
    feature_gates: Dict[str, bool] = field(default_factory=dict)
    disclaimer: str = (
        "Cet outil est educatif et ne constitue pas un conseil financier, "
        "fiscal ou juridique personnalise. Le score de confiance mesure "
        "la qualite des donnees fournies, pas la fiabilite des projections. "
        "Consulte un-e specialiste pour ta situation personnelle (LSFin art. 3)."
    )
    sources: List[str] = field(default_factory=lambda: [
        "LPP art. 7 (seuil d'entree: 22'680 CHF)",
        "LPP art. 8 (deduction de coordination: 26'460 CHF)",
        "LPP art. 14 (taux de conversion minimum: 6.8%)",
        "LPP art. 15-16 (bonifications vieillesse: 7/10/15/18%)",
        "LAVS art. 29ter (duree cotisation complete: 44 ans)",
        "LAVS art. 34 (rente maximale: 2'520 CHF/mois)",
        "OPP3 art. 7 (plafond 3a: 7'258 CHF / 36'288 CHF)",
        "LIFD art. 38 (imposition du capital de prevoyance)",
    ])
