from __future__ import annotations

import dataclasses
import json
import re
import sys
from dataclasses import dataclass
from enum import Enum
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
MOBILE_PRODUCTION = ROOT / "apps/mobile/lib"
BACKEND_ROOT = ROOT / "services/backend"
BACKEND_MINIMAL_PROFILE = (
    BACKEND_ROOT / "app/services/onboarding/minimal_profile_service.py"
)
BACKEND_PREMIER_ECLAIRAGE = (
    BACKEND_ROOT / "app/services/onboarding/premier_eclairage_selector.py"
)
BACKEND_ONBOARDING_MODELS = (
    BACKEND_ROOT / "app/services/onboarding/onboarding_models.py"
)
BACKEND_ONBOARDING_ENDPOINT = BACKEND_ROOT / "app/api/v1/endpoints/onboarding.py"
BACKEND_ONBOARDING_SCHEMA = BACKEND_ROOT / "app/schemas/onboarding.py"
CANONICAL_OPENAPI = ROOT / "tools/openapi/mint.openapi.canonical.json"
COACH_PROFILE = ROOT / "apps/mobile/lib/models/coach_profile.dart"
FORECASTER = ROOT / "apps/mobile/lib/services/forecaster_service.dart"
MONTE_CARLO = ROOT / "apps/mobile/lib/services/financial_core/monte_carlo_service.dart"
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
LEGACY_PENSION_ACCESS_RE = re.compile(
    r"(?:\b[A-Za-z_]\w*\??\.)+renteAVSEstimeeMensuelle\b"
)
PENSION_PROXY_SHAPE_RE = re.compile(
    r"\b(?:avs)?(?:maxRente\w*|renteMax\w*|max(?:imum)?(?:Monthly)?Pension\w*|"
    r"fullRente\w*)\s*\*\s*"
    r"(?:_?(?:total)?(?:Contribution)?Years\w*|annees(?:Contribuees)?\w*)"
    r"\s*/\s*(?:44(?:\.0)?|\w*(?:fullContributionYears|"
    r"DureeCotisationComplete)\w*)",
    re.IGNORECASE,
)
CONTRIBUTION_RATIO_ASSIGNMENT_RE = re.compile(
    r"\b(?:final|var|double)\s+(?P<ratio>[A-Za-z_]\w*)\s*=\s*"
    r"[^;\n]{0,240}?"
    r"\b(?:years\w*|annees\w*|[A-Za-z_]\w+(?:years|annees)\w*)\s*/\s*"
    r"(?:44(?:\.0)?|fullContributionYears\w*|fullYears\w*|"
    r"[A-Za-z_]\w*DureeCotisationComplete\w*)"
    r"[^;\n]*;",
    re.IGNORECASE,
)
PENSION_MAX_IDENTIFIER_PATTERN = (
    r"(?:maxRente\w*|avsRenteMax\w*|renteMax\w*|"
    r"max(?:imum)?(?:Monthly)?Pension\w*|fullRente\w*)"
)
DART_NON_CODE_RE = re.compile(
    r"r?'''[\s\S]*?'''"
    r'|r?"""[\s\S]*?"""'
    r"|r?'(?:\\.|[^'\\])*'"
    r'|r?"(?:\\.|[^"\\])*"'
    r"|//[^\n]*"
    r"|/\*[\s\S]*?\*/"
)
PYTHON_NON_CODE_RE = re.compile(
    r"'''[\s\S]*?'''"
    r'|"""[\s\S]*?"""'
    r"|'(?:\\.|[^'\\])*'"
    r'|"(?:\\.|[^"\\])*"'
    r"|\#[^\n]*"
)


class AvsReadinessScope(str, Enum):
    SELF = "self"
    HOUSEHOLD_TOTAL = "householdTotal"
    MARITAL_CAP = "maritalCap"


class AvsConsumerMode(str, Enum):
    CERTIFIED_GAP = "certifiedGap"
    QUARANTINED = "quarantined"
    LOCAL_SCENARIO = "localScenario"


@dataclass(frozen=True)
class AvsSourceContract:
    path: str
    required_tokens: tuple[str, ...] = ()
    forbidden_tokens: tuple[str, ...] = ()
    signature: str | None = None


@dataclass(frozen=True)
class AvsConsumerContract:
    sources: tuple[AvsSourceContract, ...]
    scopes: tuple[AvsReadinessScope, ...]
    mode: AvsConsumerMode

    @property
    def paths(self) -> tuple[str, ...]:
        return tuple(source.path for source in self.sources)


@dataclass(frozen=True)
class AvsFlowViolation:
    code: str
    detail: str


@dataclass(frozen=True)
class SeededBehaviorCase:
    name: str
    source: str
    contract: AvsConsumerContract
    expected_codes: frozenset[str]


@dataclass(frozen=True)
class LegacyPensionBoundaryAllowance:
    path: str
    block_signatures: tuple[str, ...] = ()
    exact_accesses: tuple[str, ...] = ()


