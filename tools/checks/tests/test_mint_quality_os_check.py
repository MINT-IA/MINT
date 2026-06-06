from __future__ import annotations

import importlib.util
import datetime as dt
import json
import os
import time
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[3]
MODULE_PATH = REPO_ROOT / "tools/checks/mint_quality_os_check.py"
SPEC = importlib.util.spec_from_file_location("mint_quality_os_check", MODULE_PATH)
mint_quality_os_check = importlib.util.module_from_spec(SPEC)
assert SPEC and SPEC.loader
SPEC.loader.exec_module(mint_quality_os_check)


PHASE = Path(".planning/phases/mint-prod-ready-core-journey-truth-20260601")


def _write_fixture(root: Path, *, mint_score: float = 6.5, bad_dimension_score: float = 7.0) -> None:
    phase = root / PHASE
    quality_review = phase / "evidence/quality-review"
    quality_review.mkdir(parents=True)
    (phase / "MINT-QUALITY-OS.md").write_text("# MINT Quality OS\n", encoding="utf-8")
    (phase / "JOURNEY-TRUTH-MATRIX.md").write_text(
        "| Row | Capability | Status |\n"
        "|---|---|---|\n"
        "| 1 | Demo | PARTIAL |\n",
        encoding="utf-8",
    )
    (phase / "BUG-TRACKER.md").write_text("# Bugs\n", encoding="utf-8")
    (quality_review / "mint-screen-advice-quality-review-20260605.html").write_text(
        "<html>screen</html>\n",
        encoding="utf-8",
    )
    (quality_review / "mint-flow-guidance-quality-review-20260605.html").write_text(
        "<html>flow</html>\n",
        encoding="utf-8",
    )
    (root / "tools/checks").mkdir(parents=True)
    (root / "tools/checks/mint_quality_os_check.py").write_text("# check\n", encoding="utf-8")
    tool_map = {
        "version": "2026-06-05",
        "policy": {"budget_mode": "oss_first"},
        "adoption_stages": [
            {"stage": "now_cli_ci", "tools": ["promptfoo"]},
            {"stage": "next_light_services", "tools": ["Kiwi TCMS"]},
            {"stage": "later_paid_escape_hatch", "tools": ["BrowserStack"]},
        ],
        "tool_map": [
            {
                "category": category,
                "preferred": "tool",
                "role": "role",
                "deployment": "local_ci",
                "maturity": "candidate",
                "quality_os_inputs": ["input"],
                "first_mint_step": "step",
                "security_notes": ["note"],
            }
            for category in [
                "mobile_e2e",
                "test_management",
                "automation_reporting",
                "llm_eval",
                "feature_flags",
                "crash_observability",
                "product_analytics",
                "mobile_security",
                "code_supply_chain_security",
            ]
        ],
    }
    (phase / "quality-os-oss-tool-map.json").write_text(
        json.dumps(tool_map, indent=2),
        encoding="utf-8",
    )
    scorecard = {
        "version": "2026-06-05",
        "overall": {
            "mint_prod_ready_score": mint_score,
            "codex_quality_os_work_score": 7.0,
            "target": 10,
            "release_score_cap": 7.0,
        },
        "rules": {
            "no_row_closure_from_docs_only": True,
            "no_product_claim_financial_advice": True,
            "quality_score_requires_evidence": True,
            "p0_open_caps_global_score_at": 7.0,
            "score_increase_requires_new_evidence": True,
            "score_increase_max_without_new_evidence": 0.5,
            "claude_cli_review_required": True,
            "no_workspace_clone_move_delete_without_explicit_user_approval": True,
            "environment_symptoms_must_be_scoped_to_process_and_file": True,
        },
        "debugging_protocol": {
            "canonical_repo_location_hint": "Desktop MINT.nosync working copy",
            "canonical_remote": "git@github.com:MINT-IA/MINT.git",
            "first_commands": [
                "pwd",
                "git status --short && git status -sb",
                "git remote -v",
                "cat .git/HEAD",
            ],
            "forbidden_without_explicit_user_approval": [
                "clone alternate workspace",
                "move repository",
                "delete repository",
                "relink repository",
                "chmod repository",
                "xattr repository",
                "create worktree as environment-debugging bypass",
            ],
            "required_distinctions": [
                "current process symptom vs repository fact",
                "file read failure vs git failure",
                "Desktop permission issue vs remote repository issue",
                "personal account search vs org repo (MINT-IA/MINT) fact",
                "facts vs hypotheses",
            ],
            "incident_memory_required": True,
        },
        "review_protocol": {
            "claude_cli_required_for_material_changes": True,
            "review_scope": [
                "focused diff",
                "tests and gates",
                "matrix and bug impact",
                "release or readiness claims",
            ],
            "review_timing": [
                "after meaningful patch",
                "before commit or final closure",
            ],
            "fallback_when_unavailable": "State missing Claude CLI review explicitly and do not close matrix rows from that lot.",
        },
        "required_artifacts": [
            str(PHASE / "MINT-QUALITY-OS.md"),
            str(PHASE / "quality-os-oss-tool-map.json"),
            str(PHASE / "JOURNEY-TRUTH-MATRIX.md"),
            str(PHASE / "BUG-TRACKER.md"),
            str(PHASE / "evidence/quality-review/mint-screen-advice-quality-review-20260605.html"),
            str(PHASE / "evidence/quality-review/mint-flow-guidance-quality-review-20260605.html"),
            "tools/checks/mint_quality_os_check.py",
        ],
        "evidence_freshness": {
            "max_age_days_default": 30,
            "checked_at": dt.date.today().isoformat(),
            "known_limits": [
                "mtime freshness only; does not validate semantic proof strength"
            ],
            "artifacts": [
                {
                    "path": str(PHASE / "evidence/quality-review/mint-screen-advice-quality-review-20260605.html"),
                    "kind": "quality_review",
                    "max_age_days": 30,
                    "reason": "Primary screen quality review evidence should be recent while Quality OS is active.",
                },
                {
                    "path": str(PHASE / "evidence/quality-review/mint-flow-guidance-quality-review-20260605.html"),
                    "kind": "quality_review",
                    "max_age_days": 30,
                    "reason": "Flow guidance quality review evidence should be recent while Quality OS is active.",
                },
            ],
        },
        "dimensions": [
            {
                "id": "screen_quality",
                "score": bad_dimension_score,
                "target": 10,
                "evidence": [
                    str(PHASE / "evidence/quality-review/mint-screen-advice-quality-review-20260605.html")
                ],
                "missing_to_10": ["dynamic type proof"],
            }
        ],
        "next_actions": [
            {
                "id": "qos-001",
                "priority": "P0",
                "title": "Run check",
                "rows": [29],
                "proof": "python3 tools/checks/mint_quality_os_check.py",
            }
        ],
    }
    (phase / "quality-os-scorecard.json").write_text(
        json.dumps(scorecard, indent=2),
        encoding="utf-8",
    )


