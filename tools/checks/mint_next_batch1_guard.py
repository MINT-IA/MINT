#!/usr/bin/env python3
"""Fail closed on drift in the MINT Next Batch 1 design experiment."""
from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
import sys
from pathlib import Path

import yaml


BASE = Path("product/mint_next/batch1")
FILES = {
    "batch": "batch.yaml",
    "sources": "source-matrix.yaml",
    "first_value": "first-value.yaml",
    "coordination": "coordination.yaml",
    "directions": "directions.yaml",
    "evaluation": "evaluation.yaml",
    "prototype": "prototype/index.html",
    "render": "evidence/render-20260801.yaml",
}
EXPECTED_DIRECTIONS = {
    "instant_tax_receipt": ("calculator_first", "tax_estimate_receipt"),
    "next_life_decision": ("event_decision_first", "two_option_decision_canvas"),
    "conversation_to_card": ("coach_intent_first_ui_output", "pinned_deterministic_cap_card"),
}
FORBIDDEN_DISCORD = {
    "financial_data", "tax_data", "pension_data", "insurance_data", "bank_data",
    "avs_data", "prompt", "response", "auth_header", "token", "document",
    "screenshot", "raw_stack_locals", "user_id",
}


def _yaml(root: Path, name: str, errors: list[str]) -> dict:
    path = root / BASE / FILES[name]
    try:
        value = yaml.safe_load(path.read_text(encoding="utf-8"))
    except (OSError, yaml.YAMLError) as exc:
        errors.append(f"unable to load {path.relative_to(root)}: {exc}")
        return {}
    if not isinstance(value, dict):
        errors.append(f"{path.relative_to(root)} must be a mapping")
        return {}
    return value


