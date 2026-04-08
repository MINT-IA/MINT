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
