"""
Extraction Confidence Scorer — Sprint S42-S43.

Evalue la qualite d'une extraction de document et classe les champs
par impact sur la precision des projections financieres.

Ce service est une pure function sans state.

Sources:
    - LPP art. 7-8, 14-16 (prevoyance professionnelle)
    - LAVS art. 21-40 (AVS)
    - OPP3 art. 7 (3e pilier)
    - LIFD art. 38 (imposition du capital)
"""

from __future__ import annotations

from typing import List

from app.services.document_parser.document_models import (
    DocumentType,
    ExtractionResult,
)


# ══════════════════════════════════════════════════════════════════════════════
# Field impact configuration per document type
# ══════════════════════════════════════════════════════════════════════════════

# Impact score (0-10) of each field on projection accuracy.
# Higher = more impactful for precision of financial projections.

_FIELD_IMPACT: dict[DocumentType, dict[str, dict]] = {
    DocumentType.lpp_certificate: {
        "part_obligatoire": {
            "impact": 10,
            "reason": "Critique pour l'arbitrage rente vs capital (LPP art. 14: taux 6.8% sur obligatoire uniquement)",
            "projection_affected": "rente_vs_capital, retirement_projection",
        },
        "part_surobligatoire": {
            "impact": 9,
            "reason": "Determine la rente surobligatoire (taux souvent 4-5.5%, pas 6.8%)",
            "projection_affected": "rente_vs_capital, retirement_projection",
        },
        "avoir_total": {
            "impact": 9,
            "reason": "Base de toute projection LPP (capital disponible a la retraite)",
            "projection_affected": "retirement_projection, fri",
        },
        "taux_conversion_oblig": {
            "impact": 8,
            "reason": "Taux applique a la part obligatoire pour calculer la rente (min legal: 6.8%)",
            "projection_affected": "rente_vs_capital",
        },
        "taux_conversion_suroblig": {
            "impact": 8,
            "reason": "Taux applique a la part surobligatoire (variable selon la caisse)",
            "projection_affected": "rente_vs_capital",
        },
        "lacune_rachat": {
            "impact": 7,
            "reason": "Potentiel de rachat = levier fiscal majeur (deduction du revenu imposable)",
            "projection_affected": "tax_optimization, rachat_arbitrage",
        },
        "salaire_assure": {
            "impact": 7,
            "reason": "Determine les bonifications futures et la couverture risque",
            "projection_affected": "retirement_projection, disability_gap",
        },
        "capital_projete_65": {
            "impact": 6,
            "reason": "Capital projet par la caisse a 65 ans (base pour rente vs capital)",
            "projection_affected": "retirement_projection",
        },
        "rente_projetee": {
            "impact": 6,
            "reason": "Rente annuelle projetee par la caisse (verification croisee)",
            "projection_affected": "retirement_projection",
        },
        "cotisation_employe": {
            "impact": 5,
            "reason": "Impact sur le salaire net reel et les projections de budget",
            "projection_affected": "budget, net_salary",
        },
        "cotisation_employeur": {
            "impact": 5,
            "reason": "Montre la generosite du plan (paritaire ou surparitaire)",
            "projection_affected": "job_comparison, lpp_projection",
        },
        "prestation_invalidite": {
            "impact": 4,
            "reason": "Couverture en cas d'invalidite (analyse des lacunes)",
            "projection_affected": "disability_gap",
        },
        "prestation_deces": {
            "impact": 4,
            "reason": "Couverture en cas de deces (planification successorale)",
            "projection_affected": "succession, family_coverage",
        },
    },
    DocumentType.tax_declaration: {
        "revenu_imposable": {
            "impact": 10,
            "reason": "Base de tout calcul fiscal (taux marginal, deductions)",
            "projection_affected": "tax_optimization, arbitrage",
        },
        "taux_marginal_effectif": {
            "impact": 10,
            "reason": "Determine l'avantage fiscal reel de chaque deduction",
            "projection_affected": "tax_optimization, rachat_lpp, 3a_optimization",
        },
        "fortune_imposable": {
            "impact": 7,
            "reason": "Impot sur la fortune et planification patrimoniale",
            "projection_affected": "wealth_tax, patrimoine",
        },
        "impot_cantonal": {
            "impact": 6,
            "reason": "Charge fiscale reelle pour les comparaisons cantonales",
            "projection_affected": "canton_comparison",
        },
        "impot_federal": {
            "impact": 5,
            "reason": "Charge fiscale federale reelle",
            "projection_affected": "tax_total",
        },
        "deductions_3a": {
            "impact": 6,
            "reason": "Verification de l'utilisation du plafond 3a",
            "projection_affected": "3a_optimization",
        },
    },
    DocumentType.avs_extract: {
        "annees_cotisation": {
            "impact": 10,
            "reason": "Determine le taux de rente AVS (44 ans = rente complete, LAVS art. 29ter)",
            "projection_affected": "retirement_projection, avs_rente",
        },
        "ramd": {
            "impact": 10,
            "reason": "Revenu annuel moyen determinant = base du calcul de la rente AVS",
            "projection_affected": "retirement_projection, avs_rente",
        },
        "lacunes_cotisation": {
            "impact": 8,
            "reason": "Annees manquantes = reduction de la rente AVS",
            "projection_affected": "retirement_projection, avs_gap",
        },
        "bonifications_educatives": {
            "impact": 5,
            "reason": "Majorent le RAMD pour les parents",
            "projection_affected": "avs_rente",
        },
    },
    DocumentType.three_a_attestation: {
        "solde_3a": {
            "impact": 7,
            "reason": "Capital 3a actuel pour projection retraite et planification retrait",
            "projection_affected": "retirement_projection, 3a_projection",
        },
        "versements_cumules": {
            "impact": 5,
            "reason": "Historique de versements pour estimer les versements futurs",
            "projection_affected": "3a_projection",
        },
        "rendement_net": {
            "impact": 4,
            "reason": "Performance reelle du placement 3a",
            "projection_affected": "3a_projection",
        },
    },
    DocumentType.mortgage_attestation: {
        "capital_restant": {
            "impact": 8,
            "reason": "Dette hypothecaire reelle pour le bilan patrimonial",
            "projection_affected": "patrimoine, mortgage_planning",
        },
        "taux_interet": {
            "impact": 8,
            "reason": "Taux reel vs. taux theorique 5% (Tragbarkeitsrechnung)",
            "projection_affected": "mortgage_affordability, budget",
        },
        "echeance_taux_fixe": {
            "impact": 7,
            "reason": "Date de renouvellement = risque de hausse de taux",
            "projection_affected": "mortgage_planning",
        },
        "amortissement_annuel": {
            "impact": 5,
            "reason": "Amortissement reel pour calcul de charges",
            "projection_affected": "budget, mortgage_planning",
        },
    },
}


