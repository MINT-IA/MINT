#!/usr/bin/env python3
"""Fail closed when the MINT Next foundation contract loses critical controls."""
from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path

import yaml


CONTRACT = Path("product/mint_next/foundation.yaml")
REQUIRED_CAPABILITIES = {
    "product_lead",
    "experience",
    "mobile",
    "backend_calculations",
    "swiss_domain",
    "quality_privacy_security",
    "data_integrations",
}
CAPABILITY_AGENTS = {
    "product_lead": ("mint-lead", ".claude/agents/mint-lead.md"),
    "experience": ("mint-experience", ".claude/agents/mint-experience.md"),
    "mobile": ("mint-mobile", ".claude/agents/mint-mobile.md"),
    "backend_calculations": ("mint-backend", ".claude/agents/mint-backend.md"),
    "swiss_domain": ("mint-swiss-brain", ".claude/agents/mint-swiss-brain.md"),
    "quality_privacy_security": ("mint-quality-gate", ".claude/agents/mint-quality-gate.md"),
    "data_integrations": ("mint-integrations-security", ".claude/agents/mint-integrations-security.md"),
}
SKILL_CONTRACTS = {
    "operating_gates": ("mint-quality-gate", ".agents/skills/mint-operating-gates/SKILL.md"),
    "flutter": ("mint-mobile", ".agents/skills/mint-flutter-dev/SKILL.md"),
    "backend": ("mint-backend", ".agents/skills/mint-backend-dev/SKILL.md"),
    "swiss_compliance": ("mint-swiss-brain", ".agents/skills/mint-swiss-compliance/SKILL.md"),
    "journey_design": ("mint-experience", ".agents/skills/mint-journey-design/SKILL.md"),
    "runtime_walkthrough": ("mint-quality-gate", ".agents/skills/mint-runtime-walkthrough/SKILL.md"),
    "financial_calculation_contract": ("mint-swiss-brain", ".agents/skills/mint-financial-calculation-contract/SKILL.md"),
    "consent_and_provenance": ("mint-integrations-security", ".agents/skills/mint-consent-and-provenance/SKILL.md"),
    "experience_critique": ("mint-experience", ".agents/skills/mint-experience-critique/SKILL.md"),
    "regulatory_boundary": ("mint-swiss-brain", ".agents/skills/mint-regulatory-boundary/SKILL.md"),
    "prompt_eval": ("mint-quality-gate", ".agents/skills/mint-prompt-eval/SKILL.md"),
}
REQUIRED_TOOLS = {
    "flutter",
    "beads",
    "engram",
    "mermaid",
    "maestro",
    "patrol",
    "sentry",
    "railway",
    "infomaniak",
    "vercel",
    "hugging_face",
}
ALLOWED_EVIDENCE = {
    "deterministic_check",
    "current_state_inspection",
    "independent_adversarial_review",
    "runtime_proof",
    "user_research",
}
FORBIDDEN_EVIDENCE = {"agent_summary", "author_claim", "plan_status", "memory_only"}
REQUIRED_CUTOVER = {
    "coordinated_agent_shutdown",
    "encrypted_volume_mounted",
    "database_restore_drill",
    "rollback_proof",
    "independent_review",
}
TOOL_STATES = {
    "repo_configured",
    "locally_verified",
    "existing_path_not_reverified_in_batch0",
    "unconfigured_candidate",
    "available_not_reverified_in_batch0",
    "unconfigured_optional",
}
PROVEN_TOOL_STATES = {"repo_configured", "locally_verified"}
TOOL_PROOFS = {
    "flutter": "apps/mobile/pubspec.yaml",
    "beads": "product/mint_next/evidence/bead-MINT_nosync-9kv.yaml",
    "engram": "product/mint_next/evidence/engram-fun2-20260801.yaml",
    "mermaid": "tools/checks/mermaid_render_guard.py",
    "maestro": "tools/checks/maestro_locator_audit.py",
    "patrol": "apps/mobile/pubspec.yaml",
    "sentry": "tools/checks/verify_sentry_init.py",
}
TOOL_CONTRACTS = {
    "flutter": ("iOS and Android product implementation", "mint-mobile", "repo_configured", "synthetic_and_user_financial_ui", TOOL_PROOFS["flutter"]),
    "beads": ("durable work, dependencies, blockers, and ownership", "mint-lead", "locally_verified", "project_metadata_no_user_financial_data", TOOL_PROOFS["beads"]),
    "engram": ("prior decisions, discoveries, preferences, and session recovery", "mint-lead", "locally_verified", "project_memory_no_user_financial_data", TOOL_PROOFS["engram"]),
    "mermaid": ("generated views of journeys, routes, data, and system boundaries", "mint-lead", "repo_configured", "generated_project_metadata", TOOL_PROOFS["mermaid"]),
    "maestro": ("small black-box smoke suite for critical user journeys", "mint-quality-gate", "repo_configured", "synthetic_runtime_evidence", TOOL_PROOFS["maestro"]),
    "patrol": ("native mobile boundaries such as permissions, files, biometrics, and notifications", "mint-quality-gate", "repo_configured", "synthetic_runtime_evidence", TOOL_PROOFS["patrol"]),
    "sentry": ("privacy-filtered crash and runtime error evidence", "mint-quality-gate", "repo_configured", "redacted_operational_telemetry", TOOL_PROOFS["sentry"]),
    "railway": ("current synthetic-data staging and existing runtime delivery path", "mint-backend", "existing_path_not_reverified_in_batch0", "synthetic_staging_only", None),
    "infomaniak": ("candidate Swiss production data plane pending an operational spike", "mint-integrations-security", "unconfigured_candidate", "no_data_until_spike_approved", None),
    "vercel": ("optional previews and non-sensitive web surfaces, never the default financial data plane", "mint-experience", "available_not_reverified_in_batch0", "public_or_synthetic_only", None),
    "hugging_face": ("optional measured model, embedding, and evaluation experiments only", "mint-integrations-security", "unconfigured_optional", "public_corpus_or_synthetic_only", None),
}
PROMPT_EVAL_CONTRACT = {
    "owner": "mint-quality-gate",
    "policy": "product/mint_next/contracts/llm-eval.yaml",
    "applies_to": "every_llm_or_rag_behavior_change",
    "required_artifacts": [
        "versioned_prompt", "immutable_golden_corpus",
        "deterministic_and_judged_metrics", "regression_report",
    ],
    "promotion_rule": "no_regression_on_safety_privacy_compliance_and_measured_improvement",
    "self_approval": "forbidden",
}


