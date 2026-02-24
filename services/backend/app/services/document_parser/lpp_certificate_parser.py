"""
LPP Certificate Parser — Sprint S42-S43.

Service d'extraction structuree de certificats de prevoyance LPP
a partir de texte OCR (FR + DE).

Extrait ~15 champs cles: avoir de vieillesse (total, obligatoire, surobligatoire),
taux de conversion, lacune de rachat, rente projetee, capital projete,
prestations de risque, cotisations, et salaire assure.

Ce service est une pure function sans state.

Privacy: l'image source n'est jamais stockee. Seules les valeurs extraites
sont conservees localement, chiffrees au repos.

Sources:
    - LPP art. 7 (seuil d'entree: 22'680 CHF)
    - LPP art. 8 (deduction de coordination: 26'460 CHF)
    - LPP art. 14 (taux de conversion minimum: 6.8%)
    - LPP art. 15-16 (bonifications vieillesse: 7/10/15/18%)
    - LPP art. 79b al. 3 (blocage rachat: 3 ans)
"""

from __future__ import annotations

import re
from typing import Optional

from app.services.document_parser.document_models import (
    DocumentType,
    ExtractedField,
    ExtractionResult,
)


# ══════════════════════════════════════════════════════════════════════════════
# Swiss number parsing helpers
# ══════════════════════════════════════════════════════════════════════════════

# Regex for Swiss CHF amounts: "CHF 143'287.00", "143'287", "143287.00"
_AMOUNT_RE = re.compile(
    r"(?:CHF|Fr\.|SFr\.?)?\s*"
    r"(\d{1,3}(?:['\u2019\s]\d{3})*(?:[.,]\d{1,2})?)"
    r"(?:\s*(?:CHF|Fr\.|/an|/mois))?",
    re.IGNORECASE,
)

# Regex for percentages: "6.80%", "5,20 %"
_RATE_RE = re.compile(
    r"(\d{1,3}(?:[.,]\d{1,4})?)\s*%",
)


def parse_swiss_number(raw: str) -> Optional[float]:
    """Parse un nombre au format suisse (apostrophe = separateur de milliers).

    Exemples:
        "143'287.00" -> 143287.0
        "143'287"    -> 143287.0
        "6.80"       -> 6.8
        "45'000"     -> 45000.0
        "4'200.00"   -> 4200.0

    Args:
        raw: Nombre brut au format suisse.

    Returns:
        Valeur float, ou None si parsing impossible.
    """
    if not raw or not raw.strip():
        return None

    # Remove thousand separators (apostrophe, right single quote, thin space)
    cleaned = raw.strip()
    cleaned = cleaned.replace("'", "").replace("\u2019", "").replace("\u202f", "")
    cleaned = cleaned.replace(" ", "")

    # Handle comma as decimal separator
    if "," in cleaned and "." in cleaned:
        last_comma = cleaned.rfind(",")
        last_dot = cleaned.rfind(".")
        if last_comma > last_dot:
            # European format: 1.234,56
            cleaned = cleaned.replace(".", "").replace(",", ".")
        else:
            # Anglo/Swiss: 1,234.56
            cleaned = cleaned.replace(",", "")
    elif "," in cleaned:
        parts = cleaned.split(",")
        if len(parts) == 2 and len(parts[1]) <= 2:
            cleaned = cleaned.replace(",", ".")
        else:
            cleaned = cleaned.replace(",", "")

    try:
        return float(cleaned)
    except ValueError:
        return None


def _extract_amount_near(text: str, start: int, window: int = 300, min_value: float = 100.0) -> Optional[tuple[float, str]]:
    """Extrait un montant CHF dans une fenetre de texte apres une position.

    Ignore les petits nombres (< min_value) qui font souvent partie du contexte
    (ex: "a 65 ans" ne doit pas etre lu comme CHF 65).

    Args:
        text: Texte complet.
        start: Position de debut de la recherche.
        window: Taille de la fenetre de recherche.
        min_value: Valeur minimale pour un montant CHF valide.

    Returns:
        Tuple (valeur, texte_source) ou None.
    """
    context = text[start:start + window]
    for match in _AMOUNT_RE.finditer(context):
        raw = match.group(1)
        value = parse_swiss_number(raw)
        if value is not None and min_value <= value <= 50_000_000:
            return (value, context[:match.end()].strip())
    return None