def _errors(root: Path) -> list[str]:
    return mint_quality_os_check.check(root)


def _read_scorecard(root: Path) -> dict:
    scorecard_path = root / PHASE / "quality-os-scorecard.json"
    return json.loads(scorecard_path.read_text(encoding="utf-8"))


def _write_scorecard(root: Path, scorecard: dict) -> None:
    scorecard_path = root / PHASE / "quality-os-scorecard.json"
    scorecard_path.write_text(json.dumps(scorecard, indent=2), encoding="utf-8")


def _read_tool_map(root: Path) -> dict:
    tool_map_path = root / PHASE / "quality-os-oss-tool-map.json"
    return json.loads(tool_map_path.read_text(encoding="utf-8"))


def _write_tool_map(root: Path, tool_map: dict) -> None:
    tool_map_path = root / PHASE / "quality-os-oss-tool-map.json"
    tool_map_path.write_text(json.dumps(tool_map, indent=2), encoding="utf-8")


def test_valid_scorecard_passes(tmp_path: Path) -> None:
    _write_fixture(tmp_path)

    assert _errors(tmp_path) == []


def test_missing_required_artifact_fails(tmp_path: Path) -> None:
    _write_fixture(tmp_path)
    (
        tmp_path
        / PHASE
        / "evidence/quality-review/mint-flow-guidance-quality-review-20260605.html"
    ).unlink()

    errors = _errors(tmp_path)

    assert any("required artifact missing" in error for error in errors)


