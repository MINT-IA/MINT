from __future__ import annotations

import json
from pathlib import Path
import re

import yaml


ROOT = Path(__file__).resolve().parents[3]

ADR = ROOT / "decisions/ADR-20260715-g1-bnd02a-partner-accountability.md"
NOTICE = ROOT / "docs/legal/partner_lpp_notice_contract_v1.md"
DATA_LEDGER = ROOT / "docs/codex/DATA_LEDGER.md"
DATA_QUEST = ROOT / "docs/codex/DATA_QUEST.md"
SCREEN_CONTRACTS = ROOT / "docs/codex/SCREEN_CONTRACTS.md"
WIRING_GRAPH = ROOT / "docs/codex/WIRING_GRAPH.mmd"
FOCUSED_MERMAID = ROOT / "docs/codex/PARTNER_LPP_ACCOUNTABILITY_FLOW.mmd"
REGISTRY = ROOT / ".planning/goals/G1-blocking-gate-tickets.md"
PLAN04 = ROOT / ".planning/phases/37-ledger-runtime-readiness/37-04-PLAN.md"
VALIDATION = ROOT / ".planning/phases/37-ledger-runtime-readiness/37-VALIDATION.md"
TICKET_EVIDENCE = (
    ROOT / ".planning/runtime-evidence/phase-37/ticket-evidence.json"
)

FOCUSED_MERMAID_REL = "docs/codex/PARTNER_LPP_ACCOUNTABILITY_FLOW.mmd"

BACKEND_COMMAND = (
    "cd services/backend && python3 -m pytest "
    "tests/test_partner_accountability.py "
    "tests/test_lpp_candidate_only_extraction.py "
    "tests/services/document/test_third_party_declaration.py -q"
)
MOBILE_COMMAND = (
    "cd apps/mobile && flutter test "
    "test/providers/partner_financial_consent_lifecycle_test.dart "
    "test/providers/household_bridge_recompute_test.dart "
    "test/screens/coach/manual_partner_lpp_accountability_rendering_test.dart "
    "--reporter expanded"
)
COMBINED_COMMAND = f"({BACKEND_COMMAND}) && ({MOBILE_COMMAND})"

BACKEND_BASELINE = "cd services/backend && ruff check . && pytest -q"
FLUTTER_BASELINE = "cd apps/mobile && flutter analyze && flutter test"

REQUIRED_CONTRACT_DOCS = {
    "decisions/ADR-20260715-g1-bnd02a-partner-accountability.md",
    "docs/legal/partner_lpp_notice_contract_v1.md",
    "docs/codex/DATA_LEDGER.md",
    "docs/codex/DATA_QUEST.md",
    "docs/codex/SCREEN_CONTRACTS.md",
    "docs/codex/WIRING_GRAPH.mmd",
    FOCUSED_MERMAID_REL,
}

REQUIRED_BACKEND_TARGETS = {
    "services/backend/app/models/partner_accountability_receipt.py",
    "services/backend/app/schemas/partner_accountability.py",
    "services/backend/app/services/partner_accountability/service.py",
    "services/backend/app/services/partner_accountability/receipt_builder.py",
    "services/backend/app/api/v1/endpoints/partner_accountability.py",
    "services/backend/app/api/v1/router.py",
    "services/backend/app/api/v1/endpoints/documents.py",
    "services/backend/app/services/document_third_party.py",
}

REQUIRED_TEST_TARGETS = {
    "services/backend/tests/test_partner_accountability.py",
    "services/backend/tests/test_lpp_candidate_only_extraction.py",
    "services/backend/tests/services/document/test_third_party_declaration.py",
    "apps/mobile/test/providers/partner_financial_consent_lifecycle_test.dart",
    "apps/mobile/test/providers/household_bridge_recompute_test.dart",
    "apps/mobile/test/screens/coach/manual_partner_lpp_accountability_rendering_test.dart",
}

MIGRATION_PATTERN = re.compile(
    r"^services/backend/alembic/versions/"
    r"[a-z0-9_]*partner_accountability[a-z0-9_]*\.py$"
)


def _table_row(path: Path, key_column: str, key: str) -> dict[str, str]:
    headers: list[str] | None = None
    for line in path.read_text(encoding="utf-8").splitlines():
        if not line.startswith("|"):
            continue
        cells = [cell.strip() for cell in line.strip().strip("|").split("|")]
        if key_column in cells:
            headers = cells
            continue
        if headers is None or len(cells) != len(headers):
            continue
        if cells[0] == key:
            return dict(zip(headers, cells))
    raise AssertionError(f"missing {key} row in {path.relative_to(ROOT)}")


def _markdown_command(value: str) -> str:
    assert value.startswith("`") and value.endswith("`"), value
    return value[1:-1]


