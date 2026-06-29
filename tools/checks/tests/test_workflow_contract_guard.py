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
    "python3 tools/checks/mint2_navigation_spine_guard.py",
    "python3 tools/checks/mermaid_render_guard.py",
    "python3 tools/checks/maestro_locator_audit.py",
    "bash tools/simulator/journey_os_runtime_replay.sh --dry-run",
    "bash tools/simulator/journey_os_runtime_replay.sh --dry-run --set top",
    "python3 tools/checks/verify_phase_acceptance.py",
)
CI_TESTS = (
    "tools/checks/tests/test_active_context_guard.py",
    "tools/checks/tests/test_phase_contract_guard.py",
    "tools/checks/tests/test_mint_rules_guard.py",
    "tools/checks/tests/test_agent_reference_guard.py",
    "tools/checks/tests/test_claude_hooks_guard.py",
    "tools/checks/tests/test_journey_os_check.py",
    "tools/checks/tests/test_journey_os_runtime_replay.py",
    "tools/checks/tests/test_mint2_navigation_spine_guard.py",
    "tools/checks/tests/test_maestro_locator_audit.py",
    "tools/checks/tests/test_mermaid_render_guard.py",
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
    (root / ".github/workflows/journey-os-runtime-replay.yml").write_text(
        "\n".join(
            [
                "name: Journey OS Runtime Replay",
                "on:",
                "  workflow_dispatch:",
                "    inputs:",
                "      runtime_set:",
                "        options:",
                "          - core",
                "          - top",
                "          - authenticated",
                "          - account_lifecycle",
                "permissions:",
                "  contents: read",
                "env:",
                "  MAESTRO_ZIP_SHA256: abc",
                "jobs:",
                "  classify:",
                "    runs-on: ubuntu-latest",
                "    steps:",
                "      - name: classify",
                "        run: bash tools/simulator/journey_os_runtime_replay.sh --requires-auth --set \"${{ inputs.runtime_set }}\"",
                "  replay:",
                "    if: ${{ needs.classify.outputs.requires_auth == 'false' }}",
                "    runs-on: macos-latest",
                "    steps:",
                "      - uses: actions/checkout@v4",
                "      - uses: subosito/flutter-action@1a449444c387b1966244ae4d4f8c696479add0b2",
                "      - name: Install pinned Maestro",
                "        run: shasum -a 256 -c -",
                "      - name: Replay top Journey OS runtime flow",
                "        run: |",
                "          if [ \"${{ inputs.dry_run }}\" = \"true\" ]; then",
                "            bash tools/simulator/journey_os_runtime_replay.sh --dry-run --set \"${{ inputs.runtime_set }}\"",
                "          else",
                "            bash tools/simulator/journey_os_runtime_replay.sh --set \"${{ inputs.runtime_set }}\"",
                "          fi",
                "      - name: Upload Journey OS runtime evidence",
                "        if: ${{ always() && inputs.dry_run == false }}",
                "        uses: actions/upload-artifact@ea165f8d65b6e75b540449e92b4886f43607fa02",
                "        with:",
                "          path: .planning/journeys/evidence/runtime_replay/**",
                "  auth:",
                "    if: ${{ needs.classify.outputs.requires_auth == 'true' }}",
                "    runs-on: macos-latest",
                "    environment: journey-os-staging-runtime",
                "    steps:",
                "      - name: replay",
                "        env:",
                "          MINT_E2E_EMAIL: ${{ secrets.MINT_E2E_EMAIL }}",
                "        run: bash tools/simulator/journey_os_runtime_replay.sh --set \"${{ inputs.runtime_set }}\"",
                "      - name: Upload Journey OS runtime evidence",
                "        if: ${{ always() }}",
                "        uses: actions/upload-artifact@ea165f8d65b6e75b540449e92b4886f43607fa02",
                "        with:",
                "          path: .planning/journeys/evidence/runtime_replay/**",
            ]
        )
        + "\n",
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


def test_workflow_contract_guard_requires_runtime_replay_workflow(tmp_path: Path) -> None:
    _write_fixture(tmp_path)
    (tmp_path / ".github/workflows/journey-os-runtime-replay.yml").unlink()

    proc = _run(tmp_path)

    assert proc.returncode == 1
    assert "journey-os-runtime-replay.yml" in proc.stderr


def test_workflow_contract_guard_requires_runtime_replay_dispatch_trigger(tmp_path: Path) -> None:
    _write_fixture(tmp_path)
    workflow = tmp_path / ".github/workflows/journey-os-runtime-replay.yml"
    workflow.write_text(
        workflow.read_text(encoding="utf-8").replace("  workflow_dispatch:", "  push:"),
        encoding="utf-8",
    )

    proc = _run(tmp_path)

    assert proc.returncode == 1
    assert "workflow_dispatch" in proc.stderr


def test_workflow_contract_guard_rejects_runtime_replay_continue_on_error(tmp_path: Path) -> None:
    _write_fixture(tmp_path)
    workflow = tmp_path / ".github/workflows/journey-os-runtime-replay.yml"
    workflow.write_text(
        workflow.read_text(encoding="utf-8") + "        continue-on-error: true\n",
        encoding="utf-8",
    )

    proc = _run(tmp_path)

    assert proc.returncode == 1
    assert "continue-on-error" in proc.stderr


def test_workflow_contract_guard_rejects_dry_run_only_runtime_replay(tmp_path: Path) -> None:
    _write_fixture(tmp_path)
    workflow = tmp_path / ".github/workflows/journey-os-runtime-replay.yml"
    workflow.write_text(
        workflow.read_text(encoding="utf-8").replace(
            "bash tools/simulator/journey_os_runtime_replay.sh --set \"${{ inputs.runtime_set }}\"",
            "bash tools/simulator/journey_os_runtime_replay.sh --dry-run --set \"${{ inputs.runtime_set }}\"",
        ),
        encoding="utf-8",
    )

    proc = _run(tmp_path)

    assert proc.returncode == 1
    assert "journey_os_runtime_replay.sh" in proc.stderr


def test_workflow_contract_guard_requires_maestro_locator_audit_in_ci(tmp_path: Path) -> None:
    _write_fixture(tmp_path)
    workflow = tmp_path / ".github/workflows/ai-workflow-guards.yml"
    workflow.write_text(
        workflow.read_text(encoding="utf-8").replace(
            "        run: python3 tools/checks/maestro_locator_audit.py\n",
            "        run: echo no locator audit\n",
        ),
        encoding="utf-8",
    )

    proc = _run(tmp_path)

    assert proc.returncode == 1
    assert "maestro_locator_audit.py" in proc.stderr


def test_workflow_contract_guard_requires_top_replay_dry_run_in_ci(tmp_path: Path) -> None:
    _write_fixture(tmp_path)
    workflow = tmp_path / ".github/workflows/ai-workflow-guards.yml"
    workflow.write_text(
        workflow.read_text(encoding="utf-8").replace(
            "        run: bash tools/simulator/journey_os_runtime_replay.sh --dry-run --set top\n",
            "        run: echo no top dry run\n",
        ),
        encoding="utf-8",
    )

    proc = _run(tmp_path)

    assert proc.returncode == 1
    assert "--set top" in proc.stderr


def test_workflow_contract_guard_rejects_runtime_replay_curl_to_bash(tmp_path: Path) -> None:
    _write_fixture(tmp_path)
    workflow = tmp_path / ".github/workflows/journey-os-runtime-replay.yml"
    workflow.write_text(
        workflow.read_text(encoding="utf-8").replace(
            "        run: shasum -a 256 -c -\n",
            "        run: curl -Ls https://get.maestro.mobile.dev | bash\n",
        ),
        encoding="utf-8",
    )

    proc = _run(tmp_path)

    assert proc.returncode == 1
    assert "curl-to-bash" in proc.stderr


def test_workflow_contract_guard_allows_bash_in_yaml_block_scalar(tmp_path: Path) -> None:
    _write_fixture(tmp_path)
    workflow = tmp_path / ".github/workflows/journey-os-runtime-replay.yml"
    workflow.write_text(
        workflow.read_text(encoding="utf-8")
        + "\n  shell-block-smoke:\n"
        + "    runs-on: ubuntu-latest\n"
        + "    steps:\n"
        + "      - name: bash block\n"
        + "        run: |\n"
        + "          bash tools/simulator/journey_os_runtime_replay.sh --dry-run --set top\n",
        encoding="utf-8",
    )

    proc = _run(tmp_path)

    assert proc.returncode == 0


def test_workflow_contract_guard_requires_environment_for_secret_replay(tmp_path: Path) -> None:
    _write_fixture(tmp_path)
    workflow = tmp_path / ".github/workflows/journey-os-runtime-replay.yml"
    workflow.write_text(
        workflow.read_text(encoding="utf-8")
        + "\n  auth:\n"
        + "    runs-on: macos-latest\n"
        + "    steps:\n"
        + "      - name: replay\n"
        + "        env:\n"
        + "          MINT_E2E_EMAIL: ${{ secrets.MINT_E2E_EMAIL }}\n"
        + "        run: bash tools/simulator/journey_os_runtime_replay.sh --set authenticated\n",
        encoding="utf-8",
    )

    proc = _run(tmp_path)

    assert proc.returncode == 1
    assert "GitHub Environment" in proc.stderr


def test_workflow_contract_guard_requires_runtime_auth_classification(tmp_path: Path) -> None:
    _write_fixture(tmp_path)
    workflow = tmp_path / ".github/workflows/journey-os-runtime-replay.yml"
    workflow.write_text(
        workflow.read_text(encoding="utf-8").replace(
            "        run: bash tools/simulator/journey_os_runtime_replay.sh --requires-auth --set \"${{ inputs.runtime_set }}\"\n",
            "        run: echo no classifier\n",
        ),
        encoding="utf-8",
    )

    proc = _run(tmp_path)

    assert proc.returncode == 1
    assert "classify runtime sets" in proc.stderr


def test_workflow_contract_guard_requires_runtime_artifact_upload(tmp_path: Path) -> None:
    _write_fixture(tmp_path)
    workflow = tmp_path / ".github/workflows/journey-os-runtime-replay.yml"
    workflow.write_text(
        workflow.read_text(encoding="utf-8").replace(
            "        uses: actions/upload-artifact@ea165f8d65b6e75b540449e92b4886f43607fa02\n",
            "        run: echo no upload\n",
        ),
        encoding="utf-8",
    )

    proc = _run(tmp_path)

    assert proc.returncode == 1
    assert "upload-artifact" in proc.stderr
