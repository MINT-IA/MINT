"""Phase 94 / COMP-02 — éclairage locale parity tests.

6 locales × 4 archetypes = 24 cases. Promptfoo eval suite arrives in
Phase 95 TEST-01; this is the underlying code-path coverage.

Each case asserts:
  (a) headline non-empty,
  (b) body non-empty + cites locale-invariant CHF cap (7'258 or 7,258),
  (c) ComplianceGuard banned-term scan green,
  (d) soft_account_hint non-empty,
  (e) kind == "fiscal_margin_3a",
  (f) chf_range_low/high preserved (locale-invariant numeric range).

Plus standalone:
  - cross-locale FR-leak guard (no « tu peux » in non-FR variants),
  - unsupported-language fallback emits logger.warning + returns FR,
  - default-arg returns FR (zero-regression on existing callers),
  - registry covers exactly the 6 supported locales.
"""

from __future__ import annotations

import logging

import pytest

from app.services.coach.anonymous_eclairage_prompt import (
    _ECLAIRAGE_BY_LANGUAGE,
    build_default_fiscal_margin_3a_eclairage,
)
from app.services.coach.compliance_guard import ComplianceGuard

LOCALES = ["fr", "de", "it", "en", "es", "pt"]

# Archetype is metadata only — the éclairage builder is currently
# archetype-blind. The 4× multiplier is forward-compatibility for Phase
# 95 promptfoo (per CONTEXT.md «specifics» §1).
ARCHETYPES = [
    "julien_swiss_fr",
    "lauren_expat_us_en",
    "sofia_ticino_it",
    "klaus_swiss_native_de",
]

# Locale-invariant CHF cap, two valid renderings (apostrophe in FR/DE/
# IT/ES/PT, comma in EN per UK/US convention).
CAP_VARIANTS = ("7'258", "7,258")

# Cross-locale leak detectors. The FR fingerprint « tu peux » must not
# leak into any non-FR variant — highest-stakes guard. Other fingerprints
# may collide across romance languages so are only used for positive
# detection on their own locale.
LOCALE_FINGERPRINTS = {
    "fr": "tu peux",
    "de": "kannst",
    "it": "puoi",
    "en": "you can",
    "es": "puedes",
    "pt": "podes",
}


def _scan_banned_terms(body: str) -> list[str]:
    """Run a body through ComplianceGuard's Layer 1 banned-term scan.

    Adapts to the actual API: ComplianceGuard exposes `_check_banned_terms`
    as the Layer-1 helper (see compliance_guard.py:639). The full
    `validate()` pipeline injects disclaimers and tightens length, which
    is not what we want for a static text fixture — we only want the
    banned-term layer here.
    """
    guard = ComplianceGuard()
    # Use the same scan_text masking as validate() does for negated
    # guarantees, so a body containing « rien n'est garanti » does not
    # falsely trip Layer 1.
    scan_text = body
    for neg in ComplianceGuard._NEGATED_GUARANTEE_PATTERNS:
        scan_text = neg.sub("", scan_text)
    return guard._check_banned_terms(scan_text)


@pytest.mark.parametrize("language", LOCALES)
@pytest.mark.parametrize("archetype", ARCHETYPES)
def test_eclairage_locale_structure(language: str, archetype: str) -> None:
    """6 × 4 = 24 cases asserting structural invariants per locale."""
    payload = build_default_fiscal_margin_3a_eclairage(language=language)

    assert payload.kind == "fiscal_margin_3a"
    assert payload.headline, f"empty headline for {language=}"
    assert payload.body, f"empty body for {language=}"
    assert payload.soft_account_hint, f"empty soft_account_hint for {language=}"
    assert payload.chf_range_low == 1500
    assert payload.chf_range_high == 2500
    assert payload.chf_range_period == "year"

    assert any(cap in payload.body for cap in CAP_VARIANTS), (
        f"locale {language} body missing CHF cap "
        f"(expected one of {CAP_VARIANTS}); got: {payload.body[:120]}"
    )

    banned_hits = _scan_banned_terms(payload.body)
    assert not banned_hits, (
        f"locale {language} archetype {archetype} body hit banned terms: {banned_hits}"
    )


