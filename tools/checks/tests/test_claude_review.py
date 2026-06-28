from __future__ import annotations

import importlib.util
import json
import sys
import subprocess
from pathlib import Path
import pytest


REPO_ROOT = Path(__file__).resolve().parents[3]
SCRIPT = REPO_ROOT / "tools" / "claude_review.py"
SPEC = importlib.util.spec_from_file_location("claude_review", SCRIPT)
assert SPEC is not None and SPEC.loader is not None
claude_review = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = claude_review
SPEC.loader.exec_module(claude_review)


def test_claude_args_are_streamed_safe_and_non_bypass() -> None:
    args = claude_review.build_claude_args(
        model="opus",
        output_format="stream-json",
        max_turns=1,
        budget_usd="0.25",
    )

    assert "--safe-mode" in args
    assert "--verbose" in args
    assert "--include-partial-messages" in args
    assert args[args.index("--permission-mode") + 1] == "dontAsk"
    assert "--no-session-persistence" in args
    assert args[args.index("--disallowed-tools") + 1] == (
        "mcp__plugin_engram_engram__*,Write,Edit,Bash"
    )
    assert args[args.index("--max-budget-usd") + 1] == "0.25"
    assert "bypassPermissions" not in args
    assert "--dangerously-skip-permissions" not in args
    assert args[args.index("--tools") + 1] == ""


def test_claude_args_can_omit_budget_cap() -> None:
    args = claude_review.build_claude_args(
        model="opus",
        output_format="stream-json",
        max_turns=1,
        budget_usd="",
    )

    assert "--max-budget-usd" not in args


def test_stream_parser_extracts_text_and_thinking_tokens() -> None:
    state = claude_review.StreamState()
    lines = [
        {
            "type": "system",
            "subtype": "thinking_tokens",
            "estimated_tokens": 1200,
        },
        {
            "type": "stream_event",
            "event": {
                "type": "content_block_delta",
                "delta": {"type": "text_delta", "text": "No blocking"},
            },
        },
        {
            "type": "stream_event",
            "event": {
                "type": "content_block_delta",
                "delta": {"type": "text_delta", "text": " findings."},
            },
        },
    ]

    for line in lines:
        claude_review.parse_stream_line(json.dumps(line), state)

    assert state.thinking_tokens == 1200
    assert state.text == "No blocking findings."


def test_stream_parser_uses_terminal_text_without_duplication() -> None:
    state = claude_review.StreamState()
    events = [
        {
            "type": "stream_event",
            "event": {
                "type": "content_block_delta",
                "delta": {"type": "text_delta", "text": "No blocking"},
            },
        },
        {
            "type": "stream_event",
            "event": {
                "type": "content_block_delta",
                "delta": {"type": "text_delta", "text": " findings."},
            },
        },
        {
            "type": "assistant",
            "message": {
                "content": [
                    {"type": "text", "text": "No blocking findings."},
                ]
            },
        },
        {"type": "result", "result": "No blocking findings."},
    ]

    for event in events:
        claude_review.parse_stream_line(json.dumps(event), state)

    assert state.text == "No blocking findings."


def test_truncate_diff_reports_original_size() -> None:
    diff = "0123456789éabcdef"

    truncated, original_bytes, was_truncated = claude_review.truncate_diff(
        diff,
        max_bytes=10,
    )

    assert truncated == "0123456789"
    assert original_bytes == len(diff.encode("utf-8"))
    assert was_truncated is True


def test_build_prompt_uses_non_markdown_boundary() -> None:
    prompt = claude_review.build_prompt(
        "```diff\n+fence\n```",
        original_bytes=17,
        sent_bytes=17,
        truncated=False,
    )

    assert "```diff" not in prompt.split("Diff begins", maxsplit=1)[0]
    assert "MINT_DIFF_BOUNDARY_" in prompt


def test_explicit_untracked_file_is_included_in_diff(
    tmp_path: Path,
    monkeypatch,
) -> None:
    subprocess.run(["git", "init"], cwd=tmp_path, check=True, capture_output=True)
    untracked = tmp_path / "tools" / "new_review_helper.py"
    untracked.parent.mkdir()
    untracked.write_text("print('review')\n", encoding="utf-8")
    monkeypatch.chdir(tmp_path)

    diff = claude_review.run_git_diff(
        cached=False,
        paths=["tools/new_review_helper.py"],
    )

    assert "new file mode" in diff
    assert "+print('review')" in diff


def test_explicit_untracked_file_with_space_is_included(
    tmp_path: Path,
    monkeypatch,
) -> None:
    subprocess.run(["git", "init"], cwd=tmp_path, check=True, capture_output=True)
    untracked = tmp_path / "tools" / "review helper.py"
    untracked.parent.mkdir()
    untracked.write_text("print('review')\n", encoding="utf-8")
    monkeypatch.chdir(tmp_path)

    diff = claude_review.run_git_diff(
        cached=False,
        paths=["tools/review helper.py"],
    )

    assert "review helper.py" in diff
    assert "+print('review')" in diff


