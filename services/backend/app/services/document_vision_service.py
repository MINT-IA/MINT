"""Claude Vision document extraction service.

Replaces/augments MLKit OCR with Claude Vision for Swiss financial documents.
Handles: LPP certificates, tax declarations, AVS extracts, salary certs,
payslips, lease contracts, LPP plans, insurance contracts.

Pure function pattern — no side effects, deterministic prompt, testable.

See: MINT_ANTI_BULLSHIT_MANIFESTO.md, MINT_FINAL_EXECUTION_SYSTEM.md §13.11
"""

import json
import logging
from typing import Dict, List as TList, Optional

from anthropic import Anthropic

from app.core.config import settings
from app.schemas.document_scan import (
    DocumentType,
    DocumentClassificationResult,
    ExtractedFieldConfirmation,
    ConfidenceLevel,
    LppPlanType,
    VisionExtractionResponse,
)

logger = logging.getLogger(__name__)


def _build_vision_content_block(base64_data: str) -> dict:
    """Build the correct Anthropic API content block for image or PDF.

    PDFs use type=document + media_type=application/pdf (Anthropic PDF support).
    Images use type=image + media_type=image/jpeg|png.
    """
    if base64_data.startswith("JVBERi"):  # %PDF in base64
        return {
            "type": "document",
            "source": {
                "type": "base64",
                "media_type": "application/pdf",
                "data": base64_data,
            },
        }
    media_type = "image/jpeg"
    if base64_data.startswith("iVBOR"):
        media_type = "image/png"
    return {
        "type": "image",
        "source": {
            "type": "base64",
            "media_type": media_type,
            "data": base64_data,
        },
    }

# Field definitions per document type — what to extract and validate.

