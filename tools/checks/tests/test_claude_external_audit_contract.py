import os
import re
import subprocess
import time
from pathlib import Path

import pytest


ROOT = Path(__file__).resolve().parents[3]
SCRIPT = ROOT / "tools/checks/claude_external_audit.sh"
CLAUDE_MD = ROOT / "CLAUDE.md"
AGENTS_MD = ROOT / "AGENTS.md"
AGENT = ROOT / ".claude/agents/mint-external-auditor.md"
QUALITY_GATE = ROOT / ".claude/agents/mint-quality-gate.md"
GSD_REVIEW = ROOT / ".claude/get-shit-done/workflows/review.md"
WORKFLOW = ROOT / "docs/MINT_AGENT_WORKFLOW.md"
OPERATING_GATES = ROOT / ".claude/skills/mint-operating-gates/SKILL.md"
RAW_CLAUDE_PRINT_RE = re.compile(
    r"claude\s+(-p|--print)|"
    r"\[\s*[\"']claude[\"']\s*,\s*[\"'](-p|--print)[\"']"
)
RAW_CLAUDE_PRINT_ALLOWLIST = {
    ".claude/agents/mint-quality-gate.md",
    ".claude/get-shit-done/workflows/review.md",
    ".claude/skills/mint-operating-gates/SKILL.md",
    "CLAUDE.md",
    "AGENTS.md",
    "tools/agent-drift/golden/run.py",
    "tools/agent-drift/tests/test_golden_claude_command.py",
    "tools/checks/tests/test_claude_external_audit_contract.py",
}


def _run(*args: str, **env_overrides: str) -> subprocess.CompletedProcess[str]:
    env = {
        key: value
        for key, value in os.environ.items()
        if not key.startswith("CLAUDE_AUDIT_")
    }
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


def test_wrapper_rejects_concurrent_live_audits(tmp_path: Path) -> None:
    fake_bin = tmp_path / "bin"
    fake_bin.mkdir()
    release_file = tmp_path / "release"
    fake_claude = fake_bin / "claude"
    fake_claude.write_text(
        "#!/usr/bin/env bash\n"
        'while [ ! -f "$CLAUDE_FAKE_RELEASE" ]; do sleep 0.05; done\n'
        'printf "fake claude done\\n"\n',
        encoding="utf-8",
    )
    fake_claude.chmod(0o755)

    env = os.environ.copy()
    env.update(
        {
            "PATH": f"{fake_bin}:{env['PATH']}",
            "CLAUDE_AUDIT_LOCK_DIR": str(tmp_path),
            "CLAUDE_FAKE_RELEASE": str(release_file),
        }
    )
    first = subprocess.Popen(
        ["bash", str(SCRIPT), "specs"],
        cwd=ROOT,
        env=env,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    try:
        deadline = time.monotonic() + 5
        lock_paths: list[Path] = []
        while time.monotonic() < deadline:
            lock_paths = list(tmp_path.glob("mint-claude-audit-*.lock"))
            if lock_paths:
                break
            if first.poll() is not None:
                stdout, stderr = first.communicate()
                pytest.fail(
                    f"first audit exited before creating lock: {first.returncode}\n"
                    f"stdout={stdout}\nstderr={stderr}"
                )
            time.sleep(0.05)

        assert lock_paths, "first audit did not create a lock"
        second = subprocess.run(
            ["bash", str(SCRIPT), "specs"],
            cwd=ROOT,
            env=env,
            text=True,
            capture_output=True,
            check=False,
        )

        assert second.returncode == 2
        assert "another Claude audit is already running for this repo" in second.stderr
        assert "let it finish instead of launching a duplicate" in second.stderr
    finally:
        release_file.write_text("ok", encoding="utf-8")
        try:
            first.wait(timeout=5)
        except subprocess.TimeoutExpired:
            first.kill()
            first.wait(timeout=5)

    assert list(tmp_path.glob("mint-claude-audit-*.lock")) == []


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
        "--setting-sources user",
        "--permission-mode dontAsk",
        "--tools Read\\,Grep\\,Bash",
        "--exclude-dynamic-system-prompt-sections",
        "--- PROMPT_BEGIN ---",
        "Diff line budget: 2500 lines",
        "Staged worktree diff:",
        "Unstaged worktree diff:",
    ):
        assert needle in result.stdout


