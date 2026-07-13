from __future__ import annotations

import re
from dataclasses import dataclass
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
MOBILE_PRODUCTION = ROOT / "apps/mobile/lib"
COACH_PROFILE = ROOT / "apps/mobile/lib/models/coach_profile.dart"
FORECASTER = ROOT / "apps/mobile/lib/services/forecaster_service.dart"
MONTE_CARLO = (
    ROOT / "apps/mobile/lib/services/financial_core/monte_carlo_service.dart"
)
FINANCIAL_REPORT_SERVICE = (
    ROOT / "apps/mobile/lib/services/financial_report_service.dart"
)
PDF_SERVICE = ROOT / "apps/mobile/lib/services/pdf_service.dart"
FINANCIAL_REPORT_SCREEN = (
    ROOT / "apps/mobile/lib/screens/advisor/financial_report_screen_v2.dart"
)
RETIREMENT_PROJECTION_CARD = (
    ROOT / "apps/mobile/lib/widgets/report/retirement_projection_card.dart"
)
CERTIFIED_NULL_FALLBACK_RE = re.compile(r"\.lacunesAVS\s*\?\?\s*0")


@dataclass(frozen=True)
class AvsConsumerContract:
    path: str
    readiness_tokens: tuple[str, ...] = ("avsGapEvidence",)


AVS_CONSUMERS = {
    "coach_narrative": AvsConsumerContract(
        "apps/mobile/lib/services/coach_narrative_service.dart"
    ),
    "bayesian_enricher": AvsConsumerContract(
        "apps/mobile/lib/services/financial_core/bayesian_enricher.dart"
    ),
    "monte_carlo": AvsConsumerContract(
        "apps/mobile/lib/services/financial_core/monte_carlo_service.dart",
        (
            "RetirementIncomeScope.nonAvsOnly",
            "avsIncluded: false",
            "missingFields: missingFields",
        ),
    ),
    "forecaster": AvsConsumerContract(
        "apps/mobile/lib/services/forecaster_service.dart",
        ("selfAvsPensionFieldPath",),
    ),
    "retirement_projection": AvsConsumerContract(
        "apps/mobile/lib/services/retirement_projection_service.dart",
        ("_officialAvsProjectionAvailable",),
    ),
}

EXPECTED_CONSUMERS = {
    "coach_narrative",
    "bayesian_enricher",
    "monte_carlo",
    "forecaster",
    "retirement_projection",
}


def _consumer_sources() -> dict[str, tuple[AvsConsumerContract, str]]:
    assert set(AVS_CONSUMERS) == EXPECTED_CONSUMERS
    assert len({contract.path for contract in AVS_CONSUMERS.values()}) == len(
        EXPECTED_CONSUMERS
    )
    sources: dict[str, tuple[AvsConsumerContract, str]] = {}
    for name, contract in AVS_CONSUMERS.items():
        path = ROOT / contract.path
        assert path.is_file(), f"{name}: missing declared consumer {contract.path}"
        sources[name] = (contract, path.read_text(encoding="utf-8"))
    return sources


def _assert_tokens_absent(path: Path, tokens: tuple[str, ...], reason: str) -> None:
    source = path.read_text(encoding="utf-8")
    offenders = [token for token in tokens if token in source]
    assert not offenders, (
        f"{path.relative_to(ROOT).as_posix()}: {reason}; "
        f"remove {offenders}"
    )


def test_avs_consumers_never_turn_missing_certified_years_into_zero() -> None:
    names_by_path = {
        contract.path: name for name, contract in AVS_CONSUMERS.items()
    }
    fallbacks: list[str] = []
    _consumer_sources()
    for path in sorted(MOBILE_PRODUCTION.rglob("*.dart")):
        source = path.read_text(encoding="utf-8")
        relative_path = path.relative_to(ROOT).as_posix()
        for match in CERTIFIED_NULL_FALLBACK_RE.finditer(source):
            line = source.count("\n", 0, match.start()) + 1
            name = names_by_path.get(relative_path, "undeclared_consumer")
            fallbacks.append(
                f"{name}: {relative_path}:{line}: {match.group(0)}"
            )

    assert not fallbacks, (
        "certified AVS null must remain unknown; "
        f"found {len(fallbacks)} production `lacunesAVS ?? 0` fallbacks:\n"
        + "\n".join(fallbacks)
    )


