"""Tests for Phase mint-data-architecture-v1-01 Plan 02 — Task 4
(D-04 atomicity gate + consistency check). Codex HIGH #1 closed.

These tests exercise :
- `tools/checks/doctrine_atomicity_gate.py` — given a synthetic git diff range,
  fails unless all 6 doctrine files appear in the diff.
- `tools/checks/doctrine_consistency_check.py` — greps the 6 doctrine files
  for forbidden legacy phrases ; fails on any hit.
- `lefthook.yml` carries a pre-push block invoking both scripts.
- `.github/workflows/doctrine-atomicity.yml` exists + is valid YAML.

Each fixture-driven test creates a tmp git repo via `subprocess.run(["git", ...])`.
"""

from __future__ import annotations

import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path


def _repo_root() -> Path:
    return Path(__file__).resolve().parents[3]


_DOCTRINE_FILES = (
    "CLAUDE.md",
    "docs/AGENTS/backend.md",
    "docs/AGENTS/flutter.md",
    ".claude/skills/mint-flutter-dev/SKILL.md",
    ".claude/skills/mint-backend-dev/SKILL.md",
    ".planning/decisions/2026-05-17-data-architecture-event-log-vs-bitemporal.md",
)


def _atomicity_script() -> Path:
    return _repo_root() / "tools" / "checks" / "doctrine_atomicity_gate.py"


def _consistency_script() -> Path:
    return _repo_root() / "tools" / "checks" / "doctrine_consistency_check.py"


def _init_repo(tmp: Path, files_to_touch: list) -> None:
    """Initialise a tmp git repo with all 6 doctrine files committed as baseline,
    then optionally touch + commit a subset (the « PR diff »).
    """
    env = {**os.environ, "GIT_CONFIG_GLOBAL": "/dev/null"}
    subprocess.run(["git", "init", "-q"], cwd=tmp, env=env, check=True)
    subprocess.run(
        ["git", "config", "user.email", "test@mint.test"], cwd=tmp, env=env, check=True
    )
    subprocess.run(
        ["git", "config", "user.name", "test"], cwd=tmp, env=env, check=True
    )

    # Baseline : create the 6 doctrine files with a placeholder.
    for rel in _DOCTRINE_FILES:
        path = tmp / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(f"baseline content for {rel}\n", encoding="utf-8")
    subprocess.run(["git", "add", "."], cwd=tmp, env=env, check=True)
    subprocess.run(
        ["git", "commit", "-q", "-m", "baseline"], cwd=tmp, env=env, check=True
    )

    # Touch the requested subset and commit as the « PR diff ».
    if files_to_touch:
        for rel in files_to_touch:
            path = tmp / rel
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(f"PR-edit content for {rel}\n", encoding="utf-8")
        subprocess.run(["git", "add", "."], cwd=tmp, env=env, check=True)
        subprocess.run(
            ["git", "commit", "-q", "-m", "PR diff"], cwd=tmp, env=env, check=True
        )


def _run_gate(tmp: Path, args: list) -> subprocess.CompletedProcess:
    """Run the atomicity gate against the tmp git repo."""
    return subprocess.run(
        [sys.executable, str(_atomicity_script()), *args],
        cwd=str(tmp),
        capture_output=True,
        text=True,
    )


def test_atomicity_gate_detects_all_6_files_present() -> None:
    with tempfile.TemporaryDirectory() as tmpdir:
        tmp = Path(tmpdir)
        _init_repo(tmp, list(_DOCTRINE_FILES))
        result = _run_gate(tmp, ["--base", "HEAD~1"])
        assert result.returncode == 0, (
            f"Expected exit 0 when all 6 doctrine files in diff. Got "
            f"{result.returncode} :: stderr={result.stderr}"
        )


def test_atomicity_gate_fails_on_missing_file() -> None:
    with tempfile.TemporaryDirectory() as tmpdir:
        tmp = Path(tmpdir)
        # Touch only 5 of 6 doctrine files.
        subset = list(_DOCTRINE_FILES[:5])
        _init_repo(tmp, subset)
        result = _run_gate(tmp, ["--base", "HEAD~1"])
        assert result.returncode == 1, (
            f"Expected exit 1 when 1 doctrine file missing. Got "
            f"{result.returncode} :: stderr={result.stderr}"
        )
        # Stderr must name the missing file path.
        missing = _DOCTRINE_FILES[5]
        assert missing in result.stderr, (
            f"Stderr must name the missing file path '{missing}'. "
            f"Got stderr={result.stderr!r}"
        )


