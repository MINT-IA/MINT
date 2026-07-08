import os
import subprocess
from pathlib import Path

import pytest


ROOT = Path(__file__).resolve().parents[3]
SCRIPT = ROOT / "tools/checks/claude_external_audit.sh"
AGENT = ROOT / ".claude/agents/mint-external-auditor.md"
QUALITY_GATE = ROOT / ".claude/agents/mint-quality-gate.md"
WORKFLOW = ROOT / "docs/MINT_AGENT_WORKFLOW.md"
OPERATING_GATES = ROOT / ".claude/skills/mint-operating-gates/SKILL.md"


def _run(*args: str, **env_overrides: str) -> subprocess.CompletedProcess[str]:
    env = os.environ.copy()
    env.update(env_overrides)
    return subprocess.run(
        ["bash", str(SCRIPT), *args],
        cwd=ROOT,
        env=env,
        text=True,
        capture_output=True,
        check=False,
    )


def _run_with_temporary_worktree_diff(
    *args: str,
    **env_overrides: str,
) -> subprocess.CompletedProcess[str]:
    original = WORKFLOW.read_text(encoding="utf-8")
    WORKFLOW.write_text(
        f"{original}\n\n<!-- contract-test-diff: claude audit budget -->\n",
        encoding="utf-8",
    )
    try:
        return _run(*args, **env_overrides)
    finally:
        WORKFLOW.write_text(original, encoding="utf-8")


def test_wrapper_is_syntax_valid_and_executable() -> None:
    result = subprocess.run(
        ["bash", "-n", str(SCRIPT)],
        cwd=ROOT,
        text=True,
        capture_output=True,
        check=False,
    )

    assert result.returncode == 0, result.stderr
    assert os.access(SCRIPT, os.X_OK)


def test_wrapper_defaults_are_bounded() -> None:
    result = _run("code", "HEAD", CLAUDE_AUDIT_DRY_RUN="1")

    assert result.returncode == 0, result.stderr
    for needle in (
        "--model opus",
        "--effort high",
        "--safe-mode",
        "--strict-mcp-config",
        r"\{\"mcpServers\":\{\}\}",
        "--disable-slash-commands",
        "--no-session-persistence",
        "--permission-mode dontAsk",
        "--tools Read\\,Grep\\,Bash",
        "--exclude-dynamic-system-prompt-sections",
        "--- PROMPT_BEGIN ---",
        "Diff line budget: 2500 lines",
        "Staged worktree diff:",
        "Unstaged worktree diff:",
    ):
        assert needle in result.stdout


def test_rerun_mode_defaults_to_sonnet_high() -> None:
    result = _run("code", "HEAD", CLAUDE_AUDIT_DRY_RUN="1", CLAUDE_AUDIT_RERUN="1")

    assert result.returncode == 0, result.stderr
    assert "--model sonnet" in result.stdout
    assert "--effort high" in result.stdout


@pytest.mark.parametrize(
    ("args", "env", "stderr"),
    (
        (("code",), {"CLAUDE_AUDIT_DRY_RUN": "1"}, "code mode requires a base ref"),
        (("unknown",), {"CLAUDE_AUDIT_DRY_RUN": "1"}, "unknown mode"),
        (("code", "no-such-ref-xyz"), {"CLAUDE_AUDIT_DRY_RUN": "1"}, "unknown base ref"),
        (
            ("code", "HEAD"),
            {"CLAUDE_AUDIT_DRY_RUN": "1", "CLAUDE_AUDIT_EFFORT": "max"},
            "refusing --effort max",
        ),
        (
            ("code", "HEAD"),
            {"CLAUDE_AUDIT_DRY_RUN": "1", "CLAUDE_AUDIT_MAX_TURNS": "25"},
            "MAX_TURNS is not supported",
        ),
        (
            ("code", "HEAD"),
            {"CLAUDE_AUDIT_DRY_RUN": "1", "CLAUDE_AUDIT_RERUN": "maybe"},
            "CLAUDE_AUDIT_RERUN must be 0 or 1",
        ),
        (
            ("code", "HEAD"),
            {
                "CLAUDE_AUDIT_DRY_RUN": "1",
                "CLAUDE_AUDIT_RERUN": "1",
                "CLAUDE_AUDIT_MODEL": "opus",
            },
            "CLAUDE_AUDIT_RERUN=1 must use a sonnet model",
        ),
        (
            ("code", "HEAD"),
            {
                "CLAUDE_AUDIT_DRY_RUN": "1",
                "CLAUDE_AUDIT_RERUN": "1",
                "CLAUDE_AUDIT_MODEL": "haiku",
            },
            "CLAUDE_AUDIT_RERUN=1 must use a sonnet model",
        ),
        (
            ("code", "HEAD"),
            {"CLAUDE_AUDIT_DRY_RUN": "1", "CLAUDE_AUDIT_MAX_DIFF_LINES": "not-a-number"},
            "MAX_DIFF_LINES must be a non-negative integer",
        ),
        (
            ("specs",),
            {
                "CLAUDE_AUDIT_DRY_RUN": "1",
                "CLAUDE_AUDIT_BARE": "1",
                "ANTHROPIC_API_KEY": "",
                "CLAUDE_AUDIT_SETTINGS": "",
            },
            "--bare skips OAuth/keychain",
        ),
    ),
)
def test_wrapper_rejects_unsafe_or_invalid_invocations(
    args: tuple[str, ...],
    env: dict[str, str],
    stderr: str,
) -> None:
    result = _run(*args, **env)

    assert result.returncode == 2
    assert stderr in result.stderr


