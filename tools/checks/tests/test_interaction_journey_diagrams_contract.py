from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
DIAGRAM_DIR = ROOT / ".planning/journeys/diagrams"
WORKFLOW = ROOT / "docs/MINT_AGENT_WORKFLOW.md"
REGISTRY = ROOT / "docs/codex/INTERACTION_REGISTRY.md"
CI = ROOT / ".github/workflows/ci.yml"


def _text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def test_data_quest_loop_diagram_pins_ledger_first_collection() -> None:
    diagram = _text(DIAGRAM_DIR / "data_quest_loop.mmd")

    required = (
        "SCREEN_CONTRACTS reads[]",
        "CoachProfileProvider.profile",
        "BiographyRepository",
        "DataQuest.planQuest",
        "/data-block/:type",
        "AskMode.reconfirm",
        "mergeAnswers / applySaveFact / updateProfile",
        "MintStateProvider recompute",
        "Maestro / Patrol proof",
        "Forbidden<br/>domain data in GoRouter.extra",
        "Forbidden<br/>screen-local fact sliders",
    )
    for phrase in required:
        assert phrase in diagram


def test_independent_protection_diagram_pins_fact_vs_lever_boundary() -> None:
    diagram = _text(DIAGRAM_DIR / "independent_protection.mmd")

    required = (
        "/segments/independant",
        "/independants/avs",
        "/independants/ijm",
        "/independants/3a",
        "/independants/dividende-salaire",
        "/independants/lpp-volontaire",
        "q_self_employed_income",
        "q_company_profit_annual_chf",
        "q_birth_year",
        "q_has_pension_fund",
        "q_cash_total",
        "Scenario lever",
        "Dividend-vs-salary uses q_company_profit_annual_chf",
    )
    for phrase in required:
        assert phrase in diagram


def test_health_disability_diagram_pins_ledger_first_boundary() -> None:
    diagram = _text(DIAGRAM_DIR / "health_disability_protection.mmd")

    required = (
        "/explore/sante",
        "/invalidite",
        "/disability/insurance",
        "/disability/self-employed",
        "q_gross_salary_annual",
        "q_birth_year",
        "q_cash_total",
        "q_self_employed_income",
        "q_housing_cost_period_chf + q_lamal_premium_monthly_chf",
        "/data-block/revenu<br/>?inputKey=q_gross_salary_annual",
        "/data-block/revenu<br/>?inputKey=q_birth_year",
        "/data-block/patrimoine<br/>?inputKey=q_cash_total",
        "/data-block/revenu<br/>?inputKey=q_self_employed_income",
        "/budget/setup<br/>collect monthly fixed charges",
        "SelfEmployed --> Cash",
        "SelfEmployed --> FixedCharges",
        "Gap --> FixedCharges",
        "Cash --> SelfResult",
        "FixedCharges --> SelfResult",
        "FixedCharges --> GapResult",
        "Employee --> FixedCharges",
        "FixedCharges --> EmployeeResult",
        "disability_gap_result_section",
        "disability_insurance_result_section",
        "disability_self_result_cards",
        "Scenario lever",
        "no screen-local fact sliders",
    )
    for phrase in required:
        assert phrase in diagram
    assert "legacy debt: local fact sliders" not in diagram


def test_workflow_and_registry_reference_active_mermaid_layers() -> None:
    workflow = _text(WORKFLOW)
    registry = _text(REGISTRY)

    for doc in (workflow, registry):
        assert ".planning/journeys/diagrams/data_quest_loop.mmd" in doc
        assert ".planning/journeys/diagrams/independent_protection.mmd" in doc
        assert ".planning/journeys/diagrams/health_disability_protection.mmd" in doc
        assert "tools/checks/mermaid_render_guard.py" in doc

    assert "`docs/codex/INTERACTION_REGISTRY.md` is active as a YAML/lint pilot" in workflow
    assert "executor/codegen\nremains Proposed" in workflow
    assert "Ce registre est maintenant `Status: Pilot`" in registry
    assert "tools/checks/interaction_registry_lint.py" in workflow


def test_ci_renders_mermaid_diagrams_before_contract_tests() -> None:
    ci = _text(CI)
    repository_header = "\n  repository-contract-tests:\n"
    admin_header = "\n  admin-build-sanity:\n"
    repository_start = ci.index(repository_header)
    admin_start = ci.index(
        admin_header,
        repository_start,
    )
    repository_job = ci[repository_start:admin_start]

    assert "repository-contract-tests:" not in ci[:repository_start]
    assert "admin-build-sanity:" not in ci[
        repository_start + len(repository_header) : admin_start
    ]

    assert "actions/setup-node@v4" in repository_job
    assert "actions/cache@v4" in repository_job
    assert "~/.npm" in repository_job
    assert "~/.cache/puppeteer" in repository_job
    assert "python3 tools/checks/mermaid_render_guard.py" in repository_job
    assert "pytest tools/checks/tests tests/checks" in repository_job
    assert repository_job.index("python3 tools/checks/mermaid_render_guard.py") < (
        repository_job.index("pytest tools/checks/tests tests/checks")
    )
