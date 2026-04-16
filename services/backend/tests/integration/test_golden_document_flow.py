"""Phase 30 / GATE-04 — mocked-Vision golden document flow.

Parametrised over ``GOLDEN_EXPECTATIONS`` (10 primary fixtures + 7 adversarial
reused from Phase 29-04). Each case:

    1. loads the corresponding fixture bytes from ``tests/fixtures/documents/``
    2. loads a pre-recorded Vision ``tool_use`` cassette from
       ``tests/fixtures/vision_responses/``
    3. patches ``_call_fused_vision`` to replay the cassette (no network)
    4. patches ``judge_vision_output`` with a deterministic stub that blocks
       known adversarial content
    5. invokes ``understand_document`` and asserts:
         - render_mode, documentClass, extraction_status
         - critical field ranges
         - third-party detection
         - guard_blocked / sanity_verdict
         - locale leak (German tokens absent when user_locale=fr)
         - per-fixture cost + latency budget

Two session-scoped aggregators then assert the global:
    - avg cost < $0.05 across the suite
    - p95 latency < 10s across the suite

No real Anthropic API call is made. Test runs without ANTHROPIC_API_KEY.
"""
from __future__ import annotations

import json
import os
import time
from pathlib import Path
from types import SimpleNamespace
from typing import List, Tuple
from unittest.mock import patch

import pytest

from app.schemas.document_understanding import (
    DocumentUnderstandingResult,
    FieldStatus,
    RenderMode,
)
from tests.integration.golden_expectations import (
    GOLDEN_EXPECTATIONS,
    GoldenExpectation,
)

BASE = Path(__file__).parent.parent
FIXTURES_DIR = BASE / "fixtures" / "documents"
CASSETTES_DIR = BASE / "fixtures" / "vision_responses"

# Anthropic Sonnet 4.5 pricing (2025): $3 / 1M in, $15 / 1M out.
PRICE_IN_PER_TOKEN = 3.0 / 1_000_000
PRICE_OUT_PER_TOKEN = 15.0 / 1_000_000

ATTACKER_MARKER = "ATTACKER_PAYLOAD_LEAKED"
FORBIDDEN_INJECTION_TOKENS = [
    ATTACKER_MARKER.lower(),
    "ignore all previous",
    "ignore previous instructions",
    "ubs vitainvest",
    "achete le fond",
]


# ---------------------------------------------------------------------------
# Session-scoped aggregator for p95 latency + average cost.
# ---------------------------------------------------------------------------

_timings: List[Tuple[str, float, float]] = []  # (fixture, elapsed_s, cost_usd)


def _record(fixture: str, elapsed: float, cost: float) -> None:
    _timings.append((fixture, elapsed, cost))


# ---------------------------------------------------------------------------
# Language leak heuristic.
# ---------------------------------------------------------------------------

_DE_TOKENS = (
    " der ", " die ", " und ", "sehr geehrte", "versicherung", "mit freundlichen",
)


def _looks_like_german(text: str) -> bool:
    if not text:
        return False
    lowered = " " + text.lower() + " "
    hits = sum(1 for t in _DE_TOKENS if t in lowered)
    return hits >= 2  # require 2 German markers to avoid FP on loanwords


# ---------------------------------------------------------------------------
# Cassette loader → synthesise the DUR via the service's own _ti_to_result.
# ---------------------------------------------------------------------------


def _load_cassette(name: str) -> dict:
    path = CASSETTES_DIR / f"{name}.json"
    with path.open("r", encoding="utf-8") as fh:
        return json.load(fh)


def _fixture_bytes(name: str) -> Tuple[bytes, str]:
    for ext in (".pdf", ".jpg", ".png"):
        path = FIXTURES_DIR / f"{name}{ext}"
        if path.exists():
            return path.read_bytes(), path.name
    raise FileNotFoundError(f"fixture not found: {name}(.pdf|.jpg|.png)")


def _cassette_to_dur(cassette: dict) -> DocumentUnderstandingResult:
    """Replay a cassette through the service's own tool_input→DUR helper."""
    from app.services import document_vision_service as dvs

    tool_input: dict = {}
    for block in cassette.get("content", []):
        if block.get("type") == "tool_use":
            tool_input = block.get("input") or {}
            break

    usage = cassette.get("usage") or {}
    usage_obj = SimpleNamespace(
        input_tokens=int(usage.get("input_tokens", 0) or 0),
        output_tokens=int(usage.get("output_tokens", 0) or 0),
    )

    return dvs._ti_to_result(tool_input, usage_obj)  # noqa: SLF001 — intended