def test_empty_diff_fails(tmp_path: Path, monkeypatch) -> None:
    subprocess.run(["git", "init"], cwd=tmp_path, check=True, capture_output=True)
    monkeypatch.chdir(tmp_path)

    try:
        claude_review.run_git_diff(cached=False, paths=[])
    except claude_review.ReviewError as exc:
        assert "No diff to review" in str(exc)
    else:
        raise AssertionError("empty diff should fail")


def test_secret_guard_blocks_obvious_tokens() -> None:
    secret_line = "+Authorization: " + "Be" + "arer abcdefghijklmnopqrstuv\n"
    try:
        claude_review.guard_no_obvious_secrets(secret_line)
    except claude_review.ReviewError as exc:
        assert "secret material" in str(exc)
        assert "bearer token" in str(exc)
    else:
        raise AssertionError("secret-bearing diff should fail")


def test_secret_guard_blocks_common_secret_families() -> None:
    risky_lines = [
        "+stripe_key='" + "sk_live_" + "1234567890abcdefghijkl'\n",
        "+aws='" + "AKIA" + "1234567890ABCDEF'\n",
        "+jwt='" + "eyJ" + "aaaaaaaaaaa.bbbbbbbbbbbbb.ccccccccccccc'\n",
        "+github='" + "ghp_" + "abcdefghijklmnopqrstuvwx'\n",
        "+google='" + "AIza" + "abcdefghijklmnopqrstuvwx'\n",
        "+slack='" + "xoxb-" + "1234567890abcdefghijklmnop'\n",
        "+client_" + "sec" + "ret=abcdefghijklmnop\n",
        "+DATABASE_URL='" + "postgres" + "://user:pass@example.com/db'\n",
    ]

    markers = claude_review.find_secret_markers("".join(risky_lines))

    assert "Stripe live key" in markers
    assert "AWS access key" in markers
    assert "JWT" in markers
    assert "GitHub token" in markers
    assert "Google API key" in markers
    assert "Slack token" in markers
    assert "generic secret assignment" in markers
    assert "database URL credentials" in markers


def test_secret_guard_escape_hatch_is_explicit(monkeypatch) -> None:
    monkeypatch.setenv("MINT_CLAUDE_ALLOW_SECRET_DIFF", "1")

    claude_review.guard_no_obvious_secrets("+client_" + "sec" + "ret=abcdefghijklmnop\n")


def test_secret_guard_blocks_context_secret_mentions() -> None:
    token = "Authorization: " + "Be" + "arer abcdefghijklmnopqrstuv"
    diff = f" {token}\n-{token}\n"

    assert "bearer token" in claude_review.find_secret_markers(diff)


def test_secret_guard_allows_identifier_assignments() -> None:
    diff = "+final apiKey = config.apiKey;\n+password = user.password;\n"

    assert "generic secret assignment" not in claude_review.find_secret_markers(diff)


def test_secret_guard_allows_escaped_newline_fixture_strings() -> None:
    diff = '+    diff = "+final apiKey = config.apiKey;\\n+password = user.password;\\n"\n'

    assert "generic secret assignment" not in claude_review.find_secret_markers(diff)


def test_thinking_only_stream_fails_without_answer_text() -> None:
    state = claude_review.StreamState()
    claude_review.parse_stream_line(
        json.dumps(
            {
                "type": "system",
                "subtype": "thinking_tokens",
                "estimated_tokens": 7600,
            }
        ),
        state,
    )

    try:
        claude_review.require_review_text(state)
    except claude_review.ReviewError as exc:
        assert "no answer text" in str(exc)
        assert "7600" in str(exc)
    else:
        raise AssertionError("thinking-only stream should fail")


def test_claude_help_validation_accepts_current_required_flags() -> None:
    claude_review.assert_claude_cli_support(
        "--safe-mode --include-partial-messages --max-budget-usd dontAsk"
    )


def test_claude_help_validation_fails_when_required_flag_missing() -> None:
    with pytest.raises(claude_review.ReviewError, match="required review flags"):
        claude_review.assert_claude_cli_support("--safe-mode")


def test_run_stream_json_drains_stderr() -> None:
    code = (
        "import json, sys; "
        "sys.stderr.write('x' * 100000 + '\\n'); "
        "print(json.dumps({'type': 'result', 'result': 'No blocking findings.'}))"
    )

    result = claude_review.run_stream_json(
        [sys.executable, "-c", code],
        prompt="",
        timeout_seconds=5,
    )

    assert result == "No blocking findings."


