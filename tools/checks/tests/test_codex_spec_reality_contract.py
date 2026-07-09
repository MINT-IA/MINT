import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
CODEX_DOCS = [
    ROOT / "docs/codex/DATA_LEDGER.md",
    ROOT / "docs/codex/SCREEN_CONTRACTS.md",
    ROOT / "docs/codex/WIRING_GRAPH.mmd",
    ROOT / "docs/codex/DATA_QUEST.md",
    ROOT / "docs/codex/MAESTRO_FLOWS.md",
]
APP_DART = ROOT / "apps/mobile/lib/app.dart"
COACH_CHAT = ROOT / "services/backend/app/api/v1/endpoints/coach_chat.py"
COACH_PROVIDER = ROOT / "apps/mobile/lib/providers/coach_profile_provider.dart"
DATA_LEDGER = ROOT / "docs/codex/DATA_LEDGER.md"
SCREEN_CONTRACTS = ROOT / "docs/codex/SCREEN_CONTRACTS.md"
WIRING_GRAPH = ROOT / "docs/codex/WIRING_GRAPH.mmd"
T1_SAVE_FACT_MAPPERS = {
    "goal": "q_main_goal",
    "selfEmployedNetIncome": "q_self_employed_income",
    "has2ndPillar": "q_has_pension_fund",
    "hasVoluntaryLpp": "q_has_voluntary_lpp",
    "spouseAvsContributionYears": "q_spouse_avs_contribution_years",
}


def _line_number(path: Path, needle: str) -> int:
    for index, line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
        if needle in line:
            return index
    raise AssertionError(f"{needle!r} not found in {path}")


def test_all_codex_specs_point_to_this_existing_gate() -> None:
    gate = "tools/checks/tests/test_codex_spec_reality_contract.py"
    assert (ROOT / gate).is_file()

    for doc_path in CODEX_DOCS:
        doc = doc_path.read_text(encoding="utf-8")
        assert gate in doc, f"{doc_path.name} must reference the executable gate"
        assert "095eeaa32" in doc, f"{doc_path.name} must name the audited baseline"
        assert "evidence snapshots, not evergreen truth" in doc, (
            f"{doc_path.name} must not present line refs as evergreen"
        )


def test_wiring_graph_still_declares_exactly_nine_invariants() -> None:
    graph = WIRING_GRAPH.read_text(encoding="utf-8")
    invariants = re.findall(r"^%% I-\d+ ", graph, flags=re.MULTILINE)

    assert len(invariants) == 9
    assert "I-1..I-9" in graph


def test_backend_save_fact_allowlist_count_matches_docs() -> None:
    source = COACH_CHAT.read_text(encoding="utf-8")
    match = re.search(
        r"_SAVE_FACT_ALLOWED_KEYS:\s*set\[str\]\s*=\s*\{(?P<body>.*?)\n\}",
        source,
        flags=re.DOTALL,
    )
    assert match is not None
    keys = re.findall(r'"([^"]+)"', match.group("body"))

    assert len(keys) == 35
    for doc_path in (ROOT / "docs/codex/DATA_LEDGER.md", WIRING_GRAPH):
        doc = doc_path.read_text(encoding="utf-8")
        assert "35-key allowlist" in doc or "35 keys" in doc


def test_data_ledger_unmapped_save_fact_claims_match_mobile_mapper() -> None:
    provider = COACH_PROVIDER.read_text(encoding="utf-8")
    ledger = DATA_LEDGER.read_text(encoding="utf-8")
    mapped_keys = set(re.findall(r"case '([^']+)':", provider))
    ledger_unmapped_keys = set(
        re.findall(r"\| `([^`]+)` \| ⚠ NO MAPPER CASE", ledger)
    )

    assert sorted(ledger_unmapped_keys & mapped_keys) == []


def test_data_ledger_records_t1_save_fact_repairs() -> None:
    provider = COACH_PROVIDER.read_text(encoding="utf-8")
    ledger = DATA_LEDGER.read_text(encoding="utf-8")

    for fact_key, wizard_key in T1_SAVE_FACT_MAPPERS.items():
        assert f"case '{fact_key}':" in provider
        assert wizard_key in provider
        assert f"| `{fact_key}` | `{wizard_key}`" in ledger

    assert "T-1 is complete" in ledger
    assert "0 backend-writable keys" in ledger


def test_screen_contract_scan_route_line_refs_match_router() -> None:
    contracts = SCREEN_CONTRACTS.read_text(encoding="utf-8")
    review_line = _line_number(APP_DART, "path: '/scan/review'")
    impact_line = _line_number(APP_DART, "path: '/scan/impact'")

    assert f"`/scan/review` ({review_line})" in contracts
    assert f"`/scan/impact` ({impact_line})" in contracts