# This is an executable declared inventory. Direct legacy-pension reads are
# discovered independently below, so this manifest cannot make them disappear.
# Every source carries explicit proof of certified-gap use, quarantine, or a
# local scenario opt-in. Multi-file consumers are checked per source, never by
# concatenating unrelated files into one permissive token window.
AVS_CONSUMERS = {
    "coach_narrative": AvsConsumerContract(
        (
            AvsSourceContract(
                "apps/mobile/lib/services/coach_narrative_service.dart",
                required_tokens=(
                    "profile.avsGapEvidence",
                    "evidence.selfReady",
                    "evidence.selfCertifiedYears",
                    "evidence.householdTotalReady",
                ),
            ),
        ),
        (AvsReadinessScope.SELF, AvsReadinessScope.HOUSEHOLD_TOTAL),
        AvsConsumerMode.CERTIFIED_GAP,
    ),
    "bayesian_enricher": AvsConsumerContract(
        (
            AvsSourceContract(
                "apps/mobile/lib/services/financial_core/bayesian_enricher.dart",
                required_tokens=("profile.avsGapEvidence.selfCertifiedYears",),
            ),
        ),
        (AvsReadinessScope.SELF,),
        AvsConsumerMode.CERTIFIED_GAP,
    ),
    "monte_carlo": AvsConsumerContract(
        (
            AvsSourceContract(
                "apps/mobile/lib/services/financial_core/monte_carlo_service.dart",
                required_tokens=(
                    "RetirementIncomeScope.nonAvsOnly",
                    "avsIncluded: false",
                    "AvsOfficialPensionEvidence.selfFieldPath",
                ),
            ),
        ),
        (AvsReadinessScope.SELF, AvsReadinessScope.HOUSEHOLD_TOTAL),
        AvsConsumerMode.QUARANTINED,
    ),
    "forecaster": AvsConsumerContract(
        (
            AvsSourceContract(
                "apps/mobile/lib/services/forecaster_service.dart",
                required_tokens=(
                    "const double? revenuAvsIndividuelAnnuel = null",
                    "AvsOfficialPensionEvidence.selfFieldPath",
                    "AvsOfficialPensionEvidence.spouseFieldPath",
                ),
            ),
        ),
        (AvsReadinessScope.SELF, AvsReadinessScope.HOUSEHOLD_TOTAL),
        AvsConsumerMode.QUARANTINED,
    ),
    "retirement_projection": AvsConsumerContract(
        (
            AvsSourceContract(
                "apps/mobile/lib/services/retirement_projection_service.dart",
                required_tokens=(
                    "_officialAvsProjectionAvailable",
                    "static bool _officialAvsProjectionAvailable(CoachProfile _) => false",
                ),
            ),
        ),
        (AvsReadinessScope.SELF, AvsReadinessScope.HOUSEHOLD_TOTAL),
        AvsConsumerMode.QUARANTINED,
    ),
    "circle_scoring": AvsConsumerContract(
        (
            AvsSourceContract(
                "apps/mobile/lib/services/circle_scoring_service.dart",
                required_tokens=("profile?.avsGapEvidence", "selfCertifiedYears"),
            ),
        ),
        (AvsReadinessScope.SELF,),
        AvsConsumerMode.CERTIFIED_GAP,
    ),
    "response_card_pulse": AvsConsumerContract(
        (
            AvsSourceContract(
                "apps/mobile/lib/services/response_card_service.dart",
                required_tokens=("profile.avsGapEvidence.selfCertifiedYears",),
            ),
            AvsSourceContract(
                "apps/mobile/lib/services/cap_engine.dart",
                required_tokens=("case ResponseCardType.avsGap:",),
            ),
        ),
        (AvsReadinessScope.SELF,),
        AvsConsumerMode.CERTIFIED_GAP,
    ),
    "patrimoine": AvsConsumerContract(
        (
            AvsSourceContract(
                "apps/mobile/lib/widgets/profile/patrimoine_drawer_content.dart",
                required_tokens=("profile.avsGapEvidence.selfCertifiedYears",),
            ),
        ),
        (AvsReadinessScope.SELF,),
        AvsConsumerMode.CERTIFIED_GAP,
    ),
    "minimal_profile_mobile": AvsConsumerContract(
        (
            AvsSourceContract(
                "apps/mobile/lib/models/minimal_profile_models.dart",
                required_tokens=(
                    "final double? avsMonthlyRente",
                    "final double? totalMonthlyRetirement",
                    "final double? replacementRate",
                    "final double? retirementGapMonthly",
                ),
            ),
            AvsSourceContract(
                "apps/mobile/lib/services/minimal_profile_service.dart",
                required_tokens=(
                    "avsMonthlyRente: null",
                    "totalMonthlyRetirement: null",
                    "replacementRate: null",
                    "retirementGapMonthly: null",
                ),
                forbidden_tokens=("AvsCalculator.computeMonthlyRente",),
            ),
            AvsSourceContract(
                "apps/mobile/lib/services/api_service.dart",
                signature="static MinimalProfileResult parseMinimalProfileResponse(",
                required_tokens=(
                    "avsMonthlyRente: null",
                    "totalMonthlyRetirement: null",
                    "replacementRate: null",
                    "retirementGapMonthly: null",
                ),
            ),
            AvsSourceContract(
                "apps/mobile/lib/services/api_service.dart",
                signature="static Future<PremierEclairage> computeOnboardingPremierEclairage(",
                required_tokens=("parseOnboardingPremierEclairageResponse(",),
                forbidden_tokens=(
                    "PremierEclairageType.retirementGap",
                    "PremierEclairageType.retirementIncome",
                    "fallback: 'retirement_gap'",
                ),
            ),
            AvsSourceContract(
                "apps/mobile/lib/services/api_service.dart",
                signature="static PremierEclairage parseOnboardingPremierEclairageResponse({",
                required_tokens=(
                    "const supportedCategories",
                    "final isSupported = supportedCategories.contains(backendCategory)",
                    "final primaryNumber = isSupported",
                    "backendPrimaryNumber",
                    "salaryDerivedHourlyRate",
                ),
                forbidden_tokens=(
                    "PremierEclairageType.retirementGap",
                    "PremierEclairageType.retirementIncome",
                    "fallback: 'retirement_gap'",
                    "'retirement_gap'",
                    "'retirement_income'",
                ),
            ),
            AvsSourceContract(
                "apps/mobile/lib/services/premier_eclairage_selector.dart",
                required_tokens=("_selectNonRetirementAlternative",),
                forbidden_tokens=(
                    "_buildRetirementGapChoc",
                    "_buildRetirementIncomeChoc",
                ),
            ),
            AvsSourceContract(
                "apps/mobile/lib/providers/coach_profile_provider.dart",
                signature="Future<void> updateFromSmartFlow({",
                required_tokens=("q_avs_lacunes_status", "q_avs_arrival_year"),
                forbidden_tokens=(
                    "_coach_avs_rente_estimee",
                    "q_avs_contribution_years",
                    "_avs_years_clamped",
                    "MinimalProfileService.compute",
                ),
            ),
        ),
        (AvsReadinessScope.SELF,),
        AvsConsumerMode.QUARANTINED,
    ),
    "minimal_profile_backend": AvsConsumerContract(
        (
            AvsSourceContract(
                "services/backend/app/services/onboarding/minimal_profile_service.py",
                forbidden_tokens=("def _estimate_avs_monthly(",),
            ),
            AvsSourceContract(
                "services/backend/app/services/onboarding/premier_eclairage_selector.py",
                forbidden_tokens=(
                    "profile.projected_avs_monthly",
                    "profile.estimated_monthly_retirement",
                    "profile.estimated_replacement_ratio",
                    "_build_retirement_gap_choc",
                    "_build_retirement_income_choc",
                ),
            ),
            AvsSourceContract(
                "services/backend/app/services/onboarding/onboarding_models.py",
                required_tokens=(
                    "projected_avs_monthly: Optional[float]",
                    "estimated_replacement_ratio: Optional[float]",
                    "estimated_monthly_retirement: Optional[float]",
                    "retirement_gap_monthly: Optional[float]",
                ),
            ),
            AvsSourceContract(
                "services/backend/app/schemas/onboarding.py",
                required_tokens=(
                    "projected_avs_monthly: Optional[float]",
                    "estimated_replacement_ratio: Optional[float]",
                    "estimated_monthly_retirement: Optional[float]",
                    "retirement_gap_monthly: Optional[float]",
                ),
            ),
            AvsSourceContract(
                "services/backend/app/api/v1/endpoints/onboarding.py",
                required_tokens=(
                    "projected_avs_monthly=result.projected_avs_monthly",
                    "estimated_replacement_ratio=result.estimated_replacement_ratio",
                    "estimated_monthly_retirement=result.estimated_monthly_retirement",
                    "retirement_gap_monthly=result.retirement_gap_monthly",
                ),
            ),
        ),
        (AvsReadinessScope.SELF,),
        AvsConsumerMode.QUARANTINED,
    ),
    "expat_avs_gap_widget": AvsConsumerContract(
        (
            AvsSourceContract(
                "apps/mobile/lib/screens/expat_screen.dart",
                required_tokens=(
                    "int? _yearsAbroad;",
                    "_avsScenarioStarted = false",
                    "if (!_avsScenarioStarted) return;",
                    "if (yearsAbroad == null) return;",
                    "_avsScenarioStarted = true",
                    "scenarioStarted: true",
                    "_recalculateAvs",
                    "_yearsAbroad == null ? null : _startAvsScenario",
                ),
            ),
            AvsSourceContract(
                "apps/mobile/lib/widgets/coach/avs_gap_widget.dart",
                required_tokens=(
                    "required this.scenarioStarted",
                    "if (!scenarioStarted)",
                    "return const SizedBox.shrink()",
                ),
            ),
            AvsSourceContract(
                "apps/mobile/lib/services/expat_service.dart",
                required_tokens=(
                    "required bool scenarioStarted",
                    "if (!scenarioStarted) return null;",
                ),
            ),
        ),
        (AvsReadinessScope.SELF,),
        AvsConsumerMode.LOCAL_SCENARIO,
    ),
}

