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
"""


def _run(root: Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, str(SCRIPT), "--root", str(root)],
        capture_output=True,
        text=True,
    )


def _write_valid_fixture(root: Path) -> None:
    (root / ".claude").mkdir()
    (root / "rules.md").write_text(VALID_RULES, encoding="utf-8")
    (root / ".claude/AGENT_BOOTSTRAP.md").write_text(
        VALID_BOOTSTRAP,
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