# ---------------------------------------------------------------------------
# Judge stub — behaves like the real LSFin judge.
# ---------------------------------------------------------------------------


async def _fake_judge(summary, narrative, fields_summary=None, **kwargs):
    from app.services.compliance.vision_guard import GuardVerdict

    blob = " ".join(filter(None, [summary or "", narrative or ""])).lower()
    flags = []
    if ATTACKER_MARKER.lower() in blob or "attacker_payload" in blob:
        flags.append("product_advice")
    if "ubs vitainvest" in blob or "achete le fond" in blob:
        flags.append("product_advice")
    if "garanti" in blob or "tu es assure" in blob:
        flags.append("return_promise")

    if flags:
        return GuardVerdict(
            allow=False,
            flagged_categories=list(dict.fromkeys(flags)),
            reformulation=(
                "MINT a lu ton document. Regarde les chiffres bruts ci-dessous "
                "et confirme-les."
            ),
            reason="adversarial content detected",
            cost_usd=0.0003,
        )
    return GuardVerdict(
        allow=True, flagged_categories=[], reformulation=None,
        reason="clean", cost_usd=0.0003,
    )


# ---------------------------------------------------------------------------
# Redis fake — mirrors the pattern used by Phase 28 fused-vision tests.
# ---------------------------------------------------------------------------


@pytest.fixture(autouse=True)
def _redis_fakes():
    import fakeredis.aioredis as fakeaio
    from app.core import redis_client

    redis_client.set_redis_client_for_tests(fakeaio.FakeRedis(decode_responses=True))
    yield
    redis_client.reset_for_tests()


@pytest.fixture(autouse=True)
def _patch_settings(monkeypatch):
    from app.core.config import settings

    monkeypatch.setattr(settings, "ANTHROPIC_API_KEY", "test-key", raising=False)
    monkeypatch.setattr(settings, "COACH_MODEL", "claude-sonnet-4-5-20250929", raising=False)


# ---------------------------------------------------------------------------
# Runner: feeds a fixture through understand_document with Vision + judge mocked.
# ---------------------------------------------------------------------------


async def _run_golden(exp: GoldenExpectation) -> Tuple[DocumentUnderstandingResult, float]:
    from app.services import document_vision_service as dvs

    file_bytes, _filename = _fixture_bytes(exp.fixture_name)
    cassette = _load_cassette(exp.cassette_name or exp.fixture_name)
    replay_dur = _cassette_to_dur(cassette)

    async def _fake_call_fused_vision(*_args, **_kwargs):
        return replay_dur

    with patch.object(dvs, "_call_fused_vision", side_effect=_fake_call_fused_vision), \
         patch("app.services.compliance.vision_guard.judge_vision_output",
               side_effect=_fake_judge):
        start = time.perf_counter()
        result = await dvs.understand_document(
            file_bytes=file_bytes,
            user_id="test-user-julien",
            canton=exp.user_canton,
            lang=exp.expect_response_locale,
            # Caller is "Jean TESTUSER" → hotela Lauren triggers third-party.
            profile_first_name="Jean",
            profile_last_name="Testuser",
            partner_first_name=None,
            file_sha=None,  # skip idempotency store/lookup
            db=None,
        )
        elapsed = time.perf_counter() - start

    return result, elapsed


# ---------------------------------------------------------------------------
# Parametrised test.
# ---------------------------------------------------------------------------