def test_run_stream_json_keeps_text_from_nonzero_exit() -> None:
    code = (
        "import json, sys; "
        "print(json.dumps({'type': 'result', 'result': 'No blocking findings.'})); "
        "sys.exit(1)"
    )

    result = claude_review.run_stream_json(
        [sys.executable, "-c", code],
        prompt="",
        timeout_seconds=5,
    )

    assert "treat this review as partial" in result
    assert result.endswith("No blocking findings.")


def test_run_stream_json_signal_death_fails_cleanly() -> None:
    code = "import os, signal; os.kill(os.getpid(), signal.SIGKILL)"

    with pytest.raises(claude_review.ReviewError, match="exited after signal"):
        claude_review.run_stream_json(
            [sys.executable, "-c", code],
            prompt="diff",
            timeout_seconds=5,
        )


def test_run_stream_json_timeout_fails_cleanly() -> None:
    with pytest.raises(claude_review.ReviewError, match="timed out"):
        claude_review.run_stream_json(
            [sys.executable, "-c", "import time; time.sleep(10)"],
            prompt="diff",
            timeout_seconds=1,
        )


def test_run_stream_json_timeout_reports_streamed_progress() -> None:
    code = (
        "import json, time; "
        "print(json.dumps({'type':'system','subtype':'thinking_tokens',"
        "'estimated_tokens':1234}), flush=True); "
        "time.sleep(10)"
    )

    with pytest.raises(claude_review.ReviewError, match="1234"):
        claude_review.run_stream_json(
            [sys.executable, "-c", code],
            prompt="diff",
            timeout_seconds=1,
        )


def test_run_stream_json_watchdog_handles_partial_line_hang() -> None:
    code = (
        "import sys, time; "
        "sys.stdout.write('{\"type\":\"system\"'); "
        "sys.stdout.flush(); "
        "time.sleep(10)"
    )

    with pytest.raises(claude_review.ReviewError, match="timed out"):
        claude_review.run_stream_json(
            [sys.executable, "-c", code],
            prompt="diff",
            timeout_seconds=1,
        )


def test_run_text_or_json_fails_on_empty_result(monkeypatch) -> None:
    def fake_run(*args, **kwargs):
        return subprocess.CompletedProcess(
            args=args,
            returncode=0,
            stdout='{"result": ""}',
            stderr="",
        )

    monkeypatch.setattr(claude_review.subprocess, "run", fake_run)

    try:
        claude_review.run_text_or_json(
            ["claude", "--output-format", "json"],
            prompt="diff",
            timeout_seconds=5,
        )
    except claude_review.ReviewError as exc:
        assert "empty .result" in str(exc)
    else:
        raise AssertionError("empty JSON result should fail")


def test_run_text_or_json_fails_on_invalid_json(monkeypatch) -> None:
    def fake_run(*args, **kwargs):
        return subprocess.CompletedProcess(
            args=args,
            returncode=0,
            stdout="warning\n{}",
            stderr="",
        )

    monkeypatch.setattr(claude_review.subprocess, "run", fake_run)

    with pytest.raises(claude_review.ReviewError, match="not valid JSON"):
        claude_review.run_text_or_json(
            ["claude", "--output-format", "json"],
            prompt="diff",
            timeout_seconds=5,
        )


def test_run_text_or_json_timeout_fails_cleanly(monkeypatch) -> None:
    def fake_run(*args, **kwargs):
        raise subprocess.TimeoutExpired(cmd=args[0], timeout=5)

    monkeypatch.setattr(claude_review.subprocess, "run", fake_run)

    with pytest.raises(claude_review.ReviewError, match="timed out"):
        claude_review.run_text_or_json(
            ["claude", "--output-format", "json"],
            prompt="diff",
            timeout_seconds=5,
        )


def test_cached_diff_does_not_include_untracked_files(
    tmp_path: Path,
    monkeypatch,
) -> None:
    subprocess.run(["git", "init"], cwd=tmp_path, check=True, capture_output=True)
    untracked = tmp_path / "tools" / "new_review_helper.py"
    untracked.parent.mkdir()
    untracked.write_text("print('review')\n", encoding="utf-8")
    monkeypatch.chdir(tmp_path)

    with pytest.raises(claude_review.ReviewError, match="No diff"):
        claude_review.run_git_diff(
            cached=True,
            paths=["tools/new_review_helper.py"],
        )


def test_main_runs_secret_guard_before_prompt(monkeypatch) -> None:
    monkeypatch.setattr(claude_review, "shutil_which", lambda _: "/bin/claude")
    monkeypatch.setattr(
        claude_review,
        "load_claude_help",
        lambda: "--safe-mode --include-partial-messages --max-budget-usd dontAsk",
    )
    monkeypatch.setattr(
        claude_review,
        "run_git_diff",
        lambda cached, paths: "+MINT_E2E_" + "PASSWORD=secret\n",
    )

    def fail_build_prompt(*args, **kwargs):
        raise AssertionError("build_prompt should not run before secret guard")

    monkeypatch.setattr(claude_review, "build_prompt", fail_build_prompt)

    with pytest.raises(claude_review.ReviewError, match="secret material"):
        claude_review.main(["--dry-run"])


