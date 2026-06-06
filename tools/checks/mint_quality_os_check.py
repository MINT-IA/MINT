#!/usr/bin/env python3
"""Validate the MINT Quality OS scorecard.

This check is intentionally cheap. It does not decide qualitative truth; it
prevents the most dangerous drift: missing artifacts, malformed score entries,
and overclaiming 10/10 while the matrix still contains unfinished rows.
"""

from __future__ import annotations

import argparse
import configparser
import datetime as dt
import json
import sys
import time
from pathlib import Path
from typing import Any


PHASE = ".planning/phases/mint-prod-ready-core-journey-truth-20260601"
SCORECARD = f"{PHASE}/quality-os-scorecard.json"
OSS_TOOL_MAP = f"{PHASE}/quality-os-oss-tool-map.json"
MATRIX = f"{PHASE}/JOURNEY-TRUTH-MATRIX.md"
QUALITY_OS = f"{PHASE}/MINT-QUALITY-OS.md"

TERMINAL_STATUSES = {"LIVE-PROVEN", "OUT-OF-BETA"}


def _score(value: Any, label: str, errors: list[str]) -> float | None:
    if not isinstance(value, (int, float)):
        errors.append(f"{label} must be numeric")
        return None
    score = float(value)
    if score < 0 or score > 10:
        errors.append(f"{label} must be between 0 and 10, got {score:g}")
    return score


def _as_non_empty_list(value: Any, label: str, errors: list[str]) -> list[Any]:
    if not isinstance(value, list) or not value:
        errors.append(f"{label} must be a non-empty list")
        return []
    return value


def _load_json(path: Path, errors: list[str]) -> dict[str, Any]:
    try:
        payload = path.read_text(encoding="utf-8")
    except OSError as exc:
        errors.append(f"cannot read {path}: {exc}")
        return {}
    try:
        data = json.loads(payload)
    except json.JSONDecodeError as exc:
        errors.append(f"invalid JSON in {path}: {exc}")
        return {}
    if not isinstance(data, dict):
        errors.append(f"{path} must contain a JSON object")
        return {}
    return data


def _path_exists(root: Path, artifact: str) -> bool:
    if artifact.startswith(("http://", "https://")):
        # URL reachability/freshness is a later evidence-quality gate.
        return True
    if artifact.endswith("/"):
        return (root / artifact).is_dir()
    return (root / artifact).exists()


def _latest_mtime(path: Path) -> float | None:
    if path.is_file():
        return path.stat().st_mtime
    if not path.is_dir():
        return None
    latest: float | None = None
    for child in path.rglob("*"):
        if child.is_file():
            mtime = child.stat().st_mtime
            latest = mtime if latest is None else max(latest, mtime)
    return latest


def _is_freshness_gated_evidence(artifact: str) -> bool:
    return (
        not artifact.startswith(("http://", "https://"))
        and artifact.startswith(f"{PHASE}/evidence/")
    )


def _matrix_has_unfinished_rows(matrix_text: str) -> tuple[bool, bool]:
    status_index: int | None = None
    saw_row = False
    for line in matrix_text.splitlines():
        stripped = line.strip()
        if not stripped.startswith("|"):
            continue
        cells = [cell.strip() for cell in stripped.strip("|").split("|")]
        if cells and cells[0].lower() in {"#", "row"}:
            for index, cell in enumerate(cells):
                if "status" in cell.lower():
                    status_index = index
                    break
            continue
        if not cells or not cells[0].isdigit():
            continue
        saw_row = True
        index = status_index if status_index is not None else 2
        if len(cells) <= index:
            return True, saw_row
        status_cell = cells[index]
        if status_cell not in TERMINAL_STATUSES:
            return True, saw_row
    return False, saw_row


def _git_origin_remote(root: Path) -> str | None:
    git_config_path = root / ".git" / "config"
    if not git_config_path.exists():
        return None
    parser = configparser.ConfigParser()
    try:
        parser.read(git_config_path, encoding="utf-8")
    except configparser.Error:
        return None
    section = 'remote "origin"'
    if not parser.has_section(section):
        return None
    return parser.get(section, "url", fallback=None)