EXPECTED_CONSUMERS = {
    "coach_narrative",
    "bayesian_enricher",
    "monte_carlo",
    "forecaster",
    "retirement_projection",
    "circle_scoring",
    "response_card_pulse",
    "patrimoine",
    "minimal_profile_mobile",
    "minimal_profile_backend",
    "expat_avs_gap_widget",
}


LEGACY_PENSION_BOUNDARY_ALLOWANCES = (
    LegacyPensionBoundaryAllowance(
        "apps/mobile/lib/models/coach_profile.dart",
        block_signatures=(
            "const PrevoyanceProfile({",
            "PrevoyanceProfile copyWith({",
            "static Map<String, ProfileDataSource> _resolveDataSources(",
            "factory CoachProfile.fromWizardAnswers(",
        ),
        exact_accesses=("other.renteAVSEstimeeMensuelle",),
    ),
    LegacyPensionBoundaryAllowance(
        "apps/mobile/lib/providers/coach_profile_provider.dart",
        block_signatures=(
            "Future<void> updateFromRefresh({",
            "Future<void> updateFromAvsExtraction(",
            "Future<void> updateInline({",
            "Future<void> updateFromOpenBanking({",
        ),
    ),
)


def _consumer_sources() -> dict[
    str,
    tuple[AvsConsumerContract, tuple[tuple[AvsSourceContract, str], ...]],
]:
    assert set(AVS_CONSUMERS) == EXPECTED_CONSUMERS
    declared_callsites = [
        (source.path, source.signature)
        for contract in AVS_CONSUMERS.values()
        for source in contract.sources
    ]
    assert len(set(declared_callsites)) == len(declared_callsites), (
        "each production callsite must have one AVS consumer owner"
    )

    sources: dict[
        str,
        tuple[AvsConsumerContract, tuple[tuple[AvsSourceContract, str], ...]],
    ] = {}
    for name, contract in AVS_CONSUMERS.items():
        assert contract.sources, f"{name}: consumer source bundle is empty"
        assert contract.scopes, f"{name}: readiness scope is empty"
        parts: list[tuple[AvsSourceContract, str]] = []
        for source_contract in contract.sources:
            path = ROOT / source_contract.path
            assert path.is_file(), (
                f"{name}: missing declared consumer {source_contract.path}"
            )
            source = path.read_text(encoding="utf-8")
            if source_contract.signature is not None:
                source = _block_after_signature(source, source_contract.signature)
                assert source, (
                    f"{name}: missing or empty callsite "
                    f"{source_contract.path}::{source_contract.signature}"
                )
            parts.append((source_contract, source))
        sources[name] = (contract, tuple(parts))
    return sources


def _assert_tokens_absent(path: Path, tokens: tuple[str, ...], reason: str) -> None:
    source = path.read_text(encoding="utf-8")
    offenders = [token for token in tokens if token in source]
    assert not offenders, (
        f"{path.relative_to(ROOT).as_posix()}: {reason}; remove {offenders}"
    )


def _block_range_after_signature(source: str, signature: str) -> tuple[int, int] | None:
    signature_start = source.find(signature)
    if signature_start < 0:
        return None

    parameters_open = source.find("(", signature_start)
    if parameters_open < 0:
        return None

    parameter_depth = 0
    parameters_close: int | None = None
    for index in range(parameters_open, len(source)):
        char = source[index]
        if char == "(":
            parameter_depth += 1
        elif char == ")":
            parameter_depth -= 1
            if parameter_depth == 0:
                parameters_close = index
                break
    if parameters_close is None:
        return None

    # A field-formal constructor such as `const Model({ this.value, });` has
    # no body. Its parameter list is still the storage boundary that needs a
    # precise allowlist range.
    semicolon = source.find(";", parameters_close + 1)
    opening = source.find("{", parameters_close + 1)
    if semicolon >= 0 and (opening < 0 or semicolon < opening):
        return signature_start, semicolon + 1
    if opening < 0:
        return None

    depth = 0
    for index in range(opening, len(source)):
        char = source[index]
        if char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0:
                return signature_start, index + 1
    return signature_start, len(source)


def _block_after_signature(source: str, signature: str) -> str:
    block_range = _block_range_after_signature(source, signature)
    if block_range is None:
        return ""
    start, end = block_range
    return source[start:end]


def _line_for(source: str, offset: int) -> int:
    return source.count("\n", 0, offset) + 1


EMITTED_DETECTION_CODES = frozenset(
    {
        "missing_to_zero",
        "legacy_pension_missing_to_zero",
        "declared_status_to_zero",
        "declared_status_priced",
        "exact_chf_without_official_pension",
        "backend_exact_chf_without_official_pension",
        "exact_chf_from_gap_proxy",
        "exact_pension_from_contribution_years_proxy",
        "exact_pension_from_contribution_ratio_proxy",
        "uncertified_labeled_official",
        "ambiguous_household_readiness",
        "household_total_not_ready",
        "household_scope_uses_self_only",
        "marital_cap_not_ready",
        "gap_prerequisite_used_as_payable_cap",
        "self_result_uses_household_gate",
        "uncertified_gap_rendered",
        "scenario_auto_started",
        "scenario_renderer_not_opted_in",
        "missing_fact_to_scenario_default",
    }
)


def _fixture_contract(
    scopes: tuple[AvsReadinessScope, ...],
    mode: AvsConsumerMode = AvsConsumerMode.CERTIFIED_GAP,
) -> AvsConsumerContract:
    return AvsConsumerContract(
        (AvsSourceContract("fixture.dart", required_tokens=("fixture",)),),
        scopes,
        mode,
    )


def _indirect_pension_proxy_offsets(source: str) -> tuple[int, ...]:
    offsets: list[int] = []
    for assignment in CONTRIBUTION_RATIO_ASSIGNMENT_RE.finditer(source):
        ratio = re.escape(assignment.group("ratio"))
        multiplication = re.compile(
            rf"(?:\b{PENSION_MAX_IDENTIFIER_PATTERN}\s*\*\s*\b{ratio}\b|"
            rf"\b{ratio}\b\s*\*\s*\b{PENSION_MAX_IDENTIFIER_PATTERN})",
            re.IGNORECASE,
        )
        following = source[assignment.end() : assignment.end() + 1200]
        match = multiplication.search(following)
        if match is not None:
            offsets.append(assignment.end() + match.start())
    return tuple(offsets)


