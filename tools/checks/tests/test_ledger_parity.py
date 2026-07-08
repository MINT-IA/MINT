import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
DATA_LEDGER = ROOT / "docs/codex/DATA_LEDGER.md"
COACH_CHAT = ROOT / "services/backend/app/api/v1/endpoints/coach_chat.py"
COACH_TOOLS = ROOT / "services/backend/app/services/coach/coach_tools.py"
COACH_PROFILE_PROVIDER = (
    ROOT / "apps/mobile/lib/providers/coach_profile_provider.dart"
)
COACH_PROFILE = ROOT / "apps/mobile/lib/models/coach_profile.dart"


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
    )[1].split("static bool? _asBool", 1)[0]
    case_matches = list(re.finditer(r"case '([^']+)':", mapper))
    cases: dict[str, set[str]] = {}

    for index, match in enumerate(case_matches):
        fact_key = match.group(1)
        start = match.end()
        end = (
            case_matches[index + 1].start()
            if index + 1 < len(case_matches)
            else mapper.find("default:", start)
        )
        block = mapper[start:end]
        cases[fact_key] = set(
            re.findall(r"'((?:q|_coach)_[^']+)'\s*:", block)
        )

    return cases


def _wizard_keys_read_by_profile() -> set[str]:
    source = _read(COACH_PROFILE)
    from_wizard = source.split("factory CoachProfile.fromWizardAnswers", 1)[1]
    from_wizard = from_wizard.split("\n  static ", 1)[0]
    return set(re.findall(r"answers\['([^']+)'\]", from_wizard))


def _ledger_rows() -> dict[str, set[str]]:
    text = _read(DATA_LEDGER)
    section = text.split("## 3. Ledger", 1)[1].split("## 4.", 1)[0]
    rows: dict[str, set[str]] = {}

    for fact_key, wizard_cell in re.findall(
        r"^\| `([A-Za-z0-9]+)` \| ([^|]+) \|",
        section,
        re.MULTILINE,
    ):
        rows[fact_key] = set(
            re.findall(r"`((?:q|_coach)_[^`= ()]+)", wizard_cell)
        )

    return rows


def test_save_fact_allowlist_sets_match_the_ledger_contract() -> None:
    backend_keys = _backend_allowlist()
    tool_keys = _coach_tool_enum()
    mapper_keys = set(_mapper_cases_to_wizard_keys())
    ledger_keys = set(_ledger_rows())

    assert backend_keys == tool_keys
    assert backend_keys == mapper_keys
    assert backend_keys == ledger_keys
    assert len(backend_keys) == 35


def test_save_fact_mapper_targets_are_hydrated_by_coach_profile() -> None:
    read_keys = _wizard_keys_read_by_profile()
    dead_targets = {
        fact_key: sorted(wizard_keys - read_keys)
        for fact_key, wizard_keys in _mapper_cases_to_wizard_keys().items()
        if wizard_keys - read_keys
    }

    assert dead_targets == {}


def test_data_ledger_wizard_keys_match_the_mobile_mapper() -> None:
    mapper = _mapper_cases_to_wizard_keys()
    ledger = _ledger_rows()
    mismatches = {
        fact_key: {
            "ledger": sorted(ledger_keys),
            "mapper": sorted(mapper.get(fact_key, set())),
        }
        for fact_key, ledger_keys in ledger.items()
        if not ledger_keys <= mapper.get(fact_key, set())
    }

    assert mismatches == {}
