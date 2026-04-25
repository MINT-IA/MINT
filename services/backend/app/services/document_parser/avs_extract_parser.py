"""
AVS Extract Parser — Sprint S45.

Service d'extraction structuree d'extraits de compte individuel (CI) AVS
a partir de texte OCR (FR + DE).

Extrait 4 champs cles: annees de cotisation, RAMD (revenu annuel moyen
determinant), lacunes de cotisation, bonifications educatives.

Le RAMD est critique pour la rente AVS: une erreur d'estimation
peut representer CHF 200-500/mois sur la rente projetee.

Ce service est une pure function sans state.

Privacy: l'image source n'est jamais stockee. Seules les valeurs extraites
sont conservees localement, chiffrees au repos.

Sources:
    - LAVS art. 29bis-29quinquies (duree de cotisation)
    - LAVS art. 29quater-29sexies (calcul de la rente, RAMD)
    - LAVS art. 29sexies (bonifications pour taches educatives)
    - LAVS art. 33ter (adaptation des rentes, echelle 44)
"""

from __future__ import annotations

import re
from typing import Optional

from app.constants.social_insurance import AVS_RAMD_MIN
from app.services.document_parser.document_models import (
    DocumentType,
    ExtractedField,
    ExtractionResult,
)
from app.services.document_parser.lpp_certificate_parser import (
    _extract_amount_near,
)


# ══════════════════════════════════════════════════════════════════════════════
# AVS-specific number extraction helpers
# ══════════════════════════════════════════════════════════════════════════════

# Regex for standalone integer after colon/equals (": 15", "= 22")
# This is the highest-priority pattern: the number directly after the label.
_COLON_INT_RE = re.compile(
    r"[:\s=]+\s*(\d{1,2})\b",
)

# Regex for "X annees / X Jahre" pattern with explicit unit
_YEARS_WITH_UNIT_RE = re.compile(
    r"(\d{1,2})\s*(?:ann[ée]es?|jahre?|ans?)\b",
    re.IGNORECASE,
)


def _extract_years_near(text: str, start: int, window: int = 250) -> Optional[tuple[int, str]]:
    """Extrait un nombre d'annees dans une fenetre de texte apres une position.

    Strategy:
    1. First, look for a number on the SAME LINE as the label (": 15", ": 22")
    2. Then, look for "X annees / X Jahre" pattern in the wider window

    Args:
        text: Texte complet.
        start: Position de debut de la recherche.
        window: Taille de la fenetre de recherche.

    Returns:
        Tuple (nombre_annees, texte_source) ou None.
    """
    context = text[start:start + window]

    # Find the end of the current line (limit initial search to same line)
    newline_pos = context.find("\n")
    same_line = context[:newline_pos] if newline_pos >= 0 else context

    # Strategy 1: Look for a number immediately after the label on the same line
    match = _COLON_INT_RE.search(same_line)
    if match:
        try:
            value = int(match.group(1))
            if 0 <= value <= 50:
                return (value, same_line.strip())
        except ValueError:
            pass

    # Strategy 2: Look for "X annees / X Jahre" on the same line
    match = _YEARS_WITH_UNIT_RE.search(same_line)
    if match:
        try:
            value = int(match.group(1))
            if 0 <= value <= 50:
                return (value, same_line[:match.end()].strip())
        except ValueError:
            pass

    # Strategy 3: Look in the wider context for "X annees / X Jahre"
    match = _YEARS_WITH_UNIT_RE.search(context)
    if match:
        try:
            value = int(match.group(1))
            if 0 <= value <= 50:
                return (value, context[:match.end()].strip())
        except ValueError:
            pass

    return None


# ══════════════════════════════════════════════════════════════════════════════
# Known field patterns — FR + DE
# ══════════════════════════════════════════════════════════════════════════════