def _semantic_violations(
    source: str,
    contract: AvsConsumerContract,
) -> list[AvsFlowViolation]:
    """Find AVS value-flow violations rather than presence of one magic token."""

    violations: list[AvsFlowViolation] = []
    seen: set[tuple[str, int]] = set()

    def record(code: str, detail: str, offset: int = 0) -> None:
        identity = (code, offset)
        if identity in seen:
            return
        seen.add(identity)
        violations.append(
            AvsFlowViolation(code, f"line {_line_for(source, offset)}: {detail}")
        )

    # Nullable certificate-backed values must not be coalesced into a number.
    null_to_zero = re.compile(
        r"(?:selfCertifiedYears|spouseCertifiedYears|certified(?:Gap)?Years|"
        r"lacunesAVS|gapYears|q_(?:spouse_)?avs_(?:years_abroad|gaps))"
        r"[^;\n]{0,120}\?\?\s*0(?:\.0)?"
    )
    for match in null_to_zero.finditer(source):
        record(
            "missing_to_zero",
            "missing or uncertified AVS evidence is coalesced to zero",
            match.start(),
        )

    # Follow the simplest renamed-local flow across one statement. This closes
    # the common false green `final years = evidence.selfCertifiedYears;`
    # followed by `years ?? 0` without pretending to be a full Dart data-flow
    # analyser.
    alias_assignment = re.compile(
        r"\b(?:final|var|int\?|double\?)\s+(?P<alias>[A-Za-z_]\w*)\s*=\s*"
        r"[^;\n]*(?:selfCertifiedYears|spouseCertifiedYears|"
        r"certified(?:Gap)?Years|lacunesAVS|gapYears)[^;\n]*;"
    )
    for assignment in alias_assignment.finditer(source):
        alias = re.escape(assignment.group("alias"))
        following = source[assignment.end() : assignment.end() + 500]
        fallback = re.search(rf"\b{alias}\s*\?\?\s*0(?:\.0)?", following)
        if fallback:
            record(
                "missing_to_zero",
                "an alias of missing or uncertified AVS evidence is coalesced to zero",
                assignment.start(),
            )

    for match in re.finditer(
        r"renteAVSEstimeeMensuelle[^;\n]{0,160}\?\?\s*0(?:\.0)?", source
    ):
        record(
            "legacy_pension_missing_to_zero",
            "missing legacy AVS pension is converted to zero",
            match.start(),
        )

    for match in re.finditer(
        r"(?:case\s+['\"]no_gaps['\"]\s*:\s*return\s+0\b|"
        r"AvsGapStatus\.noGaps[\s\S]{0,180}?return\s+0\b)",
        source,
    ):
        record(
            "declared_status_to_zero",
            "a declaration of no gaps is converted into certified numeric zero",
            match.start(),
        )

    # Pricing questionnaire declarations is unsafe even when the resulting
    # integer is not written back to the profile.
    if "q_avs_lacunes_status" in source and (
        "calculateAvsGapsFromAnswers" in source
        or "reductionPercentageFromGap" in source
    ):
        record(
            "declared_status_priced",
            "raw AVS questionnaire status feeds a scored or priced result",
            source.index("q_avs_lacunes_status"),
        )

    # A synthetic pension is not made official by using certificate-backed gap
    # years: exact pension CHF requires the distinct reviewed official-pension
    # envelope. Explicit local scenarios are checked separately below.
    if contract.mode != AvsConsumerMode.LOCAL_SCENARIO:
        for match in re.finditer(r"AvsCalculator\.computeMonthlyRente\s*\(", source):
            record(
                "exact_chf_without_official_pension",
                "consumer synthesizes an exact AVS pension instead of reading "
                "the reviewed official-pension envelope",
                match.start(),
            )

    for match in re.finditer(
        r"(?:def\s+_estimate_avs_monthly\s*\(|"
        r"projected_avs_monthly\s*=\s*_estimate_avs_monthly\s*\()",
        source,
    ):
        record(
            "backend_exact_chf_without_official_pension",
            "backend minimal onboarding synthesizes an exact AVS pension "
            "without a reviewed owner-scoped envelope",
            match.start(),
        )

    exact_gap_amount = re.compile(
        r"(?:avsRenteMax\w*|fullRenteMonthly)[\s\S]{0,900}"
        r"(?:monthlyLoss|_renteLoss|PremierEclairage|formatChf)"
    )
    match = exact_gap_amount.search(source)
    if match and contract.mode != AvsConsumerMode.LOCAL_SCENARIO:
        record(
            "exact_chf_from_gap_proxy",
            "gap proxy is rendered as an exact CHF pension loss",
            match.start(),
        )

    if contract.mode != AvsConsumerMode.LOCAL_SCENARIO:
        proxy_code = _strip_dart_comments_and_strings(source)
        for match in PENSION_PROXY_SHAPE_RE.finditer(proxy_code):
            record(
                "exact_pension_from_contribution_years_proxy",
                "maximum AVS pension is prorated from contribution years "
                "without a reviewed official-pension envelope",
                match.start(),
            )
        for offset in _indirect_pension_proxy_offsets(proxy_code):
            record(
                "exact_pension_from_contribution_ratio_proxy",
                "a contribution-years ratio is multiplied by maximum AVS "
                "pension without a reviewed official-pension envelope",
                offset,
            )

    # Provenance words are output facts too. A source label cannot be upgraded
    # from a declaration unless the same local branch checks certificate-backed
    # evidence.
    false_certification = re.compile(
        r"(?:source|evidenceSource)\s*:\s*['\"][^'\"]*"
        r"(?:official|certified|extrait_avs)[^'\"]*['\"]",
        re.IGNORECASE,
    )
    certified_guard = re.compile(
        r"(?:selfCertifiedYears|spouseCertifiedYears|certified(?:Gap)?Years)"
        r"\s*!=\s*null|ProfileDataSource\.certificate"
    )
    for match in false_certification.finditer(source):
        preceding_branch = source[max(0, match.start() - 500) : match.start()]
        if not certified_guard.search(preceding_branch):
            record(
                "uncertified_labeled_official",
                "declared or inferred AVS data is labeled official/certified",
                match.start(),
            )

    # The backward-compatible alias erases whether the result is individual,
    # household-total, or a marital cap. New consumers must state the scope.
    for match in re.finditer(r"\.householdReady\b", source):
        record(
            "ambiguous_household_readiness",
            "householdReady alias hides householdTotal versus maritalCap scope",
            match.start(),
        )

    household_inputs = re.compile(
        r"spouseCertifiedYears|q_spouse_avs_|spouseGap(?:Years)?\b"
    )
    household_match = household_inputs.search(source)
    if household_match and "householdTotalReady" not in source:
        record(
            "household_total_not_ready",
            "a household AVS result reads partner evidence without householdTotalReady",
            household_match.start(),
        )

    if (
        contract.mode == AvsConsumerMode.CERTIFIED_GAP
        and AvsReadinessScope.HOUSEHOLD_TOTAL in contract.scopes
        and "householdTotalReady" not in source
    ):
        marker = source.find("selfReady")
        if marker < 0:
            marker = source.find("selfCertifiedYears")
        record(
            "household_scope_uses_self_only",
            "a declared household-total consumer does not enforce householdTotalReady",
            max(marker, 0),
        )

    if "maritalCapApplicable" in source and "maritalCapReady" not in source:
        record(
            "marital_cap_not_ready",
            "marital-cap applicability is treated as payable-cap readiness",
            source.index("maritalCapApplicable"),
        )

    payable_cap = re.search(r"maritalCapReady[\s\S]{0,500}?applyCoupleCap\s*\(", source)
    if payable_cap:
        record(
            "gap_prerequisite_used_as_payable_cap",
            "gap-evidence readiness is treated as sufficient to apply the "
            "payable legal marital cap",
            payable_cap.start(),
        )

    self_overgated = re.search(
        r"if\s*\([^)]*\.householdReady[^)]*\)"
        r"[\s\S]{0,700}?selfCertifiedYears!",
        source,
    )
    if self_overgated:
        record(
            "self_result_uses_household_gate",
            "an individual self result is blocked by household-total readiness",
            self_overgated.start(),
        )

    raw_gap_display = re.compile(r"\$\{[^}\n]*(?:lacunesAVS|gapYears)[^}\n]*\}")
    for match in raw_gap_display.finditer(source):
        guard_window = source[max(0, match.start() - 500) : match.start()]
        if not re.search(r"selfCertifiedYears\s*!=\s*null|selfReady", guard_window):
            record(
                "uncertified_gap_rendered",
                "raw AVS gap years are rendered without certificate readiness",
                match.start(),
            )

    if contract.mode == AvsConsumerMode.LOCAL_SCENARIO:
        init_state = _block_after_signature(source, "void initState()")
        auto_start = re.search(
            r"\b(?:_recalculateAvs|calculateAvsScenario|computeAvsScenario)\s*\(",
            init_state,
        )
        if auto_start:
            record(
                "scenario_auto_started",
                "AVS scenario is computed during init instead of explicit opt-in",
                source.find("void initState()") + auto_start.start(),
            )

        widget_call = re.search(r"(?:return|child\s*:)\s*AvsGapWidget\s*\(", source)
        has_opt_in_guard = re.search(
            r"if\s*\([^)]*(?:_avsScenarioStarted|scenarioStarted)[^)]*\)"
            r"[\s\S]{0,700}?AvsGapWidget\s*\(",
            source,
        )
        if widget_call and not has_opt_in_guard:
            record(
                "scenario_renderer_not_opted_in",
                "exact AVS scenario widget renders without an explicit start guard",
                widget_call.start(),
            )

        missing_age_default = re.search(
            r"(?:provider\.profile!?\??\.age|profile!?\??\.age|ageOrNull)"
            r"[^;\n]{0,100}\?\?\s*\d+\b",
            source,
        )
        if missing_age_default:
            record(
                "missing_fact_to_scenario_default",
                "missing profile age is silently replaced by a real-looking "
                "scenario default",
                missing_age_default.start(),
            )

    return violations