DOCUMENT_FIELDS: Dict[DocumentType, TList[dict]] = {
    DocumentType.lpp_certificate: [
        {"name": "avoirLppTotal", "type": "float", "label": "Avoir total LPP", "range": (0, 5_000_000)},
        {"name": "avoirLppObligatoire", "type": "float", "label": "Avoir obligatoire", "range": (0, 3_000_000)},
        {"name": "avoirLppSurobligatoire", "type": "float", "label": "Avoir surobligatoire", "range": (0, 3_000_000)},
        {"name": "tauxConversion", "type": "float", "label": "Taux de conversion", "range": (0.03, 0.08)},
        {"name": "rachatMaximum", "type": "float", "label": "Rachat maximum possible", "range": (0, 2_000_000)},
        {"name": "salaireAssure", "type": "float", "label": "Salaire assuré", "range": (0, 500_000)},
        {"name": "bonificationVieillesse", "type": "float", "label": "Bonification vieillesse %", "range": (0.07, 0.25)},
    ],
    DocumentType.avs_extract: [
        {"name": "anneesContribution", "type": "int", "label": "Années de cotisation", "range": (0, 44)},
        {"name": "lacunesCotisation", "type": "int", "label": "Lacunes de cotisation", "range": (0, 20)},
        {"name": "renteEstimee", "type": "float", "label": "Rente AVS estimée (annuelle)", "range": (0, 30_240)},
        {"name": "ramd", "type": "float", "label": "Revenu annuel moyen déterminant", "range": (0, 200_000)},
    ],
    DocumentType.tax_declaration: [
        {"name": "revenuImposable", "type": "float", "label": "Revenu imposable", "range": (0, 2_000_000)},
        {"name": "fortuneImposable", "type": "float", "label": "Fortune imposable", "range": (0, 50_000_000)},
        {"name": "impotCantonal", "type": "float", "label": "Impôt cantonal", "range": (0, 500_000)},
        {"name": "impotFederal", "type": "float", "label": "Impôt fédéral direct", "range": (0, 200_000)},
        {"name": "tauxMarginal", "type": "float", "label": "Taux marginal effectif", "range": (0, 0.5)},
    ],
    DocumentType.salary_certificate: [
        {"name": "salaireBrutAnnuel", "type": "float", "label": "Salaire brut annuel", "range": (0, 2_000_000)},
        {"name": "cotisationsAvs", "type": "float", "label": "Cotisations AVS/AI/APG", "range": (0, 200_000)},
        {"name": "cotisationsLpp", "type": "float", "label": "Cotisations LPP employé", "range": (0, 100_000)},
        {"name": "nombreMois", "type": "int", "label": "Nombre de mois (12/13/13.5)", "range": (12, 14)},
    ],
    DocumentType.payslip: [
        {"name": "salaireBrutMensuel", "type": "float", "label": "Salaire brut mensuel", "range": (0, 200_000)},
        {"name": "salaireNetMensuel", "type": "float", "label": "Salaire net mensuel", "range": (0, 150_000)},
        {"name": "deductionsLpp", "type": "float", "label": "Déduction LPP", "range": (0, 10_000)},
        {"name": "deductionsAvs", "type": "float", "label": "Déduction AVS/AI/APG", "range": (0, 20_000)},
    ],
    DocumentType.lease_contract: [
        {"name": "loyerMensuel", "type": "float", "label": "Loyer mensuel brut", "range": (0, 20_000)},
        {"name": "chargesAccessoires", "type": "float", "label": "Charges accessoires", "range": (0, 5_000)},
        {"name": "dureeContrat", "type": "str", "label": "Durée du bail", "range": None},
        {"name": "garantieBancaire", "type": "float", "label": "Garantie de loyer", "range": (0, 60_000)},
    ],
    DocumentType.lpp_plan: [
        {"name": "planType", "type": "str", "label": "Type de plan (base/complet/cadre)", "range": None},
        {"name": "tauxConversionOblig", "type": "float", "label": "Taux conversion obligatoire", "range": (0.05, 0.07)},
        {"name": "tauxConversionSuroblig", "type": "float", "label": "Taux conversion surobligatoire", "range": (0.01, 0.07)},
        {"name": "bonificationsAge", "type": "str", "label": "Barème bonifications par âge", "range": None},
        {"name": "rendementCaisse", "type": "float", "label": "Rendement de la caisse", "range": (0.01, 0.10)},
    ],
    DocumentType.insurance_contract: [
        {"name": "typeAssurance", "type": "str", "label": "Type (vie, ménage, RC, IJM)", "range": None},
        {"name": "primeMensuelle", "type": "float", "label": "Prime mensuelle", "range": (0, 5_000)},
        {"name": "couvertureCapital", "type": "float", "label": "Couverture/capital", "range": (0, 10_000_000)},
        {"name": "franchise", "type": "float", "label": "Franchise", "range": (0, 10_000)},
    ],
    # Mobile-originated document types
    DocumentType.pillar_3a_attestation: [
        {"name": "solde3a", "type": "float", "label": "Solde du compte 3a", "range": (0, 500_000)},
        {"name": "versementAnnuel", "type": "float", "label": "Versement annuel", "range": (0, 40_000)},
        {"name": "fournisseur", "type": "str", "label": "Fournisseur 3a", "range": None},
    ],
    DocumentType.insurance_policy: [
        {"name": "primeMensuelle", "type": "float", "label": "Prime mensuelle", "range": (0, 5_000)},
        {"name": "typeAssurance", "type": "str", "label": "Type d'assurance", "range": None},
        {"name": "couverture", "type": "float", "label": "Couverture", "range": (0, 10_000_000)},
    ],
    DocumentType.lease: [
        {"name": "loyerMensuel", "type": "float", "label": "Loyer mensuel", "range": (0, 20_000)},
        {"name": "chargesAccessoires", "type": "float", "label": "Charges accessoires", "range": (0, 2_000)},
        {"name": "dateDebut", "type": "str", "label": "Date de début du bail", "range": None},
    ],
    DocumentType.lamal_statement: [
        {"name": "franchise", "type": "float", "label": "Franchise annuelle", "range": (0, 2_500)},
        {"name": "primeAnnuelle", "type": "float", "label": "Prime annuelle", "range": (0, 30_000)},
        {"name": "assureur", "type": "str", "label": "Assureur", "range": None},
    ],
    DocumentType.mortgage_attestation: [
        {"name": "montantHypotheque", "type": "float", "label": "Montant de l'hypothèque", "range": (0, 10_000_000)},
        {"name": "tauxInteret", "type": "float", "label": "Taux d'intérêt", "range": (0, 15)},
        {"name": "valeurImmeuble", "type": "float", "label": "Valeur de l'immeuble", "range": (0, 50_000_000)},
        {"name": "dureeContrat", "type": "str", "label": "Durée du contrat", "range": None},
    ],
    DocumentType.other: [
        {"name": "description", "type": "str", "label": "Description du document", "range": None},
    ],
}


