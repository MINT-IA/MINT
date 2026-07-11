import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
COACH_CHAT = ROOT / "services/backend/app/api/v1/endpoints/coach_chat.py"
COACH_PROVIDER = ROOT / "apps/mobile/lib/providers/coach_profile_provider.dart"
DATA_LEDGER = ROOT / "docs/codex/DATA_LEDGER.md"


def _backend_save_fact_allowlist() -> set[str]:
    source = COACH_CHAT.read_text(encoding="utf-8")
    match = re.search(
        r"_SAVE_FACT_ALLOWED_KEYS:\s*set\[str\]\s*=\s*\{(?P<body>.*?)\n\}",
        source,
        flags=re.DOTALL,
    )
    assert match is not None
    return set(re.findall(r'"([^"]+)"', match.group("body")))


def _mobile_save_fact_mapper_keys() -> set[str]:
    source = COACH_PROVIDER.read_text(encoding="utf-8")
    match = re.search(
        r"Map<String, dynamic> _mapFactKeyToAnswers"
        r"\(String factKey, dynamic value\) \{(?P<body>.*?)\n\s+default:",
        source,
        flags=re.DOTALL,
    )
    assert match is not None
    return set(re.findall(r"case '([^']+)':", match.group("body")))


def _data_ledger_allowlist_keys() -> set[str]:
    ledger = DATA_LEDGER.read_text(encoding="utf-8")
    match = re.search(r"### 3\.1 .*?(?=\n### 3\.8 )", ledger, flags=re.DOTALL)
    assert match is not None
    return {
        key
        for key, row in re.findall(
            r"^\| `([^`]+)` \|(?P<row>.*)$",
            match.group(0),
            flags=re.MULTILINE,
        )
        if "applySaveFact" in row
    }


def test_backend_mobile_and_data_ledger_save_fact_keys_match() -> None:
    allowlist_keys = _backend_save_fact_allowlist()
    mapper_keys = _mobile_save_fact_mapper_keys()
    ledger_keys = _data_ledger_allowlist_keys()

    assert len(allowlist_keys) == 36
    assert mapper_keys == allowlist_keys
    assert ledger_keys == allowlist_keys


def test_monthly_expenses_completion_marker_is_documented() -> None:
    ledger = DATA_LEDGER.read_text(encoding="utf-8")

    assert "`monthlyExpenses` is a **completion marker**" in ledger
    assert "`q_housing_cost_period_chf` and `q_lamal_premium_monthly_chf`" in ledger
    assert "must not unlock expense-sensitive projections" in ledger
    assert "`q_housing_cost_period_chf` is interpreted as a monthly housing charge" in ledger
    assert "income `q_pay_frequency` must not change housing charges" in ledger
