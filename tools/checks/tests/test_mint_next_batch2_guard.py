from __future__ import annotations

import shutil
import subprocess
import sys
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parents[3]
SCRIPT = REPO / "tools/checks/mint_next_batch2_guard.py"
BASE = Path("product/mint_next/batch2")


def copy(tmp_path: Path) -> None:
    shutil.copytree(REPO / BASE, tmp_path / BASE)
    target = tmp_path / "services/backend/app/services/fiscal"
    target.mkdir(parents=True)
    shutil.copy(REPO / "services/backend/app/services/fiscal/cantonal_comparator.py", target)
    oracle_target = tmp_path / "services/backend/tests/fixtures"
    oracle_target.mkdir(parents=True)
    shutil.copy(REPO / "services/backend/tests/fixtures/estv_oracle_2025.jsonl", oracle_target)
    shutil.copy(REPO / "services/backend/tests/test_estv_oracle.py", oracle_target.parent)


def run(root: Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run([sys.executable, str(SCRIPT), "--root", str(root)], capture_output=True, text=True)


def test_current_contract_passes() -> None:
    proc = run(REPO)
    assert proc.returncode == 0, proc.stderr


def mutate(tmp_path: Path, rel: str, old: str, new: str) -> subprocess.CompletedProcess[str]:
    copy(tmp_path)
    path = tmp_path / BASE / rel
    text = path.read_text(encoding="utf-8")
    assert old in text
    path.write_text(text.replace(old, new, 1), encoding="utf-8")
    return run(tmp_path)


def test_rejects_gross_salary_link(tmp_path: Path) -> None:
    proc = mutate(tmp_path, "fixture.yaml", "gross_income_chf: null", "gross_income_chf: 108000")
    assert proc.returncode == 1 and "gross salary" in proc.stderr


def test_rejects_taxable_input_mutation(tmp_path: Path) -> None:
    proc = mutate(tmp_path, "fixture.yaml", "baseline_taxable_income_icc_chf: 80000", "baseline_taxable_income_icc_chf: 108000")
    assert proc.returncode == 1 and "taxable-income inputs" in proc.stderr


def test_rejects_official_result_mutation(tmp_path: Path) -> None:
    proc = mutate(tmp_path, "fixture.yaml", "total_chf: 2104.00", "total_chf: 2500.00")
    assert proc.returncode == 1 and "arithmetic" in proc.stderr


def test_rejects_assumption_mutation(tmp_path: Path) -> None:
    proc = mutate(tmp_path, "fixture.yaml", "municipality: Lausanne", "municipality: Nyon")
    assert proc.returncode == 1 and "assumptions" in proc.stderr


@pytest.mark.parametrize("digest", [
    "34cb7f9f38ff8d8ea8e13b966986720a7a55b72947ad31224ce625209fcf3171",
    "e7e04fc78b69a08c09d160afd1083a2291c08fc8b53b3b4726d7bee273cc260a",
    "da5dc20f34e0dc7f4c47d218f253b3915880c10d04e370eaa224b6437a97e1a3",
    "a8a0ff6914523b9e5defa533759ee69daee892d3ab8669e21881de4728cfceaa",
])
def test_rejects_source_hash_mutation(tmp_path: Path, digest: str) -> None:
    proc = mutate(tmp_path, "sources.yaml", digest, "0" * 64)
    assert proc.returncode == 1 and "metadata" in proc.stderr


def test_rejects_source_support_mutation(tmp_path: Path) -> None:
    proc = mutate(tmp_path, "sources.yaml", "supports: [employee_with_pension_fund_3a_ceiling_7258]", "supports: [invented_claim]")
    assert proc.returncode == 1 and "support claims" in proc.stderr


def test_rejects_engine_hash_mutation(tmp_path: Path) -> None:
    proc = mutate(tmp_path, "evidence/mint-engine-capture-20260801.yaml", "12aff58f77da533a23aa898a6b9d3f4f1ffe21fe1d8f3092bb3df92b0a3ef4a4", "0" * 64)
    assert proc.returncode == 1 and "engine hash" in proc.stderr


def test_rejects_tolerance_widening(tmp_path: Path) -> None:
    proc = mutate(tmp_path, "evidence/mint-engine-capture-20260801.yaml", "per_component_tolerance_relative: 0.02", "per_component_tolerance_relative: 0.20")
    assert proc.returncode == 1 and "tolerance" in proc.stderr


def test_rejects_hidden_delta_gap(tmp_path: Path) -> None:
    proc = mutate(tmp_path, "evidence/mint-engine-capture-20260801.yaml", "delta_difference_chf: 62.59", "delta_difference_chf: 0.00")
    assert proc.returncode == 1 and "delta gap" in proc.stderr


def test_rejects_self_consistent_fake_engine_output(tmp_path: Path) -> None:
    proc = mutate(tmp_path, "evidence/mint-engine-capture-20260801.yaml", "total_chf: 15933.63", "total_chf: 15000.00")
    assert proc.returncode == 1 and "stored MINT engine evidence does not match runtime" in proc.stderr


def test_rejects_jos006_displacement(tmp_path: Path) -> None:
    proc = mutate(tmp_path, "scope.yaml", "displaced: false", "displaced: true")
    assert proc.returncode == 1 and "JOS-006" in proc.stderr


def test_rejects_official_request_mutation(tmp_path: Path) -> None:
    proc = mutate(tmp_path, "evidence/vd-calculator-capture-20260801.yaml", "civil_status_code: 1", "civil_status_code: 9")
    assert proc.returncode == 1 and "request" in proc.stderr


def test_rejects_official_submitted_input_mutation(tmp_path: Path) -> None:
    proc = mutate(tmp_path, "evidence/vd-calculator-capture-20260801.yaml", "taxable_income_icc_chf: 72742", "taxable_income_icc_chf: 99999")
    assert proc.returncode == 1 and "submitted" in proc.stderr


def test_rejects_official_component_mutation(tmp_path: Path) -> None:
    proc = mutate(tmp_path, "evidence/vd-calculator-capture-20260801.yaml", "icc_base_chf: 6389.00", "icc_base_chf: 1.00")
    assert proc.returncode == 1 and "capture" in proc.stderr


def test_rejects_claimed_error_mutation(tmp_path: Path) -> None:
    proc = mutate(tmp_path, "evidence/mint-engine-capture-20260801.yaml", "baseline_cantonal_communal_relative_error: 0.009164", "baseline_cantonal_communal_relative_error: 0.000001")
    assert proc.returncode == 1 and "recomputed" in proc.stderr


def test_rejects_source_url_mutation(tmp_path: Path) -> None:
    proc = mutate(tmp_path, "sources.yaml", "https://www.vd.ch/etat-droit-finances/impots/impots-pour-les-individus/calculer-mes-impots", "https://evil.example")
    assert proc.returncode == 1 and "metadata" in proc.stderr


def test_rejects_source_last_modified_mutation(tmp_path: Path) -> None:
    proc = mutate(tmp_path, "sources.yaml", "Thu, 02 Apr 2026 07:49:44 GMT", "Thu, 01 Jan 1970 00:00:00 GMT")
    assert proc.returncode == 1 and "last-modified" in proc.stderr


def test_rejects_fixture_capture_divergence(tmp_path: Path) -> None:
    proc = mutate(tmp_path, "fixture.yaml", "icc_chf: 14423.15", "icc_chf: 14523.15")
    assert proc.returncode == 1 and "capture" in proc.stderr


def test_rejects_existing_oracle_byte_mutation(tmp_path: Path) -> None:
    copy(tmp_path)
    path = tmp_path / "services/backend/tests/fixtures/estv_oracle_2025.jsonl"
    path.write_text(path.read_text() + "\n", encoding="utf-8")
    proc = run(tmp_path)
    assert proc.returncode == 1 and "oracle file hash" in proc.stderr


def test_rejects_missing_3a_credit_timing(tmp_path: Path) -> None:
    proc = mutate(tmp_path, "fixture.yaml", "pillar3a_contribution_credited_in_tax_year: true", "pillar3a_contribution_credited_in_tax_year: false")
    assert proc.returncode == 1 and "assumptions" in proc.stderr


def test_rejects_premature_verified_status(tmp_path: Path) -> None:
    proc = mutate(tmp_path, "fixture.yaml", "status: captured_unpromoted_fixture", "status: verified_official_fixture_not_product_connected")
    assert proc.returncode == 1 and "unpromoted" in proc.stderr
