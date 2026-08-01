from __future__ import annotations

import subprocess
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[3]
SCRIPT = REPO_ROOT / "tools/checks/mint_next_foundation_guard.py"


def _run(root: Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, str(SCRIPT), "--root", str(root)],
        capture_output=True,
        text=True,
    )


def test_guard_passes_for_repository_contract() -> None:
    proc = _run(REPO_ROOT)

    assert proc.returncode == 0, proc.stderr
    assert "OK mint_next_foundation_guard" in proc.stderr


def test_guard_rejects_self_report_as_completion_evidence(tmp_path: Path) -> None:
    contract = tmp_path / "product/mint_next/foundation.yaml"
    contract.parent.mkdir(parents=True)
    contract.write_text(
        "schema_version: 1\ncompletion_evidence:\n  allowed: [agent_summary]\n",
        encoding="utf-8",
    )

    proc = _run(tmp_path)

    assert proc.returncode == 1
    assert "agent_summary" in proc.stderr


def test_guard_rejects_unowned_required_capability(tmp_path: Path) -> None:
    contract = tmp_path / "product/mint_next/foundation.yaml"
    contract.parent.mkdir(parents=True)
    contract.write_text(
        "schema_version: 1\nrequired_capabilities:\n  experience: null\n",
        encoding="utf-8",
    )

    proc = _run(tmp_path)

    assert proc.returncode == 1
    assert "experience" in proc.stderr


def _copy_contract(tmp_path: Path) -> Path:
    target = tmp_path / "product/mint_next/foundation.yaml"
    target.parent.mkdir(parents=True)
    target.write_text(
        (REPO_ROOT / "product/mint_next/foundation.yaml").read_text(encoding="utf-8"),
        encoding="utf-8",
    )
    for rel in (
        "product/mint_next/runbooks/engram-fun2.md",
        "product/mint_next/evidence/engram-fun2-20260801.yaml",
        "product/mint_next/evidence/bead-MINT_nosync-9kv.yaml",
        "product/mint_next/evidence/engram-local-restore-20260801.txt",
        "product/mint_next/contracts/llm-eval.yaml",
    ):
        source = REPO_ROOT / rel
        path = tmp_path / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(source.read_text(encoding="utf-8"), encoding="utf-8")
    for rel in (
        ".claude/agents/mint-lead.md",
        ".claude/agents/mint-experience.md",
        ".claude/agents/mint-mobile.md",
        ".claude/agents/mint-backend.md",
        ".claude/agents/mint-swiss-brain.md",
        ".claude/agents/mint-quality-gate.md",
        ".claude/agents/mint-integrations-security.md",
    ):
        path = tmp_path / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(f"---\nname: {path.stem}\n---\n", encoding="utf-8")
    for rel in (
        ".agents/skills/mint-operating-gates/SKILL.md",
        ".agents/skills/mint-flutter-dev/SKILL.md",
        ".agents/skills/mint-backend-dev/SKILL.md",
        ".agents/skills/mint-swiss-compliance/SKILL.md",
        ".agents/skills/mint-journey-design/SKILL.md",
        ".agents/skills/mint-runtime-walkthrough/SKILL.md",
        ".agents/skills/mint-financial-calculation-contract/SKILL.md",
        ".agents/skills/mint-consent-and-provenance/SKILL.md",
        ".agents/skills/mint-experience-critique/SKILL.md",
        ".agents/skills/mint-regulatory-boundary/SKILL.md",
        ".agents/skills/mint-prompt-eval/SKILL.md",
    ):
        path = tmp_path / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(f"---\nname: {path.parent.name}\n---\n", encoding="utf-8")
    for rel in (
        "apps/mobile/pubspec.yaml",
        ".beads/config.yaml",
        "tools/checks/mermaid_render_guard.py",
        "tools/checks/maestro_locator_audit.py",
        "tools/checks/verify_sentry_init.py",
    ):
        path = tmp_path / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text("proof", encoding="utf-8")
    return target


def test_guard_rejects_premature_complete_status(tmp_path: Path) -> None:
    contract = _copy_contract(tmp_path)
    contract.write_text(
        contract.read_text(encoding="utf-8").replace("status: draft_unproven", "status: complete"),
        encoding="utf-8",
    )
    proc = _run(tmp_path)
    assert proc.returncode == 1
    assert "status" in proc.stderr


def test_guard_rejects_missing_cutover_gate(tmp_path: Path) -> None:
    contract = _copy_contract(tmp_path)
    contract.write_text(
        contract.read_text(encoding="utf-8").replace("    - rollback_proof\n", ""),
        encoding="utf-8",
    )
    proc = _run(tmp_path)
    assert proc.returncode == 1
    assert "rollback_proof" in proc.stderr