# ═══════════════════════════════════════════════════════════
#  LPP PLAN TYPE DETECTION (DOC-04)
# ═══════════════════════════════════════════════════════════

_PLAN_TYPE_PROMPT = (
    "Avant d'extraire les champs financiers, identifie le type de plan LPP: "
    "legal (minimum LPP, taux 6.8%), surobligatoire (plan enveloppant), "
    "ou 1e (investissement individuel, AUCUN taux fixe contractuellement). "
    "Indices 1e: mention 'plan 1e', pas de taux fixe, "
    "'strategies d'investissement', suroblig >> oblig avec choix de fonds. "
    'JSON: {"plan_type": "legal|surobligatoire|1e", "confidence": "high|medium|low"}'
)

_1E_WARNING = (
    "Plan 1e detecte. Aucun taux de conversion fixe contractuellement "
    "-- projection en capital uniquement."
)


def detect_lpp_plan_type(
    image_base64: str,
) -> tuple:
    """Detect LPP plan type before extraction (DOC-04).

    Sends a lightweight Claude Vision call focused on plan type classification.
    On error, defaults to surobligatoire (safest middle ground).

    Args:
        image_base64: Base64-encoded document image.

    Returns:
        Tuple of (LppPlanType, ConfidenceLevel).
    """
    api_key = settings.ANTHROPIC_API_KEY
    if not api_key:
        logger.warning("No API key for plan type detection, defaulting to surobligatoire")
        return (LppPlanType.surobligatoire, ConfidenceLevel.low)

    try:
        client = Anthropic(api_key=api_key)
        response = client.messages.create(
            model=settings.COACH_MODEL,
            max_tokens=200,
            timeout=15.0,
            messages=[
                {
                    "role": "user",
                    "content": [
                        _build_vision_content_block(image_base64),
                        {
                            "type": "text",
                            "text": _PLAN_TYPE_PROMPT,
                        },
                    ],
                }
            ],
        )

        raw_text = response.content[0].text
        parsed = json.loads(raw_text)

        plan_type_str = parsed.get("plan_type", "surobligatoire")
        confidence_str = parsed.get("confidence", "medium")

        # Map to enum
        try:
            plan_type = LppPlanType(plan_type_str)
        except ValueError:
            plan_type = LppPlanType.surobligatoire

        try:
            confidence = ConfidenceLevel(confidence_str)
        except ValueError:
            confidence = ConfidenceLevel.medium

        return (plan_type, confidence)

    except Exception as e:
        logger.warning("Plan type detection failed, defaulting to surobligatoire: %s", e)
        return (LppPlanType.surobligatoire, ConfidenceLevel.low)


# ═══════════════════════════════════════════════════════════
#  CROSS-FIELD COHERENCE VALIDATION (DOC-05)
# ═══════════════════════════════════════════════════════════


