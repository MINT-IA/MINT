"""
Tax Declaration Parser — Sprint S44.

Service d'extraction structuree de declarations fiscales suisses
(avis de taxation) a partir de texte OCR (FR + DE).

Extrait 6 champs cles: revenu imposable, fortune imposable,
deductions effectuees, impot cantonal, impot federal, taux marginal effectif.

Le taux marginal est LE champ le plus critique pour les arbitrages
(rachat LPP, optimisation 3a, allocation annuelle).

Ce service est une pure function sans state.

Privacy: l'image source n'est jamais stockee. Seules les valeurs extraites
sont conservees localement, chiffrees au repos.

Sources:
    - LIFD art. 25-33 (revenu imposable)
    - LIFD art. 38 (imposition du capital)
    - LIFD art. 33 al. 1 let. e (deduction 3a: 7'258 CHF)
    - LHID art. 7-9 (harmonisation fiscale cantonale)
"""

from __future__ import annotations

import re
from typing import Optional

from app.services.document_parser.document_models import (
    DocumentType,
    ExtractedField,
    ExtractionResult,
)
from app.services.document_parser.lpp_certificate_parser import (
    _extract_amount_near,
    _extract_rate_near,
)


# ══════════════════════════════════════════════════════════════════════════════
# Known field patterns — FR + DE (26 cantons, format plus standardise que LPP)
# ══════════════════════════════════════════════════════════════════════════════

TAX_FIELD_PATTERNS: dict[str, dict] = {
    "revenu_imposable": {
        "type": "amount",
        "patterns": [
            r"revenu\s+imposable",
            r"revenu\s+net\s+imposable",
            r"revenu\s+d[ée]terminant",
            r"total\s+(?:du\s+)?revenu\s+imposable",
            r"steuerbares?\s+einkommen",
            r"reineinkommen",
            r"massgebendes?\s+einkommen",
            r"einkommen\s+steuerpflichtig",
        ],
    },
    "fortune_imposable": {
        "type": "amount",
        "patterns": [
            r"fortune\s+imposable",
            r"fortune\s+nette\s+imposable",
            r"fortune\s+d[ée]terminante",
            r"total\s+(?:de\s+la\s+)?fortune\s+imposable",
            r"steuerbares?\s+verm[oö]gen",
            r"reinverm[oö]gen",
            r"nettoverm[oö]gen\s+steuerpflichtig",
        ],
    },
    "deductions_effectuees": {
        "type": "amount",
        "patterns": [
            r"d[ée]ductions?\s+admises?",
            r"d[ée]ductions?\s+effectu[ée]es?",
            r"d[ée]ductions?\s+total(?:es)?",
            r"total\s+(?:des?\s+)?d[ée]ductions?",
            r"montant\s+(?:des?\s+)?d[ée]ductions?",
            r"abz[uü]ge\s+total",
            r"total(?:e)?\s+abz[uü]ge",
            r"zul[äa]ssige\s+abz[uü]ge",
        ],
    },
    "impot_cantonal": {
        "type": "amount",
        "patterns": [
            r"imp[oô]t\s+cantonal\s+(?:et\s+)?communal",
            r"imp[oô]ts?\s+cantona(?:l|ux)\s+(?:et\s+)?communa(?:l|ux)",
            r"imp[oô]t\s+cantonal",
            r"total\s+imp[oô]ts?\s+cantona(?:l|ux)",
            r"imp[oô]ts?\s+(?:du\s+)?canton",
            r"kantons[- ]?\s*(?:und\s+)?gemeinde[- ]?steuer(?:n)?",
            r"kantons(?:steuer|abgabe)(?:n)?",
            r"staats[- ]?\s*(?:und\s+)?gemeinde[- ]?steuer(?:n)?",
        ],
    },
    "impot_federal": {
        "type": "amount",
        "patterns": [
            r"imp[oô]t\s+f[ée]d[ée]ral\s+direct",
            r"imp[oô]t\s+f[ée]d[ée]ral",
            r"ifd",
            r"direkte?\s+bundessteuer",
            r"bundessteuer",
            r"dbst",
        ],
    },
    "taux_marginal_effectif": {
        "type": "rate",
        "patterns": [
            r"taux\s+marginal\s+(?:effectif|estim[ée]|r[ée]el)",
            r"taux\s+marginal",
            r"taux\s+d['\u2019]?imposition\s+(?:marginal|effectif)",
            r"taux\s+effectif\s+d['\u2019]?imposition",
            r"taux\s+moyen\s+d['\u2019]?imposition",
            r"grenzsteuersatz",
            r"marginaler?\s+steuersatz",
            r"effektiver?\s+steuersatz",
        ],
    },
}

