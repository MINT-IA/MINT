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
    "coordination_evidence": "coordination-evidence.yaml",
    "inventory": "handoff-inventory.yaml",
    "directions": "directions.yaml",
    "evaluation": "evaluation.yaml",
    "prototype": "prototype/index.html",
    "render": "evidence/render-20260801.yaml",
}
EXPECTED_DIRECTIONS = {
    "instant_tax_receipt": ("calculator_first", "synthetic_result_slot_in_receipt"),
    "next_life_decision": ("event_decision_first", "synthetic_result_slot_in_decision_canvas"),
    "conversation_to_card": ("coach_intent_first_structured_data_output", "pinned_verifiable_question_card"),
}
GOVERNING_SOURCES = {
    "CLAUDE.md", "docs/MINT_UX_GRAAL_MASTERPLAN.md", "docs/MINT_IDENTITY.md",
    "docs/VOICE_SYSTEM.md", "docs/DESIGN_SYSTEM.md", "apps/mobile/lib/theme/colors.dart",
    "apps/mobile/lib/theme/mint_text_styles.dart", "apps/mobile/pubspec.yaml",
}
MODERATED_TASKS = {
    "understand_that_no_tax_result_is_calculated", "identify_required_tax_inputs_and_assumptions",
    "correct_an_assumption", "continue_without_account", "recover_next_step_on_return",
}
REQUIRED_REVIEWS = {"ux", "accessibility", "swiss_tax", "compliance", "privacy_security"}
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
    if sources.get("principle") != "repo_runtime_and_explicit_overrides_beat_handoff_proposals":
        errors.append("source matrix principle must keep repo/runtime authority")
    governing = sources.get("governing", [])
    governing_paths = {entry.get("path") for entry in governing if isinstance(entry, dict)} if isinstance(governing, list) else set()
    if governing_paths != GOVERNING_SOURCES:
        errors.append("governing source set is incomplete or has drifted")
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
    inspiration = sources.get("inspiration_only", [])
    if not isinstance(inspiration, list) or len(inspiration) < 5:
        errors.append("source matrix must retain five bounded inspiration/red-team sources")

    inventory = _yaml(root, "inventory", errors)
    summary = inventory.get("summary", {})
    inventory_files = inventory.get("files", [])
    if not isinstance(summary, dict) or summary.get("file_count", 0) < 100 or summary.get("all_files_have_decision_reason_and_hash") is not True:
        errors.append("Handoff inventory must remain exhaustive, classified, and hash-bound")
    if not isinstance(inventory_files, list) or any(
        not isinstance(item, dict) or not all(item.get(key) is not None for key in ("path", "bytes", "sha256", "decision", "reason"))
        for item in inventory_files
    ):
        errors.append("every Handoff inventory item needs path, size, hash, decision, and reason")
    elif not {"ADAPT", "REWRITE", "RETIRE_FROM_PROMPTS", "RETAIN_AS_HISTORY"} <= {item["decision"] for item in inventory_files} or len({item["reason"] for item in inventory_files}) < 10:
        errors.append("Handoff inventory decisions must be materially file-specific, not root-level boilerplate")

    first = _yaml(root, "first_value", errors)
    if first.get("decision") != "tax_first_for_batch1_experiment":
        errors.append("Batch 1 first value must remain tax-first")
    contract = first.get("first_value_contract", {})
    if not isinstance(contract, dict) or contract.get("account_required") is not False:
        errors.append("account must not be required before first value")
    if not isinstance(contract, dict) or contract.get("bank_connection_required") is not False:
        errors.append("bank connection must not be required before first value")
    result = contract.get("result", {}) if isinstance(contract, dict) else {}
    if not isinstance(result, dict) or result.get("range_chf") is not None or result.get("display_placeholder") != "CHF_X_to_Y" or result.get("number_state") != "synthetic_layout_placeholder":
        errors.append("prototype must use only the common non-financial result placeholder")
    if not {"municipality", "tax_regime", "residence"} <= set(first.get("persona", {})):
        errors.append("tax-first persona must disclose municipality, residence, and tax regime")

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
        if not isinstance(item, dict) or item.get("primary_action") != "review_missing_tax_inputs":
            errors.append(f"direction {name} must share the review_missing_tax_inputs action")
    if len(set(mechanisms)) != 3:
        errors.append("each direction must use a unique interaction mechanism")
    if len(set(objects)) != 3:
        errors.append("each direction must produce a unique first-value object")
    comparability = directions_data.get("comparability", {})
    if not isinstance(comparability, dict) or comparability.get("winner") != "none_until_user_evidence":
        errors.append("no direction winner may be claimed without user evidence")
    for key in ("same_persona", "same_financial_facts", "same_result_placeholder", "same_primary_action"):
        if not isinstance(comparability, dict) or comparability.get(key) is not True:
            errors.append(f"direction comparability requires {key}")

    evaluation = _yaml(root, "evaluation", errors)
    claims = evaluation.get("claim_boundary", {})
    if not isinstance(claims, dict) or claims.get("user_testing_completed") is not False:
        errors.append("Batch 1 must not claim user testing was completed")
    if not isinstance(claims, dict) or claims.get("winner_selected") is not False:
        errors.append("Batch 1 must not select a winner before user evidence")
    tasks = set(evaluation.get("moderated_tasks", []))
    if tasks != MODERATED_TASKS:
        errors.append("evaluation moderated tasks are incomplete or have drifted")
    falsification = evaluation.get("internal_falsification", {})
    if not isinstance(falsification, dict) or set(falsification.get("required_reviews", [])) != REQUIRED_REVIEWS:
        errors.append("evaluation required reviews are incomplete")
    participants = evaluation.get("participant_coverage", {})
    if not isinstance(participants, dict) or len(participants.get("segments", [])) < 5 or set(participants.get("languages_minimum", [])) != {"fr", "de"}:
        errors.append("evaluation participant coverage is incomplete")
    metrics = set(evaluation.get("metrics", []))
    if not {"unaided_task_success", "teach_back_correctness", "data_correction_success", "accessibility_critical_task_success"} <= metrics:
        errors.append("evaluation metrics are incomplete")
    thresholds = evaluation.get("thresholds", {})
    if not isinstance(thresholds, dict) or thresholds.get("route_dead_ends") != 0 or thresholds.get("unaided_task_success_percent") != 85:
        errors.append("evaluation thresholds are incomplete")
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
    channels = discord.get("channels", {}) if isinstance(discord, dict) else {}
    if not isinstance(channels, dict) or set(channels) != {"mint_ops", "mint_delivery"}:
        errors.append("Discord channels must remain the two bounded notification channels")
    if not isinstance(discord, dict) or len(discord.get("allowed_fields", [])) < 8 or len(coordination.get("disable_if", [])) < 5:
        errors.append("Discord allowed fields and disable criteria are incomplete")
    if coordination.get("discord_existence") != "user_attested_not_technically_verified":
        errors.append("Discord existence must not be overstated")
    coordination_evidence = _yaml(root, "coordination_evidence", errors)
    alternatives = coordination_evidence.get("alternatives", {})
    if not isinstance(alternatives, dict) or set(alternatives) != {"no_chat", "discord_notification_only", "slack_free"}:
        errors.append("coordination evidence must compare Discord, Slack Free, and no chat")
    if coordination_evidence.get("selected") != "discord_notification_only" or coordination_evidence.get("selection_boundary") != "wins_only_as_one_way_signal_not_as_coordination_system":
        errors.append("coordination evidence does not support the bounded Discord selection")
    criteria = coordination_evidence.get("criteria_100", {})
    if not isinstance(criteria, dict) or sum(v for v in criteria.values() if isinstance(v, int)) != 100:
        errors.append("coordination evidence criteria must total 100")
    if isinstance(criteria, dict) and isinstance(alternatives, dict):
        for name, alternative in alternatives.items():
            scores = alternative.get("criterion_scores_1_to_5", {}) if isinstance(alternative, dict) else {}
            if not isinstance(scores, dict) or set(scores) != set(criteria) or any(value not in {1, 2, 3, 4, 5} for value in scores.values()):
                errors.append(f"coordination evidence scores incomplete for {name}")
                continue
            computed = sum(criteria[key] * scores[key] for key in criteria) // 5
            if alternative.get("score_100") != computed:
                errors.append(f"coordination evidence total is not reproducible for {name}")
        totals = {name: item.get("score_100") for name, item in alternatives.items() if isinstance(item, dict)}
        if totals and max(totals, key=totals.get) != coordination_evidence.get("selected"):
            errors.append("coordination evidence selected option is not the scored winner")
    verified = coordination_evidence.get("verified_state", {})
    if not isinstance(verified, dict) or verified.get("webhook_created") is not False or verified.get("notification_need_runtime_measured") is not False:
        errors.append("coordination evidence must disclose its unverified runtime state")

    prototype_path = root / BASE / FILES["prototype"]
    if prototype_path.is_file():
        html = prototype_path.read_text(encoding="utf-8")
        if html.count("data-direction=") != 3:
            errors.append("prototype must expose three direction selectors")
        if html.count("()=>`") != 18:
            errors.append("prototype must contain exactly 18 prototype states")
        for phrase in ("Sans compte", "Voir les hypothèses", "MAQUETTE · AUCUN MOTEUR BRANCHÉ", "MINT compare. Léa décide.", "localStorage.setItem", "data-edit"):
            if phrase not in html:
                errors.append(f"prototype missing required contract phrase: {phrase}")
        if "900–1’700" in html or "Barème VD + tes réponses" in html or "moteur versionné" in html:
            errors.append("prototype must not present the removed fictitious fiscal provenance")
        if html.count("Vérifier les données manquantes") < 3:
            errors.append("prototype directions must expose the same primary missing-data action")

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