def test_main_checks_secrets_before_truncation(monkeypatch) -> None:
    monkeypatch.setattr(claude_review, "shutil_which", lambda _: "/bin/claude")
    monkeypatch.setattr(
        claude_review,
        "load_claude_help",
        lambda: "--safe-mode --include-partial-messages --max-budget-usd dontAsk",
    )
    secret = "+MINT_E2E_" + "PASSWORD=secret\n"
    monkeypatch.setattr(
        claude_review,
        "run_git_diff",
        lambda cached, paths: "+safe\n" + ("x" * 1000) + secret,
    )

    with pytest.raises(claude_review.ReviewError, match="secret material"):
        claude_review.main(["--dry-run", "--max-bytes", "10"])


def test_main_blocks_untracked_file_secret_before_prompt(
    tmp_path: Path,
    monkeypatch,
) -> None:
    subprocess.run(["git", "init"], cwd=tmp_path, check=True, capture_output=True)
    untracked = tmp_path / "tools" / "new_secret.py"
    untracked.parent.mkdir()
    untracked.write_text(
        "stripe_key='" + "sk_live_" + "1234567890abcdefghijkl'\n",
        encoding="utf-8",
    )
    monkeypatch.chdir(tmp_path)
    monkeypatch.setattr(claude_review, "shutil_which", lambda _: "/bin/claude")
    monkeypatch.setattr(
        claude_review,
        "load_claude_help",
        lambda: "--safe-mode --include-partial-messages --max-budget-usd dontAsk",
    )

    with pytest.raises(claude_review.ReviewError, match="secret material"):
        claude_review.main(["tools/new_secret.py"])


def test_main_returns_nonzero_for_partial_stream_review(monkeypatch, capsys) -> None:
    monkeypatch.setattr(claude_review, "shutil_which", lambda _: "/bin/claude")
    monkeypatch.setattr(
        claude_review,
        "load_claude_help",
        lambda: "--safe-mode --include-partial-messages --max-budget-usd dontAsk",
    )
    monkeypatch.setattr(claude_review, "run_git_diff", lambda cached, paths: "+safe\n")
    monkeypatch.setattr(
        claude_review,
        "run_stream_json",
        lambda args, prompt, timeout: claude_review.PARTIAL_REVIEW_WARNING + "\n\nReview",
    )

    exit_code = claude_review.main([])

    assert exit_code == 1
    assert "partial" in capsys.readouterr().out


def test_main_sends_built_prompt_to_stream_json(monkeypatch) -> None:
    captured = {}
    monkeypatch.setattr(claude_review, "shutil_which", lambda _: "/bin/claude")
    monkeypatch.setattr(
        claude_review,
        "load_claude_help",
        lambda: "--safe-mode --include-partial-messages --max-budget-usd dontAsk",
    )
    monkeypatch.setattr(claude_review, "run_git_diff", lambda cached, paths: "+safe\n")

    def fake_run_stream_json(args, prompt, timeout):
        captured["args"] = args
        captured["prompt"] = prompt
        captured["timeout"] = timeout
        return "Review"

    monkeypatch.setattr(claude_review, "run_stream_json", fake_run_stream_json)

    assert claude_review.main(["--timeout", "7"]) == 0
    assert captured["args"][0:2] == ["claude", "-p"]
    assert "--permission-mode" in captured["args"]
    assert "+safe" in captured["prompt"]
    assert captured["timeout"] == 7


def test_terminate_ignores_permission_race(monkeypatch) -> None:
    class FakeProcess:
        pid = 123

        def wait(self, timeout):
            raise AssertionError("wait should not run after SIGTERM permission race")

    def fake_killpg(pid, sig):
        raise PermissionError("already gone")

    monkeypatch.setattr(claude_review.os, "killpg", fake_killpg)

    claude_review._terminate(FakeProcess())


def test_terminate_escalates_to_sigkill(monkeypatch) -> None:
    calls = []

    class FakeProcess:
        pid = 123

        def wait(self, timeout):
            if len(calls) == 1:
                raise subprocess.TimeoutExpired(cmd="claude", timeout=timeout)

    def fake_killpg(pid, sig):
        calls.append(sig)

    monkeypatch.setattr(claude_review.os, "killpg", fake_killpg)

    claude_review._terminate(FakeProcess())

    assert calls == [claude_review.signal.SIGTERM, claude_review.signal.SIGKILL]
