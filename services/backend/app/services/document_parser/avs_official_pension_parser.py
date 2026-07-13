"""Deterministic post-validator for official personal AVS pension evidence.

This parser is intentionally narrower than OCR or Vision.  It accepts only a
self-owned, authority-issued/calculated, explicitly monthly old-age pension
with an official issue/calculation date.  It returns an ephemeral review
candidate; it has no persistence dependency and performs no database write.

Sources: LAVS art. 21-40; official AVS/AI pension estimate/decision process.
"""

from __future__ import annotations

from datetime import datetime
import re

from app.services.document_parser.document_models import (
    DocumentType,
    ExtractedField,
    ExtractionResult,
)

_CANONICAL_KEY = "avs_official_monthly_pension"
_DISCLAIMER = (
    "Candidat extrait d'un document officiel a verifier avant tout enregistrement. "
    "Cet outil est educatif et ne constitue pas un conseil financier, fiscal ou juridique."
)
_SOURCES = [
    "LAVS art. 21-40 (rentes de vieillesse)",
    "AVS/AI 3.01 (rentes de vieillesse et allocations pour impotent de l'AVS)",
]

# Broad OCR sanity interval, deliberately not the statutory AVS pension scale.
# Partial pensions may be far below the full-pension minimum; the upper bound
# only catches order-of-magnitude OCR shifts before the mandatory review.
_MIN_TECHNICAL_MONTHLY_AMOUNT = 10.0
_MAX_TECHNICAL_MONTHLY_AMOUNT = 9_999.99

_AMOUNT_RE = re.compile(
    r"(?:CHF|Fr\.)\s*"
    r"(?P<amount>[0-9]{1,3}(?:['’ .][0-9]{3})*(?:[.,][0-9]{2})?|[0-9]{3,5})"
    r"(?:[.,]?[–-])?",
    re.IGNORECASE,
)

_AUTHORITY_RE = re.compile(
    r"(?:"
    r"caisse(?:\s+(?:cantonale|suisse))?\s+de\s+compensation|"
    r"(?:schweizerische\s+)?ausgleichskasse|"
    r"cassa(?:\s+(?:cantonale|svizzera))?\s+di\s+compensazione"
    r")",
    re.IGNORECASE,
)
_RESULT_MARKER_RE = re.compile(
    r"(?:"
    r"d[ée]cision|calcul\s+d['’]une\s+rente\s+future|[ée]tabli\s+le|"
    r"rentenverf[uü]gung|rentenvorausberechnung|ausgestellt\s+am|"
    r"decisione|calcolo\s+di\s+una\s+rendita\s+futura|emesso\s+il"
    r")",
    re.IGNORECASE,
)
_DECISION_MARKER_RE = re.compile(
    r"(?:\bd[ée]cision\b|rentenverf[uü]gung|\bdecisione\b)",
    re.IGNORECASE,
)
_FORECAST_MARKER_RE = re.compile(
    r"(?:"
    r"calcul\s+d['’]une\s+rente\s+future|estimation\s+de\s+rente|"
    r"calcul\s+anticip[ée]|pr[ée]vision(?:nel(?:le)?|s)?|"
    r"rentenvorausberechnung|rentensch[aä]tzung|"
    r"provisorisch(?:e[rsnm]?)?|voraussichtlich(?:e[rsnm]?)?|"
    r"calcolo\s+di\s+una\s+rendita\s+futura|stima(?:\s+della)?\s+rendita|"
    r"prevision(?:e|i|ale|ali)|previst[oaie]|calcolo\s+anticipato"
    r")",
    re.IGNORECASE,
)
_STATEMENT_MARKER_RE = re.compile(
    r"(?:"
    r"attestation\s+(?:de\s+)?(?:rente|paiement)|"
    r"actuellement\s+vers[ée]e?|montant\s+actuel(?:le)?|"
    r"rentenbescheinigung|zahlungsbest[aä]tigung|"
    r"aktuell(?:er|e|es|en)?\s+monatlich(?:er|e|es|en)?\s+betrag|"
    r"attestazione\s+(?:di\s+)?(?:rendita|pagamento)|rendita\s+attuale"
    r")",
    re.IGNORECASE,
)
_OLD_AGE_RE = re.compile(
    r"(?:rente[^.;]{0,80}vieillesse|altersrente|rendita[^.;]{0,80}vecchiaia)",
    re.IGNORECASE,
)
_MONTHLY_RE = re.compile(
    r"(?:mensuel(?:le)?|par\s+mois|/\s*mois|monatlich(?:e[rs]?)?|pro\s+monat|/\s*monat|mensile|al\s+mese|/\s*mese)",
    re.IGNORECASE,
)
_OWNER_RE = re.compile(
    r"(?:votre|vous\s+concernant|ihre(?:r|n)?|f[uü]r\s+sie|sua|per\s+lei)",
    re.IGNORECASE,
)