def test_missing_evidence_freshness_fails(tmp_path: Path) -> None:
    _write_fixture(tmp_path)
    scorecard = _read_scorecard(tmp_path)
    del scorecard["evidence_freshness"]
    _write_scorecard(tmp_path, scorecard)

    errors = _errors(tmp_path)

    assert any("evidence_freshness must be an object" in error for error in errors)


def test_malformed_checked_at_fails(tmp_path: Path) -> None:
    _write_fixture(tmp_path)
    scorecard = _read_scorecard(tmp_path)
    scorecard["evidence_freshness"]["checked_at"] = "20260606"
    _write_scorecard(tmp_path, scorecard)

    errors = _errors(tmp_path)

    assert any("checked_at must be an ISO date string" in error for error in errors)


def test_freshness_missing_cited_evidence_path_fails(tmp_path: Path) -> None:
    _write_fixture(tmp_path)
    scorecard = _read_scorecard(tmp_path)
    scorecard["evidence_freshness"]["artifacts"] = [
        artifact
        for artifact in scorecard["evidence_freshness"]["artifacts"]
        if "mint-flow-guidance-quality-review" not in artifact["path"]
    ]
    _write_scorecard(tmp_path, scorecard)

    errors = _errors(tmp_path)

    assert any("missing cited evidence path" in error for error in errors)


def test_stale_evidence_artifact_fails(tmp_path: Path) -> None:
    _write_fixture(tmp_path)
    evidence_path = (
        tmp_path
        / PHASE
        / "evidence/quality-review/mint-flow-guidance-quality-review-20260605.html"
    )
    old_timestamp = time.time() - 60 * 86400
    os.utime(evidence_path, (old_timestamp, old_timestamp))

    errors = _errors(tmp_path)

    assert any("path is stale" in error for error in errors)


def test_freshness_artifact_in_tmp_fails(tmp_path: Path) -> None:
    _write_fixture(tmp_path)
    scorecard = _read_scorecard(tmp_path)
    scorecard["evidence_freshness"]["artifacts"].append(
        {
            "path": "/tmp/mint-quality-evidence.html",
            "kind": "quality_review",
            "max_age_days": 30,
            "reason": "Temporary evidence must not back quality claims.",
        }
    )
    _write_scorecard(tmp_path, scorecard)

    errors = _errors(tmp_path)

    assert any("path cannot live in /tmp" in error for error in errors)


def test_empty_freshness_artifact_fails(tmp_path: Path) -> None:
    _write_fixture(tmp_path)
    evidence_path = (
        tmp_path
        / PHASE
        / "evidence/quality-review/mint-flow-guidance-quality-review-20260605.html"
    )
    evidence_path.write_text("", encoding="utf-8")

    errors = _errors(tmp_path)

    assert any("path is empty" in error for error in errors)


def test_freshness_url_artifact_fails(tmp_path: Path) -> None:
    _write_fixture(tmp_path)
    scorecard = _read_scorecard(tmp_path)
    scorecard["evidence_freshness"]["artifacts"].append(
        {
            "path": "https://example.com/evidence.html",
            "kind": "quality_review",
            "max_age_days": 30,
            "reason": "URLs need a separate reachability checker.",
        }
    )
    _write_scorecard(tmp_path, scorecard)

    errors = _errors(tmp_path)

    assert any("cannot be a URL for mtime freshness" in error for error in errors)