def validate_lpp_coherence(
    fields: TList[ExtractedFieldConfirmation],
) -> TList[str]:
    """Validate cross-field coherence for LPP certificates (DOC-05).

    Checks that avoirLppObligatoire + avoirLppSurobligatoire ~ avoirLppTotal
    within 5% tolerance. Detects 10x hallucination errors.

    Args:
        fields: List of extracted field confirmations.

    Returns:
        List of warning messages (empty if coherent).
    """
    warnings: TList[str] = []

    # Find the three relevant fields
    field_map = {f.field_name: f for f in fields}
    oblig_f = field_map.get("avoirLppObligatoire")
    suroblig_f = field_map.get("avoirLppSurobligatoire")
    total_f = field_map.get("avoirLppTotal")

    # Can't validate if any field missing
    if not all([oblig_f, suroblig_f, total_f]):
        return warnings

    oblig = float(oblig_f.value) if isinstance(oblig_f.value, (int, float)) else None
    suroblig = float(suroblig_f.value) if isinstance(suroblig_f.value, (int, float)) else None
    total = float(total_f.value) if isinstance(total_f.value, (int, float)) else None

    if oblig is None or suroblig is None or total is None:
        return warnings

    expected = oblig + suroblig

    if total == 0 and expected == 0:
        return warnings

    # 10x error detection
    if expected > 0 and (total > 5 * expected or total < 0.2 * expected):
        warnings.append(
            "Possible erreur 10x detectee. Le total semble disproportionne."
        )

    # 5% tolerance check
    if total > 0:
        deviation = abs(expected - total) / total
        if deviation > 0.05:
            warnings.append(
                f"Les montants obligatoire ({oblig:,.0f}) et surobligatoire "
                f"({suroblig:,.0f}) ne correspondent pas au total ({total:,.0f}). "
                "Verifie les valeurs."
            )

    # Downgrade confidence if coherence fails
    if warnings:
        for f in [oblig_f, suroblig_f, total_f]:
            f.confidence = ConfidenceLevel.low

    return warnings


def _build_extraction_prompt(doc_type: DocumentType, canton: Optional[str], lang: Optional[str]) -> str:
    """Build the system prompt for Claude Vision extraction."""
    fields = DOCUMENT_FIELDS.get(doc_type, [])
    field_list = "\n".join(
        f"- {f['name']}: {f['label']} (type: {f['type']}, range: {f['range']})"
        for f in fields
    )

    lang_hint = f"Le document est probablement en {'français' if lang == 'fr' else 'allemand' if lang == 'de' else 'italien' if lang == 'it' else 'français ou allemand'}."
    canton_hint = f"Canton du client: {canton}." if canton else ""

    return f"""Tu es un extracteur de documents financiers suisses.

Analyse ce document de type: {doc_type.value}
{lang_hint}
{canton_hint}

Extrais les champs suivants si visibles dans le document:
{field_list}

Règles:
- Si un champ n'est pas visible, ne l'invente PAS. Omets-le.
- Les montants sont en CHF sauf indication contraire.
- Les pourcentages doivent être en décimal (6.8% → 0.068).
- Pour les dates, utilise le format ISO (YYYY-MM-DD).
- Indique la confiance pour chaque champ: "high", "medium", "low".

Réponds UNIQUEMENT en JSON valide, sans texte autour:
{{
  "fields": [
    {{"name": "avoirLppTotal", "value": 350000.00, "confidence": "high", "source_text": "Avoir de vieillesse total: CHF 350'000.00"}},
    ...
  ],
  "analysis": "Certificat LPP de la caisse XYZ, daté du 01.01.2026. Plan complet avec surobligatoire."
}}"""


