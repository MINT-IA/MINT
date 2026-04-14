"""Claude Vision document extraction service.

Replaces/augments MLKit OCR with Claude Vision for Swiss financial documents.
Handles: LPP certificates, tax declarations, AVS extracts, salary certs,
payslips, lease contracts, LPP plans, insurance contracts.

Pure function pattern — no side effects, deterministic prompt, testable.

See: MINT_ANTI_BULLSHIT_MANIFESTO.md, MINT_FINAL_EXECUTION_SYSTEM.md §13.11
"""

import json
import logging
import re
from typing import Dict, List as TList, Optional


_MARKDOWN_FENCE_RE = re.compile(r"```(?:json)?\s*(.*?)\s*```", re.DOTALL)


def _strip_markdown_fences(raw_text: str) -> str:
    """Claude occasionally wraps JSON in ```json ... ``` fences despite the
    prompt asking for raw JSON. json.loads then fails silently and the
    endpoint returns 0 fields. Strip the fence before parsing.
    """
    stripped = (raw_text or "").strip()
    if not stripped.startswith("```"):
        return raw_text
    match = _MARKDOWN_FENCE_RE.search(stripped)
    return match.group(1) if match else raw_text

from anthropic import Anthropic, AsyncAnthropic

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
        # Parse JSON from response. Claude occasionally returns the JSON
        # wrapped in ```json ... ``` fences even though the prompt asks
        # for raw JSON — strip them before decoding.
        cleaned_text = _strip_markdown_fences(raw_text)
        try:
            parsed = json.loads(cleaned_text)
        except json.JSONDecodeError as e:
            # P1 DIAG: log the raw preview so prod tells us WHY extraction
            # returned 0 fields (was it refusal, wrong shape, code fence?).
            logger.warning(
                "Vision extraction: JSON parse failed doc_type=%s err=%s raw=%r",
                doc_type, e, (raw_text or "")[:500],
            )
            return VisionExtractionResponse(
                document_type=doc_type,
                extracted_fields=[],
                overall_confidence=0.0,
                extraction_method="claude_vision",
                raw_analysis=f"JSON parse error: {e}",
                extraction_status="parse_error",
            )

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

        # P1 DIAG: surface the two silent-failure modes in prod.
        # (a) Claude returned no fields at all.
        if not fields:
            logger.warning(
                "Vision extraction: Claude returned 0 fields doc_type=%s "
                "parsed_keys=%s raw_analysis=%r",
                doc_type, list(parsed.keys()),
                (parsed.get("analysis") or "")[:200],
            )
        # (b) Claude returned fields but validation stripped them all.
        elif fields and not valid_fields:
            logger.warning(
                "Vision extraction: all %d fields rejected by _validate_fields "
                "doc_type=%s fields=%s",
                len(fields), doc_type,
                [(f.field_name, f.value, f.confidence.value) for f in fields],
            )

        # DOC-05: Cross-field coherence for LPP certificates
        coherence_warnings: TList[str] = []
        if doc_type == DocumentType.lpp_certificate:
            coherence_warnings = validate_lpp_coherence(valid_fields)

        overall = _compute_overall_confidence(valid_fields)

        # Classify the outcome so Flutter can show a targeted error
        # instead of silently rendering an empty form. The endpoint stays
        # HTTP 200 — breaking the flow with 4xx would cost UX — but the
        # status field tells the client exactly which failure mode hit.
        if not valid_fields:
            if not fields:
                extraction_status = "no_fields_found"
            else:
                extraction_status = "partial"  # all fields rejected by validation
        elif len(valid_fields) < len(fields):
            extraction_status = "partial"
        else:
            extraction_status = "success"

        return VisionExtractionResponse(
            document_type=doc_type,
            extracted_fields=valid_fields,
            overall_confidence=overall,
            extraction_method="claude_vision",
            raw_analysis=parsed.get("analysis"),
            plan_type=detected_plan_type.value if detected_plan_type else None,
            plan_type_warning=plan_type_warning,
            coherence_warnings=coherence_warnings,
            extraction_status=extraction_status,
        )

    except json.JSONDecodeError as e:
        logger.warning("Claude Vision returned non-JSON: %s", e)
        return VisionExtractionResponse(
            document_type=doc_type,
            extracted_fields=[],
            overall_confidence=0.0,
            extraction_method="claude_vision",
            raw_analysis=f"JSON parse error: {e}",
            extraction_status="parse_error",
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


# ═══════════════════════════════════════════════════════════════════════════
#  v2.7 PHASE 28 — Fused understand_document() (DOC-01..05, DOC-08)
# ═══════════════════════════════════════════════════════════════════════════

import base64 as _b64
from typing import Any as _Any

from app.schemas.document_understanding import (
    CommitmentSuggestion as _CommitmentSuggestion,
    ConfidenceLevel as _ConfidenceLevel,
    CoherenceWarning as _CoherenceWarning,
    DocumentClass as _DocumentClass,
    DocumentUnderstandingResult as _DUR,
    ExtractedField as _EF,
    ExtractionStatus as _ES,
    FieldStatus as _FS,
    RenderMode as _RM,
)
from app.services import idempotency as _idempotency
from app.services.document_pdf_preflight import (
    preflight_pdf as _preflight_pdf,
    select_pages_for_vision as _select_pages,
)
from app.services.document_render_mode import select_render_mode as _select_render_mode
from app.services.document_third_party import (
    detect_third_party as _detect_third_party,
    load_issuer_signatures as _load_signatures,
)
from app.services.document_memory_service import (
    compute_fingerprint as _compute_fingerprint,
    upsert_and_diff as _upsert_and_diff,
)


# ── tool_use schema (single fused tool) ───────────────────────────────────

ROUTE_AND_EXTRACT_TOOL: dict = {
    "name": "route_and_extract",
    "description": (
        "Classify the Swiss financial document AND extract its fields in a "
        "single call. Always set extraction_status. If the document is not "
        "financial, set document_class='non_financial' and explain in summary."
    ),
    "input_schema": {
        "type": "object",
        "properties": {
            "document_class": {
                "type": "string",
                "enum": [c.value for c in _DocumentClass],
            },
            "subtype": {"type": ["string", "null"]},
            "issuer_guess": {"type": ["string", "null"]},
            "classification_confidence": {"type": "number", "minimum": 0, "maximum": 1},
            "extracted_fields": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "field_name": {"type": "string"},
                        "value": {},  # any
                        "confidence": {"type": "string", "enum": ["high", "medium", "low"]},
                        "source_text": {"type": "string"},
                    },
                    "required": ["field_name", "confidence", "source_text"],
                },
            },
            "overall_confidence": {"type": "number", "minimum": 0, "maximum": 1},
            "extraction_status": {
                "type": "string",
                "enum": [s.value for s in _ES],
            },
            "summary": {"type": ["string", "null"]},
            "questions_for_user": {
                "type": "array",
                "items": {"type": "string"},
                "maxItems": 3,
            },
            "narrative": {"type": ["string", "null"]},
            "commitment_suggestion": {
                "type": ["object", "null"],
                "properties": {
                    "when": {"type": ["string", "null"]},
                    "where": {"type": ["string", "null"]},
                    "if_then": {"type": ["string", "null"]},
                    "action_label": {"type": ["string", "null"]},
                },
            },
            "plan_type": {"type": ["string", "null"]},
            "plan_type_warning": {"type": ["string", "null"]},
        },
        "required": ["document_class", "classification_confidence", "overall_confidence"],
    },
}


