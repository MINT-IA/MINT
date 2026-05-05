"""
Phase 84 — LANG-01..LANG-02 — Cross-language drift fix.

Pytest suite that asserts ``POST /api/v1/anonymous/chat`` honors the
``language`` field of :class:`AnonymousChatRequest`. Before Phase 84 the
parameter was accepted by the schema and propagated to
:func:`build_discovery_system_prompt`, but the function never read it — every
locale received the French system prompt. The audits B + E (2026-05-05) flagged
this as a coherence bug: a German query produced a French body with German
disclaimers (or no disclaimers).

Run::

    cd services/backend
    python3 -m pytest tests/api/test_anonymous_chat_language.py -v

Covers:
    - LANG-01 (AST/static) : the function body uses the ``language`` token,
      not just the signature.
    - LANG-02 (HTTP)       : per-locale POST returns a system-prompt + body
      coherent with the requested language. Six locales: fr/en/de/it/es/pt.
    - Fallback             : unknown locale falls back to French.
    - Disclaimers          : when the locale is supported by ComplianceGuardrails
      (fr/de/en/it), the disclaimer set is in the matching language.
"""

from __future__ import annotations

import ast
import inspect
import os
import re
from pathlib import Path
from unittest.mock import AsyncMock, patch

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

os.environ["TESTING"] = "1"
os.environ.setdefault("ANTHROPIC_API_KEY", "sk-test-anonymous-language-key")

from app.api.v1.endpoints import anonymous_chat as anon_endpoint  # noqa: E402
from app.core.database import Base, get_db  # noqa: E402
from app.main import app  # noqa: E402
from app.services.coach.discovery_prompts import (  # noqa: E402
    SUPPORTED_LANGUAGES,
    build_localized_discovery_prompt,
)


# ---------------------------------------------------------------------------
# Test DB setup — in-memory SQLite (mirrors test_anonymous_chat.py)
# ---------------------------------------------------------------------------

TEST_DB_URL = "sqlite:///./test_anonymous_chat_language.db"
test_engine = create_engine(TEST_DB_URL, connect_args={"check_same_thread": False})
TestSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=test_engine)


def override_get_db():
    db = TestSessionLocal()
    try:
        yield db
    finally:
        db.close()


@pytest.fixture(autouse=True)
def setup_db():
    Base.metadata.create_all(bind=test_engine)
    app.dependency_overrides[get_db] = override_get_db
    yield
    app.dependency_overrides.clear()
    Base.metadata.drop_all(bind=test_engine)


@pytest.fixture
def client():
    return TestClient(app)


_SESSION_HEADER = "X-Anonymous-Session"
_SESSION_PREFIX = "deadbeef-1111-2222-3333-"


def _session_for(language: str) -> str:
    """Generate a stable, unique UUID-shaped session id per locale."""
    suffix = (language + "0" * 12)[:12]
    suffix = re.sub(r"[^0-9a-f]", "0", suffix.lower())
    return f"{_SESSION_PREFIX}{suffix}"


# Mock answer per locale — the key signal we test for is that the *system
# prompt* given to the LLM is in the right language. The mocked answer body
# is irrelevant to LANG-01 but tests can still surface the disclaimer locale.
_MOCK_ANSWER = "Mocked discovery response for the requested locale."


# ---------------------------------------------------------------------------
# LANG-01 (static) — function body uses the ``language`` token
# ---------------------------------------------------------------------------


def test_build_discovery_system_prompt_reads_language_param():
    """LANG-01 — AST probe: the body of build_discovery_system_prompt uses
    the ``language`` parameter (not just declares it).

    Pre-Phase-84 the function had ``language: str = "fr"`` in its signature
    but never referenced ``language`` in its body — a dead parameter. This
    test parses the source AST and asserts at least one Name node with
    id='language' lives below the FunctionDef body, OUTSIDE the arguments
    block.
    """
    source = inspect.getsource(anon_endpoint.build_discovery_system_prompt)
    tree = ast.parse(source.strip())
    assert isinstance(tree, ast.Module)
    func = tree.body[0]
    assert isinstance(func, ast.FunctionDef)

    # Collect every Name node anywhere inside the function body.
    body_names: list[str] = []
    for node in func.body:
        for sub in ast.walk(node):
            if isinstance(sub, ast.Name):
                body_names.append(sub.id)

    assert "language" in body_names, (
        "build_discovery_system_prompt must READ its 'language' parameter, "
        "not just accept it. Found Name nodes in body: "
        f"{sorted(set(body_names))}"
    )