# Fields with highest impact on projection precision (ordered by impact)
TAX_HIGH_IMPACT_FIELDS = [
    "revenu_imposable",
    "taux_marginal_effectif",
    "fortune_imposable",
    "deductions_effectuees",
    "impot_cantonal",
    "impot_federal",
]

# Impact weight per field for confidence delta calculation
_TAX_FIELD_IMPACT_WEIGHTS: dict[str, float] = {
    "revenu_imposable": 5.0,
    "taux_marginal_effectif": 5.0,
    "fortune_imposable": 3.5,
    "deductions_effectuees": 3.0,
    "impot_cantonal": 3.0,
    "impot_federal": 2.5,
}

# Maximum confidence delta from a single tax declaration scan
_MAX_CONFIDENCE_DELTA = 20.0

# Compliance constants
_DISCLAIMER = (
    "Cet outil est educatif et ne constitue pas un conseil financier, "
    "fiscal ou juridique personnalise. Les valeurs extraites sont indicatives "
    "et doivent etre verifiees. Consulte un-e specialiste pour ta situation "
    "personnelle (LSFin art. 3). L'image source n'est jamais stockee."
)

_SOURCES = [
    "LIFD art. 25-33 (revenu imposable)",
    "LIFD art. 38 (imposition du capital)",
    "LIFD art. 33 al. 1 let. e (deduction 3a: 7'258 CHF)",
    "LHID art. 7-9 (harmonisation fiscale cantonale)",
]


# ══════════════════════════════════════════════════════════════════════════════
# Core parsing function
# ══════════════════════════════════════════════════════════════════════════════


def parse_tax_declaration(text: str) -> ExtractionResult:
    """Extrait les champs structures d'un texte OCR de declaration fiscale.

    Parse les montants au format suisse (apostrophes comme separateur de milliers),
    detecte les pourcentages (taux marginal), et cross-valide
    impot total ~= cantonal + communal + federal.

    Args:
        text: Texte brut issu d'un OCR d'avis de taxation.

    Returns:
        ExtractionResult avec les champs extraits, confiance, warnings,
        disclaimer et sources legales.
    """
    result = ExtractionResult(
        document_type=DocumentType.tax_declaration,
        disclaimer=_DISCLAIMER,
        sources=list(_SOURCES),
    )

    if not text or not text.strip():
        result.warnings.append("Texte vide fourni. Aucun champ extrait.")
        return result

    text_lower = text.lower()
    extracted_fields: list[ExtractedField] = []

    for field_name, field_def in TAX_FIELD_PATTERNS.items():
        field_type = field_def["type"]
        patterns = field_def["patterns"]

        best_match: Optional[ExtractedField] = None
        best_confidence = 0.0

        for pattern in patterns:
            for match in re.finditer(pattern, text_lower, re.IGNORECASE):
                start = match.start()

                if field_type == "amount":
                    extraction = _extract_amount_near(text, start)
                    if extraction:
                        value, source_text = extraction
                        # Higher confidence for more specific patterns (earlier in list)
                        pattern_idx = patterns.index(pattern)
                        conf = max(0.6, 1.0 - pattern_idx * 0.05)
                        if conf > best_confidence:
                            best_confidence = conf
                            best_match = ExtractedField(
                                field_name=field_name,
                                value=value,
                                confidence=round(conf, 2),
                                source_text=source_text,
                                needs_review=conf < 0.7,
                            )
                elif field_type == "rate":
                    extraction = _extract_rate_near(text, start)
                    if extraction:
                        value, source_text = extraction
                        pattern_idx = patterns.index(pattern)
                        conf = max(0.6, 1.0 - pattern_idx * 0.05)
                        if conf > best_confidence:
                            best_confidence = conf
                            best_match = ExtractedField(
                                field_name=field_name,
                                value=value,
                                confidence=round(conf, 2),
                                source_text=source_text,
                                needs_review=conf < 0.7,
                            )

        if best_match is not None:
            extracted_fields.append(best_match)

    result.fields = extracted_fields

    # Cross-validation: impot total ~= cantonal + federal
    _cross_validate_tax_totals(result)

    # Sanity checks on extracted values
    _sanity_check_tax_fields(result)

    # Calculate overall confidence
    result.overall_confidence = _calculate_overall_confidence(result)

    return result


