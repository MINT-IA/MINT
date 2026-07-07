import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
DOCS = ROOT / "docs/codex"
CODEX_SPEC_FILES = (
    DOCS / "DATA_LEDGER.md",
    DOCS / "SCREEN_CONTRACTS.md",
    DOCS / "WIRING_GRAPH.mmd",
    DOCS / "DATA_QUEST.md",
    DOCS / "MAESTRO_FLOWS.md",
)
APP_DART = ROOT / "apps/mobile/lib/app.dart"
DATA_LEDGER = DOCS / "DATA_LEDGER.md"
SCREEN_CONTRACTS = DOCS / "SCREEN_CONTRACTS.md"
WIRING_GRAPH = DOCS / "WIRING_GRAPH.mmd"
DATA_QUEST = DOCS / "DATA_QUEST.md"
MAESTRO_FLOWS = DOCS / "MAESTRO_FLOWS.md"
AUDIT_REPORT = DOCS / "SPEC_REALITY_AUDIT_G1.md"
COACH_CHAT = ROOT / "services/backend/app/api/v1/endpoints/coach_chat.py"
COACH_TOOLS = ROOT / "services/backend/app/services/coach/coach_tools.py"
COACH_PROFILE_PROVIDER = (
    ROOT / "apps/mobile/lib/providers/coach_profile_provider.dart"
)
COACH_PROFILE = ROOT / "apps/mobile/lib/models/coach_profile.dart"
ANDROID_MANIFEST = ROOT / "apps/mobile/android/app/src/main/AndroidManifest.xml"
ANDROID_BUILD = ROOT / "apps/mobile/android/app/build.gradle"
IOS_INFO = ROOT / "apps/mobile/ios/Runner/Info.plist"
MAESTRO_F2 = ROOT / "apps/mobile/.maestro/f2_datablock_to_mortgage.yaml"


def _read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def _backend_allowlist() -> set[str]:
    source = _read(COACH_CHAT)
    match = re.search(
        r"_SAVE_FACT_ALLOWED_KEYS: set\[str\] = \{(?P<body>.*?)\n\}",
        source,
        re.DOTALL,
    )
    assert match is not None
    return set(re.findall(r'"([A-Za-z0-9]+)"', match.group("body")))


def _coach_tool_enum() -> set[str]:
    source = _read(COACH_TOOLS)
    save_fact = source.split('"name": "save_fact"', 1)[1]
    match = re.search(r'"enum": \[(?P<body>.*?)\]', save_fact, re.DOTALL)
    assert match is not None
    return set(re.findall(r'"([A-Za-z0-9]+)"', match.group("body")))


def _mapper_cases_to_wizard_keys() -> dict[str, set[str]]:
    source = _read(COACH_PROFILE_PROVIDER)
    mapper = source.split(
        "Map<String, dynamic> _mapFactKeyToAnswers", 1
    )[1].split("static num? _asNum", 1)[0]
    cases: dict[str, set[str]] = {}
    pending: list[str] = []
    collecting = False
    return_lines: list[str] = []

    for line in mapper.splitlines():
        case = re.search(r"case '([^']+)':", line)
        if case:
            pending.append(case.group(1))
            continue
        if "default:" in line:
            break
        if "return {" in line:
            collecting = True
            return_lines = [line]
        elif collecting:
            return_lines.append(line)

        if collecting and "};" in line:
            wizard_keys = set(
                re.findall(r"'([^']+)'\s*:", "\n".join(return_lines))
            )
            for fact_key in pending:
                cases[fact_key] = wizard_keys
            pending = []
            collecting = False
            return_lines = []

    return cases


def _wizard_keys_read_by_profile() -> set[str]:
    source = _read(COACH_PROFILE)
    from_wizard = source.split("factory CoachProfile.fromWizardAnswers", 1)[1]
    return set(re.findall(r"answers\['([^']+)'\]", from_wizard))


def test_codex_docs_are_audited_against_current_head_not_stale_baseline() -> None:
    for path in CODEX_SPEC_FILES:
        text = _read(path)
        assert "255373b" not in text, path
        assert "UNCHANGED on this branch" not in text, path
        assert "valid at HEAD" not in text, path
        assert "095eeaa32" in text, path


def test_data_ledger_doc_matches_current_save_fact_reality() -> None:
    backend_keys = _backend_allowlist()
    tool_keys = _coach_tool_enum()
    mapper = _mapper_cases_to_wizard_keys()
    read_keys = _wizard_keys_read_by_profile()

    unmapped = backend_keys - set(mapper)
    mapped_but_unread = {
        fact_key
        for fact_key, wizard_keys in mapper.items()
        if fact_key in backend_keys and not (wizard_keys & read_keys)
    }

    assert len(backend_keys) == 35
    assert backend_keys == tool_keys
    assert len(mapper) == 24
    assert unmapped == {
        "goal",
        "selfEmployedNetIncome",
        "has2ndPillar",
        "hasVoluntaryLpp",
        "hasDebt",
        "totalDebt",
        "spouseBirthYear",
        "spouseIncomeNetMonthly",
        "spouseAvsContributionYears",
        "hasAvsGaps",
        "avsContributionYears",
    }
    assert mapped_but_unread == {
        "commune",
        "gender",
        "employmentRate",
        "annualBonus",
        "pillar3aBalance",
        "totalSavings",
        "wealthEstimate",
    }
    assert len(unmapped | mapped_but_unread) == 18

    ledger = _read(DATA_LEDGER)
    report = _read(AUDIT_REPORT)
    assert "18 backend-writable keys are ineffective locally" in ledger
    assert "mapped-but-unread" in ledger
    assert "18 backend-writable keys are ineffective locally" in report


def test_wiring_and_screen_docs_mark_extra_and_scan_as_live_gaps() -> None:
    app = _read(APP_DART)
    wiring = _read(WIRING_GRAPH)
    screen = _read(SCREEN_CONTRACTS)

    assert "state.extra as ExtractionResult?" in app
    assert "state.extra as Map<String, dynamic>?" in app
    assert "Document non disponible" in app

    assert "G1 status @095eeaa32: FALSE" in wiring
    assert "G1 status @095eeaa32: PARTIAL" in wiring
    assert "LEGACY (5 live consumers" in wiring
    assert "Scan flow — TARGET, NOT LIVE YET" in screen
    assert "G1 live status at `095eeaa32`: false as code" in screen
    assert "Scan flow — REPAIRED" not in screen
    assert "`/rapport` — REPAIRED" not in screen
    assert "`/confidence` — REPAIRED" not in screen


def test_maestro_doc_matches_current_partial_setup() -> None:
    maestro_doc = _read(MAESTRO_FLOWS)
    f2 = _read(MAESTRO_F2)
    android_manifest = _read(ANDROID_MANIFEST)
    android_build = _read(ANDROID_BUILD)
    ios_info = _read(IOS_INFO)

    assert MAESTRO_F2.exists()
    assert "appId: ch.mint.app" in f2
    assert 'applicationId = "ch.mint.coach"' in android_build
    assert "CFBundleURLSchemes" in ios_info
    assert "<string>mint</string>" in ios_info
    assert 'android:scheme="mint"' not in android_manifest

    assert "partial Maestro setup exists" in maestro_doc
    assert "only checked-in Maestro flow" in maestro_doc
    assert "Android still has no `mint://` intent-filter" in maestro_doc
    assert "iOS has `CFBundleURLSchemes`" in maestro_doc
    assert "NO Maestro setup yet" not in maestro_doc
    assert "appId: ch.mint.coach" not in maestro_doc
    assert not re.search(r'openLink:\s*"mint://(?!/)', maestro_doc)