AVS_FIELD_PATTERNS: dict[str, dict] = {
    "annees_cotisation": {
        "type": "years",
        "patterns": [
            r"ann[ée]es?\s+de\s+cotisation",
            r"dur[ée]e\s+de\s+cotisation",
            r"ann[ée]es?\s+(?:de\s+)?cotisations?\s+(?:AVS|AHV)",
            r"p[ée]riodes?\s+de\s+cotisation",
            r"beitragsjahre",
            r"beitragsdauer",
            r"versicherungsjahre",
            r"beitragszeit",
        ],
    },
    "ramd": {
        "type": "amount",
        "patterns": [
            r"revenu\s+annuel\s+moyen\s+d[ée]terminant\s*\(\s*RAMD\s*\)",
            r"revenu\s+annuel\s+moyen\s+d[ée]terminant",
            r"RAMD",
            r"revenu\s+moyen\s+d[ée]terminant",
            r"revenu\s+annuel\s+moyen",
            r"durchschnittliches?\s+jahreseinkommen",
            r"massgebendes?\s+durchschnittliches?\s+jahreseinkommen",
            r"mittleres?\s+jahreseinkommen",
        ],
    },
    "lacunes_cotisation": {
        "type": "years",
        "patterns": [
            r"lacunes?\s+de\s+cotisation",
            r"ann[ée]es?\s+manquantes?",
            r"ann[ée]es?\s+(?:de\s+)?cotisations?\s+manquantes?",
            r"p[ée]riodes?\s+(?:de\s+)?lacunes?",
            r"beitragsl[uü]cken?",
            r"fehlende\s+beitragsjahre",
            r"l[uü]cken?\s+(?:in\s+der\s+)?beitragszeit",
        ],
    },
    "bonifications_educatives": {
        "type": "years",
        "patterns": [
            r"bonifications?\s+(?:pour\s+)?t[âa]ches?\s+[ée]ducatives?",
            r"bonifications?\s+[ée]ducatives?",
            r"bonifications?\s+pour\s+[ée]ducation",
            r"ann[ée]es?\s+(?:de\s+)?bonifications?\s+[ée]ducatives?",
            r"erziehungsgutschriften?",
            r"gutschriften?\s+f[uü]r\s+erziehung(?:saufgaben)?",
            r"betreuungsgutschriften?",
        ],
    },
}

# Fields with highest impact on projection precision (ordered by impact)
AVS_HIGH_IMPACT_FIELDS = [
    "annees_cotisation",
    "ramd",
    "lacunes_cotisation",
    "bonifications_educatives",
]

# Impact weight per field for confidence delta calculation
_AVS_FIELD_IMPACT_WEIGHTS: dict[str, float] = {
    "annees_cotisation": 5.0,
    "ramd": 5.0,
    "lacunes_cotisation": 4.0,
    "bonifications_educatives": 2.5,
}

# Maximum confidence delta from a single AVS extract scan
_MAX_CONFIDENCE_DELTA = 25.0

# Compliance constants
_DISCLAIMER = (
    "Cet outil est educatif et ne constitue pas un conseil financier, "
    "fiscal ou juridique personnalise. Les valeurs extraites sont indicatives "
    "et doivent etre verifiees. Consulte un-e specialiste pour ta situation "
    "personnelle (LSFin art. 3). L'image source n'est jamais stockee."
)

_SOURCES = [
    "LAVS art. 29bis-29quinquies (duree de cotisation)",
    "LAVS art. 29quater-29sexies (calcul de la rente, RAMD)",
    "LAVS art. 29sexies (bonifications pour taches educatives)",
    "LAVS art. 33ter (adaptation des rentes, echelle 44)",
]


# ══════════════════════════════════════════════════════════════════════════════
# Core parsing function
# ══════════════════════════════════════════════════════════════════════════════


# ── Table-style IK extract heuristic ────────────────────────────────
# Official AVS account extracts (CI/IK) print one row per contribution
# year, typically `YEAR | EMPLOYER | INCOME (CHF)`. We accept any
# 4-digit year between 1960 and the current year + 1 followed by an
# income amount on the same line. Min 3 rows to qualify.
#
# Income matching: pick the LARGEST number on the year-row that is
# > 5'000 (typical AVS-cotisable income floor — sub-floor entries are
# either employer-test indices or apprenticeship part-years).