def check(root: Path) -> list[str]:
    errors: list[str] = []
    scorecard_path = root / SCORECARD
    data = _load_json(scorecard_path, errors)
    if not data:
        return errors

    for artifact in _as_non_empty_list(
        data.get("required_artifacts"), "required_artifacts", errors
    ):
        if not isinstance(artifact, str):
            errors.append("required_artifacts entries must be strings")
            continue
        if "/tmp/" in artifact or artifact.startswith("/tmp/"):
            errors.append(f"required artifact cannot live in /tmp: {artifact}")
        if not _path_exists(root, artifact):
            errors.append(f"required artifact missing: {artifact}")

    freshness = data.get("evidence_freshness")
    if not isinstance(freshness, dict):
        errors.append("evidence_freshness must be an object")
        freshness = {}
    checked_at = freshness.get("checked_at")
    if not isinstance(checked_at, str) or len(checked_at) != 10:
        errors.append("evidence_freshness.checked_at must be an ISO date string")
    else:
        try:
            checked_at_date = dt.date.fromisoformat(checked_at)
        except ValueError:
            errors.append("evidence_freshness.checked_at must be an ISO date string")
        else:
            if checked_at_date > dt.date.today():
                errors.append("evidence_freshness.checked_at cannot be in the future")
    default_max_age = freshness.get("max_age_days_default")
    if not isinstance(default_max_age, (int, float)) or default_max_age <= 0:
        errors.append("evidence_freshness.max_age_days_default must be positive")
        default_max_age = 30
    elif default_max_age > 365:
        errors.append("evidence_freshness.max_age_days_default must be <= 365")
    limits = _as_non_empty_list(
        freshness.get("known_limits"), "evidence_freshness.known_limits", errors
    )
    if not any(
        isinstance(limit, str) and "semantic proof strength" in limit
        for limit in limits
    ):
        errors.append(
            "evidence_freshness.known_limits must state that freshness is not semantic proof strength"
        )
    freshness_artifacts = _as_non_empty_list(
        freshness.get("artifacts"), "evidence_freshness.artifacts", errors
    )
    cited_freshness_paths: set[str] = {
        artifact
        for artifact in data.get("required_artifacts", [])
        if isinstance(artifact, str) and _is_freshness_gated_evidence(artifact)
    }
    for dimension in data.get("dimensions", []):
        if not isinstance(dimension, dict):
            continue
        for artifact in dimension.get("evidence", []):
            if isinstance(artifact, str) and _is_freshness_gated_evidence(artifact):
                cited_freshness_paths.add(artifact)
    listed_freshness_paths = {
        entry.get("path")
        for entry in freshness_artifacts
        if isinstance(entry, dict) and isinstance(entry.get("path"), str)
    }
    for artifact in sorted(cited_freshness_paths - listed_freshness_paths):
        errors.append(
            "evidence_freshness.artifacts missing cited evidence path: "
            f"{artifact}"
        )
    now = time.time()
    for index, entry in enumerate(freshness_artifacts):
        label = f"evidence_freshness.artifacts[{index}]"
        if not isinstance(entry, dict):
            errors.append(f"{label} must be an object")
            continue
        artifact = entry.get("path")
        if not isinstance(artifact, str) or not artifact:
            errors.append(f"{label}.path must be a non-empty string")
            continue
        if artifact.startswith(("http://", "https://")):
            errors.append(f"{label}.path cannot be a URL for mtime freshness: {artifact}")
            continue
        if "/tmp/" in artifact or artifact.startswith("/tmp/"):
            errors.append(f"{label}.path cannot live in /tmp: {artifact}")
        artifact_path = root / artifact
        if not artifact_path.exists():
            errors.append(f"{label}.path missing: {artifact}")
            continue
        if artifact_path.is_file() and artifact_path.stat().st_size == 0:
            errors.append(f"{label}.path is empty: {artifact}")
        mtime = _latest_mtime(artifact_path)
        if mtime is None:
            errors.append(f"{label}.path has no file evidence: {artifact}")
            continue
        if mtime > now + 3600:
            errors.append(f"{label}.path has a future mtime: {artifact}")
        max_age = entry.get("max_age_days", default_max_age)
        if not isinstance(max_age, (int, float)) or max_age <= 0:
            errors.append(f"{label}.max_age_days must be positive")
            continue
        age_days = (now - mtime) / 86400
        if age_days > float(max_age):
            errors.append(
                f"{label}.path is stale: {artifact} is {age_days:.1f} days old "
                f"(max {float(max_age):g})"
            )
        for field in ("kind", "reason"):
            if not isinstance(entry.get(field), str) or not entry.get(field):
                errors.append(f"{label}.{field} must be a non-empty string")

    overall = data.get("overall")
    if not isinstance(overall, dict):
        errors.append("overall must be an object")
        overall = {}
    mint_score = _score(
        overall.get("mint_prod_ready_score"), "overall.mint_prod_ready_score", errors
    )
    _score(
        overall.get("codex_quality_os_work_score"),
        "overall.codex_quality_os_work_score",
        errors,
    )
    target = _score(overall.get("target"), "overall.target", errors)
    if target is not None and target != 10:
        errors.append("overall.target must stay 10; lower targets hide quality debt")
    release_score_cap = _score(
        overall.get("release_score_cap"), "overall.release_score_cap", errors
    )
    if (
        mint_score is not None
        and release_score_cap is not None
        and mint_score > release_score_cap
    ):
        errors.append(
            "overall.mint_prod_ready_score cannot exceed overall.release_score_cap "
            "while release blockers remain open"
        )

    rules = data.get("rules")
    if not isinstance(rules, dict):
        errors.append("rules must be an object")
        rules = {}
    for rule in (
        "no_row_closure_from_docs_only",
        "no_product_claim_financial_advice",
        "quality_score_requires_evidence",
        "score_increase_requires_new_evidence",
        "claude_cli_review_required",
        "no_workspace_clone_move_delete_without_explicit_user_approval",
        "environment_symptoms_must_be_scoped_to_process_and_file",
    ):
        if rules.get(rule) is not True:
            errors.append(f"rules.{rule} must be true")
    p0_cap = _score(
        rules.get("p0_open_caps_global_score_at"),
        "rules.p0_open_caps_global_score_at",
        errors,
    )
    if p0_cap is not None and p0_cap > 7.0:
        errors.append("rules.p0_open_caps_global_score_at must be <= 7.0")
    score_increase_max = rules.get("score_increase_max_without_new_evidence")
    if not isinstance(score_increase_max, (int, float)):
        errors.append("rules.score_increase_max_without_new_evidence must be numeric")
    elif float(score_increase_max) > 0.5:
        errors.append(
            "rules.score_increase_max_without_new_evidence must be <= 0.5"
        )

    debugging_protocol = data.get("debugging_protocol")
    if not isinstance(debugging_protocol, dict):
        errors.append("debugging_protocol must be an object")
        debugging_protocol = {}
    location_hint = debugging_protocol.get("canonical_repo_location_hint")
    if not isinstance(location_hint, str) or "MINT.nosync" not in location_hint:
        errors.append(
            "debugging_protocol.canonical_repo_location_hint must name the MINT.nosync working copy"
        )
    if debugging_protocol.get("canonical_remote") != "git@github.com:MINT-IA/MINT.git":
        errors.append("debugging_protocol.canonical_remote must be git@github.com:MINT-IA/MINT.git")
    actual_origin = _git_origin_remote(root)
    if actual_origin is not None and actual_origin != "git@github.com:MINT-IA/MINT.git":
        errors.append(
            "actual git origin remote must be git@github.com:MINT-IA/MINT.git"
        )
    first_commands = _as_non_empty_list(
        debugging_protocol.get("first_commands"),
        "debugging_protocol.first_commands",
        errors,
    )
    for required_command in (
        "pwd",
        "git status --short && git status -sb",
        "git remote -v",
        "cat .git/HEAD",
    ):
        if required_command not in first_commands:
            errors.append(f"debugging_protocol.first_commands missing {required_command}")
    forbidden_actions = _as_non_empty_list(
        debugging_protocol.get("forbidden_without_explicit_user_approval"),
        "debugging_protocol.forbidden_without_explicit_user_approval",
        errors,
    )
    for required_action in (
        "clone alternate workspace",
        "move repository",
        "delete repository",
        "relink repository",
        "chmod repository",
        "xattr repository",
        "create worktree as environment-debugging bypass",
    ):
        if required_action not in forbidden_actions:
            errors.append(
                "debugging_protocol.forbidden_without_explicit_user_approval "
                f"missing {required_action}"
            )
    required_distinctions = _as_non_empty_list(
        debugging_protocol.get("required_distinctions"),
        "debugging_protocol.required_distinctions",
        errors,
    )
    for required_distinction in (
        "current process symptom vs repository fact",
        "file read failure vs git failure",
        "Desktop permission issue vs remote repository issue",
        "personal account search vs org repo (MINT-IA/MINT) fact",
        "facts vs hypotheses",
    ):
        if required_distinction not in required_distinctions:
            errors.append(
                f"debugging_protocol.required_distinctions missing {required_distinction}"
            )
    if debugging_protocol.get("incident_memory_required") is not True:
        errors.append("debugging_protocol.incident_memory_required must be true")

    review_protocol = data.get("review_protocol")
    if not isinstance(review_protocol, dict):
        errors.append("review_protocol must be an object")
        review_protocol = {}
    if review_protocol.get("claude_cli_required_for_material_changes") is not True:
        errors.append(
            "review_protocol.claude_cli_required_for_material_changes must be true"
        )
    review_scope = _as_non_empty_list(
        review_protocol.get("review_scope"), "review_protocol.review_scope", errors
    )
    for required_scope in (
        "focused diff",
        "tests and gates",
        "matrix and bug impact",
        "release or readiness claims",
    ):
        if required_scope not in review_scope:
            errors.append(f"review_protocol.review_scope missing {required_scope}")
    review_timing = _as_non_empty_list(
        review_protocol.get("review_timing"), "review_protocol.review_timing", errors
    )
    for required_timing in (
        "after meaningful patch",
        "before commit or final closure",
    ):
        if required_timing not in review_timing:
            errors.append(f"review_protocol.review_timing missing {required_timing}")
    fallback = review_protocol.get("fallback_when_unavailable")
    if not isinstance(fallback, str) or "do not close matrix rows" not in fallback:
        errors.append(
            "review_protocol.fallback_when_unavailable must prevent matrix closure"
        )

    matrix_path = root / MATRIX
    matrix_text = ""
    try:
        matrix_text = matrix_path.read_text(encoding="utf-8")
    except OSError as exc:
        errors.append(f"cannot read {MATRIX}: {exc}")
    has_unfinished_rows, saw_matrix_row = _matrix_has_unfinished_rows(matrix_text)
    if mint_score is not None and mint_score >= 10:
        if not saw_matrix_row:
            errors.append(
                "overall.mint_prod_ready_score cannot be 10 without matrix capability rows"
            )
        elif has_unfinished_rows:
            errors.append(
                "overall.mint_prod_ready_score cannot be 10 while matrix rows remain unfinished"
            )

    dimensions = _as_non_empty_list(data.get("dimensions"), "dimensions", errors)
    seen_ids: set[str] = set()
    for index, dimension in enumerate(dimensions):
        label = f"dimensions[{index}]"
        if not isinstance(dimension, dict):
            errors.append(f"{label} must be an object")
            continue
        dim_id = dimension.get("id")
        if not isinstance(dim_id, str) or not dim_id:
            errors.append(f"{label}.id must be a non-empty string")
        elif dim_id in seen_ids:
            errors.append(f"duplicate dimension id: {dim_id}")
        else:
            seen_ids.add(dim_id)
        score = _score(dimension.get("score"), f"{label}.score", errors)
        dim_target = _score(dimension.get("target"), f"{label}.target", errors)
        if dim_target is not None and dim_target != 10:
            errors.append(f"{label}.target must be 10")
        evidence = _as_non_empty_list(dimension.get("evidence"), f"{label}.evidence", errors)
        missing = dimension.get("missing_to_10")
        if not isinstance(missing, list):
            errors.append(f"{label}.missing_to_10 must be a list")
            missing = []
        if score is not None and score >= 10 and missing:
            errors.append(f"{label}.score cannot be 10 while missing_to_10 is non-empty")
        for artifact in evidence:
            if not isinstance(artifact, str):
                errors.append(f"{label}.evidence entries must be strings")
                continue
            if "/tmp/" in artifact or artifact.startswith("/tmp/"):
                errors.append(f"{label}.evidence cannot live in /tmp: {artifact}")
            if not _path_exists(root, artifact):
                errors.append(f"{label}.evidence missing: {artifact}")

    next_actions = _as_non_empty_list(data.get("next_actions"), "next_actions", errors)
    for index, action in enumerate(next_actions):
        label = f"next_actions[{index}]"
        if not isinstance(action, dict):
            errors.append(f"{label} must be an object")
            continue
        for field in ("id", "priority", "title", "proof"):
            if not isinstance(action.get(field), str) or not action.get(field):
                errors.append(f"{label}.{field} must be a non-empty string")
        if action.get("priority") not in {"P0", "P1", "P2", "P3"}:
            errors.append(f"{label}.priority must be P0, P1, P2, or P3")
        rows = action.get("rows")
        if not isinstance(rows, list) or not rows or not all(
            isinstance(row, int) for row in rows
        ):
            errors.append(f"{label}.rows must be a non-empty list of integers")

    tool_map_path = root / OSS_TOOL_MAP
    tool_map = _load_json(tool_map_path, errors)
    if tool_map:
        policy = tool_map.get("policy")
        if not isinstance(policy, dict):
            errors.append("quality-os-oss-tool-map.policy must be an object")
            policy = {}
        if policy.get("budget_mode") != "oss_first":
            errors.append("quality-os-oss-tool-map.policy.budget_mode must be oss_first")
        adoption_stages = _as_non_empty_list(
            tool_map.get("adoption_stages"),
            "quality-os-oss-tool-map.adoption_stages",
            errors,
        )
        stage_ids = {
            stage.get("stage")
            for stage in adoption_stages
            if isinstance(stage, dict) and isinstance(stage.get("stage"), str)
        }
        for required_stage in (
            "now_cli_ci",
            "next_light_services",
            "later_paid_escape_hatch",
        ):
            if required_stage not in stage_ids:
                errors.append(
                    f"quality-os-oss-tool-map.adoption_stages missing {required_stage}"
                )
        tools = _as_non_empty_list(
            tool_map.get("tool_map"), "quality-os-oss-tool-map.tool_map", errors
        )
        categories = {
            tool.get("category")
            for tool in tools
            if isinstance(tool, dict) and isinstance(tool.get("category"), str)
        }
        for category in (
            "mobile_e2e",
            "test_management",
            "automation_reporting",
            "llm_eval",
            "feature_flags",
            "crash_observability",
            "product_analytics",
            "mobile_security",
            "code_supply_chain_security",
        ):
            if category not in categories:
                errors.append(f"quality-os-oss-tool-map.tool_map missing {category}")
        for index, tool in enumerate(tools):
            label = f"quality-os-oss-tool-map.tool_map[{index}]"
            if not isinstance(tool, dict):
                errors.append(f"{label} must be an object")
                continue
            for field in (
                "category",
                "preferred",
                "role",
                "deployment",
                "maturity",
                "first_mint_step",
            ):
                if not isinstance(tool.get(field), str) or not tool.get(field):
                    errors.append(f"{label}.{field} must be a non-empty string")
            _as_non_empty_list(tool.get("quality_os_inputs"), f"{label}.quality_os_inputs", errors)
            _as_non_empty_list(tool.get("security_notes"), f"{label}.security_notes", errors)

    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--root",
        default=".",
        help="Repository root. Defaults to the current working directory.",
    )
    args = parser.parse_args()
    root = Path(args.root).resolve()
    errors = check(root)
    if errors:
        for error in errors:
            print(f"mint_quality_os_check: {error}", file=sys.stderr)
        return 1
    print("OK mint_quality_os_check")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