def _cross_validate_tax_totals(result: ExtractionResult) -> None:
    """Verifie que impot cantonal + federal est coherent avec le revenu imposable.

    Cross-validation: si on a cantonal et federal, leur somme doit etre
    plausible par rapport au revenu imposable (entre 5% et 50%).
    """
    cantonal_f = result.get_field("impot_cantonal")
    federal_f = result.get_field("impot_federal")
    revenu_f = result.get_field("revenu_imposable")

    if cantonal_f and federal_f:
        cantonal = cantonal_f.value
        federal = federal_f.value

        if isinstance(cantonal, (int, float)) and isinstance(federal, (int, float)):
            total_tax = cantonal + federal

            if revenu_f and isinstance(revenu_f.value, (int, float)) and revenu_f.value > 0:
                effective_rate = total_tax / revenu_f.value
                if 0.05 <= effective_rate <= 0.50:
                    # Plausible: boost confidence
                    for f in [cantonal_f, federal_f, revenu_f]:
                        f.confidence = min(1.0, f.confidence + 0.1)
                        f.needs_review = False
                else:
                    # Implausible ratio
                    result.warnings.append(
                        f"Incoherence detectee: impot total ({total_tax:,.0f} CHF) "
                        f"represente {effective_rate * 100:.1f}% du revenu imposable "
                        f"({revenu_f.value:,.0f} CHF). "
                        "Le taux effectif typique se situe entre 5% et 50%. "
                        "Verifie ces valeurs sur ton avis de taxation."
                    )
                    cantonal_f.needs_review = True
                    federal_f.needs_review = True
                    revenu_f.needs_review = True

            # Check federal < cantonal (typical in Switzerland)
            if federal > cantonal * 1.5 and cantonal > 0:
                result.warnings.append(
                    f"L'impot federal ({federal:,.0f} CHF) semble eleve par rapport "
                    f"a l'impot cantonal ({cantonal:,.0f} CHF). En general, "
                    "l'impot federal est inferieur a l'impot cantonal et communal."
                )


def _sanity_check_tax_fields(result: ExtractionResult) -> None:
    """Verifie la coherence des valeurs fiscales extraites."""
    # Taux marginal should be between 5% and 55%
    taux = result.get_field("taux_marginal_effectif")
    if taux and isinstance(taux.value, (int, float)):
        if taux.value < 5.0 or taux.value > 55.0:
            result.warnings.append(
                f"Le taux marginal ({taux.value}%) semble inhabituel. "
                "Les taux marginaux en Suisse se situent typiquement entre 10% et 45%."
            )
            taux.needs_review = True

    # Revenu imposable should be > 0 and < 10M
    revenu = result.get_field("revenu_imposable")
    if revenu and isinstance(revenu.value, (int, float)):
        if revenu.value < 1000:
            result.warnings.append(
                f"Le revenu imposable ({revenu.value:,.0f} CHF) semble tres bas. "
                "Verifie qu'il s'agit bien du revenu annuel imposable."
            )
            revenu.needs_review = True

    # Fortune should be >= 0
    fortune = result.get_field("fortune_imposable")
    if fortune and isinstance(fortune.value, (int, float)):
        if fortune.value > 10_000_000:
            result.warnings.append(
                f"La fortune imposable ({fortune.value:,.0f} CHF) est tres elevee. "
                "Verifie ce montant."
            )
            fortune.needs_review = True

    # Deductions should be plausible relative to income
    deductions = result.get_field("deductions_effectuees")
    if (
        deductions
        and revenu
        and isinstance(deductions.value, (int, float))
        and isinstance(revenu.value, (int, float))
        and revenu.value > 0
    ):
        deduction_ratio = deductions.value / (revenu.value + deductions.value)
        if deduction_ratio > 0.50:
            result.warnings.append(
                f"Les deductions ({deductions.value:,.0f} CHF) representent "
                f"plus de 50% du revenu brut estime. "
                "Verifie ce montant."
            )
            deductions.needs_review = True


