from __future__ import annotations

import importlib.util
import subprocess
import sys
from pathlib import Path
from typing import Any

REPO_ROOT = Path(__file__).resolve().parents[3]
SCRIPT = REPO_ROOT / "tools" / "checks" / "mint_variable_dictionary_lint.py"

NON_EMPTY_SCAN = {
    "source_lines": 10,
    "save_fact": 1,
    "profile_fields": 1,
    "extractor_keys": 1,
}


def _checker_module():
    spec = importlib.util.spec_from_file_location(
        "mint_variable_dictionary_lint", SCRIPT
    )
    assert spec is not None
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    sys.modules["mint_variable_dictionary_lint"] = module
    spec.loader.exec_module(module)
    return module


def _run(*args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, str(SCRIPT), "--root", str(REPO_ROOT), *args],
        capture_output=True,
        text=True,
        timeout=30,
    )


def _row(**overrides: Any) -> dict[str, Any]:
    module = _checker_module()
    row: dict[str, Any] = {
        "canonical_id": "birthYear",
        "profile_base_field": "birthYear",
        "profile_update_field": "birthYear",
        "save_fact_key": "birthYear",
        "extractor_key": "birthYear",
        "mobile_wizard_keys": ["q_birth_year"],
        "coach_profile_path": "CoachProfile.birthYear",
        "secure_storage_status": "sensitive",
        "source": "services/backend/app/api/v1/endpoints/coach_chat.py:_SAVE_FACT_ALLOWED_KEYS",
        "source_version": "static:test",
        "readiness_roles": {
            "rente_capital": "required",
            "logement": "not_required",
            "fiscal": "not_required",
            "calculation_owner_kind": "not_calculation",
        },
        "alias_status": "source_alias",
        "collection_permissions": {
            "rente_capital": "allowed_if_needed",
            "logement": "not_collected",
            "fiscal": "not_collected",
        },
    }
    row.update(overrides)
    assert tuple(row.keys()) == module.COLUMNS
    return row


def _codes(errors: list[Any]) -> set[str]:
    return {error.code for error in errors}


def test_real_dictionary_view_uses_exact_required_columns_and_sources() -> None:
    module = _checker_module()

    rows = module.build_dictionary(REPO_ROOT)

    assert rows, "real repo scan must produce dictionary rows"
    assert all(tuple(row.keys()) == module.COLUMNS for row in rows)
    birth_year = next(row for row in rows if row["canonical_id"] == "birthYear")
    assert birth_year["save_fact_key"] == "birthYear"
    assert birth_year["extractor_key"] == "birthYear"
    assert "apps/mobile/lib/models/coach_profile.dart" in birth_year["source"]
    assert "tools/checks/mint_variable_dictionary_lint.py" not in birth_year["source"]
    assert birth_year["source_version"]
    assert not str(birth_year["source_version"]).startswith("dictionary:")


def test_backend_only_financial_profile_field_does_not_get_invented_l1_owner() -> None:
    module = _checker_module()

    rows = module.build_dictionary(REPO_ROOT)
    household_income = next(
        row for row in rows if row["canonical_id"] == "householdGrossIncome"
    )

    assert (
        household_income["readiness_roles"]["calculation_owner_kind"]
        == "not_calculation"
    )


def test_dictionary_owned_row_is_rejected_as_source_of_truth() -> None:
    module = _checker_module()

    errors = module.lint_rows(
        [
            _row(
                source="tools/checks/mint_variable_dictionary_lint.py",
                source_version="dictionary:v1",
            )
        ],
        scan_counts=NON_EMPTY_SCAN,
    )

    assert "MVD002_SOURCE_OF_TRUTH" in _codes(errors)


def test_save_fact_without_binding_or_disposition_fails() -> None:
    module = _checker_module()

    errors = module.lint_rows(
        [
            _row(
                canonical_id="newFact",
                profile_base_field="",
                profile_update_field="",
                save_fact_key="newFact",
                extractor_key="newFact",
                mobile_wizard_keys=[],
                coach_profile_path="",
                secure_storage_status="not_applicable",
                alias_status="unmapped",
            )
        ],
        scan_counts=NON_EMPTY_SCAN,
    )

    assert "MVD003_SAVE_FACT_UNBOUND" in _codes(errors)


