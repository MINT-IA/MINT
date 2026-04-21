"""FIX-165: Direct unit tests for _detect_archetype() — 8 branches."""

from app.services.onboarding.minimal_profile_service import _detect_archetype
from app.services.onboarding.onboarding_models import MinimalProfileInput


def _input(**kwargs):
    return MinimalProfileInput(age=40, gross_salary=100000, canton="ZH", **kwargs)


def test_swiss_native_default():
    assert _detect_archetype(_input()) == "swiss_native"


def test_swiss_native_explicit():
    assert _detect_archetype(_input(nationality_country="CH", nationality_group="CH")) == "swiss_native"


def test_returning_swiss():
    assert _detect_archetype(_input(nationality_country="CH", arrival_age=35)) == "returning_swiss"


def test_expat_us():
    assert _detect_archetype(_input(nationality_country="US")) == "expat_us"


def test_expat_us_via_group():
    assert _detect_archetype(_input(nationality_group="US")) == "expat_us"


def test_expat_eu_late_arrival():
    assert _detect_archetype(_input(nationality_country="FR", arrival_age=30)) == "expat_eu"


def test_expat_non_eu_late_arrival():
    assert _detect_archetype(_input(nationality_country="BR", arrival_age=25)) == "expat_non_eu"


def test_eu_young_arrival():
    """EU citizen arrived young (< 20) → treated as integrated."""
    assert _detect_archetype(_input(nationality_country="DE", arrival_age=18)) == "expat_eu"


def test_no_nationality_default():
    """No nationality data → fallback swiss_native (backward compat)."""
    assert _detect_archetype(_input()) == "swiss_native"


# ─── AUDIT-2026-04-17: last 3 archetypes wired in ─────────────────────


def test_cross_border_permit_g():
    """Permit G frontalier — priority archetype (source taxation)."""
    assert _detect_archetype(
        _input(nationality_country="FR", permit_type="G")
    ) == "cross_border"


def test_cross_border_beats_expat_eu():
    """Cross-border must win over expat_eu even with late arrival."""
    assert _detect_archetype(
        _input(nationality_country="FR", arrival_age=35, permit_type="G")
    ) == "cross_border"


def test_independent_no_lpp():
    """Self-employed without LPP → 3a ceiling = 36'288 (OPP3 art. 7)."""
    assert _detect_archetype(
        _input(employment_status="self_employed")
    ) == "independent_no_lpp"


def test_independent_with_lpp_via_balance():
    """Self-employed WITH LPP balance → ceiling = 7'258 (salaried rule)."""
    assert _detect_archetype(
        _input(employment_status="self_employed", existing_lpp=50_000)
    ) == "independent_with_lpp"


def test_independent_with_lpp_via_caisse():
    """Self-employed declaring a caisse type also triggers LPP branch."""
    assert _detect_archetype(
        _input(employment_status="self_employed", lpp_caisse_type="base")
    ) == "independent_with_lpp"


def test_expat_us_beats_self_employed():
    """FATCA must dominate — PFIC consequences outweigh LPP/3a distinction."""
    assert _detect_archetype(
        _input(nationality_country="US", employment_status="self_employed")
    ) == "expat_us"


def test_cross_border_beats_us():
    """Permit G check runs first — a US national with permit G is a
    frontalier from MINT's fiscal standpoint (the CDI governs)."""
    assert _detect_archetype(
        _input(nationality_country="US", permit_type="G")
    ) == "cross_border"