def _frontmatter(text: str) -> dict[str, object]:
    parts = text.split("---", 2)
    assert len(parts) == 3, "Plan 37-04 must have YAML frontmatter"
    payload = yaml.safe_load(parts[1])
    assert isinstance(payload, dict)
    return payload


def _first_task(text: str) -> str:
    match = re.search(r"<task\b[^>]*>(.*?)</task>", text, re.DOTALL)
    assert match is not None, "Plan 37-04 must contain Task 1"
    return match.group(1)


def _tag(block: str, name: str) -> str:
    match = re.search(rf"<{name}>(.*?)</{name}>", block, re.DOTALL)
    assert match is not None, f"missing <{name}> in Plan 37-04 Task 1"
    return match.group(1)


def _listed_paths(block: str) -> set[str]:
    return {
        line.strip().removeprefix("- ").rstrip(",")
        for line in block.splitlines()
        if line.strip() and not line.strip().startswith("#")
    }


def _migration_targets(paths: set[str]) -> set[str]:
    return {path for path in paths if MIGRATION_PATTERN.fullmatch(path)}


def test_dedicated_swiss_ledger_quest_and_flow_contracts_exist() -> None:
    artifacts = {
        "ADR": ADR,
        "notice": NOTICE,
        "ledger": DATA_LEDGER,
        "quest": DATA_QUEST,
        "screen": SCREEN_CONTRACTS,
        "wiring": WIRING_GRAPH,
        "focused Mermaid": FOCUSED_MERMAID,
    }
    missing = [label for label, path in artifacts.items() if not path.is_file()]
    assert missing == [], f"missing dedicated BND-02A artifacts: {missing}"

    texts = {label: path.read_text(encoding="utf-8") for label, path in artifacts.items()}
    errors: list[str] = []
    required_semantics = {
        "ADR": (
            "acting_user_partner_authorization_declaration",
            "direct_partner_confirmation",
            "/grant-nominative",
        ),
        "notice": (
            "partenaire a consenti directement",
            "/grant-nominative",
            "reçu minimisé",
        ),
        "ledger": (
            "partner_accountability_receipts",
            "direct_partner_confirmation",
            "Reuse verdict — isolate, do not adapt the legacy receipt chain",
            "/consents/grant-nominative",
        ),
        "quest": (
            "G1-BND-02A",
            "acting_user_partner_authorization_declaration",
            "direct_partner_confirmation",
            "ADR-20260715-g1-bnd02a-partner-accountability.md",
            "partner_lpp_notice_contract_v1.md",
            "PARTNER_LPP_ACCOUNTABILITY_FLOW.mmd",
        ),
        "screen": (
            "G1 BND-02A/BND-02",
            "PARTNER_LPP_ACCOUNTABILITY_FLOW.mmd",
            "direct_partner_confirmation",
        ),
        "wiring": (
            "partner_accountability_receipts",
            "direct_partner_confirmation",
            "legacy grant-nominative",
            "NOT ConsentModel",
        ),
        "focused Mermaid": (
            "direct_partner_confirmation deferred",
            "partner_accountability_receipts",
        ),
    }
    for label, markers in required_semantics.items():
        for marker in markers:
            if marker not in texts[label]:
                errors.append(f"{label} missing `{marker}`")

    normalized_adr = " ".join(texts["ADR"].split())
    normalized_notice = " ".join(texts["notice"].split())
    assert "ne transforme jamais rétroactivement un reçu proxy" in normalized_adr
    assert "utilise un type de reçu différent" in normalized_notice
    assert errors == [], "\n".join(errors)


def test_registry_names_exact_cross_stack_targets_and_one_command() -> None:
    row = _table_row(REGISTRY, "ticket_id", "G1-BND-02A")
    targets = {value.strip() for value in row["target_files"].split(",")}
    required = REQUIRED_CONTRACT_DOCS | REQUIRED_BACKEND_TARGETS | REQUIRED_TEST_TARGETS
    missing = sorted(required - targets)

    migrations = _migration_targets(targets)
    errors = [f"registry missing target `{path}`" for path in missing]
    if len(migrations) != 1:
        errors.append(
            "registry must name exactly one concrete partner-accountability "
            f"Alembic migration, found {sorted(migrations)}"
        )
    if "apps/mobile/lib/services/consent/consent_service.dart" in targets:
        errors.append("registry must not reuse the legacy mobile consent service")
    if _markdown_command(row["red_command"]) != COMBINED_COMMAND:
        errors.append("registry red_command is not the exact combined backend+mobile command")
    if _markdown_command(row["green_command"]) != COMBINED_COMMAND:
        errors.append("registry green_command is not the exact combined backend+mobile command")
    if row["red_command"] != row["green_command"]:
        errors.append("registry RED and GREEN commands differ")

    assert errors == [], "\n".join(errors)