_IK_YEAR_LINE_RE = re.compile(
    r"^\s*(?P<year>(?:19[6-9]\d|20[0-3]\d))\b(?P<rest>[^\n]*)$",
    re.MULTILINE,
)
_IK_AMOUNT_TOKEN_RE = re.compile(
    r"\d{1,3}(?:['’\s]\d{3})+(?:[.,]\d{1,2})?|\d{4,}(?:[.,]\d{1,2})?"
)


def _parse_ik_year_table(text: str) -> Optional[tuple[int, float, str]]:
    """Detect a YEAR/EMPLOYER/INCOME row table in AVS IK extracts.

    Returns ``(years_count, mean_revenue, raw_window)`` if at least 3
    rows match. Returns None otherwise. The mean revenue is a *proxy*
    for RAMD (true RAMD applies LAVS art. 29sexies indexation) and is
    flagged needs_review by the caller.

    Income heuristic: the income is the LARGEST 4+ digit token (or
    Swiss-formatted thousands token) on the year-row. Single digits
    embedded in employer names (`Employeur Test 5`) are ignored.
    """
    rows: list[tuple[int, float]] = []
    raw_lines: list[str] = []
    for m in _IK_YEAR_LINE_RE.finditer(text):
        try:
            year = int(m.group("year"))
        except ValueError:
            continue
        rest = m.group("rest")
        candidates: list[float] = []
        for tok in _IK_AMOUNT_TOKEN_RE.findall(rest):
            cleaned = (
                tok.replace("'", "").replace("’", "")
                .replace(" ", "").replace(",", ".")
            )
            try:
                val = float(cleaned)
            except ValueError:
                continue
            # Income floor: AVS-cotisable income above 5'000 CHF.
            # Years like "2016" are ruled out by the line-anchor design,
            # but enforce a positive floor here too.
            if val < 5000.0 or val > 5_000_000.0:
                continue
            candidates.append(val)
        if not candidates:
            continue
        amount = max(candidates)
        rows.append((year, amount))
        raw_lines.append(f"{year}{rest}".strip())
    if len(rows) < 3:
        return None
    # Years count = unique year count.
    years_count = len({y for y, _ in rows})
    mean_revenue = sum(a for _, a in rows) / len(rows)
    raw_window = "\n".join(raw_lines[:5])
    return years_count, mean_revenue, raw_window


