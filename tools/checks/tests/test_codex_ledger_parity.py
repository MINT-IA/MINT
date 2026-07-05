import ast
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
BACKEND_COACH = ROOT / "services/backend/app/api/v1/endpoints/coach_chat.py"
MOBILE_PROVIDER = ROOT / "apps/mobile/lib/providers/coach_profile_provider.dart"
MOBILE_PROFILE = ROOT / "apps/mobile/lib/models/coach_profile.dart"
BACKEND_CROSSWALK = ROOT / "services/backend/app/services/confidence/source_crosswalk.py"
DATA_LEDGER = ROOT / "docs/codex/DATA_LEDGER.md"
DATA_QUEST = ROOT / "docs/codex/DATA_QUEST.md"
WIRING_GRAPH = ROOT / "docs/codex/WIRING_GRAPH.mmd"

# Phase 1 freezes the existing coach/backend writable ledger surface. Phase 2
# can raise this count only by adding the key to backend allowlist, Flutter
# mapper, DATA_LEDGER, and the P0 registry in the same change.
FROZEN_SAVE_FACT_ALLOWLIST_COUNT = 40


def _backend_save_fact_keys() -> set[str]:
    text = BACKEND_COACH.read_text(encoding="utf-8")
    match = re.search(
        r"_SAVE_FACT_ALLOWED_KEYS:\s*set\[str\]\s*=\s*(\{.*?\n\})",
        text,
        re.S,
    )
    assert match, "_SAVE_FACT_ALLOWED_KEYS set not found"
    parsed = ast.literal_eval(match.group(1))
    assert isinstance(parsed, set)
    return parsed


def _mobile_mapper_cases() -> set[str]:
    text = MOBILE_PROVIDER.read_text(encoding="utf-8")
    start = text.index("Map<String, dynamic> _mapFactKeyToAnswers")
    end = text.index("static num? _asNum", start)
    return set(re.findall(r"case '([^']+)':", text[start:end]))


def _ledger_allowlist_keys() -> set[str]:
    text = DATA_LEDGER.read_text(encoding="utf-8")
    start = text.index("## 3. Ledger")
    end = text.index("## 4.", start)
    section = text[start:end]
    keys: set[str] = set()
    for line in section.splitlines():
        match = re.match(r"\| `([^`]+)` \|", line)
        if match and match.group(1) != "key":
            keys.add(match.group(1))
    return keys


def _mobile_profile_data_source_members() -> set[str]:
    text = MOBILE_PROFILE.read_text(encoding="utf-8")
    match = re.search(r"enum ProfileDataSource\s*\{(.*?)\n\}", text, re.S)
    assert match, "ProfileDataSource enum not found"
    return set(re.findall(r"^\s*([A-Za-z]\w*)\s*,", match.group(1), re.M))


def _backend_crosswalk_mobile_keys() -> set[str]:
    text = BACKEND_CROSSWALK.read_text(encoding="utf-8")
    match = re.search(
        r"_MOBILE_TO_BACKEND:\s*dict\[str,\s*DataSource\]\s*=\s*\{(.*?)\n\}",
        text,
        re.S,
    )
    assert match, "_MOBILE_TO_BACKEND map not found"
    return set(re.findall(r'"([^"]+)":\s*DataSource\.', match.group(1)))


def test_backend_mobile_and_ledger_allowlist_are_identical() -> None:
    backend = _backend_save_fact_keys()
    mobile = _mobile_mapper_cases()
    ledger = _ledger_allowlist_keys()

    assert len(backend) == FROZEN_SAVE_FACT_ALLOWLIST_COUNT, (
        "Phase 1 save_fact allowlist changed. Update backend allowlist, "
        "Flutter mapper, DATA_LEDGER, P0 registry, and this frozen count in "
        "the same change."
    )
    assert ledger == backend
    assert mobile == backend


def test_profile_data_source_enum_is_exhaustively_mapped_to_backend() -> None:
    assert _backend_crosswalk_mobile_keys() == _mobile_profile_data_source_members()


def test_data_quest_allowlist_count_matches_frozen_contract() -> None:
    text = DATA_QUEST.read_text(encoding="utf-8")

    assert f"({FROZEN_SAVE_FACT_ALLOWLIST_COUNT} keys" in text
    assert f"{FROZEN_SAVE_FACT_ALLOWLIST_COUNT}-key contract" in text
    assert "(35 keys" not in text
    assert "35-key contract" not in text
    assert "(36 keys" not in text
    assert "36-key contract" not in text
    assert "(37 keys" not in text
    assert "37-key contract" not in text


def test_wiring_graph_allowlist_count_matches_frozen_contract() -> None:
    text = WIRING_GRAPH.read_text(encoding="utf-8")

    assert f"save_fact {FROZEN_SAVE_FACT_ALLOWLIST_COUNT}-key allowlist" in text
    assert "save_fact 35-key allowlist" not in text
    assert "save_fact 36-key allowlist" not in text
    assert "save_fact 37-key allowlist" not in text
