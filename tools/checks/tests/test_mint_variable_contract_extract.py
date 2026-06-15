from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[3]
SCRIPT = REPO_ROOT / "tools" / "checks" / "mint_variable_contract_extract.py"


def _run(*args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, str(SCRIPT), "--root", str(REPO_ROOT), *args],
        capture_output=True,
        text=True,
        timeout=30,
    )


def test_cli_json_freezes_current_variable_contract_snapshot() -> None:
    proc = _run("--json")

    assert proc.returncode == 0, proc.stderr
    snapshot = json.loads(proc.stdout)

    assert snapshot["profile"]["ProfileBase_count"] == 39
    assert snapshot["profile"]["ProfileUpdate_count"] == 42
    assert snapshot["profile"]["ProfileUpdate_only"] == [
        "householdGrossIncome",
        "spouseEmploymentStatus",
        "spouseSalaryGrossAnnual",
    ]
    assert snapshot["coach_save_fact"]["save_fact_count"] == 35
    assert snapshot["coach_save_fact"]["extractor_literal_count"] == 35
    assert snapshot["coach_save_fact"]["llm_tool_enum_count"] == 35
    assert snapshot["coach_save_fact"]["save_fact_minus_extractor"] == []
    assert snapshot["coach_save_fact"]["extractor_minus_save_fact"] == []
    assert snapshot["coach_save_fact"]["save_fact_minus_llm_tool_enum"] == []
    assert snapshot["coach_save_fact"]["llm_tool_enum_minus_save_fact"] == []
    assert snapshot["mobile_mapping"]["map_case_count"] == 35
    assert snapshot["mobile_mapping"]["save_fact_without_map_case"] == []
    assert snapshot["mobile_mapping"]["save_fact_explicitly_unsupported"] == [
        "wealthEstimate",
    ]
    assert snapshot["secure_wizard_store"]["static_sensitive_count"] == 93
    assert snapshot["onboarding_flush"]["completeAndFlushToProfile_key_count"] == 16
    assert snapshot["regulatory"]["backend_registry"]["count"] == 113
    assert snapshot["regulatory"]["backend_registry"]["active_count_on_2026_06_15"] == 103
    assert (
        snapshot["regulatory"]["backend_registry"]["version_hash_on_2026_06_15"]
        == "6eb0dcbd291cd0a175d0c6c22558cf609203f1966a5aaa07066e2c831599f98b"
    )
    assert snapshot["regulatory"]["dart_generated_snapshot"]["param_count"] == 103
    assert snapshot["regulatory"]["dart_generated_snapshot"]["effective_on"] == "2026-06-12"
    assert snapshot["regulatory"]["dart_reg_unique_key_count"] == 45
    assert snapshot["regulatory"]["dart_reg_exact_miss_count"] == 26


def test_cli_check_passes_for_current_repo_snapshot() -> None:
    proc = _run("--check")

    assert proc.returncode == 0
    assert "OK mint_variable_contract_extract" in proc.stderr


def test_snapshot_flags_interpolated_reg_keys_as_non_static() -> None:
    proc = _run("--json")
    snapshot = json.loads(proc.stdout)

    assert snapshot["regulatory"]["non_static_reg_keys"] == [
        'avs.max_annual_pension_${year >= avs13emeRenteAnneeDebut ? "13m" : "12m"}',
    ]


def test_snapshot_lists_secure_wizard_outputs_not_covered_by_static_or_prefix() -> None:
    proc = _run("--json")
    snapshot = json.loads(proc.stdout)

    assert snapshot["secure_wizard_store"][
        "mapped_wizard_outputs_not_covered_by_static_or_prefix"
    ] == [
        "q_canton",
        "q_employment_rate",
        "q_has_3a",
        "q_has_consumer_debt",
        "q_has_pension_fund",
        "q_main_goal",
        "q_net_income_period_source",
        "q_pay_frequency",
        "q_self_employed_net_income_annual_chf",
        "q_target_retirement_age",
    ]


def test_snapshot_classifies_profile_save_fact_write_scope_asymmetries() -> None:
    proc = _run("--json")
    snapshot = json.loads(proc.stdout)

    assert snapshot["profile_contract"]["write_only"] == [
        "householdGrossIncome",
        "spouseEmploymentStatus",
        "spouseSalaryGrossAnnual",
    ]
    assert snapshot["profile_contract"]["derived_mobile"] == [
        "annualBonus",
        "avoirLppObligatoire",
        "avoirLppSurobligatoire",
        "employmentRate",
        "incomeGrossMonthly",
        "incomeNetYearly",
    ]
    assert snapshot["profile_contract"]["read_only"] == []
    assert snapshot["profile_contract"]["profile_writable_not_coach_writable"] == [
        "isChurchMember",
        "legalForm",
        "nationality",
        "primaryActivity",
        "usTaxPerson",
    ]
    assert snapshot["profile_contract"]["out_of_scope"] == [
        "factfindCompletionIndex",
        "fragileModeEnteredAt",
        "n5IssuedThisWeek",
        "recentGravityEvents",
        "voiceCursorPreference",
    ]
    assert len(snapshot["profile_contract"]["coach_writable"]) == 35
    assert "annualBonus" in snapshot["profile_contract"]["coach_writable"]
    assert "wealthEstimate" in snapshot["profile_contract"]["coach_writable"]
    assert snapshot["profile_contract"][
        "unclassified_save_fact_without_ProfileBase"
    ] == []
    assert snapshot["profile_contract"][
        "unclassified_ProfileBase_without_save_fact"
    ] == []