def test_product_domain_prompt_is_wired() -> None:
    result = _run("product-domain", "HEAD", CLAUDE_AUDIT_DRY_RUN="1")

    assert result.returncode == 0, result.stderr
    for needle in (
        "Audit mode: product-domain",
        "MINT Product + Swiss Domain Lead auditor",
        "Swiss financial lucidity",
        "Data Ledger / Data Quest",
        "AVS, LPP, 3a, tax, mortgage, insurance",
        "inheritance/donation/succession",
        "no personalized legal/tax/financial advice",
        "known / missing / estimated / stale",
        "Product/domain verdict: PASS",
        "Product/domain verdict: NO-GO",
        "Swiss domain review",
        "Mint product logic review",
        "Staged worktree diff:",
        "Unstaged worktree diff:",
    ):
        assert needle in result.stdout
    prompt_header = result.stdout.split("Base ref:", maxsplit=1)[0]
    assert "Return exactly one verdict line: Product/domain verdict: PASS" in prompt_header
    assert "Return exactly one verdict: PASS or NO-GO." not in prompt_header


def test_rerun_mode_defaults_to_sonnet_high() -> None:
    result = _run("code", "HEAD", CLAUDE_AUDIT_DRY_RUN="1", CLAUDE_AUDIT_RERUN="1")

    assert result.returncode == 0, result.stderr
    assert "--model sonnet" in result.stdout
    assert "--effort high" in result.stdout