# ── helpers ───────────────────────────────────────────────────────────────

def _build_fused_system_prompt(
    canton: Optional[str], lang: Optional[str], archetype: Optional[str],
) -> str:
    sigs = _load_signatures().get("issuers", [])
    vignettes = "\n".join(
        f"- {i['name']}: {', '.join(i.get('keywords', [])[:3])} → {', '.join(i.get('document_classes', []))}"
        for i in sigs[:5]
    )
    archetype_hint = ""
    if archetype == "expat_us":
        archetype_hint = (
            "\nUser is US-tagged (FATCA): if foreign mutual fund mentioned outside "
            "2nd pillar, flag PFIC concern in summary."
        )
    elif archetype == "cross_border":
        archetype_hint = (
            "\nUser is frontalier: flag impôt source if salary cert from CH employer."
        )
    elif archetype == "independent_no_lpp":
        archetype_hint = (
            "\nUser is independent without LPP: 3a annual cap is 20% net income, max 36'288."
        )

    canton_hint = f"User canton: {canton}." if canton else ""
    lang_hint = (
        f"Reply in {lang}." if lang in ("fr", "de", "it", "en")
        else "Reply in French (default UI language)."
    )
    return f"""Tu es l'extracteur canonique de documents financiers suisses pour MINT.

UNE seule fonction tool est disponible: route_and_extract. Tu DOIS l'appeler.
Classification + extraction en un seul appel. Pas de double routing.

Issuers connus (vignettes):
{vignettes}

Règles:
- document_class ∈ enum strict (lpp_certificate, salary_certificate, ...).
- Si le document n'est pas financier suisse → document_class='non_financial',
  extraction_status='non_financial', extracted_fields=[], summary explique.
- Si tu ne peux pas extraire → extraction_status='no_fields_found' ou 'parse_error',
  fournis un narrative court qui dit ce que tu vois SANS inventer de chiffres.
- summary: 1 phrase, traduction humaine. JAMAIS "garanti", "optimal", "meilleur",
  "conseiller". Préfère "spécialiste".
- questions_for_user: max 3, formulées comme dialogue (tu, informel).
- Confiance par champ ('high'/'medium'/'low') basée sur lisibilité, pas sur
  ce que tu "penses" être correct.
- Pourcentages en décimal (6.8% → 0.068).
- Montants en CHF (sauf indication contraire), pas de séparateur de milliers.

{canton_hint}{archetype_hint}
{lang_hint}
"""