@pytest.mark.parametrize("language", LOCALES)
def test_eclairage_locale_fingerprint_present(language: str) -> None:
    """Every locale variant contains its own positive fingerprint."""
    payload = build_default_fiscal_margin_3a_eclairage(language=language)
    expected_fp = LOCALE_FINGERPRINTS[language]
    assert expected_fp.lower() in payload.body.lower(), (
        f"locale {language} missing its expected fingerprint {expected_fp!r}"
    )


@pytest.mark.parametrize("language", ["de", "it", "en", "es", "pt"])
def test_eclairage_no_fr_leak_into_non_fr_variants(language: str) -> None:
    """The FR phrase « tu peux » must not appear in any non-FR variant.

    This is the highest-stakes leak guard: a FR string slipping into a
    non-FR variant means the locale registry mis-keyed and a non-FR user
    sees French copy in violation of FinSA art. 8 al. 1 let. d.
    """
    payload = build_default_fiscal_margin_3a_eclairage(language=language)
    fr_fp = LOCALE_FINGERPRINTS["fr"]
    assert fr_fp.lower() not in payload.body.lower(), (
        f"FR phrase {fr_fp!r} leaked into {language} variant: {payload.body[:120]}"
    )


def test_eclairage_unsupported_language_falls_back_to_fr(
    caplog: pytest.LogCaptureFixture,
) -> None:
    """Unknown language code → FR fallback + logger.warning."""
    caplog.set_level(
        logging.WARNING,
        logger="app.services.coach.anonymous_eclairage_prompt",
    )
    fr_payload = build_default_fiscal_margin_3a_eclairage(language="fr")
    rm_payload = build_default_fiscal_margin_3a_eclairage(language="rm")

    assert rm_payload.body == fr_payload.body
    assert rm_payload.headline == fr_payload.headline
    assert rm_payload.soft_account_hint == fr_payload.soft_account_hint
    assert any(
        "unsupported language" in rec.message.lower()
        or "unsupported language" in (rec.getMessage() or "").lower()
        for rec in caplog.records
    ), "expected logger.warning citing unsupported language"


def test_eclairage_default_arg_is_fr() -> None:
    """No-arg call preserves the Phase 71b FR behaviour byte-for-byte."""
    default_payload = build_default_fiscal_margin_3a_eclairage()
    fr_payload = build_default_fiscal_margin_3a_eclairage(language="fr")
    assert default_payload.body == fr_payload.body
    assert default_payload.headline == fr_payload.headline
    assert default_payload.soft_account_hint == fr_payload.soft_account_hint


def test_eclairage_registry_has_all_six_supported_locales() -> None:
    """Registry must cover exactly the 6 ARB-supported locales."""
    assert set(_ECLAIRAGE_BY_LANGUAGE.keys()) == set(LOCALES), (
        "registry must cover exactly the 6 supported locales (fr/de/it/en/es/pt)"
    )


def test_eclairage_fr_variant_is_byte_identical_to_phase_71b_default() -> None:
    """FR variant references the locked Phase 71b constants — zero drift."""
    from app.services.coach.anonymous_eclairage_prompt import (
        DEFAULT_FISCAL_MARGIN_3A_BODY,
        DEFAULT_FISCAL_MARGIN_3A_HEADLINE,
        DEFAULT_SOFT_ACCOUNT_HINT,
    )

    fr_payload = build_default_fiscal_margin_3a_eclairage(language="fr")
    assert fr_payload.headline == DEFAULT_FISCAL_MARGIN_3A_HEADLINE
    assert fr_payload.body == DEFAULT_FISCAL_MARGIN_3A_BODY
    assert fr_payload.soft_account_hint == DEFAULT_SOFT_ACCOUNT_HINT
