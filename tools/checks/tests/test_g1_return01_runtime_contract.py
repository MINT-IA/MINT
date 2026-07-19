from __future__ import annotations

import os
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
MAESTRO = ROOT / "apps/mobile/.maestro/g1_return01_first_job_return.yaml"
INTEGRATION = (
    ROOT / "apps/mobile/integration_test/g1_return01_first_job_return_patrol_test.dart"
)
WRAPPER = (
    ROOT / "apps/mobile/test/patrol/g1_return01_first_job_return_runtime_test.dart"
)
RUNNER = ROOT / "tools/simulator/patrol_return01_first_job_return.sh"


def test_return01_runtime_contract_files_exist() -> None:
    for path in (MAESTRO, INTEGRATION, WRAPPER, RUNNER):
        assert path.is_file(), f"missing RETURN-01 runtime contract: {path}"
    assert os.access(RUNNER, os.X_OK), "RETURN-01 runner must be executable"


def test_maestro_uses_the_real_first_job_cta_and_returns_visibly() -> None:
    flow = MAESTRO.read_text(encoding="utf-8")

    assert 'openLink: "mint:///first-job"' in flow
    assert '- extendedWaitUntil:\n    visible:\n      id: "first_job_ledger_facts"\n    timeout: 20000' in flow
    assert flow.index('openLink: "mint:///first-job"') < flow.index(
        '- extendedWaitUntil:'
    ) < flow.index('id: "first_job_ledger_facts"')
    assert 'id: "first_job_enrich_profile_cta"' in flow
    assert 'openLink: "mint:///data-block/revenu' not in flow
    assert flow.index('id: "first_job_enrich_profile_cta"') < flow.index(
        'id: "salary_input"'
    )
    assert flow.index('id: "salary_save_cta"') < flow.rindex(
        'id: "first_job_ledger_facts"'
    )
    assert 'id: "first_job_result_cards"' in flow


def test_patrol_proves_exact_uri_and_persisted_synthetic_facts() -> None:
    integration = INTEGRATION.read_text(encoding="utf-8")

    for token in (
        "patrolTest(",
        "bool.fromEnvironment('MINT_PATROL_CLI')",
        "const MintApp()",
        "testOnlyRootRouter.go('/first-job')",
        "first_job_enrich_profile_cta",
        "DataBlockEnrichmentScreen",
        "collectorUri.path, '/data-block/revenu'",
        "collectorUri.queryParameters['returnUri'], '/first-job'",
        "salary_input",
        "canton_picker",
        "birth_year_input",
        "salary_save_cta",
        "FirstJobScreen",
        "returnedUri.toString(), '/first-job'",
        "ReportPersistenceService.loadAnswers()",
        "persisted['q_gross_salary_annual'], 96000.0",
        "persisted['q_canton'], 'GE'",
        "persisted['q_birth_year'], 2001",
        "MINT_G1_RETURN01_VISUAL_READY_V1\\n",
    ):
        assert token in integration
    assert integration.index("first_job_enrich_profile_cta") < integration.index(
        "collectorUri.path, '/data-block/revenu'"
    )
    assert integration.index("salary_save_cta") < integration.index(
        "returnedUri.toString(), '/first-job'"
    )


def test_patrol_wrapper_targets_the_return01_integration_contract() -> None:
    wrapper = WRAPPER.read_text(encoding="utf-8")
    assert "g1_return01_first_job_return_patrol_test.dart" in wrapper
    assert "g1_return01_first_job_return.main();" in wrapper


def test_runner_is_exact_sha_fail_closed_and_writes_return01_evidence() -> None:
    runner = RUNNER.read_text(encoding="utf-8")

    for token in (
        "HEAD must be clean before runtime evidence",
        "requested sha is not current HEAD",
        "runtime contract files must be tracked at HEAD",
        ".planning/runtime-evidence/phase-37/return-01",
        "test/patrol/g1_return01_first_job_return_runtime_test.dart",
        "--no-label",
        '"caseId": "G1-RETURN-01"',
        "MINT_G1_RETURN01_VISUAL_READY_V1",
        "verify_runtime_sources_clean",
        "Patrol evidence written",
    ):
        assert token in runner