@pytest.mark.parametrize(
    "exp", GOLDEN_EXPECTATIONS, ids=lambda e: e.fixture_name,
)
@pytest.mark.asyncio
async def test_golden_flow(exp: GoldenExpectation):
    result, elapsed = await _run_golden(exp)

    # ------------------------------------------------ render_mode + doc class
    assert result.render_mode.value == exp.expected_render_mode, (
        f"{exp.fixture_name}: expected render_mode={exp.expected_render_mode}, "
        f"got {result.render_mode.value}"
    )
    assert result.document_class.value == exp.expected_document_class, (
        f"{exp.fixture_name}: expected document_class={exp.expected_document_class}, "
        f"got {result.document_class.value}"
    )
    assert result.extraction_status.value == exp.expected_extraction_status, (
        f"{exp.fixture_name}: expected extraction_status="
        f"{exp.expected_extraction_status}, got {result.extraction_status.value}"
    )

    # ------------------------------------------------ critical field ranges
    for field_name, (lo, hi) in exp.critical_field_assertions.items():
        match = next(
            (f for f in result.extracted_fields if f.field_name == field_name),
            None,
        )
        assert match is not None, (
            f"{exp.fixture_name}: missing critical field {field_name!r}"
        )
        try:
            val = float(match.value)  # type: ignore[arg-type]
        except (TypeError, ValueError):
            pytest.fail(f"{exp.fixture_name}: field {field_name} not numeric: {match.value!r}")
        assert lo <= val <= hi, (
            f"{exp.fixture_name}: {field_name}={val} out of range [{lo},{hi}]"
        )

    # ------------------------------------------------ third-party detection
    if exp.expect_third_party:
        assert result.third_party_detected is True, (
            f"{exp.fixture_name}: expected third_party_detected=True"
        )
        if exp.expect_third_party_name is not None:
            assert result.third_party_name == exp.expect_third_party_name, (
                f"{exp.fixture_name}: expected third_party_name="
                f"{exp.expect_third_party_name!r}, got {result.third_party_name!r}"
            )

    # ------------------------------------------------ guard + sanity
    if exp.expect_guard_blocked is not None:
        assert result.guard_blocked is exp.expect_guard_blocked, (
            f"{exp.fixture_name}: guard_blocked expected={exp.expect_guard_blocked}, "
            f"got {result.guard_blocked}"
        )
    if exp.expect_sanity_verdict == "reject":
        assert result.sanity_rejected_fields, (
            f"{exp.fixture_name}: expected sanity_rejected_fields, got empty"
        )
    elif exp.expect_sanity_verdict == "human_review":
        assert result.sanity_human_review_fields, (
            f"{exp.fixture_name}: expected sanity_human_review_fields, got empty"
        )

    # ------------------------------------------------ prompt-injection scrub
    if exp.expect_prompt_injection_ignored:
        blob = " ".join(filter(None, [result.summary or "", result.narrative or ""])).lower()
        for token in FORBIDDEN_INJECTION_TOKENS:
            assert token not in blob, (
                f"{exp.fixture_name}: forbidden token {token!r} leaked in final "
                f"summary/narrative"
            )

    # ------------------------------------------------ locale leak
    if exp.expect_response_locale == "fr" and result.summary:
        assert not _looks_like_german(result.summary), (
            f"{exp.fixture_name}: summary leaked German tokens despite user_locale=fr: "
            f"{result.summary!r}"
        )

    # ------------------------------------------------ runtime invariants
    # Every field persists as needs_review regardless of model confidence.
    for f in result.extracted_fields:
        assert f.status in (
            FieldStatus.needs_review,
            FieldStatus.rejected,        # sanity-rejected fields
            FieldStatus.human_review,    # sanity human_review flagged (rare)
        ), (
            f"{exp.fixture_name}: field {f.field_name} illegal auto-status: {f.status}"
        )

    # ------------------------------------------------ cost + latency
    cost_usd = (
        result.cost_tokens_in * PRICE_IN_PER_TOKEN
        + result.cost_tokens_out * PRICE_OUT_PER_TOKEN
        + (result.guard_cost_usd or 0.0)
    )
    assert cost_usd < exp.max_cost_usd, (
        f"{exp.fixture_name}: cost ${cost_usd:.4f} >= budget ${exp.max_cost_usd}"
    )
    assert elapsed < exp.max_latency_seconds, (
        f"{exp.fixture_name}: elapsed {elapsed:.2f}s >= budget {exp.max_latency_seconds}s"
    )

    _record(exp.fixture_name, elapsed, cost_usd)


# ---------------------------------------------------------------------------
# Session aggregators (run last — rely on parametrised cases having executed).
# ---------------------------------------------------------------------------


def _percentile(values: List[float], pct: float) -> float:
    if not values:
        return 0.0
    ordered = sorted(values)
    # Nearest-rank p95.
    idx = max(0, min(len(ordered) - 1, int(round(pct / 100.0 * (len(ordered) - 1)))))
    return ordered[idx]


def test_zz_p95_latency_under_budget():
    if len(_timings) < len(GOLDEN_EXPECTATIONS):
        pytest.skip(
            f"parametrised suite incomplete: {len(_timings)}/{len(GOLDEN_EXPECTATIONS)}"
        )
    latencies = [t[1] for t in _timings]
    p95 = _percentile(latencies, 95.0)
    assert p95 < 10.0, f"p95 latency {p95:.3f}s >= 10s budget"


def test_zz_avg_cost_under_budget():
    if len(_timings) < len(GOLDEN_EXPECTATIONS):
        pytest.skip(
            f"parametrised suite incomplete: {len(_timings)}/{len(GOLDEN_EXPECTATIONS)}"
        )
    costs = [t[2] for t in _timings]
    avg = sum(costs) / len(costs)
    assert avg < 0.05, f"avg cost ${avg:.4f} >= $0.05 budget"