def test_atomicity_gate_fails_on_unrelated_diff() -> None:
    """A PR that touches an unrelated file (not in the 6-set) is « 0 of 6 »
    and atomicity = « all-or-nothing » → 0 should PASS (no doctrine touched).
    This test verifies that pure-unrelated-PR doesn't get false-flagged.
    """
    with tempfile.TemporaryDirectory() as tmpdir:
        tmp = Path(tmpdir)
        # Baseline + commit ONLY an unrelated file.
        env = {**os.environ, "GIT_CONFIG_GLOBAL": "/dev/null"}
        subprocess.run(["git", "init", "-q"], cwd=tmp, env=env, check=True)
        subprocess.run(
            ["git", "config", "user.email", "test@mint.test"], cwd=tmp, env=env, check=True
        )
        subprocess.run(
            ["git", "config", "user.name", "test"], cwd=tmp, env=env, check=True
        )
        for rel in _DOCTRINE_FILES:
            path = tmp / rel
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(f"baseline content for {rel}\n", encoding="utf-8")
        # Also create an unrelated file in baseline.
        (tmp / "unrelated.py").write_text("# unrelated baseline\n", encoding="utf-8")
        subprocess.run(["git", "add", "."], cwd=tmp, env=env, check=True)
        subprocess.run(
            ["git", "commit", "-q", "-m", "baseline"], cwd=tmp, env=env, check=True
        )
        # Touch ONLY the unrelated file (0 of 6 doctrine files touched).
        (tmp / "unrelated.py").write_text("# unrelated edit\n", encoding="utf-8")
        subprocess.run(["git", "add", "."], cwd=tmp, env=env, check=True)
        subprocess.run(
            ["git", "commit", "-q", "-m", "unrelated"], cwd=tmp, env=env, check=True
        )

        result = _run_gate(tmp, ["--base", "HEAD~1"])
        # 0 of 6 touched = atomicity « all-or-nothing » respected = exit 0.
        assert result.returncode == 0, (
            f"Expected exit 0 when 0 doctrine files touched (unrelated PR). Got "
            f"{result.returncode} :: stderr={result.stderr}"
        )


def test_atomicity_gate_skips_if_no_doctrine_files_touched_and_flag_set() -> None:
    """The `--skip-if-untouched` flag should be safe to pass — when 0 doctrine
    files are touched, behaviour is identical to default (exit 0). Test verifies
    the flag is accepted without error.
    """
    with tempfile.TemporaryDirectory() as tmpdir:
        tmp = Path(tmpdir)
        # Baseline + ONE unrelated commit, like above.
        env = {**os.environ, "GIT_CONFIG_GLOBAL": "/dev/null"}
        subprocess.run(["git", "init", "-q"], cwd=tmp, env=env, check=True)
        subprocess.run(
            ["git", "config", "user.email", "test@mint.test"], cwd=tmp, env=env, check=True
        )
        subprocess.run(
            ["git", "config", "user.name", "test"], cwd=tmp, env=env, check=True
        )
        for rel in _DOCTRINE_FILES:
            path = tmp / rel
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(f"baseline content for {rel}\n", encoding="utf-8")
        (tmp / "unrelated.py").write_text("# unrelated baseline\n", encoding="utf-8")
        subprocess.run(["git", "add", "."], cwd=tmp, env=env, check=True)
        subprocess.run(
            ["git", "commit", "-q", "-m", "baseline"], cwd=tmp, env=env, check=True
        )
        (tmp / "unrelated.py").write_text("# unrelated edit\n", encoding="utf-8")
        subprocess.run(["git", "add", "."], cwd=tmp, env=env, check=True)
        subprocess.run(
            ["git", "commit", "-q", "-m", "unrelated"], cwd=tmp, env=env, check=True
        )

        result = _run_gate(tmp, ["--base", "HEAD~1", "--skip-if-untouched"])
        assert result.returncode == 0, (
            f"Expected exit 0 with --skip-if-untouched + 0 doctrine touched. Got "
            f"{result.returncode} :: stderr={result.stderr}"
        )


