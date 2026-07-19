from __future__ import annotations

import os
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
RUNNER = ROOT / "tools/simulator/patrol_return01_rvc_lpp_scan_return.sh"


def test_rvc_runtime_runner_exists_as_tracked_executable() -> None:
    assert RUNNER.is_file()
    assert os.access(RUNNER, os.X_OK)
    index_entry = subprocess.check_output(
        ["git", "ls-files", "--stage", "--", str(RUNNER.relative_to(ROOT))],
        cwd=ROOT,
        text=True,
    )
    assert index_entry.startswith("100755 "), index_entry


def test_rvc_runner_is_exact_sha_clean_and_joins_patrol_maestro_visual_proof() -> None:
    runner = RUNNER.read_text(encoding="utf-8")

    for token in (
        "HEAD must be clean before runtime evidence",
        "requested sha is not current HEAD",
        "runtime contract files must be tracked at HEAD",
        ".planning/runtime-evidence/phase-37/return-01-rvc",
        "test/patrol/g1_return01_rvc_lpp_scan_return_runtime_test.dart",
        ".maestro/g1_return01_rvc_lpp_scan_return.yaml",
        "MINT_G1_RETURN01_RVC_LPP_VISUAL_READY_V1",
        "maestro_with_watchdog.sh",
        '"caseId": "G1-RETURN-01-RVC-LPP"',
        '"patrolResult": "passed"',
        '"maestroResult": "passed"',
        "verify_runtime_sources_clean",
        "RVC LPP runtime evidence written",
    ):
        assert token in runner

    assert runner.index("wait_for_visual_marker") < runner.index(
        "maestro_with_watchdog.sh"
    )
    assert runner.index("maestro_with_watchdog.sh") < runner.index(
        "remove_visual_marker"
    )