def _load(root: Path, errors: list[str]) -> dict:
    path = root / CONTRACT
    try:
        data = yaml.safe_load(path.read_text(encoding="utf-8"))
    except OSError as exc:
        errors.append(f"unable to read {CONTRACT}: {exc}")
        return {}
    except yaml.YAMLError as exc:
        errors.append(f"{CONTRACT} is invalid YAML: {exc}")
        return {}
    if not isinstance(data, dict):
        errors.append(f"{CONTRACT} must be a mapping")
        return {}
    return data


def _frontmatter_name(path: Path) -> str | None:
    try:
        text = path.read_text(encoding="utf-8")
    except OSError:
        return None
    if not text.startswith("---\n") or "\n---\n" not in text[4:]:
        return None
    raw = text.split("\n---\n", 1)[0][4:]
    data = yaml.safe_load(raw)
    return data.get("name") if isinstance(data, dict) else None


def validate(root: Path) -> list[str]:
    errors: list[str] = []
    data = _load(root, errors)
    if data.get("schema_version") != 1:
        errors.append("schema_version must be 1")

    tracking = data.get("work_tracking")
    if not isinstance(tracking, dict) or tracking.get("system") != "beads":
        errors.append("work_tracking must use beads")
    else:
        bead_id = tracking.get("id")
        if not isinstance(bead_id, str) or not bead_id.startswith("MINT_nosync-"):
            errors.append("work_tracking bead id is invalid")
        snapshot_rel = tracking.get("snapshot")
        if not isinstance(snapshot_rel, str) or not (root / snapshot_rel).is_file():
            errors.append("work_tracking snapshot must reference a committed file")
        else:
            snapshot = yaml.safe_load((root / snapshot_rel).read_text(encoding="utf-8"))
            if not isinstance(snapshot, dict) or snapshot.get("id") != bead_id:
                errors.append("work_tracking snapshot bead id mismatch")
            if not isinstance(snapshot, dict) or snapshot.get("status") != tracking.get("captured_status"):
                errors.append("work_tracking snapshot status mismatch")
        if tracking.get("journey_os") != "not_applicable_foundation_has_no_user_route":
            errors.append("foundation must explicitly state why no Journey OS route owns it")

    capabilities = data.get("required_capabilities")
    if not isinstance(capabilities, dict):
        errors.append("required_capabilities must be a mapping")
        capabilities = {}
    for name in sorted(REQUIRED_CAPABILITIES):
        owner = capabilities.get(name)
        if not isinstance(owner, dict) or not owner.get("agent") or not owner.get("file"):
            errors.append(f"required capability {name} has no owner")
            continue
        path = root / str(owner["file"])
        if not path.is_file():
            errors.append(f"required agent {owner['agent']} missing at {owner['file']}")
            continue
        expected_agent, expected_file = CAPABILITY_AGENTS[name]
        if (owner.get("agent"), owner.get("file")) != (expected_agent, expected_file):
            errors.append(f"required capability {name} must be owned by {expected_agent} at {expected_file}")
        if _frontmatter_name(path) != owner.get("agent"):
            errors.append(f"agent identity mismatch for {owner.get('agent')} at {owner.get('file')}")

    skills = data.get("skills")
    if not isinstance(skills, dict) or not skills:
        errors.append("skills must be a non-empty mapping")
        skills = {}
    for name, skill in skills.items():
        if not isinstance(skill, dict) or not skill.get("owner") or not skill.get("file"):
            errors.append(f"skill {name} must have owner and file")
            continue
        if not (root / str(skill["file"])).is_file():
            errors.append(f"skill {name} missing at {skill['file']}")
            continue
        roster = {agent for agent, _ in CAPABILITY_AGENTS.values()}
        if skill.get("owner") not in roster:
            errors.append(f"skill {name} has unknown owner {skill.get('owner')}")
        expected = SKILL_CONTRACTS.get(name)
        if expected is None:
            errors.append(f"skill {name} is not part of the foundation contract")
        elif (skill.get("owner"), skill.get("file")) != expected:
            errors.append(f"skill {name} must be owned by {expected[0]} at {expected[1]}")
        if _frontmatter_name(root / str(skill["file"])) != Path(str(skill["file"])).parent.name:
            errors.append(f"skill identity mismatch at {skill['file']}")
    missing_skills = set(SKILL_CONTRACTS) - set(skills)
    if missing_skills:
        errors.append(f"skills missing: {', '.join(sorted(missing_skills))}")

    tools = data.get("tools")
    if not isinstance(tools, dict):
        errors.append("tools must be a mapping")
        tools = {}
    for name in sorted(REQUIRED_TOOLS):
        entry = tools.get(name)
        missing_fields = [
            field for field in ("role", "owner", "state", "data_class")
            if not isinstance(entry, dict) or not entry.get(field)
        ]
        if missing_fields:
            errors.append(f"tool {name} missing: {', '.join(missing_fields)}")
            continue
        state = str(entry["state"])
        if state not in TOOL_STATES:
            errors.append(f"tool {name} has unknown state {state}")
        actual_contract = (
            entry.get("role"), entry.get("owner"), entry.get("state"),
            entry.get("data_class"), entry.get("proof"),
        )
        if actual_contract != TOOL_CONTRACTS[name]:
            errors.append(f"tool {name} does not match its canonical role, owner, state, data class, and proof")
        if state in PROVEN_TOOL_STATES:
            proof = entry.get("proof")
            if not isinstance(proof, str) or not (root / proof).exists():
                errors.append(f"tool {name} state {state} requires committed proof")
            expected_proof = TOOL_PROOFS.get(name)
            if proof != expected_proof:
                errors.append(f"tool {name} must use proof {expected_proof}")

    prompt_evals = data.get("prompt_evals")
    if prompt_evals != PROMPT_EVAL_CONTRACT:
        errors.append("prompt_evals must match the canonical evaluation contract")
    policy = prompt_evals.get("policy") if isinstance(prompt_evals, dict) else None
    if not isinstance(policy, str) or not (root / policy).is_file():
        errors.append("prompt_evals policy must reference a committed file")

    if data.get("status") != "draft_unproven":
        errors.append("status must remain draft_unproven until a separate promotion contract exists")

    evidence = data.get("completion_evidence")
    allowed = evidence.get("allowed") if isinstance(evidence, dict) else None
    if not isinstance(allowed, list):
        errors.append("completion_evidence.allowed must be a list")
        allowed = []
    values = {str(value) for value in allowed}
    for forbidden in sorted(values & FORBIDDEN_EVIDENCE):
        errors.append(f"completion evidence must not trust {forbidden}")
    missing = ALLOWED_EVIDENCE - values
    if missing:
        errors.append(f"completion evidence missing: {', '.join(sorted(missing))}")
    never = evidence.get("never_sufficient") if isinstance(evidence, dict) else None
    never_values = {str(value) for value in never} if isinstance(never, list) else set()
    missing_never = FORBIDDEN_EVIDENCE - never_values
    if missing_never:
        errors.append(f"never_sufficient missing: {', '.join(sorted(missing_never))}")

    batches = data.get("batch_policy")
    if not isinstance(batches, dict) or batches.get("status_default") != "unproven":
        errors.append("batch status must default to unproven")
    if not isinstance(batches, dict) or batches.get("author_cannot_approve") is not True:
        errors.append("batch author must not approve their own work")

    memory = data.get("memory")
    if not isinstance(memory, dict) or memory.get("source_of_truth") is not False:
        errors.append("Engram memory must never be a source of truth")
    if not isinstance(memory, dict) or memory.get("fun2_mode") != "encrypted_backup":
        errors.append("FUN2 must remain encrypted backup until restore/cutover proof")
    cutover = memory.get("cutover_requires") if isinstance(memory, dict) else None
    cutover_values = {str(value) for value in cutover} if isinstance(cutover, list) else set()
    missing_cutover = REQUIRED_CUTOVER - cutover_values
    if missing_cutover:
        errors.append(f"cutover requirements missing: {', '.join(sorted(missing_cutover))}")
    for key in ("runbook", "latest_evidence"):
        rel = memory.get(key) if isinstance(memory, dict) else None
        if not isinstance(rel, str) or not (root / rel).is_file():
            errors.append(f"memory {key} must reference a committed file")
    evidence_rel = memory.get("latest_evidence") if isinstance(memory, dict) else None
    if isinstance(evidence_rel, str) and (root / evidence_rel).is_file():
        try:
            receipt = yaml.safe_load((root / evidence_rel).read_text(encoding="utf-8"))
        except (OSError, yaml.YAMLError) as exc:
            errors.append(f"unable to validate Engram evidence: {exc}")
        else:
            drills = receipt.get("restore_drills") if isinstance(receipt, dict) else None
            if not isinstance(receipt, dict) or receipt.get("live_cutover_allowed") is not False:
                errors.append("Engram evidence must keep live_cutover_allowed false")
            if not isinstance(drills, dict) or drills.get("sqlite_local_restore") != "pass":
                errors.append("Engram evidence must prove a local SQLite restore")
            receipt_rel = drills.get("sqlite_local_restore_receipt") if isinstance(drills, dict) else None
            if not isinstance(receipt_rel, str) or not (root / receipt_rel).is_file():
                errors.append("Engram local restore must reference a durable receipt")

    return errors