SEEDED_BEHAVIOR_CASES = (
    SeededBehaviorCase(
        "missing certified self years become zero",
        "final years = evidence.selfCertifiedYears ?? 0;",
        _fixture_contract((AvsReadinessScope.SELF,)),
        frozenset({"missing_to_zero"}),
    ),
    SeededBehaviorCase(
        "aliased certified years become zero on the next statement",
        """
final years = evidence.selfCertifiedYears;
return years ?? 0;
""",
        _fixture_contract((AvsReadinessScope.SELF,)),
        frozenset({"missing_to_zero"}),
    ),
    SeededBehaviorCase(
        "legacy pension missing becomes zero",
        "final avs = profile.prevoyance.renteAVSEstimeeMensuelle ?? 0.0;",
        _fixture_contract((AvsReadinessScope.SELF,)),
        frozenset({"legacy_pension_missing_to_zero"}),
    ),
    SeededBehaviorCase(
        "questionnaire declaration becomes certified zero",
        """
switch (answers['q_avs_lacunes_status']) {
  case 'no_gaps': return 0;
}
""",
        _fixture_contract((AvsReadinessScope.SELF,)),
        frozenset({"declared_status_to_zero"}),
    ),
    SeededBehaviorCase(
        "typed no-gaps declaration becomes certified zero",
        """
if (profile.avsGapStatus == AvsGapStatus.noGaps) {
  return 0;
}
""",
        _fixture_contract((AvsReadinessScope.SELF,)),
        frozenset({"declared_status_to_zero"}),
    ),
    SeededBehaviorCase(
        "questionnaire declaration feeds pricing",
        """
final status = answers['q_avs_lacunes_status'];
return calculateAvsGapsFromAnswers(status);
""",
        _fixture_contract((AvsReadinessScope.SELF,)),
        frozenset({"declared_status_priced"}),
    ),
    SeededBehaviorCase(
        "profile proxy becomes exact CHF pension",
        """
final avs = AvsCalculator.computeMonthlyRente(
  currentAge: profile.age,
  grossAnnualSalary: profile.revenuBrutAnnuel,
);
""",
        _fixture_contract((AvsReadinessScope.SELF,)),
        frozenset({"exact_chf_without_official_pension"}),
    ),
    SeededBehaviorCase(
        "backend minimal inputs synthesize exact AVS",
        """
def _estimate_avs_monthly(salary, years):
    return salary / years
projected_avs_monthly = _estimate_avs_monthly(gross_salary, years)
""",
        _fixture_contract((AvsReadinessScope.SELF,), AvsConsumerMode.QUARANTINED),
        frozenset({"backend_exact_chf_without_official_pension"}),
    ),
    SeededBehaviorCase(
        "gap proxy becomes exact CHF loss",
        """
final fullRenteMonthly = 2520.0;
final monthlyLoss = fullRenteMonthly * gapYears / 44;
return formatChf(monthlyLoss);
""",
        _fixture_contract((AvsReadinessScope.SELF,)),
        frozenset({"exact_chf_from_gap_proxy"}),
    ),
    SeededBehaviorCase(
        "contribution years proxy becomes exact monthly pension",
        """
const maxRenteMensuelle = 2520.0;
return (maxRenteMensuelle * contributionYears / 44).clamp(
  0,
  maxRenteMensuelle,
);
""",
        _fixture_contract((AvsReadinessScope.SELF,), AvsConsumerMode.QUARANTINED),
        frozenset({"exact_pension_from_contribution_years_proxy"}),
    ),
    SeededBehaviorCase(
        "aliased contribution ratio becomes exact monthly pension",
        """
final completeness = min(1.0, yearsInCh / fullContributionYears);
final maxRenteMensuelle = avsRenteMaxMensuelle;
final estimatedRente = maxRenteMensuelle * completeness;
""",
        _fixture_contract((AvsReadinessScope.SELF,), AvsConsumerMode.QUARANTINED),
        frozenset({"exact_pension_from_contribution_ratio_proxy"}),
    ),
    SeededBehaviorCase(
        "declaration receives official source label",
        """
final declared = profile.prevoyance.anneesContribuees;
return collapse(declared, source: 'official:extrait_avs');
""",
        _fixture_contract((AvsReadinessScope.SELF,)),
        frozenset({"uncertified_labeled_official"}),
    ),
    SeededBehaviorCase(
        "ambiguous household alias gates a result",
        """
final evidence = profile.avsGapEvidence;
if (!evidence.householdReady) return partial();
return renderYears(evidence.selfCertifiedYears!);
""",
        _fixture_contract((AvsReadinessScope.SELF,)),
        frozenset({"ambiguous_household_readiness"}),
    ),
    SeededBehaviorCase(
        "household total silently fills missing partner",
        """
final evidence = profile.avsGapEvidence;
if (!evidence.selfReady) return partial();
return evidence.selfCertifiedYears! + (evidence.spouseCertifiedYears ?? 0);
""",
        _fixture_contract((AvsReadinessScope.HOUSEHOLD_TOTAL,)),
        frozenset({"missing_to_zero", "household_total_not_ready"}),
    ),
    SeededBehaviorCase(
        "household contract uses only self readiness",
        """
final evidence = profile.avsGapEvidence;
if (!evidence.selfReady) return partial();
return renderYears(evidence.selfCertifiedYears!);
""",
        _fixture_contract((AvsReadinessScope.HOUSEHOLD_TOTAL,)),
        frozenset({"household_scope_uses_self_only"}),
    ),
    SeededBehaviorCase(
        "marital applicability becomes payable cap",
        """
final evidence = profile.avsGapEvidence;
if (evidence.maritalCapApplicable) return applyCoupleCap();
return partial();
""",
        _fixture_contract((AvsReadinessScope.MARITAL_CAP,)),
        frozenset({"marital_cap_not_ready"}),
    ),
    SeededBehaviorCase(
        "gap prerequisite directly applies payable marital cap",
        """
final evidence = profile.avsGapEvidence;
if (!evidence.maritalCapReady) return partial();
return applyCoupleCap();
""",
        _fixture_contract((AvsReadinessScope.MARITAL_CAP,)),
        frozenset({"gap_prerequisite_used_as_payable_cap"}),
    ),
    SeededBehaviorCase(
        "self result is over-gated by household alias",
        """
final evidence = profile.avsGapEvidence;
if (!evidence.householdReady) return partial();
return renderYears(evidence.selfCertifiedYears!);
""",
        _fixture_contract((AvsReadinessScope.SELF,)),
        frozenset({"self_result_uses_household_gate"}),
    ),
    SeededBehaviorCase(
        "uncertified raw gap is rendered",
        "return Text('${profile.prevoyance.lacunesAVS} years');",
        _fixture_contract((AvsReadinessScope.SELF,)),
        frozenset({"uncertified_gap_rendered"}),
    ),
    SeededBehaviorCase(
        "local AVS scenario looks like current reality on load",
        """
void initState() {
  super.initState();
  _recalculateAvs();
}
Widget build() {
  return AvsGapWidget(currentContributionYears: 20, currentAge: 40);
}
""",
        _fixture_contract((AvsReadinessScope.SELF,), AvsConsumerMode.LOCAL_SCENARIO),
        frozenset({"scenario_auto_started", "scenario_renderer_not_opted_in"}),
    ),
    SeededBehaviorCase(
        "local AVS scenario replaces missing age with 40",
        "final age = provider.profile?.age ?? 40;",
        _fixture_contract((AvsReadinessScope.SELF,), AvsConsumerMode.LOCAL_SCENARIO),
        frozenset({"missing_fact_to_scenario_default"}),
    ),
)


