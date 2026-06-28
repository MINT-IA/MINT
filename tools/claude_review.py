#!/usr/bin/env python3
"""Bounded Claude Code review helper for Mint diffs.

The Claude CLI can spend a long time in hidden thinking before it prints a
normal text/json result. Stream JSON mode exposes progress events, so this
wrapper uses it by default and fails loudly when Claude produces no review text.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import selectors
import signal
import subprocess
import sys
import threading
import time
from dataclasses import dataclass, field
from pathlib import Path
from typing import Iterable


DEFAULT_TIMEOUT_SECONDS = 900
DEFAULT_MAX_BYTES = 30000
DEFAULT_MODEL = "opus"
DEFAULT_OUTPUT = "stream-json"
DEFAULT_TURNS = 1
DEFAULT_BUDGET_USD = "1.00"
DISALLOWED_TOOLS = "mcp__plugin_engram_engram__*,Write,Edit,Bash"
PARTIAL_REVIEW_WARNING = (
    "[WARNING: Claude exited non-zero after producing answer text; "
    "treat this review as partial.]"
)
REQUIRED_CLAUDE_HELP_SNIPPETS = (
    "--safe-mode",
    "--include-partial-messages",
    "--max-budget-usd",
    "dontAsk",
)
SECRET_PATTERNS = (
    (re.compile(r"MINT_E2E_PASSWORD\s*="), "MINT_E2E_PASSWORD"),
    (re.compile(r"ANTHROPIC_API_KEY\s*="), "ANTHROPIC_API_KEY"),
    (re.compile(r"OPENAI_API_KEY\s*="), "OPENAI_API_KEY"),
    (re.compile(r"Authorization:\s*Bearer\s+", re.IGNORECASE), "Authorization bearer token"),
    (re.compile(r"\bBearer\s+[A-Za-z0-9._~+/\-]{20,}"), "bearer token"),
    (re.compile(r"-----BEGIN [A-Z ]*PRIVATE KEY-----"), "private key"),
    (re.compile(r"\b(?:sk|rk)_live_[A-Za-z0-9]{16,}"), "Stripe live key"),
    (re.compile(r"\bwhsec_[A-Za-z0-9]{16,}"), "Stripe webhook secret"),
    (re.compile(r"\b(?:AKIA|ASIA)[A-Z0-9]{16}\b"), "AWS access key"),
    (re.compile(r"\beyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\b"), "JWT"),
    (re.compile(r"\bgh[pousr]_[A-Za-z0-9_]{20,}"), "GitHub token"),
    (re.compile(r"\bAIza[A-Za-z0-9_-]{20,}"), "Google API key"),
    (re.compile(r"\bxox[baprs]-[A-Za-z0-9-]{20,}"), "Slack token"),
    (
        re.compile(r"\b(?:postgres|postgresql|mysql|mongodb)://[^:\s]+:[^@\s]+@"),
        "database URL credentials",
    ),
)
GENERIC_SECRET_ASSIGNMENT = re.compile(
    r"\b(password|secret|client_secret|api[_-]?key)\s*[:=]\s*['\"]?([^'\"\\\s]{12,})",
    re.IGNORECASE,
)
IDENTIFIER_CHAIN = re.compile(r"[A-Za-z_][A-Za-z0-9_]*(?:\.[A-Za-z_][A-Za-z0-9_]*)+")


class ReviewError(RuntimeError):
    """Review helper failed before a usable review was produced."""


@dataclass
class StreamState:
    delta_parts: list[str] = field(default_factory=list)
    terminal_text: str = ""
    thinking_tokens: int = 0
    last_events: list[str] = field(default_factory=list)

    @property
    def text(self) -> str:
        if self.terminal_text.strip():
            return self.terminal_text.strip()
        return "".join(self.delta_parts).strip()

    def remember(self, line: str) -> None:
        self.last_events.append(line.rstrip())
        if len(self.last_events) > 20:
            self.last_events.pop(0)


def usage_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Run a bounded Claude review on the current git diff.",
    )
    parser.add_argument("--cached", action="store_true", help="review staged diff")
    parser.add_argument(
        "--model",
        default=os.environ.get("MINT_CLAUDE_MODEL", DEFAULT_MODEL),
        help=f"Claude model alias/id, default: {DEFAULT_MODEL}",
    )
    parser.add_argument(
        "--timeout",
        type=int,
        default=int(os.environ.get("MINT_CLAUDE_TIMEOUT", DEFAULT_TIMEOUT_SECONDS)),
        help=f"hard timeout in seconds, default: {DEFAULT_TIMEOUT_SECONDS}",
    )
    parser.add_argument(
        "--max-bytes",
        type=int,
        default=int(os.environ.get("MINT_CLAUDE_MAX_BYTES", DEFAULT_MAX_BYTES)),
        help=f"max diff bytes sent to Claude, default: {DEFAULT_MAX_BYTES}",
    )
    parser.add_argument(
        "--budget-usd",
        default=os.environ.get("MINT_CLAUDE_BUDGET_USD", DEFAULT_BUDGET_USD),
        help=f"Claude CLI budget cap, default: {DEFAULT_BUDGET_USD}; set empty to disable",
    )
    parser.add_argument(
        "--output-format",
        choices=("stream-json", "json", "text"),
        default=os.environ.get("MINT_CLAUDE_OUTPUT", DEFAULT_OUTPUT),
        help=f"Claude CLI output format, default: {DEFAULT_OUTPUT}",
    )
    parser.add_argument(
        "--max-turns",
        type=int,
        default=int(os.environ.get("MINT_CLAUDE_TURNS", DEFAULT_TURNS)),
        help=f"Claude max turns, default: {DEFAULT_TURNS}",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="print metadata and Claude args without calling Claude",
    )
    parser.add_argument(
        "paths",
        nargs="*",
        help="optional path scope after --, passed to git diff",
    )
    return parser


def _explicit_untracked_diffs(paths: list[str]) -> str:
    if not paths:
        return ""
    proc = subprocess.run(
        ["git", "ls-files", "-z", "--others", "--exclude-standard", "--", *paths],
        capture_output=True,
        text=False,
        check=False,
    )
    if proc.returncode != 0:
        stderr = proc.stderr.decode("utf-8", errors="replace").strip()
        stdout = proc.stdout.decode("utf-8", errors="replace").strip()
        raise ReviewError(stderr or stdout)

    chunks: list[str] = []
    for raw in proc.stdout.split(b"\0"):
        if not raw:
            continue
        raw_path = raw.decode("utf-8", errors="surrogateescape")
        path = Path(raw_path)
        if not path.is_file():
            continue
        diff_proc = subprocess.run(
            ["git", "diff", "--no-index", "--", "/dev/null", raw_path],
            capture_output=True,
            text=True,
            check=False,
        )
        if diff_proc.returncode not in (0, 1):
            raise ReviewError(diff_proc.stderr.strip() or diff_proc.stdout.strip())
        chunks.append(diff_proc.stdout)
    return "\n".join(chunks)


def run_git_diff(cached: bool, paths: list[str]) -> str:
    args = ["git", "diff"]
    if cached:
        args.append("--cached")
    if paths:
        args.extend(["--", *paths])
    proc = subprocess.run(args, capture_output=True, text=True, check=False)
    if proc.returncode != 0:
        raise ReviewError(proc.stderr.strip() or proc.stdout.strip())
    untracked_diff = "" if cached else _explicit_untracked_diffs(paths)
    combined = proc.stdout
    if untracked_diff:
        combined = f"{combined}\n{untracked_diff}" if combined else untracked_diff

    if not combined:
        raise ReviewError("No diff to review.")
    return combined


def find_secret_markers(diff: str) -> list[str]:
    markers = [label for pattern, label in SECRET_PATTERNS if pattern.search(diff)]
    for match in GENERIC_SECRET_ASSIGNMENT.finditer(diff):
        value = match.group(2).rstrip(";,")
        if not IDENTIFIER_CHAIN.fullmatch(value):
            markers.append("generic secret assignment")
            break
    return markers


def guard_no_obvious_secrets(diff: str) -> None:
    if os.environ.get("MINT_CLAUDE_ALLOW_SECRET_DIFF") == "1":
        return
    markers = find_secret_markers(diff)
    if markers:
        joined = ", ".join(sorted(set(markers)))
        raise ReviewError(
            "Refusing to send diff to Claude because it appears to contain "
            f"secret material: {joined}. Set MINT_CLAUDE_ALLOW_SECRET_DIFF=1 "
            "only after manual redaction/risk review."
        )


def truncate_diff(diff: str, max_bytes: int) -> tuple[str, int, bool]:
    raw = diff.encode("utf-8")
    if len(raw) <= max_bytes:
        return diff, len(raw), False
    trimmed = raw[:max_bytes].decode("utf-8", errors="ignore")
    return trimmed, len(raw), True


def build_prompt(diff: str, original_bytes: int, sent_bytes: int, truncated: bool) -> str:
    delimiter = "MINT_DIFF_BOUNDARY_" + hashlib.sha256(
        diff.encode("utf-8")
    ).hexdigest()[:16]
    return f"""Review this Mint diff for correctness, regressions, missing tests, security, and fintech trust issues.