def test_every_avs_consumer_uses_declared_readiness_or_quarantine_api() -> None:
    missing_evidence: list[str] = []
    for name, (contract, source) in _consumer_sources().items():
        assert contract.readiness_tokens, f"{name}: readiness contract is empty"
        for token in contract.readiness_tokens:
            assert len(token) >= 12, (
                f"{name}: readiness token must identify an explicit API use"
            )
            assert token not in {"lacunesAVS", "prevoyance"}
            if token not in source:
                missing_evidence.append(f"{name}: {contract.path} -> {token}")

    assert not missing_evidence, (
        "every AVS consumer must read its declared evidence/readiness API or "
        "use an explicit typed quarantine:\n" + "\n".join(missing_evidence)
    )


def test_coach_profile_exposes_avs_gap_evidence_contract() -> None:
    source = COACH_PROFILE.read_text(encoding="utf-8")

    assert re.search(r"\bclass\s+AvsGapEvidence\b", source), (
        "coach_profile.dart must declare class AvsGapEvidence"
    )
    assert re.search(
        r"\bAvsGapEvidence\??\s+get\s+avsGapEvidence\b", source
    ), "CoachProfile must expose an avsGapEvidence getter"


def test_official_avs_pension_paths_have_one_shared_contract() -> None:
    profile_source = COACH_PROFILE.read_text(encoding="utf-8")
    forecaster_source = FORECASTER.read_text(encoding="utf-8")
    monte_carlo_source = MONTE_CARLO.read_text(encoding="utf-8")

    assert re.search(r"\bclass\s+AvsOfficialPensionEvidence\b", profile_source)
    assert re.search(
        r"selfFieldPath\s*=\s*'prevoyance\.renteAVSEstimeeMensuelle'",
        profile_source,
    )
    assert re.search(
        r"spouseFieldPath\s*=\s*'conjoint\.prevoyance\.renteAVSEstimeeMensuelle'",
        profile_source,
    )
    assert re.search(
        r"selfAvsPensionFieldPath\s*=\s*"
        r"AvsOfficialPensionEvidence\.selfFieldPath",
        forecaster_source,
    )
    assert re.search(
        r"spouseAvsPensionFieldPath\s*=\s*"
        r"AvsOfficialPensionEvidence\.spouseFieldPath",
        forecaster_source,
    )
    assert "AvsOfficialPensionEvidence.selfFieldPath" in monte_carlo_source
    assert "AvsOfficialPensionEvidence.spouseFieldPath" in monte_carlo_source
    assert "'prevoyance.renteAVSEstimeeMensuelle'" not in forecaster_source
    assert "'conjoint.prevoyance.renteAVSEstimeeMensuelle'" not in forecaster_source
    assert "'prevoyance.renteAVSEstimeeMensuelle'" not in monte_carlo_source
    assert "'conjoint.prevoyance.renteAVSEstimeeMensuelle'" not in monte_carlo_source


def test_financial_report_service_never_synthesizes_official_avs_amount() -> None:
    _assert_tokens_absent(
        FINANCIAL_REPORT_SERVICE,
        ("AvsCalculator.computeMonthlyRente", "_estimateAvsRent"),
        "the report must keep AVS unknown until the reviewed official mobile "
        "envelope exists",
    )


def test_pdf_never_reads_unknown_avs_or_avs_dependent_totals() -> None:
    _assert_tokens_absent(
        PDF_SERVICE,
        (
            "ret.monthlyAvsRent",
            "ret.totalMonthlyIncome",
            "ret.avsReductionFactor",
        ),
        "the PDF must show AVS as to verify without formatting an amount, "
        "retirement total, or exact reduction",
    )


def test_report_screen_never_formats_or_derives_unknown_avs_values() -> None:
    _assert_tokens_absent(
        FINANCIAL_REPORT_SCREEN,
        (
            "projection.replacementRate",
            "projection.totalMonthlyIncome",
            "q_avs_lacunes_status",
            "q_avs_arrival_year",
            "q_avs_years_abroad",
            "q_first_employment_year",
        ),
        "the report screen must not format AVS-dependent totals/rates or "
        "derive certified contribution years from questionnaire gaps",
    )


def test_retirement_projection_card_never_formats_or_derives_unknown_avs() -> None:
    _assert_tokens_absent(
        RETIREMENT_PROJECTION_CARD,
        (
            "projection.monthlyAvsRent",
            "projection.totalMonthlyIncome",
            "projection.replacementRate",
            "projection.avsReductionFactor",
            "contributionYears",
            "avsLacunesStatus",
            "AvsCalculator.reductionPercentageFromGap",
            "AvsCalculator.monthlyLossFromGap",
        ),
        "the report widget must not format or derive an AVS amount, exact "
        "reduction, retirement total, or replacement rate",
    )
