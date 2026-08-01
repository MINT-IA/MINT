from __future__ import annotations

import shutil
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
SCRIPT = REPO / "tools/checks/mint_next_batch2_guard.py"
BASE = Path("product/mint_next/batch2")


def copy(tmp_path: Path) -> None:
    shutil.copytree(REPO / BASE, tmp_path / BASE)
    target = tmp_path / "services/backend/app/services/fiscal"
    target.mkdir(parents=True)
    shutil.copy(REPO / "services/backend/app/services/fiscal/cantonal_comparator.py", target)


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


def test_rejects_source_hash_mutation(tmp_path: Path) -> None:
    proc = mutate(tmp_path, "sources.yaml", "7640653ee007938ed3b1c5030b67acb32189949f55492236de53d2c2d1293eb8", "0" * 64)
    assert proc.returncode == 1 and "response hashes" in proc.stderr


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
    assert proc.returncode == 1 and ("runtime" in proc.stderr or "arithmetic" in proc.stderr)


def test_rejects_jos006_displacement(tmp_path: Path) -> None:
    proc = mutate(tmp_path, "scope.yaml", "displaced: false", "displaced: true")
    assert proc.returncode == 1 and "JOS-006" in proc.stderr