def test_freshness_limits_must_name_semantic_proof_strength(tmp_path: Path) -> None:
    _write_fixture(tmp_path)
    scorecard = _read_scorecard(tmp_path)
    scorecard["evidence_freshness"]["known_limits"] = ["mtime only"]
    _write_scorecard(tmp_path, scorecard)

    errors = _errors(tmp_path)

    assert any("semantic proof strength" in error for error in errors)


def test_score_outside_range_fails(tmp_path: Path) -> None:
    _write_fixture(tmp_path, bad_dimension_score=10.5)

    errors = _errors(tmp_path)

    assert any("between 0 and 10" in error for error in errors)


def test_global_score_outside_range_fails(tmp_path: Path) -> None:
    _write_fixture(tmp_path, mint_score=11)

    errors = _errors(tmp_path)

    assert any("overall.mint_prod_ready_score must be between 0 and 10" in error for error in errors)


def test_release_score_cap_fails(tmp_path: Path) -> None:
    _write_fixture(tmp_path, mint_score=7.5)

    errors = _errors(tmp_path)

    assert any("cannot exceed overall.release_score_cap" in error for error in errors)


def test_ten_score_with_missing_work_fails(tmp_path: Path) -> None:
    _write_fixture(tmp_path, bad_dimension_score=10)

    errors = _errors(tmp_path)

    assert any("cannot be 10 while missing_to_10 is non-empty" in error for error in errors)


def test_global_ten_with_unfinished_matrix_rows_fails(tmp_path: Path) -> None:
    _write_fixture(tmp_path, mint_score=10)

    errors = _errors(tmp_path)

    assert any("cannot be 10 while matrix rows remain unfinished" in error for error in errors)


def test_matrix_status_column_only_controls_unfinished_detection(tmp_path: Path) -> None:
    _write_fixture(tmp_path, mint_score=10)
    matrix_path = tmp_path / PHASE / "JOURNEY-TRUTH-MATRIX.md"
    matrix_path.write_text(
        "| Row | Capability | Status |\n"
        "|---|---|---|\n"
        "| 1 | LIVE-PROVEN appears in description only | PARTIAL |\n",
        encoding="utf-8",
    )

    errors = _errors(tmp_path)

    assert any("cannot be 10 while matrix rows remain unfinished" in error for error in errors)


def test_matrix_terminal_status_must_be_exact(tmp_path: Path) -> None:
    _write_fixture(tmp_path, mint_score=10)
    matrix_path = tmp_path / PHASE / "JOURNEY-TRUTH-MATRIX.md"
    matrix_path.write_text(
        "| Row | Capability | Status |\n"
        "|---|---|---|\n"
        "| 1 | Demo | NOT LIVE-PROVEN |\n",
        encoding="utf-8",
    )

    errors = _errors(tmp_path)

    assert any("cannot be 10 while matrix rows remain unfinished" in error for error in errors)


def test_global_ten_requires_matrix_capability_rows(tmp_path: Path) -> None:
    _write_fixture(tmp_path, mint_score=10)
    matrix_path = tmp_path / PHASE / "JOURNEY-TRUTH-MATRIX.md"
    matrix_path.write_text(
        "| Row | Capability | Status |\n"
        "|---|---|---|\n",
        encoding="utf-8",
    )

    errors = _errors(tmp_path)

    assert any("cannot be 10 without matrix capability rows" in error for error in errors)


def test_missing_oss_tool_category_fails(tmp_path: Path) -> None:
    _write_fixture(tmp_path)
    tool_map = _read_tool_map(tmp_path)
    tool_map["tool_map"] = [
        tool for tool in tool_map["tool_map"] if tool["category"] != "llm_eval"
    ]
    _write_tool_map(tmp_path, tool_map)

    errors = _errors(tmp_path)

    assert any("tool_map missing llm_eval" in error for error in errors)


