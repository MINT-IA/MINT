"""Phase mint-data-architecture-v1-01 Plan 04 Task 2 — codegen integration tests.

Verifies the shipped artifacts of Plan 04 :
  - the generated Dart file exists at the canonical path + has the
    AUTO-GENERATED header + exposes the expected top-level constants
  - lefthook.yml carries the pre-commit `regulatory-codegen-check` entry
  - .github/workflows/regulatory-codegen.yml exists + parses as valid YAML
    + declares `on: pull_request` + references the codegen script + the
    aging-state file path
  - the workflow has 4 escalation levels (UP, level 1 PR comment, level 2
    auto-open issue, level 3 HARD BLOCK)
"""
from __future__ import annotations

import re
from pathlib import Path

import pytest
import yaml

_REPO_ROOT = Path(__file__).resolve().parents[3]
_GENERATED_DART = (
    _REPO_ROOT
    / "apps"
    / "mobile"
    / "lib"
    / "services"
    / "financial_core"
    / "generated"
    / "regulatory_constants.g.dart"
)
_LEFTHOOK = _REPO_ROOT / "lefthook.yml"
_WORKFLOW = _REPO_ROOT / ".github" / "workflows" / "regulatory-codegen.yml"


# ── Test 1 ──
def test_generated_dart_file_exists() -> None:
    """File exists at the canonical path, has AUTO-GENERATED header + expected exports."""
    assert _GENERATED_DART.exists(), (
        f"missing generated file at {_GENERATED_DART} — run "
        f"python3 tools/codegen/regulatory_constants_to_dart.py --source local --write"
    )
    content = _GENERATED_DART.read_text(encoding="utf-8")
    assert "AUTO-GENERATED" in content
    assert "Phase mint-data-architecture-v1-01 Plan 04" in content
    assert "DO NOT EDIT MANUALLY" in content
    assert "const String regulatoryConstantsVersionHash" in content
    assert "const String regulatoryConstantsEffectiveOn" in content
    assert "regulatoryConstantsSnapshot" in content
    # SHA-256 hex sanity check on the baked version_hash literal.
    match = re.search(
        r"const\s+String\s+regulatoryConstantsVersionHash\s*=\s*'([0-9a-f]{64})';",
        content,
    )
    assert match is not None, "version_hash literal not 64-char hex"


# ── Test 3 ──
def test_lefthook_entry_present() -> None:
    """lefthook.yml carries an entry invoking the codegen --check in pre-commit."""
    assert _LEFTHOOK.exists()
    parsed = yaml.safe_load(_LEFTHOOK.read_text(encoding="utf-8"))
    pre_commit = parsed.get("pre-commit", {}).get("commands", {})
    matching = [
        name for name in pre_commit
        if "regulatory-codegen" in name or "regulatory_codegen" in name
    ]
    assert matching, (
        f"no pre-commit entry containing 'regulatory-codegen' found ; "
        f"available: {list(pre_commit.keys())}"
    )
    # Locate the actual command line.
    entry = pre_commit[matching[0]]
    assert "regulatory_constants_to_dart.py" in entry["run"]
    assert "--check" in entry["run"]
    assert "--source" in entry["run"] and "local" in entry["run"]


# ── Test 4 ──
def test_github_workflow_present() -> None:
    """The codegen workflow exists, parses as YAML, on: pull_request, references script + aging state."""
    assert _WORKFLOW.exists(), f"missing workflow at {_WORKFLOW}"
    parsed = yaml.safe_load(_WORKFLOW.read_text(encoding="utf-8"))
    assert parsed is not None
    # `on` is parsed as Python's True boolean — YAML accepts both keys.
    on_block = parsed.get("on") if "on" in parsed else parsed.get(True)
    assert on_block is not None, f"workflow missing `on:` block ; keys = {list(parsed.keys())}"
    assert "pull_request" in on_block, f"workflow not triggered on pull_request: {on_block}"

    text = _WORKFLOW.read_text(encoding="utf-8")
    assert "tools/codegen/regulatory_constants_to_dart.py" in text
    assert ".planning/state/regulatory-codegen-aging.json" in text


# ── Test 5 ──
def test_github_workflow_aging_state_path() -> None:
    """The workflow contains a step that reads/writes the aging state JSON."""
    text = _WORKFLOW.read_text(encoding="utf-8")
    assert "regulatory-codegen-aging.json" in text
    # Should pass --aging-state-file as a flag at least once.
    assert "--aging-state-file" in text


# ── Test 6 ──
def test_workflow_escalation_step_naming() -> None:
    """The workflow has 4 escalation steps visible in CI logs : UP probe, L1, L2, L3."""
    text = _WORKFLOW.read_text(encoding="utf-8")
    # Step naming convention so CI run logs visibly show the escalation chain.
    assert "level 1" in text.lower() and "pr comment" in text.lower(), (
        "expected 'level 1 ... PR comment' step naming"
    )
    assert "level 2" in text.lower() and ("open issue" in text.lower() or "auto-open issue" in text.lower()), (
        "expected 'level 2 ... open issue' step naming"
    )
    assert "level 3" in text.lower() and "block" in text.lower(), (
        "expected 'level 3 ... HARD BLOCK' step naming"
    )
    # Confirms the per-day numeric thresholds appear so the contract is visible in YAML.
    assert "7" in text and "14" in text and "28" in text


def test_staging_up_hash_mismatch_warns_not_blocks() -> None:
    """A PR that changes the local registry must not require staging to
    already publish the new hash; the local --check remains the hard gate."""
    text = _WORKFLOW.read_text(encoding="utf-8")
    assert "::warning::Staging hash differs" in text
    assert "::error::Staging hash differs" not in text


# ── Test 7 (aging state file seeded with initial state) ──
def test_aging_state_file_seeded() -> None:
    """`.planning/state/regulatory-codegen-aging.json` exists with initial state."""
    state_file = _REPO_ROOT / ".planning" / "state" / "regulatory-codegen-aging.json"
    assert state_file.exists(), f"missing aging state file at {state_file}"
    import json
    state = json.loads(state_file.read_text(encoding="utf-8"))
    assert state.get("escalation_level") == 0
    assert state.get("consecutive_down_days") == 0


if __name__ == "__main__":
    raise SystemExit(pytest.main([__file__, "-v"]))