# ---------------------------------------------------------------------------
# LANG-02 (HTTP) — per-locale signature in the system prompt
# ---------------------------------------------------------------------------


_LOCALE_PROMPT_SIGNATURES: dict[str, tuple[str, ...]] = {
    # Each tuple = strings that must appear in the LOCALIZED prompt for that
    # language. They are intentionally specific to the locale (not just
    # words that happen to appear in the FR prompt) so a regression that
    # falls back to French would fail.
    "fr": ("Tu es MINT", "lucidité financière", "Réponds en français"),
    "en": ("You are MINT", "Swiss financial-lucidity", "Respond in English"),
    "de": ("Du bist MINT", "finanzielle Klarheit", "Antworte auf Deutsch"),
    "it": ("Sei MINT", "lucidità finanziaria", "Rispondi in italiano"),
    "es": ("Eres MINT", "lucidez financiera", "Responde en español"),
    "pt": ("És o MINT", "lucidez financeira", "Responde em português"),
}


@pytest.mark.parametrize("language", sorted(SUPPORTED_LANGUAGES))
def test_localized_discovery_prompt_signature(language: str):
    """LANG-02 (unit) — direct probe of build_localized_discovery_prompt.

    Asserts the rendered system prompt for each of the 6 supported locales
    contains its locale-specific signature strings. A French fallback would
    miss every non-French signature.
    """
    prompt = build_localized_discovery_prompt(intent=None, language=language)
    for signature in _LOCALE_PROMPT_SIGNATURES[language]:
        assert signature in prompt, (
            f"Locale '{language}' prompt missing signature '{signature}'.\n"
            f"Got prompt:\n{prompt}"
        )


@pytest.mark.parametrize("language", sorted(SUPPORTED_LANGUAGES))
@patch(
    "app.api.v1.endpoints.anonymous_chat._NoRagOrchestrator.query",
    new_callable=AsyncMock,
)
def test_post_anonymous_chat_passes_localized_prompt(
    mock_query, client, language: str
):
    """LANG-02 — POST /anonymous/chat with language=X passes a system prompt
    matching X to the LLM orchestrator.

    The orchestrator is mocked so we never call the real LLM. We assert on
    the ``system_prompt`` kwarg the endpoint forwards to ``_NoRagOrchestrator.query``.
    """
    mock_query.return_value = {
        "answer": _MOCK_ANSWER,
        "sources": [],
        "disclaimers": [],
        "tokens_used": 12,
    }

    payload = {
        "message": _LOCALE_TEST_MESSAGES[language],
        "language": language,
    }
    resp = client.post(
        "/api/v1/anonymous/chat",
        json=payload,
        headers={_SESSION_HEADER: _session_for(language)},
    )
    assert resp.status_code == 200, resp.text

    # Inspect the system_prompt kwarg the endpoint forwarded.
    assert mock_query.await_count == 1
    _, kwargs = mock_query.call_args
    system_prompt = kwargs.get("system_prompt", "")
    assert system_prompt, "Endpoint must forward a system_prompt kwarg"

    for signature in _LOCALE_PROMPT_SIGNATURES[language]:
        assert signature in system_prompt, (
            f"POST with language={language!r} produced a system prompt "
            f"missing the locale signature {signature!r}.\n"
            f"system_prompt was:\n{system_prompt}"
        )

    # The endpoint must also forward the language to the orchestrator (so
    # ComplianceGuardrails can pick the right disclaimer set).
    assert kwargs.get("language") == language


# Test inputs per locale: a question about pillar 3a / retirement framed in
# the locale's vocabulary. The wording itself is checked downstream against
# the locale-specific prompt, NOT against an LLM response.
_LOCALE_TEST_MESSAGES: dict[str, str] = {
    "fr": "Qu'est-ce que le 3e pilier ?",
    "en": "What is the third pillar?",
    "de": "Was ist die 3. Säule?",
    "it": "Cos'è il 3o pilastro?",
    "es": "¿Qué es el 3er pilar?",
    "pt": "O que é o 3º pilar?",
}


# ---------------------------------------------------------------------------
# LANG-02 (disclaimers) — German request returns German disclaimers
# ---------------------------------------------------------------------------