def test_rerun_mode_allows_non_sonnet_only_with_explicit_override() -> None:
    result = _run(
        "code",
        "HEAD",
        CLAUDE_AUDIT_DRY_RUN="1",
        CLAUDE_AUDIT_RERUN="1",
        CLAUDE_AUDIT_MODEL="opus",
        CLAUDE_AUDIT_ALLOW_NON_SONNET_RERUN="1",
    )

    assert result.returncode == 0, result.stderr
    assert "--model opus" in result.stdout


def test_wrapper_rejects_large_code_diff_without_explicit_override() -> None:
    result = _run_with_temporary_worktree_diff(
        "code",
        "HEAD",
        CLAUDE_AUDIT_DRY_RUN="1",
        CLAUDE_AUDIT_MAX_DIFF_LINES="1",
    )

    assert result.returncode == 2
    assert "diff prompt is" in result.stderr
    assert "CLAUDE_AUDIT_ALLOW_LARGE_DIFF=1" in result.stderr


def test_wrapper_allows_large_code_diff_only_with_named_override() -> None:
    result = _run_with_temporary_worktree_diff(
        "code",
        "HEAD",
        CLAUDE_AUDIT_DRY_RUN="1",
        CLAUDE_AUDIT_MAX_DIFF_LINES="1",
        CLAUDE_AUDIT_ALLOW_LARGE_DIFF="1",
    )

    assert result.returncode == 0, result.stderr
    assert "Diff line budget: 1 lines" in result.stdout


def test_specs_and_architecture_prompts_are_wired() -> None:
    specs = _run("specs", CLAUDE_AUDIT_DRY_RUN="1")
    architecture = _run("architecture", CLAUDE_AUDIT_DRY_RUN="1")

    assert specs.returncode == 0, specs.stderr
    assert architecture.returncode == 0, architecture.stderr
    for spec in (
        "DATA_LEDGER.md",
        "SCREEN_CONTRACTS.md",
        "WIRING_GRAPH.mmd",
        "DATA_QUEST.md",
        "MAESTRO_FLOWS.md",
    ):
        assert spec in specs.stdout
    for doc in ("AGENTS.md", "CLAUDE.md", "docs/MINT_AGENT_WORKFLOW.md"):
        assert doc in architecture.stdout


def test_auditor_docs_point_to_wrapper_policy() -> None:
    for text in (
        AGENT.read_text(encoding="utf-8"),
        WORKFLOW.read_text(encoding="utf-8"),
        OPERATING_GATES.read_text(encoding="utf-8"),
    ):
        lowered = text.lower()
        assert "tools/checks/claude_external_audit.sh" in text
        assert "opus high" in lowered
        assert "Sonnet high" in text
        assert "CLAUDE_AUDIT_RERUN=1" in text
        assert "CLAUDE_AUDIT_ALLOW_NON_SONNET_RERUN=1" in text
        assert "--effort max" in text
        assert "CLAUDE_AUDIT_MAX_DIFF_LINES" in text


def test_quality_gate_does_not_allow_raw_claude_fallback() -> None:
    text = QUALITY_GATE.read_text(encoding="utf-8")

    assert "tools/checks/claude_external_audit.sh" in text
    assert "otherwise `claude -p`" not in text
    assert "raw `claude -p`" in text


def test_operating_gates_do_not_mark_claude_wrapper_as_missing() -> None:
    text = OPERATING_GATES.read_text(encoding="utf-8")
    missing_section = text.split("## Roadmap Gates Not Installed At G0", 1)[1]

    assert "tools/checks/claude_external_audit.sh" not in missing_section