def _build_vision_block_v2(file_bytes: bytes) -> dict:
    """Build the Anthropic content block for image or PDF given raw bytes."""
    is_pdf = file_bytes[:4] == b"%PDF"
    b64 = _b64.b64encode(file_bytes).decode("ascii")
    if is_pdf:
        return {
            "type": "document",
            "source": {"type": "base64", "media_type": "application/pdf", "data": b64},
        }
    media_type = "image/png" if file_bytes[:4] == b"\x89PNG" else "image/jpeg"
    return {
        "type": "image",
        "source": {"type": "base64", "media_type": media_type, "data": b64},
    }


def _ti_to_result(tool_input: dict, usage: _Any) -> _DUR:
    """Map tool_use input → DocumentUnderstandingResult."""
    fields = []
    for f in (tool_input.get("extracted_fields") or []):
        try:
            conf = _ConfidenceLevel(f.get("confidence", "medium"))
        except Exception:
            conf = _ConfidenceLevel.medium
        fields.append(_EF(
            field_name=f.get("field_name", ""),
            value=f.get("value"),
            confidence=conf,
            source_text=f.get("source_text", "") or "",
        ))

    try:
        doc_cls = _DocumentClass(tool_input.get("document_class", "unknown"))
    except Exception:
        doc_cls = _DocumentClass.unknown

    status_str = tool_input.get("extraction_status")
    if not status_str:
        if doc_cls == _DocumentClass.non_financial:
            status_str = "non_financial"
        elif fields:
            status_str = "success"
        else:
            status_str = "no_fields_found"
    try:
        status = _ES(status_str)
    except Exception:
        status = _ES.no_fields_found

    cs = tool_input.get("commitment_suggestion")
    commitment = _CommitmentSuggestion(**cs) if isinstance(cs, dict) else None

    tokens_in = int(getattr(usage, "input_tokens", 0) or 0)
    tokens_out = int(getattr(usage, "output_tokens", 0) or 0)

    return _DUR(
        document_class=doc_cls,
        subtype=tool_input.get("subtype"),
        issuer_guess=tool_input.get("issuer_guess"),
        classification_confidence=float(tool_input.get("classification_confidence", 0.0) or 0.0),
        extracted_fields=fields,
        overall_confidence=float(tool_input.get("overall_confidence", 0.0) or 0.0),
        extraction_status=status,
        summary=tool_input.get("summary"),
        questions_for_user=list(tool_input.get("questions_for_user") or [])[:3],
        narrative=tool_input.get("narrative"),
        commitment_suggestion=commitment,
        plan_type=tool_input.get("plan_type"),
        plan_type_warning=tool_input.get("plan_type_warning"),
        render_mode=_RM.narrative,  # placeholder, overwritten by selector
        cost_tokens_in=tokens_in,
        cost_tokens_out=tokens_out,
    )