def test_wrong_oss_budget_mode_fails(tmp_path: Path) -> None:
    _write_fixture(tmp_path)
    tool_map = _read_tool_map(tmp_path)
    tool_map["policy"]["budget_mode"] = "paid_first"
    _write_tool_map(tmp_path, tool_map)

    errors = _errors(tmp_path)

    assert any("budget_mode must be oss_first" in error for error in errors)


def test_wrong_canonical_remote_fails(tmp_path: Path) -> None:
    _write_fixture(tmp_path)
    scorecard = _read_scorecard(tmp_path)
    scorecard["debugging_protocol"]["canonical_remote"] = "git@github.com:Julienbatt/MINT.git"
    _write_scorecard(tmp_path, scorecard)

    errors = _errors(tmp_path)

    assert any("canonical_remote" in error for error in errors)


def test_missing_forbidden_workspace_action_fails(tmp_path: Path) -> None:
    _write_fixture(tmp_path)
    scorecard = _read_scorecard(tmp_path)
    scorecard["debugging_protocol"]["forbidden_without_explicit_user_approval"] = [
        action
        for action in scorecard["debugging_protocol"]["forbidden_without_explicit_user_approval"]
        if action != "clone alternate workspace"
    ]
    _write_scorecard(tmp_path, scorecard)

    errors = _errors(tmp_path)

    assert any("clone alternate workspace" in error for error in errors)


def test_required_artifact_in_tmp_fails(tmp_path: Path) -> None:
    _write_fixture(tmp_path)
    scorecard = _read_scorecard(tmp_path)
    scorecard["required_artifacts"].append("/tmp/mint-quality-os.html")
    _write_scorecard(tmp_path, scorecard)

    errors = _errors(tmp_path)

    assert any("required artifact cannot live in /tmp" in error for error in errors)


def test_dimension_evidence_in_tmp_fails(tmp_path: Path) -> None:
    _write_fixture(tmp_path)
    scorecard = _read_scorecard(tmp_path)
    scorecard["dimensions"][0]["evidence"].append("/tmp/mint-quality-evidence.html")
    _write_scorecard(tmp_path, scorecard)

    errors = _errors(tmp_path)

    assert any("evidence cannot live in /tmp" in error for error in errors)


def test_false_rule_fails_with_rule_name(tmp_path: Path) -> None:
    _write_fixture(tmp_path)
    scorecard = _read_scorecard(tmp_path)
    scorecard["rules"]["quality_score_requires_evidence"] = False
    _write_scorecard(tmp_path, scorecard)

    errors = _errors(tmp_path)

    assert any("rules.quality_score_requires_evidence must be true" in error for error in errors)


def test_duplicate_dimension_id_fails(tmp_path: Path) -> None:
    _write_fixture(tmp_path)
    scorecard = _read_scorecard(tmp_path)
    scorecard["dimensions"].append(dict(scorecard["dimensions"][0]))
    _write_scorecard(tmp_path, scorecard)

    errors = _errors(tmp_path)

    assert any("duplicate dimension id: screen_quality" in error for error in errors)


def test_next_action_missing_proof_fails(tmp_path: Path) -> None:
    _write_fixture(tmp_path)
    scorecard = _read_scorecard(tmp_path)
    del scorecard["next_actions"][0]["proof"]
    _write_scorecard(tmp_path, scorecard)

    errors = _errors(tmp_path)

    assert any("next_actions[0].proof must be a non-empty string" in error for error in errors)


def test_missing_required_distinction_fails(tmp_path: Path) -> None:
    _write_fixture(tmp_path)
    scorecard = _read_scorecard(tmp_path)
    scorecard["debugging_protocol"]["required_distinctions"] = [
        distinction
        for distinction in scorecard["debugging_protocol"]["required_distinctions"]
        if distinction != "facts vs hypotheses"
    ]
    _write_scorecard(tmp_path, scorecard)

    errors = _errors(tmp_path)

    assert any("required_distinctions missing facts vs hypotheses" in error for error in errors)