def _live_tracking_errors(root: Path, data: dict) -> list[str]:
    tracking = data.get("work_tracking", {})
    common = subprocess.run(
        ["git", "rev-parse", "--path-format=absolute", "--git-common-dir"],
        cwd=root,
        capture_output=True,
        text=True,
    )
    if common.returncode:
        return ["unable to locate canonical repository for live Beads check"]
    canonical_root = Path(common.stdout.strip()).parent
    proc = subprocess.run(
        ["bd", "-C", str(canonical_root), "show", str(tracking.get("id", "")), "--json"],
        cwd=root,
        capture_output=True,
        text=True,
    )
    if proc.returncode:
        return [f"unable to inspect live Bead: {proc.stderr.strip() or proc.stdout.strip()}"]
    try:
        payload = json.loads(proc.stdout)
    except json.JSONDecodeError as exc:
        return [f"live Bead returned invalid JSON: {exc}"]
    item = payload[0] if isinstance(payload, list) and payload else payload
    if not isinstance(item, dict) or item.get("id") != tracking.get("id"):
        return ["live Bead identity mismatch"]
    if item.get("status") != "in_progress":
        return [f"live Bead must remain in_progress while foundation is draft, got {item.get('status')}"]
    return []


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path.cwd())
    parser.add_argument("--live-work-tracking", action="store_true")
    args = parser.parse_args()
    root = args.root.resolve()
    errors = validate(root)
    if args.live_work_tracking and not errors:
        errors += _live_tracking_errors(root, _load(root, errors))
    if errors:
        for error in errors:
            print(f"ERROR mint_next_foundation_guard: {error}", file=sys.stderr)
        return 1
    print("OK mint_next_foundation_guard: foundation contract is fail-closed.", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