def _build_acroform_result(pre: dict) -> _DUR:
    """Construct a DocumentUnderstandingResult from an AcroForm preflight."""
    fields = [
        _EF(
            field_name=name,
            value=value,
            confidence=_ConfidenceLevel.high,  # PDF form values are exact
            source_text=f"AcroForm field: {name}",
        )
        for name, value in (pre.get("acroform_fields") or {}).items()
    ]
    return _DUR(
        document_class=_DocumentClass.unknown,
        classification_confidence=0.5,
        extracted_fields=fields,
        overall_confidence=0.95 if fields else 0.0,
        extraction_status=_ES.success if fields else _ES.no_fields_found,
        summary="Formulaire PDF lu directement (sans IA)." if fields else None,
        render_mode=_RM.confirm,
        pages_processed=pre.get("page_count"),
        pages_total=pre.get("page_count"),
        cost_tokens_in=0,
        cost_tokens_out=0,
    )


def _build_encrypted_result(pre: dict) -> _DUR:
    return _DUR(
        document_class=_DocumentClass.unknown,
        classification_confidence=0.0,
        extracted_fields=[],
        overall_confidence=0.0,
        extraction_status=_ES.encrypted_needs_password,
        summary=(
            "Ce PDF est protégé par un mot de passe. "
            "Colle-le ici si tu veux que je le lise — je ne le stocke pas."
        ),
        render_mode=_RM.narrative,
        pages_processed=0,
        pages_total=pre.get("page_count"),
        pdf_warning="encrypted_needs_password",
        cost_tokens_in=0,
        cost_tokens_out=0,
    )


def _scrub_compliance_text(text: Optional[str]) -> Optional[str]:
    """Strip banned terms from free-text fields before returning to user.

    ComplianceGuard.validate() expects a CoachContext we don't have here.
    We use the lower-level _sanitize_banned_terms() which is the same Layer
    1 sanitisation applied to coach output (covers garanti/optimal/conseiller
    + inflections + GUARANTEE_REPLACEMENTS).
    """
    if not text:
        return text
    try:
        from app.services.coach.compliance_guard import ComplianceGuard
        guard = ComplianceGuard()
        return guard._sanitize_banned_terms(text)  # noqa: SLF001 — intended internal use
    except Exception as exc:
        logger.warning("compliance scrub failed err=%s", exc)
        return text


async def _call_fused_vision(
    file_bytes: bytes,
    pre: Optional[dict],
    canton: Optional[str],
    lang: Optional[str],
    archetype: Optional[str],
) -> _DUR:
    """Single Anthropic call — tool_use forced + extended thinking budget."""
    api_key = settings.ANTHROPIC_API_KEY
    if not api_key:
        raise ValueError("ANTHROPIC_API_KEY not configured")

    # Page selection for scanned/long PDFs — keep the bytes for now (Anthropic
    # PDF block accepts the full file; selection is informational for
    # downstream cost analysis until we wire per-page extraction).
    pages_processed: Optional[int] = None
    pages_total: Optional[int] = None
    pdf_warning: Optional[str] = None
    if pre is not None:
        pages_total = pre.get("page_count")
        if pre.get("status") == "scanned" or (pages_total or 0) > 4:
            try:
                chosen = _select_pages(file_bytes, max_pages=3)
                pages_processed = len(chosen)
                if pages_total and pages_processed < pages_total:
                    pdf_warning = (
                        f"PDF long ({pages_total} pages) — j'ai lu les "
                        f"{pages_processed} pages clés."
                    )
            except Exception:
                pages_processed = pages_total
        else:
            pages_processed = pages_total

    client = AsyncAnthropic(api_key=api_key)
    response = await client.messages.create(
        model=settings.COACH_MODEL,
        max_tokens=3000,
        thinking={"type": "enabled", "budget_tokens": 1024},
        tools=[ROUTE_AND_EXTRACT_TOOL],
        tool_choice={"type": "tool", "name": "route_and_extract"},
        system=_build_fused_system_prompt(canton, lang, archetype),
        messages=[{
            "role": "user",
            "content": [
                _build_vision_block_v2(file_bytes),
                {"type": "text", "text": "Route and extract."},
            ],
        }],
    )

    # Find tool_use block
    tool_input: dict = {}
    for block in response.content:
        if getattr(block, "type", None) == "tool_use":
            tool_input = getattr(block, "input", {}) or {}
            break

    result = _ti_to_result(tool_input, response.usage)
    if pages_processed is not None:
        result.pages_processed = pages_processed
    if pages_total is not None:
        result.pages_total = pages_total
    if pdf_warning is not None:
        result.pdf_warning = pdf_warning
    return result