def test_guard_rejects_missing_never_sufficient_evidence(tmp_path: Path) -> None:
    contract = _copy_contract(tmp_path)
    contract.write_text(
        contract.read_text(encoding="utf-8").replace("    - author_claim\n", ""),
        encoding="utf-8",
    )
    proc = _run(tmp_path)
    assert proc.returncode == 1
    assert "author_claim" in proc.stderr


def test_guard_rejects_nonexistent_agent(tmp_path: Path) -> None:
    contract = _copy_contract(tmp_path)
    (tmp_path / ".claude/agents/mint-experience.md").unlink()
    proc = _run(tmp_path)
    assert proc.returncode == 1
    assert "mint-experience" in proc.stderr


def test_guard_rejects_missing_engram_receipt(tmp_path: Path) -> None:
    _copy_contract(tmp_path)
    (tmp_path / "product/mint_next/evidence/engram-fun2-20260801.yaml").unlink()
    proc = _run(tmp_path)
    assert proc.returncode == 1
    assert "latest_evidence" in proc.stderr


def test_guard_rejects_agent_identity_mismatch(tmp_path: Path) -> None:
    contract = _copy_contract(tmp_path)
    contract.write_text(
        contract.read_text(encoding="utf-8").replace(
            "experience: {agent: mint-experience,",
            "experience: {agent: mint-lead,",
        ),
        encoding="utf-8",
    )
    proc = _run(tmp_path)
    assert proc.returncode == 1
    assert "experience" in proc.stderr


def test_guard_rejects_unknown_skill_owner(tmp_path: Path) -> None:
    contract = _copy_contract(tmp_path)
    contract.write_text(
        contract.read_text(encoding="utf-8").replace(
            "journey_design: {owner: mint-experience,",
            "journey_design: {owner: ghost-agent,",
        ),
        encoding="utf-8",
    )
    proc = _run(tmp_path)
    assert proc.returncode == 1
    assert "ghost-agent" in proc.stderr


def test_guard_rejects_wrong_known_skill_owner(tmp_path: Path) -> None:
    contract = _copy_contract(tmp_path)
    contract.write_text(
        contract.read_text(encoding="utf-8").replace(
            "regulatory_boundary: {owner: mint-swiss-brain,",
            "regulatory_boundary: {owner: mint-mobile,",
        ),
        encoding="utf-8",
    )
    proc = _run(tmp_path)
    assert proc.returncode == 1
    assert "regulatory_boundary" in proc.stderr


def test_guard_rejects_unrelated_tool_proof(tmp_path: Path) -> None:
    contract = _copy_contract(tmp_path)
    unrelated = tmp_path / "product/mint_next/README.md"
    unrelated.write_text("unrelated", encoding="utf-8")
    contract.write_text(
        contract.read_text(encoding="utf-8").replace(
            "proof: tools/checks/verify_sentry_init.py",
            "proof: product/mint_next/README.md",
        ),
        encoding="utf-8",
    )
    proc = _run(tmp_path)
    assert proc.returncode == 1
    assert "sentry" in proc.stderr


def test_guard_rejects_tool_state_downgrade_that_removes_proof(tmp_path: Path) -> None:
    contract = _copy_contract(tmp_path)
    contract.write_text(
        contract.read_text(encoding="utf-8").replace(
            "owner: mint-quality-gate\n    state: repo_configured\n"
            "    data_class: redacted_operational_telemetry\n"
            "    proof: tools/checks/verify_sentry_init.py",
            "owner: ghost-agent\n    state: unconfigured_optional\n"
            "    data_class: redacted_operational_telemetry",
        ),
        encoding="utf-8",
    )
    proc = _run(tmp_path)
    assert proc.returncode == 1
    assert "sentry" in proc.stderr


def test_guard_rejects_missing_prompt_eval_contract(tmp_path: Path) -> None:
    contract = _copy_contract(tmp_path)
    text = contract.read_text(encoding="utf-8")
    contract.write_text(text.split("\nprompt_evals:\n", 1)[0] + "\n", encoding="utf-8")
    proc = _run(tmp_path)
    assert proc.returncode == 1
    assert "prompt_evals" in proc.stderr


def test_guard_rejects_invented_tool_state(tmp_path: Path) -> None:
    contract = _copy_contract(tmp_path)
    contract.write_text(
        contract.read_text(encoding="utf-8").replace(
            "state: unconfigured_candidate",
            "state: fully_production_verified",
        ),
        encoding="utf-8",
    )
    proc = _run(tmp_path)
    assert proc.returncode == 1
    assert "fully_production_verified" in proc.stderr