def test_declared_avs_consumer_contracts_are_executable_and_well_formed() -> None:
    inventory = _consumer_sources()
    assert {contract.mode for contract in AVS_CONSUMERS.values()} == set(
        AvsConsumerMode
    )
    declared_scopes = {
        scope for contract in AVS_CONSUMERS.values() for scope in contract.scopes
    }
    assert declared_scopes == {
        AvsReadinessScope.SELF,
        AvsReadinessScope.HOUSEHOLD_TOTAL,
    }
    assert AvsReadinessScope.MARITAL_CAP not in declared_scopes

    findings: list[str] = []
    for name, (contract, source_entries) in inventory.items():
        if contract.mode == AvsConsumerMode.CERTIFIED_GAP and not any(
            "avsGapEvidence" in token
            for source_contract, _ in source_entries
            for token in source_contract.required_tokens
        ):
            findings.append(f"{name}: certified-gap mode has no evidence token")

        for source_contract, source in source_entries:
            if (
                not source_contract.required_tokens
                and not source_contract.forbidden_tokens
            ):
                findings.append(
                    f"{name}: {source_contract.path} has no executable contract"
                )
            missing = [
                token
                for token in source_contract.required_tokens
                if token not in source
            ]
            present_forbidden = [
                token for token in source_contract.forbidden_tokens if token in source
            ]
            callsite = source_contract.path
            if source_contract.signature:
                callsite += f"::{source_contract.signature}"
            if missing:
                findings.append(f"{name}: {callsite} missing {missing}")
            if present_forbidden:
                findings.append(
                    f"{name}: {callsite} contains forbidden {present_forbidden}"
                )

    assert not findings, "AVS declared contracts are not executable:\n" + "\n".join(
        findings
    )


def test_each_emitted_detection_code_has_a_failing_negative_seed() -> None:
    observed_codes: set[str] = set()
    for case in SEEDED_BEHAVIOR_CASES:
        violations = _semantic_violations(case.source, case.contract)
        codes = {violation.code for violation in violations}
        observed_codes.update(codes)
        assert case.expected_codes <= codes, (
            f"{case.name}: expected {sorted(case.expected_codes)}, "
            f"observed {sorted(codes)}"
        )

    assert observed_codes == EMITTED_DETECTION_CODES


def test_safe_seeded_scope_flows_stay_green() -> None:
    safe_cases = (
        (
            _fixture_contract((AvsReadinessScope.SELF,)),
            """
final evidence = profile.avsGapEvidence;
if (!evidence.selfReady) return partialAndAsk();
return renderYears(evidence.selfCertifiedYears!);
""",
        ),
        (
            _fixture_contract((AvsReadinessScope.HOUSEHOLD_TOTAL,)),
            """
final evidence = profile.avsGapEvidence;
if (!evidence.householdTotalReady) return partialAndAsk();
return renderTotal(
  evidence.selfCertifiedYears!, evidence.spouseCertifiedYears!,
);
""",
        ),
        (
            _fixture_contract((AvsReadinessScope.MARITAL_CAP,)),
            """
final evidence = profile.avsGapEvidence;
if (!evidence.maritalCapReady) return partialAndAsk();
return continueToSeparateLegalCapEvaluation();
""",
        ),
        (
            _fixture_contract((AvsReadinessScope.SELF,), AvsConsumerMode.QUARANTINED),
            """
const education = 'final completeness = yearsInCh / fullContributionYears; '
    'final estimatedRente = maxRenteMensuelle * completeness;';
""",
        ),
        (
            _fixture_contract(
                (AvsReadinessScope.SELF,), AvsConsumerMode.LOCAL_SCENARIO
            ),
            """
bool _avsScenarioStarted = false;
void _startAvsScenario() {
  _avsScenarioStarted = true;
  _recalculateAvs();
}
Widget build() {
  if (_avsScenarioStarted) {
    return AvsGapWidget(
      currentContributionYears: assumedYears,
      currentAge: assumedAge,
    );
  }
  return startScenarioCta();
}
""",
        ),
    )

    for contract, source in safe_cases:
        assert _semantic_violations(source, contract) == []


