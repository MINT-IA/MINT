from __future__ import annotations

import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[3]
SCRIPT = REPO_ROOT / "tools" / "checks" / "mint_rules_guard.py"


VALID_RULES = """# Mint rules

## ALWAYS DO

- Read `.planning/ACTIVE_CONTEXT.md` and `.planning/ACTIVE_CONTEXT.json`.
- Run `python3 tools/checks/active_context_guard.py`.
- Run `python3 tools/checks/journey_os_check.py`.
- Run `python3 tools/checks/workflow_contract_guard.py`.
- Write the phase `SPEC.md` before implementation.
- Save Engram after decisions, discoveries, conventions, and bug fixes.

## ASK FIRST

- Merge or push `dev`, `staging`, or `main`.
- Add a new financial formula or regulatory constant.
- Archive historical planning directories.

## NEVER DO

- Show a financial number without provenance, assumptions, confidence, and missing fields.
- Recode financial calculations in UI code.
- Ship an AI/LLM path without golden fixtures or evaluator evidence.
- Use a silent fallback that hides drift.
"""


VALID_BOOTSTRAP = """# Bootstrap

Read `AGENTS.md`, `CLAUDE.md`, `docs/MINT_AGENT_WORKFLOW.md`,
`.planning/ACTIVE_CONTEXT.md`, and `.planning/ACTIVE_CONTEXT.json`.
Run `python3 tools/checks/active_context_guard.py` before product work.
Run `python3 tools/checks/journey_os_check.py` before Journey OS work.
Run `python3 tools/checks/workflow_contract_guard.py` before workflow changes.
"""

VALID_DICTIONARY_LINT = """from __future__ import annotations

import sys

print("OK mint_variable_dictionary_lint: dictionary view is coherent.", file=sys.stderr)
raise SystemExit(0)
"""


def _run(root: Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, str(SCRIPT), "--root", str(root)],
        capture_output=True,
        text=True,
    )


def _write_valid_fixture(root: Path) -> None:
    (root / ".claude").mkdir()
    (root / "tools/checks").mkdir(parents=True)
    (root / "rules.md").write_text(VALID_RULES, encoding="utf-8")
    (root / ".claude/AGENT_BOOTSTRAP.md").write_text(
        VALID_BOOTSTRAP,
        encoding="utf-8",
    )
    (root / "tools/checks/mint_variable_dictionary_lint.py").write_text(
        VALID_DICTIONARY_LINT,
        encoding="utf-8",
    )


def test_guard_passes_for_rules_registry_and_bootstrap(tmp_path: Path) -> None:
    _write_valid_fixture(tmp_path)

    proc = _run(tmp_path)

    assert proc.returncode == 0
    assert "OK mint_rules_guard" in proc.stderr


def test_guard_fails_when_ask_first_section_missing(tmp_path: Path) -> None:
    _write_valid_fixture(tmp_path)
    (tmp_path / "rules.md").write_text(
        VALID_RULES.replace("## ASK FIRST", "## MAYBE"),
        encoding="utf-8",
    )

    proc = _run(tmp_path)

    assert proc.returncode == 1
    assert "ASK FIRST" in proc.stderr


def test_guard_fails_when_never_do_lacks_financial_provenance(
    tmp_path: Path,
) -> None:
    _write_valid_fixture(tmp_path)
    (tmp_path / "rules.md").write_text(
        VALID_RULES.replace(
            "- Show a financial number without provenance, assumptions, confidence, and missing fields.\n",
            "",
        ),
        encoding="utf-8",
    )

    proc = _run(tmp_path)

    assert proc.returncode == 1
    assert "financial number" in proc.stderr


def test_guard_fails_when_bootstrap_skips_active_context(tmp_path: Path) -> None:
    _write_valid_fixture(tmp_path)
    (tmp_path / ".claude/AGENT_BOOTSTRAP.md").write_text(
        "Read CLAUDE.md then decisions/ before coding.",
        encoding="utf-8",
    )

    proc = _run(tmp_path)

    assert proc.returncode == 1
    assert "AGENT_BOOTSTRAP.md" in proc.stderr


def test_guard_fails_when_variable_dictionary_lint_fails(tmp_path: Path) -> None:
    _write_valid_fixture(tmp_path)
    (tmp_path / "tools/checks/mint_variable_dictionary_lint.py").write_text(
        "from __future__ import annotations\n"
        "import sys\n"
        "print('FAIL mint_variable_dictionary_lint: fixture violation', file=sys.stderr)\n"
        "raise SystemExit(1)\n",
        encoding="utf-8",
    )

    proc = _run(tmp_path)

    assert proc.returncode == 1
    assert "mint_variable_dictionary_lint.py" in proc.stderr
    assert "fixture violation" in proc.stderr