def parse_avs_extract(text: str) -> ExtractionResult:
    """Extrait les champs structures d'un texte OCR d'extrait de compte AVS.

    Parse les nombres d'annees et les montants au format suisse,
    et cross-valide annees cotisation + lacunes <= age - 20.

    Args:
        text: Texte brut issu d'un OCR d'extrait de compte individuel (CI).

    Returns:
        ExtractionResult avec les champs extraits, confiance, warnings,
        disclaimer et sources legales.
    """
    result = ExtractionResult(
        document_type=DocumentType.avs_extract,
        disclaimer=_DISCLAIMER,
        sources=list(_SOURCES),
    )

    if not text or not text.strip():
        result.warnings.append("Texte vide fourni. Aucun champ extrait.")
        return result

    text_lower = text.lower()
    extracted_fields: list[ExtractedField] = []

    for field_name, field_def in AVS_FIELD_PATTERNS.items():
        field_type = field_def["type"]
        patterns = field_def["patterns"]

        best_match: Optional[ExtractedField] = None
        best_confidence = 0.0

        for pattern in patterns:
            for match in re.finditer(pattern, text_lower, re.IGNORECASE):
                start = match.start()

                if field_type == "years":
                    extraction = _extract_years_near(text, start)
                    if extraction:
                        value, source_text = extraction
                        pattern_idx = patterns.index(pattern)
                        conf = max(0.6, 1.0 - pattern_idx * 0.05)
                        if conf > best_confidence:
                            best_confidence = conf
                            best_match = ExtractedField(
                                field_name=field_name,
                                value=float(value),
                                confidence=round(conf, 2),
                                source_text=source_text,
                                needs_review=conf < 0.7,
                            )
                elif field_type == "amount":
                    extraction = _extract_amount_near(text, start, min_value=1000.0)
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

    # Table-style IK extract fallback: official AVS account extracts (CI/IK)
    # are usually printed as a YEAR | EMPLOYER | INCOME table without the
    # explicit "années de cotisation" / "RAMD" labels the patterns above
    # expect. Detect such tables and derive both fields from the rows.
    # 2026-04-25: ground-truth `tests/fixtures/documents/avs_ik_extract.pdf`.
    extracted_field_names = {f.field_name for f in extracted_fields}
    if "annees_cotisation" not in extracted_field_names or "ramd" not in extracted_field_names:
        table = _parse_ik_year_table(text)
        if table is not None:
            years_count, mean_revenue, raw_window = table
            if "annees_cotisation" not in extracted_field_names:
                extracted_fields.append(
                    ExtractedField(
                        field_name="annees_cotisation",
                        value=float(years_count),
                        confidence=0.85,
                        source_text=raw_window,
                        needs_review=False,
                    )
                )
            if "ramd" not in extracted_field_names and mean_revenue >= AVS_RAMD_MIN:
                extracted_fields.append(
                    ExtractedField(
                        field_name="ramd",
                        value=float(round(mean_revenue, 2)),
                        confidence=0.75,
                        source_text=raw_window,
                        needs_review=True,  # mean of the window, not an
                                            # official RAMD figure
                    )
                )

    result.fields = extracted_fields

    # Cross-validation: annees cotisation + lacunes is plausible
    _cross_validate_avs(result)

    # Sanity checks
    _sanity_check_avs_fields(result)

    # Calculate overall confidence
    result.overall_confidence = _calculate_overall_confidence(result)

    return result


def _cross_validate_avs(result: ExtractionResult) -> None:
    """Verifie que annees cotisation + lacunes est plausible.

    Cross-validation: annees_cotisation + lacunes_cotisation <= 44 (max possible).
    La cotisation AVS est obligatoire de 20 ans a 65 ans = max 44 annees.
    Aussi: lacunes ne doivent pas depasser le total d'annees theoriques.
    """
    annees_f = result.get_field("annees_cotisation")
    lacunes_f = result.get_field("lacunes_cotisation")

    if annees_f and lacunes_f:
        annees = annees_f.value
        lacunes = lacunes_f.value

        if isinstance(annees, (int, float)) and isinstance(lacunes, (int, float)):
            total = annees + lacunes
            if total <= 44:
                # Plausible: boost confidence
                for f in [annees_f, lacunes_f]:
                    f.confidence = min(1.0, f.confidence + 0.1)
                    f.needs_review = False
            else:
                result.warnings.append(
                    f"Incoherence detectee: annees de cotisation ({int(annees)}) + "
                    f"lacunes ({int(lacunes)}) = {int(total)}, "
                    "ce qui depasse le maximum de 44 annees (LAVS: cotisation de 20 a 65 ans). "
                    "Verifie ces valeurs sur ton extrait CI."
                )
                annees_f.needs_review = True
                lacunes_f.needs_review = True

    # RAMD plausibility
    ramd_f = result.get_field("ramd")
    if ramd_f and isinstance(ramd_f.value, (int, float)):
        # RAMD should be between minimum AVS and about 2x the max insured salary
        if ramd_f.value < AVS_RAMD_MIN:
            result.warnings.append(
                f"Le RAMD ({ramd_f.value:,.0f} CHF) est inferieur au minimum AVS. "
                "Verifie ce montant sur ton extrait CI."
            )
            ramd_f.needs_review = True
        elif ramd_f.value > 200_000:
            result.warnings.append(
                f"Le RAMD ({ramd_f.value:,.0f} CHF) semble tres eleve. "
                "Le RAMD est plafonne a environ 88'200 CHF pour le calcul de la rente. "
                "Verifie ce montant."
            )
            ramd_f.needs_review = True


