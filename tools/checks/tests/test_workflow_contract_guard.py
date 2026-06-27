from __future__ import annotations

import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[3]
SCRIPT = REPO_ROOT / "tools/checks/workflow_contract_guard.py"

SESSION_COMMANDS = (
    "python3 tools/checks/active_context_guard.py",
    "python3 tools/checks/phase_contract_guard.py",
    "python3 tools/checks/mint_rules_guard.py",
    "python3 tools/checks/journey_os_check.py",
    "python3 tools/checks/workflow_contract_guard.py",
)
CI_EXTRA = (
    "python3 tools/checks/agent_reference_guard.py",
    "python3 tools/checks/claude_hooks_guard.py",
    "python3 tools/checks/mermaid_render_guard.py",
    "python3 tools/checks/verify_phase_acceptance.py",
)
CI_TESTS = (
    "tools/checks/tests/test_active_context_guard.py",
    "tools/checks/tests/test_phase_contract_guard.py",
    "tools/checks/tests/test_mint_rules_guard.py",
    "tools/checks/tests/test_agent_reference_guard.py",
    "tools/checks/tests/test_claude_hooks_guard.py",
    "tools/checks/tests/test_journey_os_check.py",
    "tools/checks/tests/test_workflow_contract_guard.py",
    "tools/checks/tests/test_verify_phase_acceptance.py",
)


def _run(root: Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, str(SCRIPT), "--root", str(root)],
        capture_output=True,
        text=True,
    )


def _write_fixture(root: Path) -> None:
    (root / ".claude").mkdir()
    (root / ".github/workflows").mkdir(parents=True)
    commands = "\n".join(SESSION_COMMANDS)
    (root / "AGENTS.md").write_text(commands, encoding="utf-8")
    (root / "rules.md").write_text(commands, encoding="utf-8")
    (root / ".claude/AGENT_BOOTSTRAP.md").write_text(commands, encoding="utf-8")
    lefthook_lines = ["pre-commit:", "  commands:"]
    for command in SESSION_COMMANDS:
        name = Path(command.split()[-1]).stem.replace("_", "-")
        lefthook_lines += [f"    {name}:", f"      run: {command}"]
    (root / "lefthook.yml").write_text("\n".join(lefthook_lines) + "\n", encoding="utf-8")
    workflow_lines = [
        "name: AI Workflow Guards",
        "on: pull_request",
        "jobs:",
        "  guards:",
        "    runs-on: ubuntu-latest",
        "    steps:",
    ]
    for command in SESSION_COMMANDS + CI_EXTRA:
        workflow_lines += ["      - name: guard", f"        run: {command}"]
    workflow_lines += ["      - name: Guard tests", "        run: >"]
    workflow_lines += [f"          python3 -m pytest {' '.join(CI_TESTS)} -q"]
    (root / ".github/workflows/ai-workflow-guards.yml").write_text(
        "\n".join(workflow_lines) + "\n",
        encoding="utf-8",
    )


def test_workflow_contract_guard_passes_for_complete_wiring(tmp_path: Path) -> None:
    _write_fixture(tmp_path)

    proc = _run(tmp_path)

    assert proc.returncode == 0
    assert "OK workflow_contract_guard" in proc.stderr


def test_workflow_contract_guard_fails_when_ci_skips_phase_acceptance(tmp_path: Path) -> None:
    _write_fixture(tmp_path)
    workflow = tmp_path / ".github/workflows/ai-workflow-guards.yml"
    workflow.write_text(
        workflow.read_text(encoding="utf-8")
        + "\necho 'Skipping generic phase acceptance for old milestone'\n",
        encoding="utf-8",
    )

    proc = _run(tmp_path)

    assert proc.returncode == 1
    assert "verify_phase_acceptance.py" in proc.stderr


def test_workflow_contract_guard_fails_when_landing_hook_drops_journey_os(tmp_path: Path) -> None:
    _write_fixture(tmp_path)
    lefthook = tmp_path / "lefthook.yml"
    lefthook.write_text(
        lefthook.read_text(encoding="utf-8").replace(
            "      run: python3 tools/checks/journey_os_check.py\n",
            "      # python3 tools/checks/journey_os_check.py\n",
        ),
        encoding="utf-8",
    )

    proc = _run(tmp_path)

    assert proc.returncode == 1
    assert "journey_os_check.py" in proc.stderr


def test_workflow_contract_guard_fails_when_ci_command_is_comment_only(tmp_path: Path) -> None:
    _write_fixture(tmp_path)
    workflow = tmp_path / ".github/workflows/ai-workflow-guards.yml"
    workflow.write_text(
        workflow.read_text(encoding="utf-8").replace(
            "        run: python3 tools/checks/journey_os_check.py\n",
            "        run: |\n          # python3 tools/checks/journey_os_check.py\n",
        ),
        encoding="utf-8",
    )

    proc = _run(tmp_path)

    assert proc.returncode == 1
    assert "journey_os_check.py" in proc.stderr


def test_workflow_contract_guard_fails_when_ci_command_is_echoed(tmp_path: Path) -> None:
    _write_fixture(tmp_path)
    workflow = tmp_path / ".github/workflows/ai-workflow-guards.yml"
    workflow.write_text(
        workflow.read_text(encoding="utf-8").replace(
            "        run: python3 tools/checks/journey_os_check.py\n",
            "        run: echo noop # python3 tools/checks/journey_os_check.py\n",
        ),
        encoding="utf-8",
    )

    proc = _run(tmp_path)

    assert proc.returncode == 1
    assert "journey_os_check.py" in proc.stderr


def test_workflow_contract_guard_fails_when_ci_command_is_in_false_branch(tmp_path: Path) -> None:
    _write_fixture(tmp_path)
    workflow = tmp_path / ".github/workflows/ai-workflow-guards.yml"
    workflow.write_text(
        workflow.read_text(encoding="utf-8").replace(
            "        run: python3 tools/checks/journey_os_check.py\n",
            "        run: if false; then python3 tools/checks/journey_os_check.py; fi\n",
        ),
        encoding="utf-8",
    )

    proc = _run(tmp_path)

    assert proc.returncode == 1
    assert "journey_os_check.py" in proc.stderr


def test_workflow_contract_guard_fails_when_ci_command_is_in_multiline_false_branch(tmp_path: Path) -> None:
    _write_fixture(tmp_path)
    workflow = tmp_path / ".github/workflows/ai-workflow-guards.yml"
    workflow.write_text(
        workflow.read_text(encoding="utf-8").replace(
            "        run: python3 tools/checks/journey_os_check.py\n",
            "        run: |\n          if false; then\n            python3 tools/checks/journey_os_check.py\n          fi\n",
        ),
        encoding="utf-8",
    )

    proc = _run(tmp_path)

    assert proc.returncode == 1
    assert "journey_os_check.py" in proc.stderr


def test_workflow_contract_guard_fails_when_ci_command_is_printed_prose(tmp_path: Path) -> None:
    _write_fixture(tmp_path)
    workflow = tmp_path / ".github/workflows/ai-workflow-guards.yml"
    workflow.write_text(
        workflow.read_text(encoding="utf-8").replace(
            "        run: python3 tools/checks/journey_os_check.py\n",
            "        run: |\n          printf '%s\\n' 'python3 tools/checks/journey_os_check.py is documented here'\n",
        ),
        encoding="utf-8",
    )

    proc = _run(tmp_path)

    assert proc.returncode == 1
    assert "journey_os_check.py" in proc.stderr