_DATE_PATTERNS = (
    re.compile(
        r"(?:date\s+de\s+la\s+d[ée]cision|date\s+du\s+calcul)\s*:\s*(\d{2}\.\d{2}\.\d{4})",
        re.IGNORECASE,
    ),
    re.compile(r"[ée]tabli\s+le\s+(\d{2}\.\d{2}\.\d{4})", re.IGNORECASE),
    re.compile(
        r"(?:verf[uü]gungsdatum|berechnungsdatum)\s*:\s*(\d{2}\.\d{2}\.\d{4})",
        re.IGNORECASE,
    ),
    re.compile(r"ausgestellt\s+am\s+(\d{2}\.\d{2}\.\d{4})", re.IGNORECASE),
    re.compile(
        r"(?:data\s+della\s+decisione|data\s+del\s+calcolo)\s*:\s*(\d{2}\.\d{2}\.\d{4})",
        re.IGNORECASE,
    ),
    re.compile(r"emesso\s+il\s+(\d{2}\.\d{2}\.\d{4})", re.IGNORECASE),
)

_EXCLUSIONS: tuple[tuple[str, re.Pattern[str]], ...] = (
    (
        "statutory_reference_value",
        re.compile(
            r"(?:rente\s+minimale|rente\s+maximale|rententabelle|"
            r"minimale\s+altersrente|maximale\s+altersrente|montants\s+20\d{2})",
            re.IGNORECASE,
        ),
    ),
    ("example_value", re.compile(r"\b(?:exemple|esempio|beispiel)\b", re.IGNORECASE)),
    (
        "generic_simulation_not_authority_result",
        re.compile(
            r"(?:\bESCAL\b|estimation\s+en\s+ligne|simulation\s+en\s+ligne|"
            r"donn[ée]es\s+saisies\s+librement)",
            re.IGNORECASE,
        ),
    ),
    (
        "couple_cap_or_150_percent",
        re.compile(r"(?:plafond[^.;]{0,80}couple|\b150\s*%|plafonamento|plafonierung)", re.IGNORECASE),
    ),
    (
        "couple_or_household_amount",
        re.compile(
            r"(?:rentes?\s+du\s+couple|renten\s+des\s+ehepaars|rendite\s+dei\s+coniugi|"
            r"total\s+mensuel[^.;]{0,40}couple|summe[^.;]{0,40}ehepaar|"
            r"totale\s+mensile[^.;]{0,40}coniugi)",
            re.IGNORECASE,
        ),
    ),
    (
        "annual_only_not_convertible",
        re.compile(r"(?:rente\s+annuelle|j[aä]hrliche\s+altersrente|rendita\s+annua|/\s*an|pro\s+jahr)", re.IGNORECASE),
    ),
    (
        "wrong_benefit_survivor",
        re.compile(r"(?:rente[^.;]{0,40}survivant|hinterlassenenrente|rendita[^.;]{0,40}superstit)", re.IGNORECASE),
    ),
    (
        "wrong_benefit_invalidity",
        re.compile(r"(?:rente[^.;]{0,40}invalidit[ée]|invalidenrente|rendita[^.;]{0,40}invalidit)", re.IGNORECASE),
    ),
    (
        "wrong_benefit_child",
        re.compile(r"(?:(?:rente|rendita)[^.;]{0,40}(?:enfant|figli)|kinderrente)", re.IGNORECASE),
    ),
    (
        "ci_extract_not_pension_decision",
        re.compile(
            r"(?:extrait\s+de\s+compte\s+individuel|individuellen\s+konto|"
            r"estratto\s+del\s+conto\s+individuale|\bCI\b[^.;]{0,50}cotisations|\bIK\b[^.;]{0,50}beitr[aä]ge)",
            re.IGNORECASE,
        ),
    ),
    (
        "application_not_authority_result",
        re.compile(r"(?:formular\s+318\.282|antrag[^.;]{0,80}rentenvorausberechnung|demande[^.;]{0,80}rente\s+future)", re.IGNORECASE),
    ),
)

_THIRD_PERSON_RE = re.compile(
    r"(?:conjoint|partenaire|partnerin|partner(?:s)?|coniuge|coniugi|ehepartner)",
    re.IGNORECASE,
)
_THIRTEENTH_RE = re.compile(
    r"(?:"
    r"\b13(?:e|a|[eè]me)\s+(?:rente|mensualit[àa]|pension)\b|"
    r"\b13\.\s+(?:rente|ahv-rente|altersrente|zahlung)\b"
    r")",
    re.IGNORECASE,
)


def _rejected(reason: str) -> ExtractionResult:
    return ExtractionResult(
        document_type=DocumentType.avs_official_pension,
        rejection_reason=reason,
        disclaimer=_DISCLAIMER,
        sources=list(_SOURCES),
    )