def _calculate_overall_confidence(result: ExtractionResult) -> float:
    """Calcule la confiance globale de l'extraction fiscale.

    Basee sur:
    - Nombre de champs extraits vs. total possible
    - Confiance moyenne des champs individuels
    - Bonus si cross-validation passe
    """
    if not result.fields:
        return 0.0

    total_possible = len(TAX_FIELD_PATTERNS)
    fields_found = len(result.fields)

    # Coverage component
    coverage = fields_found / total_possible

    # Average confidence
    avg_confidence = sum(f.confidence for f in result.fields) / fields_found

    # Weighted combination: 40% coverage + 60% confidence
    overall = 0.4 * coverage + 0.6 * avg_confidence

    # Bonus for having the critical duo (revenu + taux marginal)
    critical_fields = {"revenu_imposable", "taux_marginal_effectif"}
    found_names = {f.field_name for f in result.fields}
    if critical_fields.issubset(found_names):
        overall += 0.05

    # Penalty for warnings
    warning_penalty = min(0.1, len(result.warnings) * 0.02)
    overall -= warning_penalty

    return round(max(0.0, min(1.0, overall)), 3)


# ══════════════════════════════════════════════════════════════════════════════
# Confidence delta estimation
# ══════════════════════════════════════════════════════════════════════════════


def estimate_tax_confidence_delta(
    extraction: ExtractionResult,
    current_profile: dict,
) -> float:
    """Estime l'augmentation du ConfidenceScore si ces valeurs fiscales sont confirmees.

    Le delta depend de:
    - Quels champs ont ete extraits
    - L'impact de chaque champ sur la precision des projections
    - Quels champs etaient deja renseignes dans le profil actuel

    Args:
        extraction: Resultat de l'extraction fiscale.
        current_profile: Profil actuel de l'utilisateur (champ -> valeur).

    Returns:
        Delta en points de pourcentage (0-20). Une declaration fiscale complete
        peut apporter jusqu'a +20 points de confiance.
    """
    if not extraction.fields:
        return 0.0

    delta = 0.0
    for field in extraction.fields:
        weight = _TAX_FIELD_IMPACT_WEIGHTS.get(field.field_name, 1.0)

        # If the field was already in the profile, the gain is smaller
        profile_key = _tax_field_to_profile_key(field.field_name)
        if profile_key and profile_key in current_profile:
            weight *= 0.4
        else:
            weight *= 1.0

        # Scale by extraction confidence
        delta += weight * field.confidence

    return round(min(delta, _MAX_CONFIDENCE_DELTA), 1)


def _tax_field_to_profile_key(field_name: str) -> Optional[str]:
    """Mappe un nom de champ extraction fiscale vers le champ profil correspondant."""
    mapping = {
        "revenu_imposable": "actual_taxable_income",
        "fortune_imposable": "actual_taxable_wealth",
        "deductions_effectuees": "actual_deductions",
        "impot_cantonal": "actual_cantonal_tax",
        "impot_federal": "actual_federal_tax",
        "taux_marginal_effectif": "actual_marginal_rate",
    }
    return mapping.get(field_name)