def test_registered_avs_consumers_preserve_certified_null_behavior() -> None:
    findings: list[str] = []
    for name, (contract, source_entries) in _consumer_sources().items():
        for source_contract, source in source_entries:
            for violation in _semantic_violations(source, contract):
                callsite = source_contract.path
                if source_contract.signature:
                    callsite += f"::{source_contract.signature}"
                findings.append(
                    f"{name} [{contract.mode.value}; "
                    f"{', '.join(scope.value for scope in contract.scopes)}] "
                    f"{violation.code}: {violation.detail}; file={callsite}"
                )

    assert not findings, (
        "G1-LDG-06A certified-null behavioral hard floor is RED. "
        "Missing/uncertified AVS data must stay partial+ask and may not become "
        "zero, exact CHF, official/certified provenance, household-total or "
        "marital-cap readiness, or an auto-started real-looking scenario:\n"
        + "\n".join(findings)
    )


def _strip_dart_comments_and_strings(source: str) -> str:
    def blank(match: re.Match[str]) -> str:
        return "".join("\n" if char == "\n" else " " for char in match.group(0))

    return DART_NON_CODE_RE.sub(blank, source)


def _strip_production_comments_and_strings(path: Path, source: str) -> str:
    def blank(match: re.Match[str]) -> str:
        return "".join("\n" if char == "\n" else " " for char in match.group(0))

    if path.suffix == ".dart":
        return DART_NON_CODE_RE.sub(blank, source)
    if path.suffix == ".py":
        return PYTHON_NON_CODE_RE.sub(blank, source)
    raise AssertionError(f"unsupported production source type: {path}")


def _brace_block_range_from_opening(
    source: str,
    opening: int,
) -> tuple[int, int] | None:
    depth = 0
    for index in range(opening, len(source)):
        char = source[index]
        if char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0:
                return opening, index + 1
    return None


def _enclosing_class_block(source: str, offset: int) -> str:
    search_end = offset
    while search_end > 0:
        class_start = source.rfind("class ", 0, search_end)
        if class_start < 0:
            return ""
        opening = source.find("{", class_start, offset)
        if opening >= 0:
            block_range = _brace_block_range_from_opening(source, opening)
            if block_range is not None:
                start, end = block_range
                if start <= offset < end:
                    return source[start:end]
        search_end = class_start
    return ""


def _has_mechanical_local_scenario_opt_in(
    relative_path: str,
    source: str,
    offset: int,
) -> bool:
    for contract, source_entries in _consumer_sources().values():
        if contract.mode != AvsConsumerMode.LOCAL_SCENARIO:
            continue
        current_entries = [
            (source_contract, callsite_source)
            for source_contract, callsite_source in source_entries
            if source_contract.path == relative_path
        ]
        if not current_entries:
            continue
        if any(
            token not in callsite_source
            for source_contract, callsite_source in source_entries
            for token in source_contract.required_tokens
        ):
            continue

        enclosing_class = _enclosing_class_block(source, offset)
        if not enclosing_class:
            continue
        if not re.search(
            r"if\s*\(\s*!\s*(?:widget\.)?scenarioStarted\s*\)",
            enclosing_class,
        ):
            continue
        return True
    return False


def _legacy_pension_access_is_allowed(
    relative_path: str,
    source: str,
    match: re.Match[str],
) -> bool:
    allowance = next(
        (
            candidate
            for candidate in LEGACY_PENSION_BOUNDARY_ALLOWANCES
            if candidate.path == relative_path
        ),
        None,
    )
    if allowance is None:
        return False
    if match.group(0) in allowance.exact_accesses:
        return True
    for signature in allowance.block_signatures:
        block_range = _block_range_after_signature(source, signature)
        assert block_range is not None, (
            f"stale legacy-pension boundary allowance: {relative_path}::{signature}"
        )
        start, end = block_range
        if start <= match.start() < end:
            return True
    return False


def test_no_unreviewed_mobile_consumer_reads_legacy_avs_pension() -> None:
    scanner_seed = """
// profile.prevoyance.renteAVSEstimeeMensuelle
const label = 'profile.prevoyance.renteAVSEstimeeMensuelle';
/* spouse.prevoyance.renteAVSEstimeeMensuelle */
final live = profile.prevoyance.renteAVSEstimeeMensuelle;
"""
    scanner_matches = LEGACY_PENSION_ACCESS_RE.findall(
        _strip_dart_comments_and_strings(scanner_seed)
    )
    assert scanner_matches == ["profile.prevoyance.renteAVSEstimeeMensuelle"]

    findings: list[str] = []
    for path in sorted(MOBILE_PRODUCTION.rglob("*.dart")):
        original = path.read_text(encoding="utf-8")
        source = _strip_dart_comments_and_strings(original)
        relative_path = path.relative_to(ROOT).as_posix()
        for match in LEGACY_PENSION_ACCESS_RE.finditer(source):
            if _legacy_pension_access_is_allowed(relative_path, source, match):
                continue
            line = _line_for(source, match.start())
            excerpt = original.splitlines()[line - 1].strip()
            findings.append(f"{relative_path}:{line}: {excerpt}")

    assert not findings, (
        "legacy `renteAVSEstimeeMensuelle` has no reviewed official-pension "
        "envelope and may be read only by the explicit model/provider storage "
        "boundaries. Live consumers must stay partial:\n" + "\n".join(findings)
    )


def test_repo_wide_production_has_no_unreviewed_exact_pension_proxy_shape() -> None:
    production_files = list(MOBILE_PRODUCTION.rglob("*.dart")) + list(
        (BACKEND_ROOT / "app").rglob("*.py")
    )
    findings: list[str] = []
    for path in sorted(production_files):
        relative_path = path.relative_to(ROOT).as_posix()
        original = path.read_text(encoding="utf-8")
        source = _strip_production_comments_and_strings(path, original)
        for match in PENSION_PROXY_SHAPE_RE.finditer(source):
            if _has_mechanical_local_scenario_opt_in(
                relative_path,
                source,
                match.start(),
            ):
                continue
            line = _line_for(source, match.start())
            excerpt = original.splitlines()[line - 1].strip()
            findings.append(
                "exact_pension_from_contribution_years_proxy: "
                f"{relative_path}:{line}: {excerpt}"
            )
        for offset in _indirect_pension_proxy_offsets(source):
            if _has_mechanical_local_scenario_opt_in(
                relative_path,
                source,
                offset,
            ):
                continue
            line = _line_for(source, offset)
            excerpt = original.splitlines()[line - 1].strip()
            findings.append(
                "exact_pension_from_contribution_ratio_proxy: "
                f"{relative_path}:{line}: {excerpt}"
            )

    assert not findings, (
        "an exact AVS pension proxy derived directly or through an intermediate "
        "contribution-years ratio is forbidden repo-wide. A local-scenario name "
        "or file allowlist is insufficient: the proxy must be inside a guarded "
        "scenario class whose full declared contract proves explicit user opt-in. "
        "Otherwise keep the result unknown until a reviewed owner-scoped "
        "official-pension envelope exists:\n" + "\n".join(findings)
    )