def extract_with_vision(
    image_base64: str,
    doc_type: DocumentType,
    canton: Optional[str] = None,
    language_hint: Optional[str] = None,
) -> VisionExtractionResponse:
    """Extract structured data from a document image using Claude Vision.

    Args:
        image_base64: Base64-encoded document (JPEG, PNG, or PDF).
        doc_type: Expected document type (guides extraction).
        canton: User's canton (contextualizes fiscal documents).
        language_hint: Expected language (fr/de/it).

    Returns:
        VisionExtractionResponse with extracted fields and confidence.

    Raises:
        ValueError: If API key is missing or image is invalid.
    """
    api_key = settings.ANTHROPIC_API_KEY
    if not api_key:
        raise ValueError("ANTHROPIC_API_KEY not configured")

    # DOC-04: Detect LPP plan type BEFORE extraction
    detected_plan_type = None
    plan_type_warning = None
    if doc_type == DocumentType.lpp_certificate:
        detected_plan_type, _pt_confidence = detect_lpp_plan_type(image_base64)
        if detected_plan_type == LppPlanType.plan_1e:
            plan_type_warning = _1E_WARNING

    client = Anthropic(api_key=api_key)

    # DOC-04: For 1e plans, remove tauxConversion from extraction fields
    if detected_plan_type == LppPlanType.plan_1e:
        # Build prompt without tauxConversion for 1e plans
        original_fields = DOCUMENT_FIELDS.get(doc_type, [])
        filtered_fields = [f for f in original_fields if f["name"] != "tauxConversion"]
        # Temporarily override for prompt building
        _saved = DOCUMENT_FIELDS.get(doc_type)
        DOCUMENT_FIELDS[doc_type] = filtered_fields
        system_prompt = _build_extraction_prompt(doc_type, canton, language_hint)
        DOCUMENT_FIELDS[doc_type] = _saved
    else:
        system_prompt = _build_extraction_prompt(doc_type, canton, language_hint)

    try:
        response = client.messages.create(
            model=settings.COACH_MODEL,
            max_tokens=2000,
            timeout=30.0,  # 30s timeout to prevent worker blocking
            system=system_prompt,
            messages=[
                {
                    "role": "user",
                    "content": [
                        _build_vision_content_block(image_base64),
                        {
                            "type": "text",
                            "text": "Extrais les données de ce document.",
                        },
                    ],
                }
            ],
        )

        raw_text = response.content[0].text
        # Parse JSON from response
        parsed = json.loads(raw_text)

        fields = []
        for f in parsed.get("fields", []):
            raw_source_text = f.get("source_text")
            field_confidence = ConfidenceLevel(f.get("confidence", "medium"))

            # DOC-09: Source text enforcement
            if not raw_source_text or not raw_source_text.strip():
                logger.warning(
                    "Field %s missing source_text -- forced to low confidence",
                    f["name"],
                )
                raw_source_text = "[non fourni par l'extraction]"
                field_confidence = ConfidenceLevel.low

            fields.append(ExtractedFieldConfirmation(
                field_name=f["name"],
                value=f["value"],
                confidence=field_confidence,
                source_text=raw_source_text,
            ))

        # Validate against known ranges
        valid_fields = _validate_fields(fields, doc_type)

        # DOC-05: Cross-field coherence for LPP certificates
        coherence_warnings: TList[str] = []
        if doc_type == DocumentType.lpp_certificate:
            coherence_warnings = validate_lpp_coherence(valid_fields)

        overall = _compute_overall_confidence(valid_fields)

        return VisionExtractionResponse(
            document_type=doc_type,
            extracted_fields=valid_fields,
            overall_confidence=overall,
            extraction_method="claude_vision",
            raw_analysis=parsed.get("analysis"),
            plan_type=detected_plan_type.value if detected_plan_type else None,
            plan_type_warning=plan_type_warning,
            coherence_warnings=coherence_warnings,
        )

    except json.JSONDecodeError as e:
        logger.warning("Claude Vision returned non-JSON: %s", e)
        return VisionExtractionResponse(
            document_type=doc_type,
            extracted_fields=[],
            overall_confidence=0.0,
            extraction_method="claude_vision",
            raw_analysis=f"JSON parse error: {e}",
        )
    except Exception as e:
        logger.error("Claude Vision extraction failed: %s", e)
        raise


def _validate_fields(
    fields: list[ExtractedFieldConfirmation],
    doc_type: DocumentType,
) -> list[ExtractedFieldConfirmation]:
    """Validate extracted values against Swiss legal ranges."""
    specs = {f["name"]: f for f in DOCUMENT_FIELDS.get(doc_type, [])}
    valid = []

    for field in fields:
        spec = specs.get(field.field_name)
        if spec is None:
            # Unknown field — keep but downgrade confidence
            valid.append(field.model_copy(update={"confidence": ConfidenceLevel.low}))
            continue

        if spec["range"] is not None and isinstance(field.value, (int, float)):
            lo, hi = spec["range"]
            if not (lo <= float(field.value) <= hi):
                logger.warning(
                    "Field %s value %s outside range [%s, %s] — downgraded to low",
                    field.field_name, field.value, lo, hi,
                )
                valid.append(field.model_copy(update={"confidence": ConfidenceLevel.low}))
                continue

        valid.append(field)

    return valid