def _extract_rate_near(text: str, start: int, window: int = 200) -> Optional[tuple[float, str]]:
    """Extrait un pourcentage dans une fenetre de texte apres une position.

    Returns:
        Tuple (valeur_pourcent, texte_source) ou None.
    """
    context = text[start:start + window]
    match = _RATE_RE.search(context)
    if match:
        raw = match.group(1).replace(",", ".")
        try:
            value = float(raw)
            if 0 < value <= 100:
                return (value, context[:match.end()].strip())
        except ValueError:
            pass
    return None


# ══════════════════════════════════════════════════════════════════════════════
# Known field patterns — FR + DE
# ══════════════════════════════════════════════════════════════════════════════

# Each entry: (field_name, type, regex_patterns_list)
# type: "amount" (CHF) or "rate" (%)

KNOWN_FIELD_PATTERNS: dict[str, dict] = {
    "avoir_total": {
        "type": "amount",
        "patterns": [
            r"avoir\s+de\s+vieillesse\s+total",
            r"avoir\s+vieillesse\s+total",
            r"capital\s+vieillesse\s+total",
            r"total\s+(?:des?\s+)?avoirs?\s+de\s+vieillesse",
            r"total\s+avoir",
            r"altersguthaben\s+total",
            r"totales?\s+altersguthaben",
            r"gesamtes?\s+altersguthaben",
        ],
    },
    "part_obligatoire": {
        "type": "amount",
        "patterns": [
            r"part\s+obligatoire",
            r"avoir\s+(?:de\s+)?vieillesse\s+obligatoire",
            r"capital\s+(?:de\s+)?vieillesse\s+obligatoire",
            r"avoirs?\s+obligatoires?",
            r"obligatorisch(?:es?)?\s+altersguthaben",
            r"altersguthaben\s+obligatorium",
            r"bvg[- ]?altersguthaben",
            r"obligatoire",
        ],
    },
    "part_surobligatoire": {
        "type": "amount",
        "patterns": [
            r"part\s+surobligatoire",
            r"avoir\s+(?:de\s+)?vieillesse\s+surobligatoire",
            r"capital\s+(?:de\s+)?vieillesse\s+surobligatoire",
            r"avoirs?\s+surobligatoires?",
            r"extra[- ]?obligatoire",
            r"[u\u00fc]berobligatorisch(?:es?)?\s+altersguthaben",
            r"altersguthaben\s+[u\u00fc]berobligatorium",
            r"surobligatoire",
        ],
    },
    "taux_conversion_oblig": {
        "type": "rate",
        "patterns": [
            r"taux\s+de\s+conversion\s*\(\s*obligatoire\s*\)",
            r"taux\s+de\s+conversion\s+obligatoire",
            r"taux\s+de\s+conversion\s+(?:lpp|bvg)",
            r"taux\s+de\s+conversion\s+l[ée]gal",
            r"umwandlungssatz\s+(?:obligatorium|bvg)",
            r"(?<![a-z\u00fc])obligatorischer?\s+umwandlungssatz",
            r"bvg[- ]?umwandlungssatz",
        ],
    },
    "taux_conversion_suroblig": {
        "type": "rate",
        "patterns": [
            r"taux\s+de\s+conversion\s*\(\s*surobligatoire\s*\)",
            r"taux\s+de\s+conversion\s+surobligatoire",
            r"taux\s+de\s+conversion\s+extra[- ]?obligatoire",
            r"umwandlungssatz\s+[u\u00fc]berobligatorium",
            r"[u\u00fc]berobligatorischer?\s+umwandlungssatz",
        ],
    },
    "lacune_rachat": {
        "type": "amount",
        "patterns": [
            r"lacune\s+de\s+rachat",
            r"rachat\s+(?:maximum|maximal|possible)",
            r"montant\s+de?\s+rachat",
            r"possibilit[ée]\s+de\s+rachat",
            r"einkaufsl[u\u00fc]cke",
            r"einkaufspotenzial",
            r"(?:maximaler?|m[o\u00f6]glicher?)\s+einkauf",
        ],
    },
    "rente_projetee": {
        "type": "amount",
        "patterns": [
            r"rente\s+de\s+vieillesse\s+projet[ée]e?\s+(?:[aà]\s+65|65)",
            r"rente\s+(?:de\s+vieillesse\s+)?projet[ée]e",
            r"rente\s+vieillesse\s+projet[ée]e",
            r"rente\s+annuelle\s+projet[ée]e",
            r"projizierte\s+altersrente",
            r"voraussichtliche\s+altersrente",
        ],
    },
    "capital_projete_65": {
        "type": "amount",
        "patterns": [
            r"capital\s+projet[ée]\s+[àa]\s+65",
            r"capital\s+de\s+vieillesse\s+projet[ée]\s+[àa]\s+65",
            r"avoir\s+(?:de\s+vieillesse\s+)?projet[ée]\s+[àa]\s+65",
            r"projiziertes?\s+altersguthaben",
            r"voraussichtliches?\s+altersguthaben\s+(?:mit|bei)\s+65",
        ],
    },
    "prestation_invalidite": {
        "type": "amount",
        "patterns": [
            r"prestation\s+d['\u2019]?invalidit[ée]",
            r"rente\s+d['\u2019]?invalidit[ée]",
            r"rente\s+invalidit[ée]",
            r"invalidenleistung",
            r"invalidenrente",
        ],
    },
    "prestation_deces": {
        "type": "amount",
        "patterns": [
            r"prestation\s+de\s+d[ée]c[èe]s",
            r"capital[- ]?d[ée]c[èe]s",
            r"capital\s+en\s+cas\s+de\s+d[ée]c[èe]s",
            r"todesfallleistung",
            r"todesfallkapital",
        ],
    },
    "cotisation_employe": {
        "type": "amount",
        "patterns": [
            r"cotisation\s+employ[ée]",
            r"cotisation\s+(?:de\s+l['\u2019]?)?employ[ée]",
            r"part\s+employ[ée]",
            r"contribution\s+employ[ée]",
            r"cotisation\s+salari[ée]",
            r"arbeitnehmer[- ]?beitrag",
            r"beitrag\s+arbeitnehmer",
        ],
    },
    "cotisation_employeur": {
        "type": "amount",
        "patterns": [
            r"cotisation\s+employeur",
            r"cotisation\s+(?:de\s+l['\u2019]?)?employeur",
            r"part\s+employeur",
            r"contribution\s+employeur",
            r"arbeitgeber[- ]?beitrag",
            r"beitrag\s+arbeitgeber",
        ],
    },
    "salaire_assure": {
        "type": "amount",
        "patterns": [
            r"salaire\s+assur[ée]",
            r"salaire\s+coordonn[ée]",
            r"salaire\s+annuel\s+assur[ée]",
            r"versicherter?\s+lohn",
            r"versicherter?\s+gehalt",
            r"koordinierter?\s+lohn",
        ],
    },
}