def test_avs_consumers_never_turn_missing_certified_years_into_zero() -> None:
    names_by_path = {
        path: name
        for name, contract in AVS_CONSUMERS.items()
        for path in contract.paths
    }
    fallbacks: list[str] = []
    _consumer_sources()
    for path in sorted(MOBILE_PRODUCTION.rglob("*.dart")):
        source = path.read_text(encoding="utf-8")
        relative_path = path.relative_to(ROOT).as_posix()
        for match in CERTIFIED_NULL_FALLBACK_RE.finditer(source):
            line = source.count("\n", 0, match.start()) + 1
            name = names_by_path.get(relative_path, "undeclared_consumer")
            fallbacks.append(f"{name}: {relative_path}:{line}: {match.group(0)}")

    assert not fallbacks, (
        "certified AVS null must remain unknown; "
        f"found {len(fallbacks)} production `lacunesAVS ?? 0` fallbacks:\n"
        + "\n".join(fallbacks)
    )


def test_coach_profile_exposes_avs_gap_evidence_contract() -> None:
    source = COACH_PROFILE.read_text(encoding="utf-8")

    assert re.search(r"\bclass\s+AvsGapEvidence\b", source), (
        "coach_profile.dart must declare class AvsGapEvidence"
    )
    assert re.search(r"\bAvsGapEvidence\??\s+get\s+avsGapEvidence\b", source), (
        "CoachProfile must expose an avsGapEvidence getter"
    )
    assert "bool get selfReady" in source
    assert "bool get householdTotalReady" in source
    assert "bool get maritalCapReady" in source


def _unwrap_decorated_endpoint(endpoint: object) -> object:
    while hasattr(endpoint, "__wrapped__"):
        endpoint = endpoint.__wrapped__  # type: ignore[attr-defined]
    return endpoint


def test_backend_minimal_profile_service_schema_endpoint_and_selector_fail_closed() -> (
    None
):
    backend_path = str(BACKEND_ROOT)
    if backend_path not in sys.path:
        sys.path.insert(0, backend_path)

    from app.api.v1.endpoints.onboarding import (  # noqa: PLC0415
        compute_premier_eclairage,
        compute_profile,
    )
    from app.schemas.onboarding import MinimalProfileRequest  # noqa: PLC0415
    from app.services.onboarding.minimal_profile_service import (  # noqa: PLC0415
        compute_minimal_profile,
    )
    from app.services.onboarding.onboarding_models import (  # noqa: PLC0415
        MinimalProfileInput,
    )
    from app.services.onboarding.premier_eclairage_selector import (  # noqa: PLC0415
        select_premier_eclairage,
    )

    avs_dependent_fields = (
        "projected_avs_monthly",
        "estimated_monthly_retirement",
        "estimated_replacement_ratio",
        "retirement_gap_monthly",
    )
    service_result = compute_minimal_profile(
        MinimalProfileInput(
            age=52,
            gross_salary=125_000,
            canton="GE",
            household_type="couple",
            nationality_group="EU",
            nationality_country="FR",
            arrival_age=31,
            current_savings=80_000,
            existing_3a=0,
            existing_lpp=350_000,
            lpp_caisse_type="complementaire",
        )
    )
    assert {
        field: getattr(service_result, field) for field in avs_dependent_fields
    } == {field: None for field in avs_dependent_fields}

    # A hand-built legacy result must not reactivate a retirement choice in the
    # selector. This makes quarantine a behavior rather than a source-token claim.
    legacy_result = dataclasses.replace(
        service_result,
        projected_avs_monthly=1_200,
        estimated_monthly_retirement=2_100,
        estimated_replacement_ratio=0.25,
        retirement_gap_monthly=6_200,
    )
    legacy_choc = select_premier_eclairage(
        legacy_result,
        stress_type="stress_retraite",
    )
    assert legacy_choc.category not in {"retirement_gap", "retirement_income"}
    assert (
        "avs"
        not in " ".join(
            (
                legacy_choc.display_text,
                legacy_choc.explanation_text,
                legacy_choc.action_text,
            )
        ).lower()
    )

    request = MinimalProfileRequest(
        age=52,
        grossSalary=125_000,
        canton="GE",
        householdType="couple",
        nationalityGroup="EU",
        nationalityCountry="FR",
        arrivalAge=31,
        currentSavings=80_000,
        existing3a=0,
        existingLpp=350_000,
        lppCaisseType="complementaire",
        stressType="stress_retraite",
    )
    endpoint = _unwrap_decorated_endpoint(compute_profile)
    endpoint_response = endpoint(None, request)  # type: ignore[operator]
    payload = endpoint_response.model_dump(by_alias=True)
    assert {
        "projectedAvsMonthly": payload["projectedAvsMonthly"],
        "estimatedMonthlyRetirement": payload["estimatedMonthlyRetirement"],
        "estimatedReplacementRatio": payload["estimatedReplacementRatio"],
        "retirementGapMonthly": payload["retirementGapMonthly"],
    } == {
        "projectedAvsMonthly": None,
        "estimatedMonthlyRetirement": None,
        "estimatedReplacementRatio": None,
        "retirementGapMonthly": None,
    }

    premier_endpoint = _unwrap_decorated_endpoint(compute_premier_eclairage)
    premier_response = premier_endpoint(None, request)  # type: ignore[operator]
    premier_payload = premier_response.model_dump(by_alias=True)
    assert premier_payload["category"] not in {
        "retirement_gap",
        "retirement_income",
    }
    assert (
        "avs"
        not in " ".join(
            (
                premier_payload["displayText"],
                premier_payload["explanationText"],
                premier_payload["actionText"],
            )
        ).lower()
    )


def test_canonical_openapi_keeps_avs_dependent_fields_required_nullable() -> None:
    schema = json.loads(CANONICAL_OPENAPI.read_text(encoding="utf-8"))["components"][
        "schemas"
    ]["MinimalProfileResponse"]
    for field in (
        "projectedAvsMonthly",
        "estimatedMonthlyRetirement",
        "estimatedReplacementRatio",
        "retirementGapMonthly",
    ):
        variants = schema["properties"][field].get("anyOf", ())
        assert {variant.get("type") for variant in variants} == {"number", "null"}
        assert field in schema["required"]


def test_legacy_avs_pension_paths_are_centralized_but_not_certified() -> None:
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