def _parse_source_date(text: str) -> str | None:
    for pattern in _DATE_PATTERNS:
        match = pattern.search(text)
        if match is None:
            continue
        try:
            return datetime.strptime(match.group(1), "%d.%m.%Y").date().isoformat()
        except ValueError:
            return None
    return None


def _parse_amount(raw: str) -> float | None:
    cleaned = raw.replace("'", "").replace("’", "").replace(" ", "")
    if "." in cleaned and "," in cleaned:
        cleaned = cleaned.replace(".", "").replace(",", ".")
    elif "," in cleaned:
        cleaned = cleaned.replace(",", ".")
    elif cleaned.count(".") == 1 and len(cleaned.rsplit(".", 1)[1]) != 2:
        cleaned = cleaned.replace(".", "")
    try:
        amount = float(cleaned)
    except ValueError:
        return None
    return amount if amount > 0 else None


def _source_clause(text: str, amount_match: re.Match[str]) -> str:
    start = text.rfind(". ", 0, amount_match.start())
    dash_start = text.rfind("— ", 0, amount_match.start())
    start = max(start + 2 if start >= 0 else 0, dash_start + 2 if dash_start >= 0 else 0)
    return text[start:amount_match.end()].strip()


def _evidence_kind(text: str) -> str:
    if _FORECAST_MARKER_RE.search(text) is not None:
        return "official_forecast"
    if _DECISION_MARKER_RE.search(text) is not None:
        return "official_decision"
    if _STATEMENT_MARKER_RE.search(text) is not None:
        return "official_statement"
    # Accepted official evidence without an explicit status marker stays an
    # estimate.  A generic issue date must never silently become a known value.
    return "official_forecast"


def parse_avs_official_pension(text: str) -> ExtractionResult:
    """Return one review candidate only when every certification marker holds.

    Exclusion semantics are evaluated before numeric extraction.  Consequently,
    a legitimate personal CHF 1'260/2'520 can pass while the same values in a
    minimum/maximum table fail.  Annual amounts are never converted to monthly.
    """
    if not text or not text.strip():
        return _rejected("empty_input")

    amount_matches = list(_AMOUNT_RE.finditer(text))

    for reason, pattern in _EXCLUSIONS:
        if pattern.search(text):
            return _rejected(reason)

    if len(amount_matches) > 1 and _THIRD_PERSON_RE.search(text) and _OWNER_RE.search(text):
        return _rejected("multiple_person_amounts")
    if _THIRD_PERSON_RE.search(text):
        return _rejected("third_person_amount")

    if amount_matches:
        thirteenth = _THIRTEENTH_RE.search(text)
        if thirteenth is not None and thirteenth.start() < amount_matches[0].start():
            return _rejected("thirteenth_pension_not_ordinary_monthly")

    if not amount_matches:
        return _rejected("monthly_amount_missing")

    amount_match = amount_matches[0]
    clause = _source_clause(text, amount_match)
    frequency_context = text[max(0, amount_match.start() - 120):amount_match.end() + 30]

    if _AUTHORITY_RE.search(text) is None:
        # A start-of-pension date is not an accepted source date.  Preserve
        # that more specific diagnosis when all other personal markers hold.
        if (
            _OLD_AGE_RE.search(clause) is not None
            and _OWNER_RE.search(clause) is not None
            and _MONTHLY_RE.search(frequency_context) is not None
            and _parse_source_date(text) is None
        ):
            return _rejected("source_date_missing")
        return _rejected("authority_marker_missing")

    if _OWNER_RE.search(clause) is None:
        return _rejected("personal_owner_label_missing")
    if _OLD_AGE_RE.search(clause) is None:
        return _rejected("old_age_benefit_label_missing")
    if _MONTHLY_RE.search(frequency_context) is None:
        return _rejected("explicit_monthly_frequency_missing")

    source_date = _parse_source_date(text)
    if source_date is None:
        return _rejected("source_date_missing")
    if _RESULT_MARKER_RE.search(text) is None:
        return _rejected("authority_result_marker_missing")

    amount = _parse_amount(amount_match.group("amount"))
    if amount is None:
        return _rejected("monthly_amount_invalid")
    if not (
        _MIN_TECHNICAL_MONTHLY_AMOUNT
        <= amount
        <= _MAX_TECHNICAL_MONTHLY_AMOUNT
    ):
        return _rejected("monthly_amount_implausible")

    candidate = ExtractedField(
        field_name=_CANONICAL_KEY,
        value=amount,
        confidence=1.0,
        source_text=clause,
        needs_review=True,
        source="certificate",
        source_date=source_date,
        evidence_kind=_evidence_kind(text),
    )
    return ExtractionResult(
        document_type=DocumentType.avs_official_pension,
        fields=[candidate],
        # Field confidence describes the deterministic match; the candidate as
        # a whole stays untrusted until explicit mobile review.
        overall_confidence=0.0,
        disclaimer=_DISCLAIMER,
        sources=list(_SOURCES),
    )