# Fields with the highest impact on projection precision
# (ordered by impact on ConfidenceScore)
HIGH_IMPACT_FIELDS = [
    "part_obligatoire",
    "part_surobligatoire",
    "avoir_total",
    "taux_conversion_oblig",
    "taux_conversion_suroblig",
    "lacune_rachat",
    "salaire_assure",
    "rente_projetee",
    "capital_projete_65",
    "cotisation_employe",
    "cotisation_employeur",
    "prestation_invalidite",
    "prestation_deces",
]

# Impact weight per field for confidence delta calculation
_FIELD_IMPACT_WEIGHTS: dict[str, float] = {
    "part_obligatoire": 5.0,
    "part_surobligatoire": 4.5,
    "avoir_total": 4.0,
    "taux_conversion_oblig": 4.0,
    "taux_conversion_suroblig": 3.5,
    "lacune_rachat": 3.0,
    "salaire_assure": 3.0,
    "rente_projetee": 2.5,
    "capital_projete_65": 2.5,
    "cotisation_employe": 2.0,
    "cotisation_employeur": 2.0,
    "prestation_invalidite": 1.5,
    "prestation_deces": 1.5,
}

# Maximum confidence delta from a single LPP certificate scan
_MAX_CONFIDENCE_DELTA = 30.0

