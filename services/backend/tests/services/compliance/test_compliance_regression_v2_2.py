"""
Plan 12-04 — v2.2 ComplianceGuard regression suite (final ship-gate audit).

Loads `services/backend/data/compliance_regression/v2_2_channels.json` and walks
every sample on every channel through `ComplianceGuard.validate()`. The suite
asserts ZERO violations. Any failure = red build = ship blocked.

Channels under test (per D-06 / Plan 12-04 must_haves):
    - alerts (MintAlertObject Phase 9, G2/G3 x N1-N5)
    - biography facts (Phase 9 ack, Phase 11 fragility, v2.0 narrative)
    - openers / first-message templates
    - extraction summaries / educational inserts
    - alert grammar triples (fact / cause / nextMoment)
    - rewritten coach phrases (subset of Plan 11-01)
    - voice cursor outputs at N1-N5
    - Ton chooser micro-examples
    - regional voice overlays
    - landing v2 + onboarding v2 copy

Samples carrying a `cursor_level` field are validated at that level so that
Layer 2b (high-register drift) is exercised end-to-end on N4/N5 content.

This test IS the mitigation for T-12-09 / T-12-10 (audit fix B4).
"""

from __future__ import annotations

import json
from pathlib import Path
from typing import Iterator

import pytest

from app.services.coach.compliance_guard import ComplianceGuard
from app.services.coach.coach_models import ComponentType


# ── Fixture path ────────────────────────────────────────────────────────────
# Repo layout:
#   services/backend/tests/services/compliance/test_compliance_regression_v2_2.py
#   services/backend/data/compliance_regression/v2_2_channels.json
_THIS_FILE = Path(__file__).resolve()
_BACKEND_ROOT = _THIS_FILE.parents[3]  # services/backend/
_FIXTURE_PATH = (
    _BACKEND_ROOT / "data" / "compliance_regression" / "v2_2_channels.json"
)


def _load_fixture() -> dict:
    assert _FIXTURE_PATH.exists(), f"Channel fixture missing at {_FIXTURE_PATH}"
    with _FIXTURE_PATH.open("r", encoding="utf-8") as f:
        data = json.load(f)
    assert isinstance(data, dict), "fixture root must be a dict"
    assert "channels" in data and isinstance(data["channels"], list), (
        "fixture must contain a 'channels' list"
    )
    return data


_FIXTURE = _load_fixture()
_CHANNELS = _FIXTURE["channels"]


def _iter_samples() -> Iterator[tuple[str, str, str, str | None]]:
    """Yield (channel_id, sample_id, text, cursor_level) for every sample."""
    for ch in _CHANNELS:
        ch_id = ch["id"]
        for sample in ch.get("samples", []):
            yield (
                ch_id,
                sample["id"],
                sample["text"],
                sample.get("cursor_level"),
            )


_ALL_SAMPLES = list(_iter_samples())


# ── Structural sanity ──────────────────────────────────────────────────────


def test_fixture_version_is_v2_2():
    assert _FIXTURE.get("version") == "v2.2"


def test_fixture_has_all_required_channels():
    """Every channel mandated by D-06 / Plan 12-04 must be present."""
    required = {
        "alerts_mint_alert_object",
        "biography_facts",
        "openers_first_message",
        "extraction_summaries",
        "alert_grammar_triples",
        "rewritten_coach_phrases",
        "voice_cursor_outputs",
        "ton_chooser_micro_examples",
        "regional_voice_overlays",
        "landing_onboarding_copy",
    }
    present = {ch["id"] for ch in _CHANNELS}
    missing = required - present
    assert not missing, f"missing required channels: {sorted(missing)}"


def test_fixture_has_at_least_40_samples():
    assert len(_ALL_SAMPLES) >= 40, (
        f"expected >= 40 samples across all channels, got {len(_ALL_SAMPLES)}"
    )


def test_every_sample_has_id_and_text():
    for ch_id, s_id, text, _level in _ALL_SAMPLES:
        assert s_id, f"channel {ch_id}: sample missing id"
        assert isinstance(text, str) and text.strip(), (
            f"channel {ch_id} sample {s_id}: empty text"
        )


# ── Main regression: every sample must pass ComplianceGuard ────────────────


@pytest.fixture(scope="module")
def guard() -> ComplianceGuard:
    return ComplianceGuard()


@pytest.mark.parametrize(
    "channel_id,sample_id,text,cursor_level",
    _ALL_SAMPLES,
    ids=[f"{c}::{s}" for c, s, _t, _l in _ALL_SAMPLES],
)
def test_sample_passes_compliance_guard(
    guard: ComplianceGuard,
    channel_id: str,
    sample_id: str,
    text: str,
    cursor_level: str | None,
):
    result = guard.validate(
        llm_output=text,
        component_type=ComponentType.general,
        cursor_level=cursor_level,
    )
    assert result.is_compliant, (
        f"[{channel_id}::{sample_id}] level={cursor_level} "
        f"violations={result.violations} text={text!r}"
    )
    assert not result.use_fallback, (
        f"[{channel_id}::{sample_id}] level={cursor_level} "
        f"forced fallback violations={result.violations}"
    )


# ── Per-channel pass-rate aggregation (informational) ──────────────────────


def test_per_channel_pass_rate_is_100_percent(guard: ComplianceGuard):
    """Aggregate report: every channel must hit 100% pass rate.

    This is intentionally separate from the parameterized test so that
    the runner script can pull a single per-channel summary easily.
    """
    failures: dict[str, list[str]] = {}
    for ch in _CHANNELS:
        ch_id = ch["id"]
        for sample in ch.get("samples", []):
            result = guard.validate(
                llm_output=sample["text"],
                component_type=ComponentType.general,
                cursor_level=sample.get("cursor_level"),
            )
            if not result.is_compliant:
                failures.setdefault(ch_id, []).append(
                    f"{sample['id']}: {result.violations}"
                )
    assert not failures, f"per-channel failures: {failures}"