def test_run_helper_scrubs_shell_audit_environment(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("CLAUDE_AUDIT_MODEL", "opus")

    result = _run("code", "HEAD", CLAUDE_AUDIT_DRY_RUN="1", CLAUDE_AUDIT_RERUN="1")

    assert result.returncode == 0, result.stderr
    assert "--model sonnet" in result.stdout
    assert "--effort high" in result.stdout


@pytest.mark.parametrize(
    ("args", "env", "stderr"),
    (
        (("code",), {"CLAUDE_AUDIT_DRY_RUN": "1"}, "code mode requires a base ref"),
        (
            ("product-domain",),
            {"CLAUDE_AUDIT_DRY_RUN": "1"},
            "product-domain mode requires a base ref",
        ),
        (("unknown",), {"CLAUDE_AUDIT_DRY_RUN": "1"}, "unknown mode"),
        (("code", "no-such-ref-xyz"), {"CLAUDE_AUDIT_DRY_RUN": "1"}, "unknown base ref"),
        (
            ("product-domain", "no-such-ref-xyz"),
            {"CLAUDE_AUDIT_DRY_RUN": "1"},
            "unknown base ref",
        ),
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
            ("code", "HEAD"),
            {"CLAUDE_AUDIT_DRY_RUN": "1", "CLAUDE_AUDIT_SETTING_SOURCES": "project"},
            "project/local settings can load repo hooks",
        ),
        (
            ("code", "HEAD"),
            {"CLAUDE_AUDIT_DRY_RUN": "1", "CLAUDE_AUDIT_SETTING_SOURCES": "local"},
            "project/local settings can load repo hooks",
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


def test_project_setting_sources_require_explicit_override() -> None:
    result = _run(
        "code",
        "HEAD",
        CLAUDE_AUDIT_DRY_RUN="1",
        CLAUDE_AUDIT_SETTING_SOURCES="project,local",
        CLAUDE_AUDIT_ALLOW_PROJECT_SETTINGS="1",
    )

    assert result.returncode == 0, result.stderr
    assert "--setting-sources project\\,local" in result.stdout


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
        AGENTS_MD.read_text(encoding="utf-8"),
        WORKFLOW.read_text(encoding="utf-8"),
        OPERATING_GATES.read_text(encoding="utf-8"),
    ):
        lowered = text.lower()
        assert "tools/checks/claude_external_audit.sh" in text
        assert "product-domain" in text
        assert (
            "Swiss domain" in text
            or "swiss domain" in lowered
            or "Swiss financial" in text
            or "swiss financial" in lowered
        )
        assert "opus high" in lowered
        assert "Sonnet high" in text
        assert "CLAUDE_AUDIT_RERUN=1" in text
        assert "CLAUDE_AUDIT_ALLOW_NON_SONNET_RERUN=1" in text
        assert "safe mode" in lowered
        assert "hooks" in lowered
        assert "plugins" in lowered
        assert "--setting-sources user" in text
        assert "CLAUDE_AUDIT_ALLOW_PROJECT_SETTINGS=1" in text
        assert "--effort max" in text
        assert "CLAUDE_AUDIT_MAX_DIFF_LINES" in text


def test_auditor_docs_reject_repeated_same_gate_audit_loops() -> None:
    for text in (
        CLAUDE_MD.read_text(encoding="utf-8"),
        AGENT.read_text(encoding="utf-8"),
        AGENTS_MD.read_text(encoding="utf-8"),
        WORKFLOW.read_text(encoding="utf-8"),
        OPERATING_GATES.read_text(encoding="utf-8"),
    ):
        lowered = text.lower()
        assert "no audit carousel" in lowered
        assert "one first pass" in lowered
        assert "one sonnet rerun" in lowered
        assert "one opus final confirmation" in lowered
        assert "fix or triage" in lowered


def test_claude_md_anchors_external_audit_latency_policy() -> None:
    text = CLAUDE_MD.read_text(encoding="utf-8")

    for needle in (
        "tools/checks/claude_external_audit.sh",
        "product-domain <base-ref>",
        "Opus high",
        "Sonnet high",
        "CLAUDE_AUDIT_RERUN=1",
        "--safe-mode",
        "no-hooks",
        "hooks, skills, plugins",
        "--strict-mcp-config",
        "--setting-sources user",
        "--no-session-persistence",
        "--effort max",
        "unsupported `--max-turns`",
        "No audit carousel",
    ):
        assert needle in text


def test_quality_gate_does_not_allow_raw_claude_fallback() -> None:
    text = QUALITY_GATE.read_text(encoding="utf-8")

    assert "tools/checks/claude_external_audit.sh" in text
    assert "otherwise `claude -p`" not in text
    assert "raw `claude -p`" in text


def test_raw_claude_print_usage_is_confined_to_known_contracts() -> None:
    files = subprocess.run(
        ["git", "ls-files"],
        cwd=ROOT,
        text=True,
        capture_output=True,
        check=True,
    ).stdout.splitlines()

    offenders: list[str] = []
    for rel_path in files:
        if rel_path.startswith(".planning/phases/"):
            continue
        if not rel_path.endswith((".md", ".py", ".sh", ".yml", ".yaml", ".txt")):
            continue
        text = (ROOT / rel_path).read_text(encoding="utf-8", errors="ignore")
        if RAW_CLAUDE_PRINT_RE.search(text) and rel_path not in RAW_CLAUDE_PRINT_ALLOWLIST:
            offenders.append(rel_path)

    assert offenders == []


def test_raw_claude_print_allowlist_entries_still_match() -> None:
    stale_entries = [
        rel_path
        for rel_path in RAW_CLAUDE_PRINT_ALLOWLIST
        if not RAW_CLAUDE_PRINT_RE.search(
            (ROOT / rel_path).read_text(encoding="utf-8", errors="ignore")
        )
    ]

    assert stale_entries == []


def test_gsd_review_claude_invocation_is_bounded() -> None:
    text = GSD_REVIEW.read_text(encoding="utf-8")

    assert "--no-input" not in text
    for needle in (
        "--model sonnet",
        "--effort high",
        "--safe-mode",
        "--strict-mcp-config",
        "--mcp-config",
        '{"mcpServers":{}}',
        "--disable-slash-commands",
        "--no-session-persistence",
        "--setting-sources user",
        "--permission-mode dontAsk",
        '--tools ""',
        "--exclude-dynamic-system-prompt-sections",
    ):
        assert needle in text


def test_operating_gates_do_not_mark_claude_wrapper_as_missing() -> None:
    text = OPERATING_GATES.read_text(encoding="utf-8")
    missing_section = text.split("## Roadmap Gates Not Installed At G0", 1)[1]

    assert "tools/checks/claude_external_audit.sh" not in missing_section