def test_score_increase_max_rule_fails_when_too_large(tmp_path: Path) -> None:
    _write_fixture(tmp_path)
    scorecard = _read_scorecard(tmp_path)
    scorecard["rules"]["score_increase_max_without_new_evidence"] = 1.0
    _write_scorecard(tmp_path, scorecard)

    errors = _errors(tmp_path)

    assert any("score_increase_max_without_new_evidence must be <= 0.5" in error for error in errors)


def test_p0_cap_must_not_exceed_seven(tmp_path: Path) -> None:
    _write_fixture(tmp_path)
    scorecard = _read_scorecard(tmp_path)
    scorecard["rules"]["p0_open_caps_global_score_at"] = 8.0
    _write_scorecard(tmp_path, scorecard)

    errors = _errors(tmp_path)

    assert any("p0_open_caps_global_score_at must be <= 7.0" in error for error in errors)


def test_missing_score_increase_max_rule_fails(tmp_path: Path) -> None:
    _write_fixture(tmp_path)
    scorecard = _read_scorecard(tmp_path)
    del scorecard["rules"]["score_increase_max_without_new_evidence"]
    _write_scorecard(tmp_path, scorecard)

    errors = _errors(tmp_path)

    assert any("score_increase_max_without_new_evidence must be numeric" in error for error in errors)


def test_missing_org_repo_distinction_fails(tmp_path: Path) -> None:
    _write_fixture(tmp_path)
    scorecard_path = tmp_path / PHASE / "quality-os-scorecard.json"
    scorecard = json.loads(scorecard_path.read_text(encoding="utf-8"))
    scorecard["debugging_protocol"]["required_distinctions"] = [
        distinction
        for distinction in scorecard["debugging_protocol"]["required_distinctions"]
        if distinction != "personal account search vs org repo (MINT-IA/MINT) fact"
    ]
    scorecard_path.write_text(json.dumps(scorecard, indent=2), encoding="utf-8")

    errors = _errors(tmp_path)

    assert any("MINT-IA/MINT" in error for error in errors)


def test_missing_claude_cli_review_protocol_fails(tmp_path: Path) -> None:
    _write_fixture(tmp_path)
    scorecard = _read_scorecard(tmp_path)
    del scorecard["review_protocol"]
    _write_scorecard(tmp_path, scorecard)

    errors = _errors(tmp_path)

    assert any("review_protocol must be an object" in error for error in errors)


def test_false_claude_cli_review_rule_fails(tmp_path: Path) -> None:
    _write_fixture(tmp_path)
    scorecard = _read_scorecard(tmp_path)
    scorecard["rules"]["claude_cli_review_required"] = False
    _write_scorecard(tmp_path, scorecard)

    errors = _errors(tmp_path)

    assert any("rules.claude_cli_review_required must be true" in error for error in errors)


def test_claude_cli_review_fallback_must_prevent_matrix_closure(tmp_path: Path) -> None:
    _write_fixture(tmp_path)
    scorecard = _read_scorecard(tmp_path)
    scorecard["review_protocol"]["fallback_when_unavailable"] = "Use local checks only."
    _write_scorecard(tmp_path, scorecard)

    errors = _errors(tmp_path)

    assert any("fallback_when_unavailable" in error for error in errors)


def test_actual_origin_remote_must_match_when_git_config_exists(tmp_path: Path) -> None:
    _write_fixture(tmp_path)
    git_dir = tmp_path / ".git"
    git_dir.mkdir()
    (git_dir / "config").write_text(
        "[remote \"origin\"]\n\turl = git@github.com:Julienbatt/MINT.git\n",
        encoding="utf-8",
    )

    errors = _errors(tmp_path)

    assert any("actual git origin remote" in error for error in errors)
