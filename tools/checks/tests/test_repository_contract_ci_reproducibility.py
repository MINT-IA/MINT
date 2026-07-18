from __future__ import annotations

import subprocess
from pathlib import Path

import pytest


ROOT = Path(__file__).resolve().parents[3]
CI = ROOT / ".github/workflows/ci.yml"
RUNTIME_SCRIPTS = (
    "tools/simulator/patrol_bnd05_document_reference_process_death.sh",
    "tools/simulator/patrol_coach01_inline_amount.sh",
    "tools/simulator/patrol_lpp_capital_notice_process_death.sh",
)


def _repository_contract_job() -> str:
    source = CI.read_text(encoding="utf-8")
    start = source.index("  repository-contract-tests:")
    end = source.index("\n  # ─── Phase 32", start)
    return source[start:end]


def _flutter_job() -> str:
    source = CI.read_text(encoding="utf-8")
    start = source.index("\n  flutter:\n    name:") + 1
    end = source.index("\n  # ─── Phase 32", start)
    return source[start:end]


def test_repository_contract_job_has_full_history_and_installs_backend() -> None:
    job = _repository_contract_job()
    assert "fetch-depth: 0" in job
    install = next(line for line in job.splitlines() if "pip install" in line)
    assert "pytest" in install
    assert "-e services/backend" in install


def test_flutter_services_job_installs_pdf_text_extraction_tooling() -> None:
    job = _flutter_job()
    assert "Install PDF text extraction tooling" in job
    assert "if: matrix.shard == 'services'" in job
    assert "sudo apt-get update" in job
    assert "poppler-utils" in job


@pytest.mark.parametrize("relative_path", RUNTIME_SCRIPTS)
def test_runtime_contract_scripts_are_executable_in_git(
    relative_path: str,
) -> None:
    stage = subprocess.run(
        ["git", "-C", str(ROOT), "ls-files", "--stage", "--", relative_path],
        check=True,
        capture_output=True,
        text=True,
    ).stdout
    assert stage.startswith("100755 "), f"{relative_path} is not executable in Git"