async def understand_document(
    file_bytes: bytes,
    *,
    user_id: str,
    canton: Optional[str] = None,
    lang: Optional[str] = None,
    profile_archetype: Optional[str] = None,
    profile_first_name: Optional[str] = None,
    profile_last_name: Optional[str] = None,
    partner_first_name: Optional[str] = None,
    file_sha: Optional[str] = None,
    db=None,
) -> _DUR:
    """Fused classify+extract entrypoint behind DOCUMENTS_V2_ENABLED.

    Returns the canonical DocumentUnderstandingResult with render_mode
    computed by the deterministic selector. Side-effects:
        - file_sha-keyed idempotency cache (24h)
        - DocumentMemory upsert + diff (when db provided)
        - TokenBudget consume (kind='vision')
        - ComplianceGuard scrub on summary/narrative/questions_for_user
    """
    # 1. Idempotency lookup by file SHA
    if file_sha:
        cached = await _idempotency.lookup_by_file_sha(file_sha)
        if cached is not None:
            try:
                return _DUR.model_validate(cached)
            except Exception as exc:
                logger.warning("idempotency: cached payload invalid err=%s", exc)

    # 2. PDF preflight (if PDF)
    is_pdf = file_bytes[:4] == b"%PDF"
    pre: Optional[dict] = _preflight_pdf(file_bytes) if is_pdf else None

    # 3. Branch routing
    if pre is not None and pre.get("status") == "encrypted_needs_password":
        result = _build_encrypted_result(pre)
    elif pre is not None and pre.get("status") == "acroform":
        result = _build_acroform_result(pre)
    else:
        result = await _call_fused_vision(
            file_bytes, pre, canton, lang, profile_archetype,
        )

    # 4. LPP coherence (compat with legacy validator on a list of EF-shaped objs)
    if result.document_class == _DocumentClass.lpp_certificate and result.extracted_fields:
        try:
            # Build minimal ExtractedFieldConfirmation-compatible objects
            compat = [
                ExtractedFieldConfirmation(
                    field_name=f.field_name,
                    value=f.value,
                    confidence=f.confidence,
                    source_text=f.source_text,
                )
                for f in result.extracted_fields
            ]
            warns = validate_lpp_coherence(compat)
            if warns:
                result.coherence_warnings = [
                    _CoherenceWarning(code="lpp_coherence", message=w, fields=[])
                    for w in warns
                ]
        except Exception as exc:
            logger.warning("LPP coherence v2 failed err=%s", exc)

    # 5a. NumericSanity — deterministic bounds on extracted values (Phase 29-04 / PRIV-05).
    #     Runs BEFORE the LLM judge because it is free and catches the crudest
    #     prompt-injection values ("rendement 50%"). Rejects force render=reject.
    try:
        from app.services.compliance import numeric_sanity as _ns

        verdict = _ns.check(result.extracted_fields)
        if verdict.rejects:
            result.sanity_rejected_fields = [r.field_name for r in verdict.rejects]
            # Mark the offending fields as rejected so callers can highlight them.
            reject_names = set(result.sanity_rejected_fields)
            for f in result.extracted_fields:
                if f.field_name in reject_names:
                    f.status = _FS.rejected
            # Convert the whole document to reject render mode with an explicit
            # reason. The summary becomes the top-most bound violated so the
            # user knows why MINT refused the number.
            primary = verdict.rejects[0]
            result.render_mode = _RM.reject
            result.extraction_status = _ES.parse_error if result.extraction_status == _ES.success else result.extraction_status
            result.summary = (
                f"MINT a refuse une valeur impossible — {primary.bound}. "
                "Ouvre le document original et verifie."
            )
            result.pdf_warning = "numeric_sanity_reject"
        if verdict.human_reviews:
            result.sanity_human_review_fields = [r.field_name for r in verdict.human_reviews]
            hr_names = set(result.sanity_human_review_fields)
            for f in result.extracted_fields:
                if f.field_name in hr_names:
                    f.human_review_flag = True
    except Exception as exc:
        logger.warning("numeric_sanity check failed err=%s", exc)

    # 5b. Render mode (deterministic selector) — unless already forced to reject above.
    if result.render_mode != _RM.reject:
        result.render_mode = _select_render_mode(result)

    # 6. Document Memory upsert + diff
    if db is not None and result.extraction_status == _ES.success:
        try:
            diff = _upsert_and_diff(db, user_id, result)
            result.diff_from_previous = diff
            result.fingerprint = _compute_fingerprint(
                result.document_class.value, result.issuer_guess, None,
            )
        except Exception as exc:
            logger.warning("document_memory upsert failed err=%s", exc)

    # 7. Third-party detection (silent flag)
    try:
        flagged, name = _detect_third_party(
            result, profile_first_name, profile_last_name, partner_first_name,
        )
        result.third_party_detected = flagged
        result.third_party_name = name
    except Exception as exc:
        logger.warning("third-party detection failed err=%s", exc)

    # 8a. PII pre-scrub (Phase 29-03 pii_scrubber) — strip IBAN/AVS/phone/
    #     employer names from Vision free text BEFORE the judge sees it.
    #     The judge still gets enough context to evaluate compliance, but
    #     never receives raw PII even in transit.
    try:
        from app.services.privacy.pii_scrubber import scrub as _pii_scrub

        result.summary = _pii_scrub(result.summary) if result.summary else result.summary
        result.narrative = _pii_scrub(result.narrative) if result.narrative else result.narrative
        result.questions_for_user = [
            _pii_scrub(q) if q else q for q in result.questions_for_user
        ]
    except Exception as exc:
        logger.warning("pii_scrubber failed err=%s", exc)

    # 8b. Coach banned-term Layer 1 — cheap static pass before the LLM judge.
    result.summary = _scrub_compliance_text(result.summary)
    result.narrative = _scrub_compliance_text(result.narrative)
    result.questions_for_user = [
        _scrub_compliance_text(q) or q for q in result.questions_for_user
    ]

    # 8c. VisionGuard — LLM-as-judge on critical outputs (PRIV-05).
    #     Skip when nothing critical to judge OR when rendering a reject
    #     (the document is already blocked; judging adds cost with no benefit).
    if result.render_mode != _RM.reject and (result.summary or result.narrative):
        try:
            from app.services.compliance import vision_guard as _vg

            fields_summary = ", ".join(
                f"{f.field_name}={f.value}"
                for f in result.extracted_fields[:5]
                if f.value is not None
            )
            verdict = await _vg.judge_vision_output(
                summary=result.summary,
                narrative=result.narrative,
                fields_summary=fields_summary or None,
            )
            result.guard_cost_usd = verdict.cost_usd
            result.guard_flagged_categories = list(verdict.flagged_categories)
            result.guard_reason = verdict.reason
            if not verdict.allow:
                result.guard_blocked = True
                # Replace the salient free-text outputs with the judge's
                # reformulation (or canonical safe fallback). Keep the raw
                # fields intact — the user still sees the validated numbers.
                safe_text = verdict.reformulation or (
                    "MINT n'a pas pu resumer ce document de maniere educative. "
                    "Voici les chiffres bruts validés."
                )
                result.summary = safe_text
                # Narrative is dropped on block; the BatchValidationBubble
                # handles the user-facing dialogue instead.
                result.narrative = None
        except Exception as exc:
            # Fail-closed on unexpected error — strip the free text so a
            # potentially non-compliant output never reaches the user.
            logger.warning("vision_guard failed — fail-closed err=%s", exc)
            result.guard_blocked = True
            result.guard_reason = "judge_unavailable"
            result.summary = (
                "MINT n'a pas pu valider ce resume — voici les chiffres bruts."
            )
            result.narrative = None

    # 8d. Runtime no-auto-confirm invariant (Phase 29-04 / PRIV-08).
    #     Regardless of classifier confidence, every field persists as
    #     needs_review. Only user interaction (tap / swipe on the
    #     BatchValidationBubble) promotes to user_validated or corrected_by_user.
    for f in result.extracted_fields:
        if f.status not in (
            _FS.rejected,
            _FS.user_validated,
            _FS.corrected_by_user,
            _FS.human_review,
        ):
            f.status = _FS.needs_review

    # 9. Token budget consume (Vision tokens count too — STAB-04 reuse)
    try:
        from app.services.coach.token_budget import TokenBudget
        await TokenBudget().consume(
            user_id, result.cost_tokens_in + result.cost_tokens_out,
        )
    except Exception as exc:
        logger.warning("token_budget consume failed err=%s", exc)

    # 10. Idempotency store
    if file_sha:
        try:
            await _idempotency.store_by_file_sha(
                file_sha, result.model_dump(mode="json"),
            )
        except Exception as exc:
            logger.warning("idempotency store failed err=%s", exc)

    return result