# Compliance constants
_DISCLAIMER = (
    "Cet outil est educatif et ne constitue pas un conseil financier, "
    "fiscal ou juridique personnalise. Les valeurs extraites sont indicatives "
    "et doivent etre verifiees. Consulte un-e specialiste pour ta situation "
    "personnelle (LSFin art. 3). L'image source n'est jamais stockee."
)

_SOURCES = [
    "LPP art. 7 (seuil d'entree: 22'680 CHF)",
    "LPP art. 8 (deduction de coordination: 26'460 CHF)",
    "LPP art. 14 (taux de conversion minimum: 6.8%)",
    "LPP art. 15-16 (bonifications vieillesse: 7/10/15/18%)",
    "LPP art. 79b al. 3 (blocage rachat: 3 ans)",
]


# ══════════════════════════════════════════════════════════════════════════════
# Core parsing function
# ══════════════════════════════════════════════════════════════════════════════


def parse_lpp_certificate(text: str) -> ExtractionResult:
    """Extrait les champs structures d'un texte OCR de certificat LPP.

    Parse les nombres au format suisse (apostrophes comme separateur de milliers),
    detecte les pourcentages (taux de conversion), et cross-valide
    obligatoire + surobligatoire vs. total.

    Args:
        text: Texte brut issu d'un OCR de certificat de prevoyance.

    Returns:
        ExtractionResult avec les champs extraits, confiance, warnings,
        disclaimer et sources legales.
    """
    result = ExtractionResult(
        document_type=DocumentType.lpp_certificate,
        disclaimer=_DISCLAIMER,
        sources=list(_SOURCES),
    )

    if not text or not text.strip():
        result.warnings.append("Texte vide fourni. Aucun champ extrait.")
        return result

    text_lower = text.lower()
    extracted_fields: list[ExtractedField] = []

    for field_name, field_def in KNOWN_FIELD_PATTERNS.items():
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

    # Cross-validation: obligatoire + surobligatoire ~= total
    _cross_validate_totals(result)

    # Sanity checks on extracted values
    _sanity_check_fields(result)

    # Calculate overall confidence
    result.overall_confidence = _calculate_overall_confidence(result)

    return result


def _cross_validate_totals(result: ExtractionResult) -> None:
    """Verifie que obligatoire + surobligatoire = total (tolerance 5%)."""
    total_f = result.get_field("avoir_total")
    oblig_f = result.get_field("part_obligatoire")
    suroblig_f = result.get_field("part_surobligatoire")

    if total_f and oblig_f and suroblig_f:
        total = total_f.value
        expected = oblig_f.value + suroblig_f.value  # type: ignore[operator]

        if isinstance(total, (int, float)) and isinstance(expected, (int, float)):
            if expected > 0:
                ratio = total / expected
                if 0.95 <= ratio <= 1.05:
                    # Consistent: boost confidence
                    for f in [total_f, oblig_f, suroblig_f]:
                        f.confidence = min(1.0, f.confidence + 0.1)
                        f.needs_review = False
                else:
                    # Inconsistent: flag for review
                    result.warnings.append(
                        f"Incoherence detectee: obligatoire ({oblig_f.value:,.0f}) + "
                        f"surobligatoire ({suroblig_f.value:,.0f}) = "
                        f"{expected:,.0f}, mais le total indique {total:,.0f}. "
                        "Verifie ces valeurs sur ton certificat."
                    )
                    total_f.needs_review = True
                    oblig_f.needs_review = True
                    suroblig_f.needs_review = True