def _sanity_check_avs_fields(result: ExtractionResult) -> None:
    """Verifie la coherence des valeurs AVS extraites."""
    # Annees de cotisation: max 44 (20 a 65 ans)
    annees = result.get_field("annees_cotisation")
    if annees and isinstance(annees.value, (int, float)):
        if annees.value > 44:
            result.warnings.append(
                f"Les annees de cotisation ({int(annees.value)}) depassent "
                "le maximum de 44 ans (LAVS: cotisation de 20 a 65 ans)."
            )
            annees.needs_review = True
        if annees.value < 0:
            result.warnings.append(
                "Les annees de cotisation ne peuvent pas etre negatives."
            )
            annees.needs_review = True

    # Lacunes: should be < annees_cotisation + lacunes total
    lacunes = result.get_field("lacunes_cotisation")
    if lacunes and isinstance(lacunes.value, (int, float)):
        if lacunes.value > 44:
            result.warnings.append(
                f"Les lacunes de cotisation ({int(lacunes.value)}) depassent "
                "le maximum de 44 annees."
            )
            lacunes.needs_review = True

    # Bonifications educatives: typically 0-16 (max children * years)
    bonif = result.get_field("bonifications_educatives")
    if bonif and isinstance(bonif.value, (int, float)):
        if bonif.value > 16:
            result.warnings.append(
                f"Les bonifications educatives ({int(bonif.value)} annees) "
                "semblent elevees. Le maximum typique est de 16 annees "
                "(2 enfants x 16 ans, mais plafonnees)."
            )
            bonif.needs_review = True


def _calculate_overall_confidence(result: ExtractionResult) -> float:
    """Calcule la confiance globale de l'extraction AVS.

    Basee sur:
    - Nombre de champs extraits vs. total possible (4)
    - Confiance moyenne des champs individuels
    - Bonus si cross-validation passe
    """
    if not result.fields:
        return 0.0

    total_possible = len(AVS_FIELD_PATTERNS)
    fields_found = len(result.fields)

    # Coverage component
    coverage = fields_found / total_possible

    # Average confidence
    avg_confidence = sum(f.confidence for f in result.fields) / fields_found

    # Weighted combination: 40% coverage + 60% confidence
    overall = 0.4 * coverage + 0.6 * avg_confidence

    # Bonus for having the critical duo (annees + RAMD)
    critical_fields = {"annees_cotisation", "ramd"}
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


def estimate_avs_confidence_delta(
    extraction: ExtractionResult,
    current_profile: dict,
) -> float:
    """Estime l'augmentation du ConfidenceScore si ces valeurs AVS sont confirmees.

    Le delta depend de:
    - Quels champs ont ete extraits
    - L'impact de chaque champ sur la precision des projections
    - Quels champs etaient deja renseignes dans le profil actuel

    Args:
        extraction: Resultat de l'extraction AVS.
        current_profile: Profil actuel de l'utilisateur (champ -> valeur).

    Returns:
        Delta en points de pourcentage (0-25). Un extrait AVS complet
        peut apporter jusqu'a +25 points de confiance.
    """
    if not extraction.fields:
        return 0.0

    delta = 0.0
    for field in extraction.fields:
        weight = _AVS_FIELD_IMPACT_WEIGHTS.get(field.field_name, 1.0)

        # If the field was already in the profile, the gain is smaller
        profile_key = _avs_field_to_profile_key(field.field_name)
        if profile_key and profile_key in current_profile:
            weight *= 0.4
        else:
            weight *= 1.0

        # Scale by extraction confidence
        delta += weight * field.confidence

    return round(min(delta, _MAX_CONFIDENCE_DELTA), 1)


def _avs_field_to_profile_key(field_name: str) -> Optional[str]:
    """Mappe un nom de champ extraction AVS vers le champ profil correspondant."""
    mapping = {
        "annees_cotisation": "avs_contribution_years",
        "ramd": "avs_ramd",
        "lacunes_cotisation": "avs_gaps",
        "bonifications_educatives": "avs_education_credits",
    }
    return mapping.get(field_name)