Focus on concrete blocking findings. Do not ask to run tools. Do not restate the whole diff.

Diff metadata:
bytes_sent={sent_bytes}
bytes_original={original_bytes}
truncated={'yes' if truncated else 'no'}

Return:
- Critical blocking findings with file/line references, if any.
- Important non-blocking findings, if any.
- Missing high-risk tests, if any.
- Otherwise: "No blocking findings."

Diff begins after this delimiter line and ends at the matching delimiter:
{delimiter}
{diff}
{delimiter}
"""


def build_claude_args(
    *,
    model: str,
    output_format: str,
    max_turns: int,
    budget_usd: str,
) -> list[str]:
    args = [
        "claude",
        "-p",
        "--model",
        model,
        "--tools",
        "",
        "--disallowed-tools",
        DISALLOWED_TOOLS,
        "--no-session-persistence",
        "--safe-mode",
        "--permission-mode",
        "dontAsk",
        "--max-turns",
        str(max_turns),
        "--output-format",
        output_format,
    ]
    if output_format == "stream-json":
        args.extend(["--verbose", "--include-partial-messages"])
    if budget_usd:
        args.extend(["--max-budget-usd", budget_usd])
    return args


def load_claude_help(timeout_seconds: int = 10) -> str:
    try:
        proc = subprocess.run(
            ["claude", "--help"],
            capture_output=True,
            text=True,
            timeout=timeout_seconds,
            check=False,
        )
    except subprocess.TimeoutExpired as exc:
        raise ReviewError("claude --help timed out") from exc
    if proc.returncode != 0:
        raise ReviewError(proc.stderr.strip() or proc.stdout.strip())
    return f"{proc.stdout}\n{proc.stderr}"


def assert_claude_cli_support(help_text: str) -> None:
    missing = [
        snippet
        for snippet in REQUIRED_CLAUDE_HELP_SNIPPETS
        if snippet not in help_text
    ]
    if missing:
        raise ReviewError(
            "Installed claude CLI does not advertise required review flags: "
            + ", ".join(missing)
        )


def _append_text_from_obj(obj: dict, state: StreamState) -> None:
    if obj.get("type") == "system" and obj.get("subtype") == "thinking_tokens":
        state.thinking_tokens = max(
            state.thinking_tokens,
            int(obj.get("estimated_tokens") or 0),
        )
        return

    if obj.get("type") == "stream_event":
        event = obj.get("event") or {}
        if event.get("type") == "content_block_start":
            block = event.get("content_block") or {}
            if block.get("type") == "text":
                state.delta_parts.append(block.get("text") or "")
        if event.get("type") == "content_block_delta":
            delta = event.get("delta") or {}
            if delta.get("type") == "text_delta":
                state.delta_parts.append(delta.get("text") or "")
        return

    if obj.get("type") == "assistant":
        message = obj.get("message") or {}
        parts: list[str] = []
        for block in message.get("content") or []:
            if isinstance(block, dict) and block.get("type") == "text":
                parts.append(block.get("text") or "")
        if parts:
            state.terminal_text = "".join(parts)
        return

    if obj.get("type") == "result" and obj.get("result"):
        state.terminal_text = str(obj["result"])


def parse_stream_line(line: str, state: StreamState) -> None:
    state.remember(line)
    try:
        obj = json.loads(line)
    except json.JSONDecodeError:
        return
    _append_text_from_obj(obj, state)


def require_review_text(state: StreamState) -> str:
    if state.text:
        return state.text
    tail = "\n".join(state.last_events[-5:])
    raise ReviewError(
        "Claude review produced no answer text; "
        f"last thinking estimate={state.thinking_tokens} tokens.\n"
        f"Last stream events:\n{tail}"
    )


def _terminate(proc: subprocess.Popen[str]) -> None:
    try:
        os.killpg(proc.pid, signal.SIGTERM)
    except (PermissionError, ProcessLookupError):
        return
    try:
        proc.wait(timeout=3)
    except subprocess.TimeoutExpired:
        try:
            os.killpg(proc.pid, signal.SIGKILL)
        except (PermissionError, ProcessLookupError):
            return
        proc.wait(timeout=3)


def _feed_stdin(proc: subprocess.Popen[str], prompt: str, errors: list[str]) -> None:
    try:
        assert proc.stdin is not None
        proc.stdin.write(prompt)
        proc.stdin.close()
    except BrokenPipeError:
        return
    except Exception as exc:  # pragma: no cover - defensive thread handoff.
        errors.append(str(exc))


def _watchdog(
    proc: subprocess.Popen[str],
    timeout_seconds: int,
    stop_event: threading.Event,
    timed_out: threading.Event,
) -> None:
    if stop_event.wait(timeout_seconds):
        return
    if proc.poll() is None:
        timed_out.set()
        _terminate(proc)


def run_stream_json(args: list[str], prompt: str, timeout_seconds: int) -> str:
    proc = subprocess.Popen(
        args,
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        bufsize=1,
        start_new_session=True,
    )
    assert proc.stdout is not None

    stdin_errors: list[str] = []
    stdin_thread = threading.Thread(
        target=_feed_stdin,
        args=(proc, prompt, stdin_errors),
        daemon=True,
    )
    stdin_thread.start()
    stop_watchdog = threading.Event()
    timed_out = threading.Event()
    watchdog_thread = threading.Thread(
        target=_watchdog,
        args=(proc, timeout_seconds, stop_watchdog, timed_out),
        daemon=True,
    )
    watchdog_thread.start()

    state = StreamState()
    selector = selectors.DefaultSelector()
    selector.register(proc.stdout, selectors.EVENT_READ)
    deadline = time.monotonic() + timeout_seconds
    next_progress = 1000

    while True:
        if time.monotonic() > deadline:
            _terminate(proc)
            raise ReviewError(
                "Claude review timed out after "
                f"{timeout_seconds}s; last thinking estimate="
                f"{state.thinking_tokens} tokens."
            )

        if proc.poll() is not None:
            rest = proc.stdout.read()
            for line in rest.splitlines():
                parse_stream_line(line, state)
            break

        for key, _ in selector.select(timeout=0.5):
            line = key.fileobj.readline()
            if not line:
                continue
            parse_stream_line(line, state)
            if state.thinking_tokens >= next_progress:
                print(
                    f"[claude_review] thinking_tokens~{state.thinking_tokens}",
                    file=sys.stderr,
                    flush=True,
                )
                next_progress += 1000

    stdin_thread.join(timeout=1)
    stop_watchdog.set()
    watchdog_thread.join(timeout=1)
    if stdin_errors:
        raise ReviewError(f"Unable to send prompt to Claude: {stdin_errors[-1]}")
    if timed_out.is_set():
        raise ReviewError(
            "Claude review timed out after "
            f"{timeout_seconds}s; last thinking estimate="
            f"{state.thinking_tokens} tokens."
        )
    if proc.returncode is not None and proc.returncode < 0:
        raise ReviewError(
            "Claude review exited after signal "
            f"{-proc.returncode}; last thinking estimate={state.thinking_tokens} tokens."
        )

    if proc.returncode != 0 and state.text:
        print(
            f"[claude_review] Claude exited with code {proc.returncode} "
            "after producing answer text; using captured review text.",
            file=sys.stderr,
        )
        return PARTIAL_REVIEW_WARNING + "\n\n" + state.text
    if proc.returncode != 0:
        tail = "\n".join(state.last_events[-5:])
        raise ReviewError(
            f"Claude exited with code {proc.returncode}.\nLast stream output:\n{tail}"
        )
    return require_review_text(state)


def run_text_or_json(args: list[str], prompt: str, timeout_seconds: int) -> str:
    try:
        proc = subprocess.run(
            args,
            input=prompt,
            capture_output=True,
            text=True,
            timeout=timeout_seconds,
            check=False,
        )
    except subprocess.TimeoutExpired as exc:
        raise ReviewError(f"Claude review timed out after {timeout_seconds}s") from exc
    if proc.returncode != 0:
        raise ReviewError(proc.stderr.strip() or proc.stdout.strip())
    if "--output-format" in args and args[args.index("--output-format") + 1] == "json":
        try:
            payload = json.loads(proc.stdout)
        except json.JSONDecodeError as exc:
            raise ReviewError(f"Claude JSON output was not valid JSON: {proc.stdout}") from exc
        result = (payload.get("result") or "").strip()
        if not result:
            raise ReviewError(f"Claude JSON output had empty .result: {proc.stdout}")
        return result
    return proc.stdout.strip()


def main(argv: Iterable[str] | None = None) -> int:
    parser = usage_parser()
    ns = parser.parse_args(list(argv) if argv is not None else None)

    if ns.timeout <= 0 or ns.max_bytes <= 0 or ns.max_turns <= 0:
        parser.error("--timeout, --max-bytes, and --max-turns must be positive")

    if not shutil_which("claude"):
        raise ReviewError("claude CLI not found on PATH")
    assert_claude_cli_support(load_claude_help())

    diff = run_git_diff(ns.cached, ns.paths)
    guard_no_obvious_secrets(diff)
    diff_for_prompt, original_bytes, truncated = truncate_diff(diff, ns.max_bytes)
    sent_bytes = len(diff_for_prompt.encode("utf-8"))
    prompt = build_prompt(diff_for_prompt, original_bytes, sent_bytes, truncated)
    claude_args = build_claude_args(
        model=ns.model,
        output_format=ns.output_format,
        max_turns=ns.max_turns,
        budget_usd=ns.budget_usd,
    )

    if ns.dry_run:
        print(
            json.dumps(
                {
                    "model": ns.model,
                    "output_format": ns.output_format,
                    "timeout": ns.timeout,
                    "bytes_sent": sent_bytes,
                    "bytes_original": original_bytes,
                    "truncated": truncated,
                    "claude_args": claude_args,
                },
                indent=2,
            )
        )
        return 0

    if ns.output_format == "stream-json":
        result = run_stream_json(claude_args, prompt, ns.timeout)
    else:
        result = run_text_or_json(claude_args, prompt, ns.timeout)
    print(result)
    if result.startswith(PARTIAL_REVIEW_WARNING):
        return 1
    return 0


def shutil_which(cmd: str) -> str | None:
    for directory in os.environ.get("PATH", "").split(os.pathsep):
        candidate = Path(directory) / cmd
        if candidate.is_file() and os.access(candidate, os.X_OK):
            return str(candidate)
    return None


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except ReviewError as exc:
        print(f"claude_review: {exc}", file=sys.stderr)
        raise SystemExit(2)
