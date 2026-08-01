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
}
ALLOWED_EVIDENCE = {
    "deterministic_check",
    "current_state_inspection",
    "independent_adversarial_review",
    "runtime_proof",
    "user_research",
}
FORBIDDEN_EVIDENCE = {"agent_summary", "author_claim", "plan_status", "memory_only"}


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

    capabilities = data.get("required_capabilities")
    if not isinstance(capabilities, dict):
        errors.append("required_capabilities must be a mapping")
        capabilities = {}
    for name in sorted(REQUIRED_CAPABILITIES):
        owner = capabilities.get(name)
        if not isinstance(owner, str) or not owner.strip():
            errors.append(f"required capability {name} has no owner")

    tools = data.get("tools")
    if not isinstance(tools, dict):
        errors.append("tools must be a mapping")
        tools = {}
    for name in sorted(REQUIRED_TOOLS):
        entry = tools.get(name)
        if not isinstance(entry, dict) or not entry.get("role"):
            errors.append(f"tool {name} must have one explicit role")

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