def test_plan04_frontmatter_and_task1_name_the_accepted_cross_stack_slice() -> None:
    text = PLAN04.read_text(encoding="utf-8")
    frontmatter = _frontmatter(text)
    task = _first_task(text)
    read_first = _listed_paths(_tag(task, "read_first"))
    task_files = _listed_paths(_tag(task, "files"))
    frontmatter_files = set(frontmatter.get("files_modified", []))

    required_implementation = REQUIRED_BACKEND_TARGETS | REQUIRED_TEST_TARGETS
    errors: list[str] = []
    for label, paths, required in (
        (
            "frontmatter files_modified",
            frontmatter_files,
            REQUIRED_CONTRACT_DOCS | required_implementation,
        ),
        ("Task 1 read_first", read_first, REQUIRED_CONTRACT_DOCS),
        (
            "Task 1 files",
            task_files,
            REQUIRED_CONTRACT_DOCS | required_implementation,
        ),
    ):
        for path in sorted(required - paths):
            errors.append(f"{label} missing `{path}`")

    for label, paths in (
        ("frontmatter files_modified", frontmatter_files),
        ("Task 1 files", task_files),
    ):
        migrations = _migration_targets(paths)
        if len(migrations) != 1:
            errors.append(
                f"{label} must name one concrete partner-accountability migration, "
                f"found {sorted(migrations)}"
            )

    contradiction_patterns = (
        r"no declared backend target",
        r"plans no backend mutation",
        r"no backend mutation is permitted",
        r"neither the registry nor this plan names a concrete backend surface",
    )
    for pattern in contradiction_patterns:
        if re.search(pattern, text, re.IGNORECASE):
            errors.append(f"Plan 37-04 retains backend contradiction `{pattern}`")

    if FOCUSED_MERMAID_REL not in read_first:
        errors.append("Task 1 does not read the focused BND-02A Mermaid")

    assert errors == [], "\n".join(errors)


def test_plan04_orders_baselines_agents_and_red_green_dependency() -> None:
    task = _first_task(PLAN04.read_text(encoding="utf-8"))
    action = _tag(task, "action").replace("&amp;", "&")
    errors: list[str] = []

    agent_markers = (
        "mint-swiss-brain",
        "mint-data-ledger-architect",
        "mint-data-quest-architect",
        "mint-backend",
        "mint-mobile",
    )
    agent_positions = [action.find(marker) for marker in agent_markers]
    if any(position < 0 for position in agent_positions):
        missing = [
            marker
            for marker, position in zip(agent_markers, agent_positions)
            if position < 0
        ]
        errors.append(f"Task 1 missing permanent-agent dispatches: {missing}")
    elif agent_positions != sorted(agent_positions):
        errors.append("Task 1 must order Swiss -> ledger -> quest -> backend -> mobile")

    red_match = re.search(r"BND-02A semantic RED", action, re.IGNORECASE)
    caller_match = re.search(
        r"(?:Continue with|prove(?: the)?) BND-02(?: real caller)?",
        action,
        re.IGNORECASE,
    )
    green_match = re.search(r"BND-02A GREEN", action, re.IGNORECASE)
    if not all((red_match, caller_match, green_match)):
        errors.append("Task 1 must explicitly name BND-02A RED -> BND-02 caller -> BND-02A GREEN")
    elif not (red_match.start() < caller_match.start() < green_match.start()):
        errors.append("Task 1 violates BND-02A RED -> BND-02 caller -> BND-02A GREEN order")

    red_position = red_match.start() if red_match is not None else len(action)
    for label, command in (
        ("independent full backend baseline", BACKEND_BASELINE),
        ("independent full Flutter baseline", FLUTTER_BASELINE),
    ):
        position = action.find(command)
        if position < 0:
            errors.append(f"Task 1 missing {label}: `{command}`")
        elif position > red_position:
            errors.append(f"Task 1 runs {label} after BND-02A RED")

    if COMBINED_COMMAND not in action:
        errors.append("Task 1 action does not freeze the exact combined RED/GREEN command")

    assert errors == [], "\n".join(errors)


def test_validation_and_evidence_use_the_registry_combined_command() -> None:
    registry = _table_row(REGISTRY, "ticket_id", "G1-BND-02A")
    validation = _table_row(VALIDATION, "Ticket", "G1-BND-02A")
    payload = json.loads(TICKET_EVIDENCE.read_text(encoding="utf-8"))
    evidence_rows = [
        row for row in payload["tickets"] if row["ticket_id"] == "G1-BND-02A"
    ]
    assert len(evidence_rows) == 1, evidence_rows

    commands = {
        "registry RED": _markdown_command(registry["red_command"]),
        "registry GREEN": _markdown_command(registry["green_command"]),
        "Validation": _markdown_command(validation["Automated command"]),
        "ticket evidence": evidence_rows[0]["command"],
    }
    mismatches = {
        label: command
        for label, command in commands.items()
        if command != COMBINED_COMMAND
    }
    assert mismatches == {}, mismatches
    assert len(set(commands.values())) == 1, commands