def test_consistency_check_detects_legacy_phrase() -> None:
    """Given a tmp doctrine file with a forbidden legacy phrase, the consistency
    check exits 1 and names the file + phrase.
    """
    with tempfile.TemporaryDirectory() as tmpdir:
        tmp = Path(tmpdir)
        # Mirror the doctrine-file paths under tmp so the script can scan them
        # relative to its `--repo-root` flag.
        for rel in _DOCTRINE_FILES:
            path = tmp / rel
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(f"clean content for {rel}\n", encoding="utf-8")
        # Inject the forbidden legacy phrase into backend.md.
        legacy = (
            "- **Backend = source of truth** pour constants et formulas. "
            "Flutter mirrors, jamais n'invente."
        )
        (tmp / "docs/AGENTS/backend.md").write_text(legacy + "\n", encoding="utf-8")
        result = subprocess.run(
            [sys.executable, str(_consistency_script()), "--repo-root", str(tmp)],
            capture_output=True,
            text=True,
        )
        assert result.returncode == 1, (
            f"Expected exit 1 on legacy phrase. Got {result.returncode} :: "
            f"stderr={result.stderr}"
        )
        assert "docs/AGENTS/backend.md" in result.stderr, (
            f"Stderr must name the offending file. Got {result.stderr!r}"
        )


def test_consistency_check_passes_on_rewritten_files() -> None:
    """Run the consistency check on the LIVE repo state (post-Task-1-3 rewrites)
    — must exit 0 because the legacy phrases were replaced.
    """
    result = subprocess.run(
        [sys.executable, str(_consistency_script()), "--repo-root", str(_repo_root())],
        capture_output=True,
        text=True,
    )
    assert result.returncode == 0, (
        f"Expected exit 0 on rewritten doctrine files. Got {result.returncode} "
        f":: stderr={result.stderr}"
    )


def test_lefthook_entry_present() -> None:
    lefthook = (_repo_root() / "lefthook.yml").read_text(encoding="utf-8")
    # Expect at least 2 mentions (atomicity hook + consistency hook).
    atom_hits = len(re.findall(r"doctrine-atomicity|doctrine_atomicity_gate\.py", lefthook))
    cons_hits = len(re.findall(r"doctrine-consistency|doctrine_consistency_check\.py", lefthook))
    assert atom_hits >= 1, (
        f"Expected lefthook.yml to reference doctrine_atomicity_gate.py. Got {atom_hits}."
    )
    assert cons_hits >= 1, (
        f"Expected lefthook.yml to reference doctrine_consistency_check.py. Got {cons_hits}."
    )
    # Must be in a `pre-push:` block (or any block — minimum is reference existence).
    assert "pre-push:" in lefthook, (
        "Expected a `pre-push:` block declaring the doctrine-atomicity hook."
    )


def test_github_workflow_present() -> None:
    workflow = _repo_root() / ".github" / "workflows" / "doctrine-atomicity.yml"
    assert workflow.is_file(), (
        ".github/workflows/doctrine-atomicity.yml missing — Task 4 not landed."
    )
    src = workflow.read_text(encoding="utf-8")
    # Must parse as YAML.
    try:
        import yaml

        parsed = yaml.safe_load(src)
    except Exception as exc:
        raise AssertionError(f"doctrine-atomicity.yml does not parse as YAML : {exc}")

    # Declares `on: pull_request` with types [opened, synchronize, reopened].
    # PyYAML maps `on:` to Python boolean True — handle both keys.
    on_key = "on" if "on" in parsed else (True if True in parsed else None)
    assert on_key is not None, "doctrine-atomicity.yml must declare an `on:` trigger."
    pull_request = parsed[on_key].get("pull_request")
    assert pull_request is not None, "Trigger must include `pull_request`."
    types = pull_request.get("types", [])
    for t in ("opened", "synchronize", "reopened"):
        assert t in types, (
            f"pull_request.types must include '{t}'. Got {types}."
        )
    # Must call both scripts somewhere in steps.
    assert "doctrine_atomicity_gate.py" in src, (
        "Workflow must invoke tools/checks/doctrine_atomicity_gate.py."
    )
    assert "doctrine_consistency_check.py" in src, (
        "Workflow must invoke tools/checks/doctrine_consistency_check.py."
    )