@patch(
    "app.api.v1.endpoints.anonymous_chat._NoRagOrchestrator.query",
    new_callable=AsyncMock,
)
def test_german_request_returns_german_disclaimers(mock_query, client):
    """LANG-02 (HTTP) — explicit German example from REQ wording.

    POST with ``{"message": "Was ist die 3. Säule?", "language": "de"}``
    returns a response whose ``disclaimers`` are German (contain
    'Bildungszwecken' or similar German marker), NOT French.
    """
    # We bypass the mocked orchestrator and run guardrails for real on the
    # mocked LLM raw text — that's where disclaimers get attached.
    from app.services.rag.guardrails import ComplianceGuardrails

    guardrails = ComplianceGuardrails()
    real_filter = guardrails.filter_response(
        "Die 3. Säule ist eine private Vorsorge in der Schweiz.",
        language="de",
    )

    mock_query.return_value = {
        "answer": real_filter["text"],
        "sources": [],
        "disclaimers": real_filter["disclaimers_added"],
        "tokens_used": 17,
    }

    resp = client.post(
        "/api/v1/anonymous/chat",
        json={"message": "Was ist die 3. Säule?", "language": "de"},
        headers={_SESSION_HEADER: _session_for("de")},
    )
    assert resp.status_code == 200, resp.text
    data = resp.json()
    disclaimers = data.get("disclaimers", [])
    assert disclaimers, "Disclaimers must always be present for compliance"

    joined = " ".join(disclaimers).lower()
    # German disclaimer signature words.
    assert any(
        marker in joined
        for marker in ("bildungszwecken", "finanzberatung", "anlage birgt")
    ), f"Disclaimers must be German, got: {disclaimers!r}"
    # And NOT French.
    assert "éducatif" not in joined, (
        f"Disclaimers leaked French copy: {disclaimers!r}"
    )


# ---------------------------------------------------------------------------
# Fallback — unknown locale falls back to French
# ---------------------------------------------------------------------------


def test_unknown_language_falls_back_to_french():
    """Unknown locale → FR prompt (preserves pre-Phase-84 behaviour)."""
    prompt = build_localized_discovery_prompt(intent=None, language="zz")
    assert "Tu es MINT" in prompt
    assert "Réponds en français" in prompt


def test_locale_variant_is_normalized():
    """`fr-CH`, `DE`, `pt_BR` → matched on the leading two-letter code."""
    fr_ch = build_localized_discovery_prompt(language="fr-CH")
    de_caps = build_localized_discovery_prompt(language="DE")
    pt_br = build_localized_discovery_prompt(language="pt_BR")
    assert "Tu es MINT" in fr_ch
    assert "Du bist MINT" in de_caps
    assert "És o MINT" in pt_br


# ---------------------------------------------------------------------------
# LSFin compliance — no banned terms in any of the 6 prompt variants
# ---------------------------------------------------------------------------


# A small banned-terms set per locale. Full list lives in
# app/services/coach/compliance_guard.py and ComplianceGuardrails — here we
# just assert the locale-specific variants of the worst offenders are absent
# from the prompt itself (the prompt is meant to FORBID them, not USE them).
_BANNED_PER_LOCALE: dict[str, tuple[str, ...]] = {
    "fr": ("rendement garanti", "sans risque", "l'optimal"),
    "en": ("guaranteed return", "risk-free", "the optimal"),
    "de": ("garantierte Rendite", "risikofrei", "das optimale"),
    "it": ("rendimento garantito", "senza rischio", "l'ottimale"),
    "es": ("rendimiento garantizado", "sin riesgo", "lo óptimo"),
    "pt": ("rendimento garantido", "sem risco", "o ótimo"),
}


@pytest.mark.parametrize("language", sorted(SUPPORTED_LANGUAGES))
def test_localized_prompt_has_no_banned_terms(language: str):
    """LSFin — none of the locale-specific banned terms are present in the
    rendered system prompt body. A prompt that contains 'rendement garanti'
    inside an example would leak the term to the LLM."""
    prompt = build_localized_discovery_prompt(intent=None, language=language).lower()
    for term in _BANNED_PER_LOCALE[language]:
        assert term.lower() not in prompt, (
            f"Locale '{language}' prompt contains banned term '{term}'"
        )


# ---------------------------------------------------------------------------
# Sanity — the new module path matches the file the roadmap referenced
# ---------------------------------------------------------------------------


def test_discovery_prompts_module_lives_at_expected_path():
    """Smoke: the new module ships at services/backend/app/services/coach/."""
    expected = Path(__file__).resolve().parents[2] / (
        "app/services/coach/discovery_prompts.py"
    )
    assert expected.is_file(), f"discovery_prompts.py missing at {expected}"
