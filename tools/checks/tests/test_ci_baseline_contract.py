import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
CI = ROOT / ".github/workflows/ci.yml"


def _ci_text() -> str:
    return CI.read_text(encoding="utf-8").replace("\r\n", "\n")


def _job_block(source: str, job_name: str) -> str:
    pattern = re.compile(
        rf"\n  {re.escape(job_name)}:\n"
        rf"(?P<body>.*?)(?=\n  [a-zA-Z0-9_-]+:\n|\Z)",
        re.DOTALL,
    )
    match = pattern.search(source)
    assert match is not None, f"{job_name} job missing from ci.yml"
    return match.group(0)


def test_ci_pull_request_trigger_is_not_branch_limited() -> None:
    ci = _ci_text()
    trigger = ci.split("concurrency:", maxsplit=1)[0]

    assert "pull_request:" in trigger
    assert "pull_request:\n    branches:" not in trigger


def test_backend_and_flutter_baselines_run_on_every_pr() -> None:
    ci = _ci_text()
    backend = _job_block(ci, "backend")
    flutter = _job_block(ci, "flutter")

    assert (
        "if: github.event_name == 'pull_request' || "
        "needs.changes.outputs.backend == 'true' || github.event_name == 'push'"
        in backend
    )
    assert "python -m pytest tests/ -q" in backend
    assert (
        "if: github.event_name == 'pull_request' || "
        "needs.changes.outputs.flutter == 'true' || github.event_name == 'push'"
        in flutter
    )
    assert "flutter analyze --no-fatal-warnings --no-fatal-infos" in flutter
    assert 'if [[ "$errors" -gt 0 ]]' in flutter
    assert "xargs -0 flutter test" in flutter


def test_ci_gate_observes_all_core_baseline_jobs() -> None:
    ci = _ci_text()
    gate = _job_block(ci, "ci-gate")

    for job in (
        "contracts-drift",
        "secret-scan",
        "repo-contract-tests",
        "backend",
        "flutter",
        "pii-log-gate",
        "route-registry-parity",
        "mint-routes-tests",
    ):
        assert job in gate
    assert 'contracts="${{ needs.contracts-drift.result }}"' in gate
    assert 'repo_contracts="${{ needs.repo-contract-tests.result }}"' in gate
    assert 'pii="${{ needs.pii-log-gate.result }}"' in gate
    assert '"$contracts" != "success"' in gate
    assert '"$repo_contracts" != "success"' in gate
    assert '"$pii" != "success"' in gate


def test_repo_contract_tests_run_in_ci() -> None:
    ci = _ci_text()
    repo_contracts = _job_block(ci, "repo-contract-tests")

    assert "Repository contract tests" in repo_contracts
    assert "python3 -m pytest tools/checks/tests/ -q" in repo_contracts


def test_dataviz_contract_gate_blocks_after_infra_g5() -> None:
    ci = _ci_text()
    flutter = _job_block(ci, "flutter")

    dataviz_step = flutter.split("Dataviz contract gate (Infra-G5)", maxsplit=1)[1]
    dataviz_step = dataviz_step.split("# \u2500\u2500\u2500 Phase 32", maxsplit=1)[0]

    assert "continue-on-error" not in dataviz_step
    assert "flutter test test/goldens/dataviz_contract_test.dart --reporter compact" in dataviz_step
