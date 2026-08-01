#!/usr/bin/env python3
"""Fail closed when the MINT Next foundation contract loses critical controls."""
from __future__ import annotations

import argparse
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
            if not isinstance(snapshot, dict) or snapshot.get("status") != tracking.get("expected_status"):
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

    return errors


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path.cwd())
    args = parser.parse_args()
    errors = validate(args.root.resolve())
    if errors:
        for error in errors:
            print(f"ERROR mint_next_foundation_guard: {error}", file=sys.stderr)
        return 1
    print("OK mint_next_foundation_guard: foundation contract is fail-closed.", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