def _sanity_check_fields(result: ExtractionResult) -> None:
    """Verifie la coherence des valeurs extraites."""
    # Taux de conversion obligatoire should be around 6.8%
    taux_oblig = result.get_field("taux_conversion_oblig")
    if taux_oblig and isinstance(taux_oblig.value, (int, float)):
        if taux_oblig.value < 4.0 or taux_oblig.value > 8.0:
            result.warnings.append(
                f"Le taux de conversion obligatoire ({taux_oblig.value}%) "
                "semble inhabituel. Le minimum legal est de 6.8% (LPP art. 14)."
            )
            taux_oblig.needs_review = True

    # Taux de conversion surobligatoire typically 4-6%
    taux_suroblig = result.get_field("taux_conversion_suroblig")
    if taux_suroblig and isinstance(taux_suroblig.value, (int, float)):
        if taux_suroblig.value < 2.0 or taux_suroblig.value > 7.5:
            result.warnings.append(
                f"Le taux de conversion surobligatoire ({taux_suroblig.value}%) "
                "semble inhabituel. La plupart des caisses appliquent entre 4% et 6%."
            )
            taux_suroblig.needs_review = True

    # Cotisation employeur should be >= cotisation employe (common in CH)
    cot_employe = result.get_field("cotisation_employe")
    cot_employeur = result.get_field("cotisation_employeur")
    if (
        cot_employe
        and cot_employeur
        and isinstance(cot_employe.value, (int, float))
        and isinstance(cot_employeur.value, (int, float))
    ):
        if cot_employeur.value < cot_employe.value * 0.8:
            result.warnings.append(
                "La cotisation employeur semble inferieure a la cotisation employe. "
                "En general, l'employeur cotise au moins autant que l'employe (LPP art. 66)."
            )


def _calculate_overall_confidence(result: ExtractionResult) -> float:
    """Calcule la confiance globale de l'extraction.

    Basee sur:
    - Nombre de champs extraits vs. total possible
    - Confiance moyenne des champs individuels
    - Bonus si cross-validation passe
    """
    if not result.fields:
        return 0.0

    total_possible = len(KNOWN_FIELD_PATTERNS)
    fields_found = len(result.fields)

    # Coverage component: fields found / total possible
    coverage = fields_found / total_possible

    # Average confidence of extracted fields
    avg_confidence = sum(f.confidence for f in result.fields) / fields_found

    # Weighted combination: 40% coverage + 60% average confidence
    overall = 0.4 * coverage + 0.6 * avg_confidence

    # Bonus for having the critical trio (total, oblig, suroblig)
    critical_fields = {"avoir_total", "part_obligatoire", "part_surobligatoire"}
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


def estimate_confidence_delta(
    extraction: ExtractionResult,
    current_profile: dict,
) -> float:
    """Estime l'augmentation du ConfidenceScore si ces valeurs sont confirmees.

    Le delta depend de:
    - Quels champs ont ete extraits
    - L'impact de chaque champ sur la precision des projections
    - Quels champs etaient deja renseignes dans le profil actuel

    Args:
        extraction: Resultat de l'extraction LPP.
        current_profile: Profil actuel de l'utilisateur (champ -> valeur).

    Returns:
        Delta en points de pourcentage (0-30). Un certificat LPP complet
        peut apporter jusqu'a +30 points de confiance.
    """
    if not extraction.fields:
        return 0.0

    delta = 0.0
    for field in extraction.fields:
        weight = _FIELD_IMPACT_WEIGHTS.get(field.field_name, 1.0)

        # If the field was already in the profile (user estimate), the gain
        # is smaller than if it was completely missing
        profile_key = _field_to_profile_key(field.field_name)
        if profile_key and profile_key in current_profile:
            # Already had an estimate: improvement is partial
            weight *= 0.4
        else:
            # Brand new field: full impact
            weight *= 1.0

        # Scale by extraction confidence
        delta += weight * field.confidence

    # Cap at maximum delta
    return round(min(delta, _MAX_CONFIDENCE_DELTA), 1)


def _field_to_profile_key(field_name: str) -> Optional[str]:
    """Mappe un nom de champ extraction vers le champ profil correspondant."""
    mapping = {
        "avoir_total": "lpp_total",
        "part_obligatoire": "lpp_obligatoire",
        "part_surobligatoire": "lpp_surobligatoire",
        "taux_conversion_oblig": "conversion_rate_oblig",
        "taux_conversion_suroblig": "conversion_rate_suroblig",
        "lacune_rachat": "buyback_potential",
        "rente_projetee": "projected_rente_lpp",
        "capital_projete_65": "projected_capital_65",
        "prestation_invalidite": "disability_coverage",
        "prestation_deces": "death_coverage",
        "cotisation_employe": "employee_lpp_contribution",
        "cotisation_employeur": "employer_lpp_contribution",
        "salaire_assure": "lpp_insured_salary",
    }
    return mapping.get(field_name)