def _compute_overall_confidence(fields: list[ExtractedFieldConfirmation]) -> float:
    """Compute overall confidence from individual field confidences."""
    if not fields:
        return 0.0
    weights = {"high": 1.0, "medium": 0.6, "low": 0.25}
    total = sum(weights.get(f.confidence.value, 0.5) for f in fields)
    return round(total / len(fields), 2)


# ═══════════════════════════════════════════════════════════
#  PRE-EXTRACTION CLASSIFICATION (DOC-10)
# ═══════════════════════════════════════════════════════════

_CLASSIFICATION_PROMPT = """Is this a Swiss financial document? Supported types: LPP certificate, salary certificate, 3a attestation, insurance policy, AVS extract, tax declaration, payslip, lease contract, mortgage attestation, LAMal statement.

Respond ONLY with valid JSON:
{"is_financial": true, "detected_type": "lpp_certificate", "confidence": "high"}

If the image is NOT a Swiss financial document (e.g. receipt, selfie, landscape photo), respond:
{"is_financial": false, "detected_type": "description_of_what_it_is", "confidence": "high"}"""


def classify_document(image_base64: str) -> DocumentClassificationResult:
    """Classify whether an image is a Swiss financial document before extraction.

    Uses Claude Vision with a lightweight classification prompt (NOT full extraction).
    Fails open on API errors: returns is_financial=True so legitimate users are not blocked.

    Args:
        image_base64: Base64-encoded image data.

    Returns:
        DocumentClassificationResult with is_financial, detected_type, confidence.
    """
    api_key = settings.ANTHROPIC_API_KEY
    if not api_key:
        # Fail open — don't block user if API key missing
        logger.warning("ANTHROPIC_API_KEY not configured for classification, failing open")
        return DocumentClassificationResult(
            is_financial=True,
            confidence=ConfidenceLevel.low,
        )

    try:
        client = Anthropic(api_key=api_key)
        response = client.messages.create(
            model=settings.COACH_MODEL,
            max_tokens=200,
            timeout=15.0,  # Lightweight call — shorter timeout
            messages=[
                {
                    "role": "user",
                    "content": [
                        _build_vision_content_block(image_base64),
                        {
                            "type": "text",
                            "text": _CLASSIFICATION_PROMPT,
                        },
                    ],
                }
            ],
        )

        raw_text = response.content[0].text
        parsed = json.loads(raw_text)

        is_financial = bool(parsed.get("is_financial", False))
        detected_type = parsed.get("detected_type")
        confidence_str = parsed.get("confidence", "medium")

        # Map confidence string to enum
        try:
            confidence = ConfidenceLevel(confidence_str)
        except ValueError:
            confidence = ConfidenceLevel.medium

        rejection_reason = None
        if not is_financial:
            rejection_reason = (
                f"Document identifie comme '{detected_type}' — "
                "pas un document financier suisse reconnu."
            )

        return DocumentClassificationResult(
            is_financial=is_financial,
            detected_type=detected_type,
            confidence=confidence,
            rejection_reason=rejection_reason,
        )

    except json.JSONDecodeError as e:
        # Malformed JSON — fail open
        logger.warning("Classification returned non-JSON: %s", e)
        return DocumentClassificationResult(
            is_financial=True,
            confidence=ConfidenceLevel.low,
        )
    except Exception as e:
        # API error — fail open (T-02-05)
        logger.warning("Document classification failed, failing open: %s", e)
        return DocumentClassificationResult(
            is_financial=True,
            confidence=ConfidenceLevel.low,
        )