# ══════════════════════════════════════════════════════════════════════════════
# Scoring functions
# ══════════════════════════════════════════════════════════════════════════════


def score_extraction(result: ExtractionResult) -> float:
    """Evalue la qualite globale d'une extraction (0-100).

    Le score tient compte de:
    - Couverture: combien de champs importants ont ete extraits
    - Confiance: qualite moyenne de l'extraction par champ
    - Coherence: absence de warnings (cross-validation OK)

    Args:
        result: Resultat d'extraction a evaluer.

    Returns:
        Score de 0 a 100.
    """
    if not result.fields:
        return 0.0

    doc_impacts = _FIELD_IMPACT.get(result.document_type, {})
    if not doc_impacts:
        # Document type without defined impacts: use simple average
        avg_conf = sum(f.confidence for f in result.fields) / len(result.fields)
        return round(avg_conf * 100, 1)

    # Weighted score: each field contributes proportionally to its impact
    total_weight = sum(info["impact"] for info in doc_impacts.values())
    if total_weight == 0:
        return 0.0

    weighted_score = 0.0
    for field in result.fields:
        if field.field_name in doc_impacts:
            impact = doc_impacts[field.field_name]["impact"]
            weighted_score += impact * field.confidence

    # Normalize to 0-100
    score = (weighted_score / total_weight) * 100

    # Penalty for warnings (coherence issues)
    warning_penalty = min(15.0, len(result.warnings) * 3.0)
    score -= warning_penalty

    # Bonus for fields not needing review
    fields_ok = sum(1 for f in result.fields if not f.needs_review)
    if result.fields:
        review_bonus = (fields_ok / len(result.fields)) * 5.0
        score += review_bonus

    return round(max(0.0, min(100.0, score)), 1)


def rank_fields_by_impact(
    missing_fields: list[str],
    document_type: DocumentType,
) -> List[dict]:
    """Classe les champs manquants par impact sur la precision des projections.

    Retourne une liste ordonnee du champ le plus impactant au moins impactant,
    avec pour chaque champ: son nom, son score d'impact, la raison de son
    importance, et les projections affectees.

    Args:
        missing_fields: Liste des noms de champs manquants dans le profil.
        document_type: Type de document pour contextualiser l'impact.

    Returns:
        Liste de dicts ordonnee par impact decroissant:
        [{"field_name": ..., "impact": ..., "reason": ..., "projection_affected": ...}]
    """
    doc_impacts = _FIELD_IMPACT.get(document_type, {})

    ranked = []
    for field_name in missing_fields:
        if field_name in doc_impacts:
            info = doc_impacts[field_name]
            ranked.append({
                "field_name": field_name,
                "impact": info["impact"],
                "reason": info["reason"],
                "projection_affected": info["projection_affected"],
            })
        else:
            # Unknown field: minimal impact
            ranked.append({
                "field_name": field_name,
                "impact": 1,
                "reason": "Champ complementaire",
                "projection_affected": "general",
            })

    # Sort by impact descending
    ranked.sort(key=lambda x: x["impact"], reverse=True)

    return ranked