def validate(root: Path) -> list[str]:
    errors: list[str] = []
    for rel in FILES.values():
        if not (root / BASE / rel).is_file():
            errors.append(f"missing Batch 1 artifact: {BASE / rel}")

    batch = _yaml(root, "batch", errors)
    if batch.get("schema_version") != 1 or batch.get("status") != "draft_unproven":
        errors.append("Batch 1 must remain schema 1 draft_unproven before promotion")
    tracking = batch.get("work_tracking", {})
    if not isinstance(tracking, dict) or tracking.get("system") != "beads" or tracking.get("id") != "MINT_nosync-5em":
        errors.append("Batch 1 must be owned by Bead MINT_nosync-5em")
    excluded = set(batch.get("scope", {}).get("excludes", [])) if isinstance(batch.get("scope"), dict) else set()
    required_exclusions = {"flutter_implementation", "discord_webhook_wiring", "winner_claim", "user_validation_claim"}
    if not required_exclusions <= excluded:
        errors.append("Batch 1 scope exclusions are incomplete")

    sources = _yaml(root, "sources", errors)
    governing = sources.get("governing", [])
    for entry in governing if isinstance(governing, list) else []:
        rel = entry.get("path") if isinstance(entry, dict) else None
        if not isinstance(rel, str) or not (root / rel).exists():
            errors.append(f"governing design source missing: {rel}")
    excluded_prompts = set(sources.get("excluded_from_direction_prompts", []))
    if ".planning/handoff/2026-05-09-design-system-v8/handoff" not in excluded_prompts:
        errors.append("duplicated Claude-like Handoff must stay excluded")
    unresolved = sources.get("unresolved_must_not_be_inherited", {})
    if not isinstance(unresolved, dict) or not {"navigation_shell", "typography", "positioning"} <= set(unresolved):
        errors.append("source matrix must expose navigation, typography, and positioning conflicts")

    first = _yaml(root, "first_value", errors)
    if first.get("decision") != "tax_first_for_batch1_experiment":
        errors.append("Batch 1 first value must remain tax-first")
    contract = first.get("first_value_contract", {})
    if not isinstance(contract, dict) or contract.get("account_required") is not False:
        errors.append("account must not be required before first value")
    if not isinstance(contract, dict) or contract.get("bank_connection_required") is not False:
        errors.append("bank connection must not be required before first value")
    result = contract.get("result", {}) if isinstance(contract, dict) else {}
    if not isinstance(result, dict) or result.get("range_chf") != [900, 1700] or result.get("number_state") != "example":
        errors.append("common illustrative result range/state changed")

    directions_data = _yaml(root, "directions", errors)
    directions = directions_data.get("directions", {})
    if not isinstance(directions, dict) or set(directions) != set(EXPECTED_DIRECTIONS):
        errors.append("exactly three canonical Batch 1 directions are required")
        directions = {}
    mechanisms: list[str] = []
    objects: list[str] = []
    for name, expected in EXPECTED_DIRECTIONS.items():
        item = directions.get(name, {})
        actual = (item.get("mechanism"), item.get("first_value_object")) if isinstance(item, dict) else (None, None)
        if actual != expected:
            errors.append(f"direction {name} mechanism/object must remain {expected}")
        mechanisms.append(str(actual[0]))
        objects.append(str(actual[1]))
        if not isinstance(item, dict) or len(item.get("sequence", [])) != 6:
            errors.append(f"direction {name} must contain six comparable states")
    if len(set(mechanisms)) != 3:
        errors.append("each direction must use a unique interaction mechanism")
    if len(set(objects)) != 3:
        errors.append("each direction must produce a unique first-value object")
    comparability = directions_data.get("comparability", {})
    if not isinstance(comparability, dict) or comparability.get("winner") != "none_until_user_evidence":
        errors.append("no direction winner may be claimed without user evidence")
    for key in ("same_persona", "same_financial_facts", "same_result_range", "same_primary_action"):
        if not isinstance(comparability, dict) or comparability.get(key) is not True:
            errors.append(f"direction comparability requires {key}")

    evaluation = _yaml(root, "evaluation", errors)
    claims = evaluation.get("claim_boundary", {})
    if not isinstance(claims, dict) or claims.get("user_testing_completed") is not False:
        errors.append("Batch 1 must not claim user testing was completed")
    if not isinstance(claims, dict) or claims.get("winner_selected") is not False:
        errors.append("Batch 1 must not select a winner before user evidence")
    scorecard = evaluation.get("scorecard_100", {})
    if not isinstance(scorecard, dict) or sum(v for v in scorecard.values() if isinstance(v, int)) != 100:
        errors.append("evaluation scorecard must total 100")
    vetoes = set(evaluation.get("promotion", {}).get("vetoes", [])) if isinstance(evaluation.get("promotion"), dict) else set()
    if not {"account_before_value", "number_without_provenance", "inaccessible_critical_task", "unperformed_user_test_claimed_as_performed"} <= vetoes:
        errors.append("evaluation promotion vetoes are incomplete")

    coordination = _yaml(root, "coordination", errors)
    discord = coordination.get("discord", {})
    if coordination.get("decision") != "existing_private_discord_notification_only" or coordination.get("status") != "specified_not_wired":
        errors.append("coordination must remain private Discord notification-only and unwired")
    for key in ("source_of_truth", "approval_surface", "agent_input_surface"):
        if not isinstance(discord, dict) or discord.get(key) is not False:
            errors.append(f"Discord must never be {key}")
    forbidden = set(discord.get("forbidden_fields", [])) if isinstance(discord, dict) else set()
    if not FORBIDDEN_DISCORD <= forbidden:
        errors.append("Discord forbidden sensitive fields are incomplete")
    boundary = set(discord.get("implementation_boundary", [])) if isinstance(discord, dict) else set()
    if not {"no_bidirectional_bot", "no_slash_commands", "failed_notification_never_changes_authoritative_result"} <= boundary:
        errors.append("Discord implementation boundary is incomplete")

    prototype_path = root / BASE / FILES["prototype"]
    if prototype_path.is_file():
        html = prototype_path.read_text(encoding="utf-8")
        if html.count("data-direction=") != 3:
            errors.append("prototype must expose three direction selectors")
        if html.count("()=>`") != 18:
            errors.append("prototype must contain exactly 18 prototype states")
        for phrase in ("Sans compte", "Voir les hypothèses", "CARTE DÉTERMINISTE", "MINT compare. Léa décide."):
            if phrase not in html:
                errors.append(f"prototype missing required contract phrase: {phrase}")

    render = _yaml(root, "render", errors)
    claims = render.get("claims", {})
    if not isinstance(claims, dict) or claims.get("all_three_rendered") is not True:
        errors.append("render evidence must cover all three directions")
    for forbidden_claim in ("interactions_fully_runtime_tested", "accessibility_validated", "user_validated"):
        if not isinstance(claims, dict) or claims.get(forbidden_claim) is not False:
            errors.append(f"render evidence must not claim {forbidden_claim}")
    artifacts = render.get("artifacts", {})
    for name in ("direction_a", "direction_b", "direction_c"):
        item = artifacts.get(name, {}) if isinstance(artifacts, dict) else {}
        rel = item.get("path") if isinstance(item, dict) else None
        expected_hash = item.get("sha256") if isinstance(item, dict) else None
        path = root / rel if isinstance(rel, str) else None
        if path is None or not path.is_file():
            errors.append(f"render evidence missing {name}")
        elif hashlib.sha256(path.read_bytes()).hexdigest() != expected_hash:
            errors.append(f"render evidence hash mismatch for {name}")

    return errors


def live_tracking_errors(root: Path) -> list[str]:
    common = subprocess.run(["git", "rev-parse", "--path-format=absolute", "--git-common-dir"], cwd=root, capture_output=True, text=True)
    if common.returncode:
        return ["unable to locate canonical repository for live Bead check"]
    canonical = Path(common.stdout.strip()).parent
    proc = subprocess.run(["bd", "-C", str(canonical), "show", "MINT_nosync-5em", "--json"], capture_output=True, text=True)
    if proc.returncode:
        return ["unable to inspect live Batch 1 Bead"]
    try:
        payload = json.loads(proc.stdout)
    except json.JSONDecodeError:
        return ["live Batch 1 Bead returned invalid JSON"]
    item = payload[0] if isinstance(payload, list) and payload else payload
    if not isinstance(item, dict) or item.get("status") != "in_progress":
        return [f"live Batch 1 Bead must be in_progress, got {item.get('status') if isinstance(item, dict) else None}"]
    return []


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path.cwd())
    parser.add_argument("--live-work-tracking", action="store_true")
    args = parser.parse_args()
    root = args.root.resolve()
    errors = validate(root)
    if args.live_work_tracking and not errors:
        errors += live_tracking_errors(root)
    if errors:
        for error in errors:
            print(f"ERROR mint_next_batch1_guard: {error}", file=sys.stderr)
        return 1
    print("OK mint_next_batch1_guard: Batch 1 remains comparable, bounded, and unproven.", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