def test_sensitive_key_without_classification_fails() -> None:
    module = _checker_module()

    errors = module.lint_rows(
        [
            _row(
                canonical_id="q_gross_salary_annual",
                profile_base_field="",
                profile_update_field="",
                save_fact_key="",
                extractor_key="",
                mobile_wizard_keys=["q_gross_salary_annual"],
                coach_profile_path="CoachProfile.fromWizardAnswers.q_gross_salary_annual",
                secure_storage_status="unknown",
                alias_status="identity",
            )
        ],
        scan_counts=NON_EMPTY_SCAN,
    )

    assert "MVD004_SENSITIVE_UNCLASSIFIED" in _codes(errors)


def test_french_financial_key_without_classification_fails() -> None:
    module = _checker_module()

    errors = module.lint_rows(
        [
            _row(
                canonical_id="q_revenu_imposable",
                profile_base_field="",
                profile_update_field="",
                save_fact_key="",
                extractor_key="",
                mobile_wizard_keys=["q_revenu_imposable"],
                secure_storage_status="unknown",
                alias_status="identity",
            )
        ],
        scan_counts=NON_EMPTY_SCAN,
    )

    assert "MVD004_SENSITIVE_UNCLASSIFIED" in _codes(errors)


def test_active_calculation_variable_without_owner_fails() -> None:
    module = _checker_module()
    row = _row(
        canonical_id="pillar3aAnnual",
        readiness_roles={
            "rente_capital": "required",
            "logement": "not_required",
            "fiscal": "not_required",
            "calculation_owner_kind": "unknown",
        },
    )

    errors = module.lint_rows([row], scan_counts=NON_EMPTY_SCAN)

    assert "MVD005_CALC_OWNER_MISSING" in _codes(errors)


def test_signaletique_axis_rejects_detailed_unused_collection() -> None:
    module = _checker_module()
    row = _row(
        canonical_id="pillar3aBalance",
        readiness_roles={
            "rente_capital": "required",
            "logement": "not_required",
            "fiscal": "not_required",
            "calculation_owner_kind": "l1_mobile",
        },
        collection_permissions={
            "rente_capital": "allowed_if_needed",
            "logement": "required_if_needed",
            "fiscal": "not_collected",
        },
    )

    errors = module.lint_rows([row], scan_counts=NON_EMPTY_SCAN)

    assert "MVD006_SIGNALETIQUE_OVER_COLLECTION" in _codes(errors)


def test_uncovered_reg_key_fails_loud() -> None:
    module = _checker_module()
    row = _row(
        canonical_id="reg:dynamic.rate",
        profile_base_field="",
        profile_update_field="",
        save_fact_key="",
        extractor_key="",
        mobile_wizard_keys=[],
        coach_profile_path="",
        secure_storage_status="not_applicable",
        source="apps/mobile/lib/services/example.dart:12:reg()",
        source_version="regulatory:test",
        alias_status="unmapped",
        readiness_roles={
            "rente_capital": "optional",
            "logement": "not_required",
            "fiscal": "not_required",
            "calculation_owner_kind": "not_calculation",
        },
    )

    errors = module.lint_rows([row], scan_counts=NON_EMPTY_SCAN)

    assert "MVD007_REG_UNCOVERED" in _codes(errors)


def test_unknown_enum_value_fails_with_canonical_id_and_field() -> None:
    module = _checker_module()

    errors = module.lint_rows(
        [_row(alias_status="handwaved")],
        scan_counts=NON_EMPTY_SCAN,
    )

    assert "MVD008_ENUM" in _codes(errors)
    assert any(
        error.canonical_id == "birthYear" and error.field == "alias_status"
        for error in errors
    )


def test_empty_real_scan_is_rejected() -> None:
    module = _checker_module()

    errors = module.lint_rows(
        [],
        scan_counts={
            "source_lines": 0,
            "save_fact": 0,
            "profile_fields": 0,
            "extractor_keys": 0,
        },
    )

    assert "MVD001_EMPTY_SCAN" in _codes(errors)


def test_empty_mobile_or_reg_scan_is_rejected() -> None:
    module = _checker_module()

    errors = module.lint_rows(
        [_row()],
        scan_counts={
            "source_lines": 10,
            "save_fact": 1,
            "profile_fields": 1,
            "extractor_keys": 1,
            "mobile_wizard_keys": 0,
            "reg_keys": 0,
        },
    )

    assert "MVD001_EMPTY_SCAN" in _codes(errors)


def test_cli_check_passes_for_current_repo_sources() -> None:
    proc = _run("--check")

    assert proc.returncode == 0, proc.stderr
    assert "OK mint_variable_dictionary_lint" in proc.stderr
