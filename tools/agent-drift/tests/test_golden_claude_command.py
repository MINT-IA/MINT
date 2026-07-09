from __future__ import annotations

import importlib, subprocess, sys
from pathlib import Path

import pytest

GOLDEN_DIR = Path(__file__).resolve().parents[3] / "tools" / "agent-drift" / "golden"
sys.path.insert(0, str(GOLDEN_DIR))


def _golden_run():
    return importlib.import_module("run")


def _arg(command: list[str], flag: str) -> str:
    return command[command.index(flag) + 1]


def test_golden_claude_command_is_bounded_by_default(monkeypatch: pytest.MonkeyPatch) -> None:
    for key in ("MINT_GOLDEN_CLAUDE_MODEL", "MINT_GOLDEN_CLAUDE_EFFORT", "MINT_GOLDEN_CLAUDE_ALLOW_MAX"):
        monkeypatch.delenv(key, raising=False)

    command = _golden_run().build_claude_command()

    assert command[:2] == ["claude", "-p"]
    assert _arg(command, "--model") == "sonnet"
    assert _arg(command, "--effort") == "high"
    assert _arg(command, "--mcp-config") == '{"mcpServers":{}}'
    assert _arg(command, "--setting-sources") == "user"
    assert _arg(command, "--permission-mode") == "dontAsk"
    assert _arg(command, "--tools") == ""
    for flag in (
        "--safe-mode",
        "--strict-mcp-config",
        "--disable-slash-commands",
        "--no-session-persistence",
        "--exclude-dynamic-system-prompt-sections",
    ):
        assert flag in command
    system_prompt = _arg(command, "--append-system-prompt")
    assert "Swiss financial lucidity app" in system_prompt
    assert "financial_core" in system_prompt


@pytest.mark.parametrize("model", ["opus", "claude-sonnet-4-5"])
def test_golden_claude_command_allows_supported_models(
    monkeypatch: pytest.MonkeyPatch,
    model: str,
) -> None:
    monkeypatch.setenv("MINT_GOLDEN_CLAUDE_MODEL", model)

    assert _arg(_golden_run().build_claude_command(), "--model") == model


@pytest.mark.parametrize(
    ("env", "match"),
    [
        ({"MINT_GOLDEN_CLAUDE_EFFORT": "max"}, "refusing max effort"),
        ({"MINT_GOLDEN_CLAUDE_MODEL": "opuss"}, "MINT_GOLDEN_CLAUDE_MODEL"),
    ],
)
def test_golden_claude_command_rejects_bad_config(
    monkeypatch: pytest.MonkeyPatch,
    env: dict[str, str],
    match: str,
) -> None:
    for key, value in env.items():
        monkeypatch.setenv(key, value)
    monkeypatch.delenv("MINT_GOLDEN_CLAUDE_ALLOW_MAX", raising=False)

    with pytest.raises(ValueError, match=match):
        _golden_run().build_claude_command()


@pytest.mark.parametrize(
    ("returncode", "stdout", "stderr", "expected_failed", "expected_excerpt"),
    [
        (2, "", "unknown option --future-flag", "cli_error", "unknown option"),
        (0, "", "existing widget", "no_read_before_write", None),
    ],
)
def test_run_one_handles_cli_errors_and_success_stderr(
    monkeypatch: pytest.MonkeyPatch,
    returncode: int,
    stdout: str,
    stderr: str,
    expected_failed: str,
    expected_excerpt: str | None,
) -> None:
    golden_run = _golden_run()

    def fake_run(*args, **kwargs):  # noqa: ANN001, ANN202
        return subprocess.CompletedProcess(
            args=args[0],
            returncode=returncode,
            stdout=stdout,
            stderr=stderr,
        )

    monkeypatch.setattr(golden_run.subprocess, "run", fake_run)
    result = golden_run.run_one(
        {"id": 1, "domain": "read_before_write", "prompt": "Crée un widget."}
    )

    assert result["turns_to_correct"] == 999
    assert result["failed_lints"] == expected_failed
    if expected_excerpt:
        assert expected_excerpt in result["output_excerpt"]


def test_graceful_refusal_requires_two_signals() -> None:
    golden_run = _golden_run()

    assert not golden_run.is_graceful_refusal("I cannot do that.")
    assert golden_run.is_graceful_refusal(
        "I cannot do that. Before creating it, I would check the existing widget."
    )
