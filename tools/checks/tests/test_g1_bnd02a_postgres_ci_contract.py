from pathlib import Path

import yaml


ROOT = Path(__file__).resolve().parents[3]
CI = ROOT / ".github" / "workflows" / "ci.yml"
JOB_NAME = "partner-accountability-postgres"
POSTGRES_URL = (
    "postgresql://mint_ci:mint_ci_${{ github.run_id }}@127.0.0.1:5432/mint_ci"
)
TARGET_TEST = "tests/postgres/test_partner_accountability_postgres.py"


def _workflow() -> dict:
    return yaml.safe_load(CI.read_text(encoding="utf-8"))


def _postgres_step(job: dict) -> dict:
    matching = [step for step in job["steps"] if TARGET_TEST in step.get("run", "")]
    assert len(matching) == 1
    return matching[0]


def test_ci_routes_backend_changes_to_a_real_postgres_lane() -> None:
    workflow = _workflow()
    changes = workflow["jobs"]["changes"]

    assert changes["outputs"]["postgres"] == "${{ steps.filter.outputs.postgres }}"
    filters = changes["steps"][1]["with"]["filters"]
    assert "postgres:" in filters
    assert "'services/backend/**'" in filters
    assert "'.github/workflows/ci.yml'" in filters
    assert "'tools/checks/tests/test_g1_bnd02a_postgres_ci_contract.py'" in filters

    job = workflow["jobs"][JOB_NAME]
    assert job["needs"] == ["changes"]
    assert "needs.changes.outputs.postgres == 'true'" in job["if"]
    assert "github.event_name == 'push'" in job["if"]

    ci_gate = workflow["jobs"]["ci-gate"]
    assert JOB_NAME in ci_gate["needs"]
    gate_script = ci_gate["steps"][0]["run"]
    assert (
        'partner_postgres="${{ needs.partner-accountability-postgres.result }}"'
        in gate_script
    )
    assert '[[ "$partner_postgres" == "skipped" ]] && partner_postgres="success"' in (
        gate_script
    )
    assert '[[ "$partner_postgres" != "success" ]]' in gate_script


def test_postgres_lane_is_ephemeral_bounded_and_health_checked() -> None:
    job = _workflow()["jobs"][JOB_NAME]

    assert job["runs-on"] == "ubuntu-latest"
    assert job["timeout-minutes"] <= 15
    assert job["permissions"] == {"contents": "read"}

    postgres = job["services"]["postgres"]
    assert postgres["image"] == "postgres:18.1-alpine"
    assert postgres["env"] == {
        "POSTGRES_DB": "mint_ci",
        "POSTGRES_USER": "mint_ci",
        "POSTGRES_PASSWORD": "mint_ci_${{ github.run_id }}",
        "POSTGRES_INITDB_ARGS": "--auth-host=scram-sha-256",
    }
    assert postgres["ports"] == ["5432:5432"]
    options = postgres["options"]
    for required in (
        'pg_isready -U mint_ci -d mint_ci',
        "--health-interval 10s",
        "--health-timeout 5s",
        "--health-retries 5",
    ):
        assert required in options
    assert "POSTGRES_HOST_AUTH_METHOD" not in postgres["env"]


def test_postgres_lane_runs_the_exact_gate_without_skip_or_soft_failure() -> None:
    job = _workflow()["jobs"][JOB_NAME]
    step = _postgres_step(job)

    assert step["working-directory"] == "services/backend"
    assert step["env"] == {
        "TESTING": "1",
        "MINT_TEST_POSTGRES_URL": POSTGRES_URL,
    }
    assert step["run"] == f"python -m pytest {TARGET_TEST} -q --tb=short"
    assert step.get("continue-on-error") is not True
    assert job.get("continue-on-error") is not True
    assert "${{ secrets." not in str(job)
