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


def _write_fixture(
    root: Path,
    *,
    mint_score: float = 5.2,
    felt_score: float = 4.2,
    bad_dimension_score: float = 7.0,
) -> None:
    phase = root / PHASE
    quality_review = phase / "evidence/quality-review"
    quality_review.mkdir(parents=True)
    (phase / "MINT-QUALITY-OS.md").write_text("# MINT Quality OS\n", encoding="utf-8")
    (phase / "persona-flow-benchmark.md").write_text(
        "# Persona Flow Benchmark\n", encoding="utf-8"
    )
    (phase / "persona-flow-benchmark.json").write_text(
        json.dumps(
            {
                "version": "2026-06-06",
                "status": "seed_framework",
                "source_policy": {
                    "official_or_regulatory_anchor_required": True,
                    "minimum_public_swiss_expert_market_references": 2,
                    "forbidden": ["regulated personalized investment advice language"],
                    "provider_reference_use": "Define coverage expectations only; never recommend provider products.",
                },
                "scoring_dimensions": [
                    {
                        "id": "runtime_completion",
                        "weight_percent": 50,
                        "ten_signal": "runtime proof",
                    },
                    {
                        "id": "guidance_quality",
                        "weight_percent": 50,
                        "ten_signal": "guidance proof",
                    },
                ],
                "cap_application_order": [
                    "privacy_and_compliance_caps",
                    "calculation_caps",
                    "runtime_and_evidence_caps",
                ],
                "record_template": {"reviewers": {"claude_cli": ""}},
            },
            indent=2,
        ),
        encoding="utf-8",
    )
    (phase / "flow-evidence-registry.json").write_text(
        json.dumps(
            {
                "version": "2026-06-06",
                "status": "schema_seed",
                "purpose": "Machine-readable registry for per-flow evidence quality.",
                "rules": {
                    "matrix_and_bug_tracker_remain_operational_truth": True,
                    "registry_entries_cannot_close_rows_by_themselves": True,
                    "score_must_not_exceed_score_cap": True,
                    "p0_p1_gaps_must_be_linked_to_bug_tracker": True,
                    "html_reviews_should_be_generated_from_structured_records": True,
                },
                "required_fields_per_entry": [
                    "flow_id",
                    "matrix_rows",
                    "bug_ids",
                    "persona",
                    "surface_family",
                    "tier",
                    "status_claim",
                    "score",
                    "score_cap",
                    "cap_reasons",
                    "automation",
                    "evidence_artifacts",
                    "contract_tests",
                    "semantic_evals",
                    "user_visible_outcome",
                    "guidance_boundary_evidence",
                    "benchmark_references",
                    "critical_assertions",
                    "anti_surface_assertions",
                    "rubric",
                    "remaining_gaps",
                    "last_reviewed",
                ],
                "score_caps": [
                    {"condition": "no_durable_evidence_artifact", "cap": 2.0}
                ],
                "rubric_dimensions": [
                    "runtime_mechanics",
                    "human_goal",
                    "guidance_boundary",
                    "user_data_grounding",
                    "provenance_freshness",
                    "restart_or_continuity",
                    "next_step_quality",
                    "ux_a11y_i18n",
                    "automation_reliability",
                    "debt_hygiene",
                ],
                "entries": [],
            },
            indent=2,
        ),
        encoding="utf-8",
    )
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
    (quality_review / "user-feedback-flow-feeling-20260606.md").write_text(
        "User feedback: MINT still does not work well enough; flow feeling and guidance are weak.\n",
        encoding="utf-8",
    )
    (quality_review / "persona-flow-benchmark-seed-20260606.md").write_text(
        "Persona-flow benchmark seed evidence.\n",
        encoding="utf-8",
    )
    (quality_review / "result.xml").write_text(
        "<testsuite tests=\"1\" failures=\"0\" />\n",
        encoding="utf-8",
    )
    (root / "tools/checks").mkdir(parents=True)
    (root / "tools/checks/mint_quality_os_check.py").write_text("# check\n", encoding="utf-8")
    flow_dir = root / "tools/simulator/flows/maestro-perfect-set"
    flow_dir.mkdir(parents=True)
    (flow_dir / "flow_row22_primary_screen_visual_crawl.yaml").write_text(
        "appId: com.mint.test\n---\n- launchApp\n",
        encoding="utf-8",
    )
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
            "felt_product_quality_score": felt_score,
            "journey_truth_proof_score_percent": 59.5,
            "codex_quality_os_work_score": 7.0,
            "target": 10,
            "release_score_cap": 7.0,
            "felt_product_quality_score_cap": 5.5,
        },
        "rules": {
            "no_row_closure_from_docs_only": True,
            "no_product_claim_financial_advice": True,
            "quality_score_requires_evidence": True,
            "felt_quality_caps_global_score": True,
            "no_single_percentage_without_component_scores": True,
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
            str(PHASE / "persona-flow-benchmark.md"),
            str(PHASE / "persona-flow-benchmark.json"),
            str(PHASE / "flow-evidence-registry.json"),
            str(PHASE / "quality-os-oss-tool-map.json"),
            str(PHASE / "JOURNEY-TRUTH-MATRIX.md"),
            str(PHASE / "BUG-TRACKER.md"),
            str(PHASE / "evidence/quality-review/mint-screen-advice-quality-review-20260605.html"),
            str(PHASE / "evidence/quality-review/mint-flow-guidance-quality-review-20260605.html"),
            str(PHASE / "evidence/quality-review/persona-flow-benchmark-seed-20260606.md"),
            str(PHASE / "evidence/quality-review/user-feedback-flow-feeling-20260606.md"),
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
                {
                    "path": str(PHASE / "evidence/quality-review/persona-flow-benchmark-seed-20260606.md"),
                    "kind": "quality_review",
                    "max_age_days": 30,
                    "reason": "Persona-flow benchmark method evidence should be recent while Quality OS is active.",
                },
                {
                    "path": str(PHASE / "evidence/quality-review/user-feedback-flow-feeling-20260606.md"),
                    "kind": "user_feedback",
                    "max_age_days": 30,
                    "reason": "User feedback on flow feeling should cap product-readiness claims until addressed.",
                },
            ],
        },
        "dimensions": [
            {
                "id": "felt_product_quality",
                "score": felt_score,
                "target": 10,
                "evidence": [
                    str(PHASE / "evidence/quality-review/user-feedback-flow-feeling-20260606.md")
                ],
                "missing_to_10": ["runtime flows feel useful and guidance-quality gaps are resolved"],
            },
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
                "title": "Improve felt flow quality and guidance usefulness",
                "rows": [29],
                "proof": "Runtime flow review plus updated user-visible guidance evidence",
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


def test_flow_registry_requires_deep_flow_contract_fields(tmp_path: Path) -> None:
    _write_fixture(tmp_path)
    registry_path = tmp_path / PHASE / "flow-evidence-registry.json"
    registry = json.loads(registry_path.read_text(encoding="utf-8"))
    registry["required_fields_per_entry"] = [
        field
        for field in registry["required_fields_per_entry"]
        if field
        not in {
            "benchmark_references",
            "critical_assertions",
            "anti_surface_assertions",
        }
    ]
    registry_path.write_text(json.dumps(registry, indent=2), encoding="utf-8")

    errors = _errors(tmp_path)

    assert any("benchmark_references" in error for error in errors)
    assert any("critical_assertions" in error for error in errors)
    assert any("anti_surface_assertions" in error for error in errors)


def test_high_scoring_flow_requires_benchmark_and_assertion_depth(tmp_path: Path) -> None:
    _write_fixture(tmp_path)
    registry_path = tmp_path / PHASE / "flow-evidence-registry.json"
    registry = json.loads(registry_path.read_text(encoding="utf-8"))
    registry["entries"].append(
        {
            "flow_id": "flow_row23_shallow_green",
            "matrix_rows": [23],
            "bug_ids": ["CJT-TEST"],
            "persona": "independent_no_lpp_income_reality",
            "surface_family": "coach_trust",
            "tier": "T1",
            "status_claim": "PARTIAL",
            "score": 8.5,
            "score_cap": 9.0,
            "cap_reasons": ["Still missing VoiceOver proof."],
            "automation": {
                "maestro_flow": "tools/simulator/flows/maestro-perfect-set/flow_row22_primary_screen_visual_crawl.yaml",
                "junit": str(PHASE / "evidence/quality-review/result.xml"),
                "watchdog_exit": 0,
            },
            "evidence_artifacts": [
                str(PHASE / "evidence/quality-review/persona-flow-benchmark-seed-20260606.md")
            ],
            "contract_tests": [{"command": "test", "result": "pass"}],
            "semantic_evals": [{"type": "review", "result": "pass"}],
            "user_visible_outcome": "A high-scoring but shallow flow.",
            "guidance_boundary_evidence": ["No product prescription."],
            "benchmark_references": [],
            "critical_assertions": ["asserts title only"],
            "anti_surface_assertions": [],
            "rubric": {
                "runtime_mechanics": 8.0,
                "human_goal": 8.0,
                "guidance_boundary": 8.0,
                "user_data_grounding": 8.0,
                "provenance_freshness": 8.0,
                "restart_or_continuity": 8.0,
                "next_step_quality": 8.0,
                "ux_a11y_i18n": 8.0,
                "automation_reliability": 8.0,
                "debt_hygiene": 8.0,
            },
            "remaining_gaps": ["VoiceOver proof."],
            "last_reviewed": dt.date.today().isoformat(),
        }
    )
    registry_path.write_text(json.dumps(registry, indent=2), encoding="utf-8")

    errors = _errors(tmp_path)

    assert any("benchmark_references must be non-empty" in error for error in errors)
    assert any("anti_surface_assertions must be non-empty" in error for error in errors)


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


def test_missing_felt_product_quality_score_fails(tmp_path: Path) -> None:
    _write_fixture(tmp_path)
    scorecard = _read_scorecard(tmp_path)
    del scorecard["overall"]["felt_product_quality_score"]
    _write_scorecard(tmp_path, scorecard)

    errors = _errors(tmp_path)

    assert any("felt_product_quality_score" in error for error in errors)


def test_mint_score_cannot_exceed_felt_quality_cap(tmp_path: Path) -> None:
    _write_fixture(tmp_path, mint_score=6.5, felt_score=4.0)

    errors = _errors(tmp_path)

    assert any("cannot exceed felt product quality cap" in error for error in errors)


def test_missing_component_percentage_fails(tmp_path: Path) -> None:
    _write_fixture(tmp_path)
    scorecard = _read_scorecard(tmp_path)
    del scorecard["overall"]["journey_truth_proof_score_percent"]
    _write_scorecard(tmp_path, scorecard)

    errors = _errors(tmp_path)

    assert any("journey_truth_proof_score_percent" in error for error in errors)


def test_missing_felt_quality_dimension_fails(tmp_path: Path) -> None:
    _write_fixture(tmp_path)
    scorecard = _read_scorecard(tmp_path)
    scorecard["dimensions"] = [
        dimension
        for dimension in scorecard["dimensions"]
        if dimension["id"] != "felt_product_quality"
    ]
    _write_scorecard(tmp_path, scorecard)

    errors = _errors(tmp_path)

    assert any("felt_product_quality dimension" in error for error in errors)


def test_felt_quality_dimension_must_match_overall_score(tmp_path: Path) -> None:
    _write_fixture(tmp_path)
    scorecard = _read_scorecard(tmp_path)
    felt_dimension = next(
        dimension
        for dimension in scorecard["dimensions"]
        if dimension["id"] == "felt_product_quality"
    )
    felt_dimension["score"] = 5.0
    _write_scorecard(tmp_path, scorecard)

    errors = _errors(tmp_path)

    assert any("felt_product_quality dimension score must match" in error for error in errors)


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
    screen_quality = next(
        dimension for dimension in scorecard["dimensions"] if dimension["id"] == "screen_quality"
    )
    scorecard["dimensions"].append(dict(screen_quality))
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


def test_flow_evidence_registry_rejects_score_above_cap(tmp_path: Path) -> None:
    _write_fixture(tmp_path)
    registry_path = tmp_path / PHASE / "flow-evidence-registry.json"
    registry = json.loads(registry_path.read_text(encoding="utf-8"))
    registry["entries"] = [
        {
            "flow_id": "flow_test",
            "matrix_rows": [22],
            "bug_ids": ["CJT-001"],
            "persona": "sophie_housing_purchase",
            "surface_family": "money_spine",
            "tier": "T1",
            "status_claim": "PARTIAL",
            "score": 8.0,
            "score_cap": 6.0,
            "cap_reasons": ["maestro pass but no guidance review"],
            "automation": {},
            "evidence_artifacts": [
                str(PHASE / "evidence/quality-review/persona-flow-benchmark-seed-20260606.md")
            ],
            "contract_tests": [],
            "semantic_evals": [],
            "user_visible_outcome": "Shows a seeded benchmark outcome.",
            "guidance_boundary_evidence": ["No regulated-advice wording."],
            "rubric": {
                "runtime_mechanics": 1.0,
                "human_goal": 1.0,
                "guidance_boundary": 1.0,
                "user_data_grounding": 1.0,
                "provenance_freshness": 1.0,
                "restart_or_continuity": 1.0,
                "next_step_quality": 1.0,
                "ux_a11y_i18n": 1.0,
                "automation_reliability": 1.0,
                "debt_hygiene": 1.0,
            },
            "remaining_gaps": ["no guidance review"],
            "last_reviewed": dt.date.today().isoformat(),
        }
    ]
    registry_path.write_text(json.dumps(registry, indent=2), encoding="utf-8")

    errors = _errors(tmp_path)

    assert any("score cannot exceed score_cap" in error for error in errors)


def test_flow_evidence_registry_requires_rubric_dimensions(tmp_path: Path) -> None:
    _write_fixture(tmp_path)
    registry_path = tmp_path / PHASE / "flow-evidence-registry.json"
    registry = json.loads(registry_path.read_text(encoding="utf-8"))
    registry["entries"] = [
        {
            "flow_id": "flow_test",
            "matrix_rows": [22],
            "bug_ids": [],
            "persona": "sophie_housing_purchase",
            "surface_family": "money_spine",
            "tier": "T1",
            "status_claim": "PARTIAL",
            "score": 5.0,
            "score_cap": 6.0,
            "cap_reasons": ["seed"],
            "automation": {},
            "evidence_artifacts": [
                str(PHASE / "evidence/quality-review/persona-flow-benchmark-seed-20260606.md")
            ],
            "contract_tests": [],
            "semantic_evals": [],
            "user_visible_outcome": "Shows a seeded benchmark outcome.",
            "guidance_boundary_evidence": ["No regulated-advice wording."],
            "rubric": {},
            "remaining_gaps": [],
            "last_reviewed": dt.date.today().isoformat(),
        }
    ]
    registry_path.write_text(json.dumps(registry, indent=2), encoding="utf-8")

    errors = _errors(tmp_path)

    assert any("rubric missing runtime_mechanics" in error for error in errors)


def test_flow_evidence_registry_derives_cap_from_missing_evidence(tmp_path: Path) -> None:
    _write_fixture(tmp_path)
    registry_path = tmp_path / PHASE / "flow-evidence-registry.json"
    registry = json.loads(registry_path.read_text(encoding="utf-8"))
    registry["entries"] = [
        {
            "flow_id": "flow_overclaimed",
            "matrix_rows": [22],
            "bug_ids": [],
            "persona": "sophie_housing_purchase",
            "surface_family": "money_spine",
            "tier": "T1",
            "status_claim": "LIVE-PROVEN",
            "score": 10.0,
            "score_cap": 10.0,
            "cap_reasons": [],
            "automation": {},
            "evidence_artifacts": [],
            "contract_tests": [],
            "semantic_evals": [],
            "user_visible_outcome": "Claims a complete user-visible outcome.",
            "guidance_boundary_evidence": ["Claims safe guidance."],
            "rubric": {
                "runtime_mechanics": 10.0,
                "human_goal": 10.0,
                "guidance_boundary": 10.0,
                "user_data_grounding": 10.0,
                "provenance_freshness": 10.0,
                "restart_or_continuity": 10.0,
                "next_step_quality": 10.0,
                "ux_a11y_i18n": 10.0,
                "automation_reliability": 10.0,
                "debt_hygiene": 10.0,
            },
            "remaining_gaps": [],
            "last_reviewed": dt.date.today().isoformat(),
        }
    ]
    registry_path.write_text(json.dumps(registry, indent=2), encoding="utf-8")

    errors = _errors(tmp_path)

    assert any("derived evidence cap 2" in error for error in errors)


def test_flow_evidence_registry_does_not_treat_watchdog_alone_as_runtime(
    tmp_path: Path,
) -> None:
    _write_fixture(tmp_path)
    registry_path = tmp_path / PHASE / "flow-evidence-registry.json"
    registry = json.loads(registry_path.read_text(encoding="utf-8"))
    evidence_path = str(
        PHASE / "evidence/quality-review/persona-flow-benchmark-seed-20260606.md"
    )
    junit_path = str(PHASE / "evidence/quality-review/result.xml")
    registry["entries"] = [
        {
            "flow_id": "flow_watchdog_only",
            "matrix_rows": [22],
            "bug_ids": [],
            "persona": "sophie_housing_purchase",
            "surface_family": "money_spine",
            "tier": "T1",
            "status_claim": "LIVE-PROVEN",
            "score": 10.0,
            "score_cap": 10.0,
            "cap_reasons": [],
            "automation": {"watchdog_exit": 0},
            "evidence_artifacts": [evidence_path],
            "contract_tests": [{"command": "flutter test", "result": "pass"}],
            "semantic_evals": [{"id": "eval", "result": "pass"}],
            "user_visible_outcome": "Claims a complete user-visible outcome.",
            "guidance_boundary_evidence": ["Claims safe guidance."],
            "rubric": {
                "runtime_mechanics": 10.0,
                "human_goal": 10.0,
                "guidance_boundary": 10.0,
                "user_data_grounding": 10.0,
                "provenance_freshness": 10.0,
                "restart_or_continuity": 10.0,
                "next_step_quality": 10.0,
                "ux_a11y_i18n": 10.0,
                "automation_reliability": 10.0,
                "debt_hygiene": 10.0,
            },
            "remaining_gaps": [],
            "last_reviewed": dt.date.today().isoformat(),
        }
    ]
    registry_path.write_text(json.dumps(registry, indent=2), encoding="utf-8")

    errors = _errors(tmp_path)

    assert any("derived evidence cap 5" in error for error in errors)


def test_empty_flow_evidence_registry_object_fails(tmp_path: Path) -> None:
    _write_fixture(tmp_path)
    registry_path = tmp_path / PHASE / "flow-evidence-registry.json"
    registry_path.write_text("{}", encoding="utf-8")

    errors = _errors(tmp_path)

    assert any("flow-evidence-registry must contain a non-empty object" in error for error in errors)


def test_persona_flow_benchmark_weights_must_sum_to_100(tmp_path: Path) -> None:
    _write_fixture(tmp_path)
    benchmark_path = tmp_path / PHASE / "persona-flow-benchmark.json"
    benchmark = json.loads(benchmark_path.read_text(encoding="utf-8"))
    benchmark["scoring_dimensions"][0]["weight_percent"] = 60
    benchmark_path.write_text(json.dumps(benchmark, indent=2), encoding="utf-8")

    errors = _errors(tmp_path)

    assert any("weights must sum to 100" in error for error in errors)


def test_flow_evidence_registry_accepts_fully_populated_valid_entry(
    tmp_path: Path,
) -> None:
    _write_fixture(tmp_path)
    registry_path = tmp_path / PHASE / "flow-evidence-registry.json"
    registry = json.loads(registry_path.read_text(encoding="utf-8"))
    evidence_path = str(
        PHASE / "evidence/quality-review/persona-flow-benchmark-seed-20260606.md"
    )
    junit_path = str(PHASE / "evidence/quality-review/result.xml")
    registry["entries"] = [
        {
            "flow_id": "flow_valid",
            "matrix_rows": [22],
            "bug_ids": [],
            "persona": "sophie_housing_purchase",
            "surface_family": "money_spine",
            "tier": "T1",
            "status_claim": "PARTIAL",
            "score": 8.0,
            "score_cap": 8.0,
            "cap_reasons": ["open qualitative guidance debt"],
            "automation": {
                "maestro_flow": "tools/simulator/flows/maestro-perfect-set/flow_row22_primary_screen_visual_crawl.yaml",
                "junit": junit_path,
                "watchdog_exit": 0,
            },
            "evidence_artifacts": [evidence_path],
            "contract_tests": [{"command": "flutter test", "result": "pass"}],
            "semantic_evals": [{"id": "eval", "result": "pass"}],
            "user_visible_outcome": "User can inspect Budget/Profile/Rapport flow quality.",
            "guidance_boundary_evidence": ["No product recommendation."],
            "benchmark_references": ["Public Swiss expert-market benchmark artifact."],
            "critical_assertions": [
                "Runtime proves the scenario-specific user outcome, not only navigation."
            ],
            "anti_surface_assertions": [
                "Runtime rejects stale or misleading generic CTA/content."
            ],
            "rubric": {
                "runtime_mechanics": 8.0,
                "human_goal": 8.0,
                "guidance_boundary": 8.0,
                "user_data_grounding": 8.0,
                "provenance_freshness": 8.0,
                "restart_or_continuity": 8.0,
                "next_step_quality": 8.0,
                "ux_a11y_i18n": 8.0,
                "automation_reliability": 8.0,
                "debt_hygiene": 8.0,
            },
            "remaining_gaps": ["release proof still pending"],
            "last_reviewed": dt.date.today().isoformat(),
        }
    ]
    registry_path.write_text(json.dumps(registry, indent=2), encoding="utf-8")

    assert _errors(tmp_path) == []


def test_flow_evidence_registry_caps_high_score_without_restart_depth(
    tmp_path: Path,
) -> None:
    _write_fixture(tmp_path)
    registry_path = tmp_path / PHASE / "flow-evidence-registry.json"
    registry = json.loads(registry_path.read_text(encoding="utf-8"))
    evidence_path = str(
        PHASE / "evidence/quality-review/persona-flow-benchmark-seed-20260606.md"
    )
    junit_path = str(PHASE / "evidence/quality-review/result.xml")
    registry["entries"] = [
        {
            "flow_id": "flow_restart_gap",
            "matrix_rows": [23],
            "bug_ids": [],
            "persona": "independent_no_lpp_income_reality",
            "surface_family": "coach_trust",
            "tier": "T1",
            "status_claim": "PARTIAL",
            "score": 8.5,
            "score_cap": 9.0,
            "cap_reasons": ["Restart proof still pending."],
            "automation": {
                "maestro_flow": "tools/simulator/flows/maestro-perfect-set/flow_row22_primary_screen_visual_crawl.yaml",
                "junit": junit_path,
                "watchdog_exit": 0,
            },
            "evidence_artifacts": [evidence_path],
            "contract_tests": [{"command": "flutter test", "result": "pass"}],
            "semantic_evals": [{"id": "eval", "result": "pass"}],
            "user_visible_outcome": "User gets a high-quality guidance answer.",
            "guidance_boundary_evidence": ["No product recommendation."],
            "benchmark_references": ["Public Swiss expert-market benchmark artifact."],
            "critical_assertions": ["Runtime proves scenario-specific facts."],
            "anti_surface_assertions": ["Runtime rejects misleading generic cards."],
            "rubric": {
                "runtime_mechanics": 9.0,
                "human_goal": 9.0,
                "guidance_boundary": 9.0,
                "user_data_grounding": 9.0,
                "provenance_freshness": 8.0,
                "restart_or_continuity": 6.0,
                "next_step_quality": 9.0,
                "ux_a11y_i18n": 8.0,
                "automation_reliability": 9.0,
                "debt_hygiene": 9.0,
            },
            "remaining_gaps": ["Restart proof still pending."],
            "last_reviewed": dt.date.today().isoformat(),
        }
    ]
    registry_path.write_text(json.dumps(registry, indent=2), encoding="utf-8")

    errors = _errors(tmp_path)

    assert any("derived evidence cap 8" in error for error in errors)


def test_flow_evidence_registry_accepts_score_at_restart_cap_boundary(
    tmp_path: Path,
) -> None:
    _write_fixture(tmp_path)
    registry_path = tmp_path / PHASE / "flow-evidence-registry.json"
    registry = json.loads(registry_path.read_text(encoding="utf-8"))
    evidence_path = str(
        PHASE / "evidence/quality-review/persona-flow-benchmark-seed-20260606.md"
    )
    junit_path = str(PHASE / "evidence/quality-review/result.xml")
    registry["entries"] = [
        {
            "flow_id": "flow_restart_cap_boundary",
            "matrix_rows": [23],
            "bug_ids": [],
            "persona": "independent_no_lpp_income_reality",
            "surface_family": "coach_trust",
            "tier": "T1",
            "status_claim": "PARTIAL",
            "score": 8.0,
            "score_cap": 8.0,
            "cap_reasons": ["Restart proof still pending."],
            "automation": {
                "maestro_flow": "tools/simulator/flows/maestro-perfect-set/flow_row22_primary_screen_visual_crawl.yaml",
                "junit": junit_path,
                "watchdog_exit": 0,
            },
            "evidence_artifacts": [evidence_path],
            "contract_tests": [{"command": "flutter test", "result": "pass"}],
            "semantic_evals": [{"id": "eval", "result": "pass"}],
            "user_visible_outcome": "User gets a strong but capped guidance answer.",
            "guidance_boundary_evidence": ["No product recommendation."],
            "benchmark_references": ["Public Swiss expert-market benchmark artifact."],
            "critical_assertions": ["Runtime proves scenario-specific facts."],
            "anti_surface_assertions": ["Runtime rejects misleading generic cards."],
            "rubric": {
                "runtime_mechanics": 9.0,
                "human_goal": 9.0,
                "guidance_boundary": 9.0,
                "user_data_grounding": 9.0,
                "provenance_freshness": 8.0,
                "restart_or_continuity": 6.0,
                "next_step_quality": 9.0,
                "ux_a11y_i18n": 8.0,
                "automation_reliability": 9.0,
                "debt_hygiene": 9.0,
            },
            "remaining_gaps": ["Restart proof still pending."],
            "last_reviewed": dt.date.today().isoformat(),
        }
    ]
    registry_path.write_text(json.dumps(registry, indent=2), encoding="utf-8")

    assert _errors(tmp_path) == []


def test_flow_evidence_registry_caps_near_ten_without_a11y_runtime_depth(
    tmp_path: Path,
) -> None:
    _write_fixture(tmp_path)
    registry_path = tmp_path / PHASE / "flow-evidence-registry.json"
    registry = json.loads(registry_path.read_text(encoding="utf-8"))
    evidence_path = str(
        PHASE / "evidence/quality-review/persona-flow-benchmark-seed-20260606.md"
    )
    junit_path = str(PHASE / "evidence/quality-review/result.xml")
    registry["entries"] = [
        {
            "flow_id": "flow_a11y_gap",
            "matrix_rows": [23],
            "bug_ids": [],
            "persona": "independent_no_lpp_income_reality",
            "surface_family": "coach_trust",
            "tier": "T1",
            "status_claim": "PARTIAL",
            "score": 9.5,
            "score_cap": 10.0,
            "cap_reasons": ["VoiceOver runtime proof still pending."],
            "automation": {
                "maestro_flow": "tools/simulator/flows/maestro-perfect-set/flow_row22_primary_screen_visual_crawl.yaml",
                "junit": junit_path,
                "watchdog_exit": 0,
            },
            "evidence_artifacts": [evidence_path],
            "contract_tests": [{"command": "flutter test", "result": "pass"}],
            "semantic_evals": [{"id": "eval", "result": "pass"}],
            "user_visible_outcome": "User gets a near-complete guidance answer.",
            "guidance_boundary_evidence": ["No product recommendation."],
            "benchmark_references": ["Public Swiss expert-market benchmark artifact."],
            "critical_assertions": ["Runtime proves scenario-specific facts."],
            "anti_surface_assertions": ["Runtime rejects misleading generic cards."],
            "rubric": {
                "runtime_mechanics": 9.0,
                "human_goal": 9.0,
                "guidance_boundary": 9.0,
                "user_data_grounding": 9.0,
                "provenance_freshness": 9.0,
                "restart_or_continuity": 9.0,
                "next_step_quality": 9.0,
                "ux_a11y_i18n": 7.0,
                "automation_reliability": 9.0,
                "debt_hygiene": 9.0,
            },
            "remaining_gaps": ["VoiceOver runtime proof still pending."],
            "last_reviewed": dt.date.today().isoformat(),
        }
    ]
    registry_path.write_text(json.dumps(registry, indent=2), encoding="utf-8")

    errors = _errors(tmp_path)

    assert any("derived evidence cap 9" in error for error in errors)


def test_flow_evidence_registry_rejects_missing_automation_paths(
    tmp_path: Path,
) -> None:
    _write_fixture(tmp_path)
    registry_path = tmp_path / PHASE / "flow-evidence-registry.json"
    registry = json.loads(registry_path.read_text(encoding="utf-8"))
    evidence_path = str(
        PHASE / "evidence/quality-review/persona-flow-benchmark-seed-20260606.md"
    )
    registry["entries"] = [
        {
            "flow_id": "flow_fake_runtime",
            "matrix_rows": [22],
            "bug_ids": [],
            "persona": "sophie_housing_purchase",
            "surface_family": "money_spine",
            "tier": "T1",
            "status_claim": "LIVE-PROVEN",
            "score": 10.0,
            "score_cap": 10.0,
            "cap_reasons": [],
            "automation": {
                "maestro_flow": "does/not/exist.yaml",
                "junit": "does/not/exist-result.xml",
                "watchdog_exit": 0,
            },
            "evidence_artifacts": [evidence_path],
            "contract_tests": [{"command": "flutter test", "result": "pass"}],
            "semantic_evals": [{"id": "eval", "result": "pass"}],
            "user_visible_outcome": "Claims a complete user-visible outcome.",
            "guidance_boundary_evidence": ["Claims safe guidance."],
            "rubric": {
                "runtime_mechanics": 10.0,
                "human_goal": 10.0,
                "guidance_boundary": 10.0,
                "user_data_grounding": 10.0,
                "provenance_freshness": 10.0,
                "restart_or_continuity": 10.0,
                "next_step_quality": 10.0,
                "ux_a11y_i18n": 10.0,
                "automation_reliability": 10.0,
                "debt_hygiene": 10.0,
            },
            "remaining_gaps": [],
            "last_reviewed": dt.date.today().isoformat(),
        }
    ]
    registry_path.write_text(json.dumps(registry, indent=2), encoding="utf-8")

    errors = _errors(tmp_path)

    assert any("automation.maestro_flow missing" in error for error in errors)
    assert any("automation.junit missing" in error for error in errors)
    assert any("derived evidence cap 5" in error for error in errors)


def test_flow_evidence_registry_rejects_missing_api_contract_even_with_backend_contract(
    tmp_path: Path,
) -> None:
    _write_fixture(tmp_path)
    registry_path = tmp_path / PHASE / "flow-evidence-registry.json"
    registry = json.loads(registry_path.read_text(encoding="utf-8"))
    evidence_path = str(
        PHASE / "evidence/quality-review/persona-flow-benchmark-seed-20260606.md"
    )
    backend_contract_path = str(PHASE / "evidence/quality-review/result.xml")
    registry["entries"] = [
        {
            "flow_id": "flow_backend_contract",
            "matrix_rows": [22],
            "bug_ids": [],
            "persona": "sophie_housing_purchase",
            "surface_family": "money_spine",
            "tier": "backend",
            "status_claim": "PARTIAL",
            "score": 8.0,
            "score_cap": 8.0,
            "cap_reasons": ["backend-only seed"],
            "automation": {
                "backend_contract": backend_contract_path,
                "api_contract": "does/not/exist-openapi.json",
            },
            "evidence_artifacts": [evidence_path],
            "contract_tests": [{"command": "pytest", "result": "pass"}],
            "semantic_evals": [{"id": "eval", "result": "pass"}],
            "user_visible_outcome": "Backend contract supports a future flow.",
            "guidance_boundary_evidence": ["No user-facing advice."],
            "rubric": {
                "runtime_mechanics": 8.0,
                "human_goal": 8.0,
                "guidance_boundary": 8.0,
                "user_data_grounding": 8.0,
                "provenance_freshness": 8.0,
                "restart_or_continuity": 8.0,
                "next_step_quality": 8.0,
                "ux_a11y_i18n": 8.0,
                "automation_reliability": 8.0,
                "debt_hygiene": 8.0,
            },
            "remaining_gaps": ["runtime flow pending"],
            "last_reviewed": dt.date.today().isoformat(),
        }
    ]
    registry_path.write_text(json.dumps(registry, indent=2), encoding="utf-8")

    errors = _errors(tmp_path)

    assert any("automation.api_contract missing" in error for error in errors)


def test_flow_evidence_registry_rejects_boolean_watchdog_exit(tmp_path: Path) -> None:
    _write_fixture(tmp_path)
    registry_path = tmp_path / PHASE / "flow-evidence-registry.json"
    registry = json.loads(registry_path.read_text(encoding="utf-8"))
    evidence_path = str(
        PHASE / "evidence/quality-review/persona-flow-benchmark-seed-20260606.md"
    )
    junit_path = str(PHASE / "evidence/quality-review/result.xml")
    registry["entries"] = [
        {
            "flow_id": "flow_bool_watchdog",
            "matrix_rows": [22],
            "bug_ids": [],
            "persona": "sophie_housing_purchase",
            "surface_family": "money_spine",
            "tier": "T1",
            "status_claim": "PARTIAL",
            "score": 8.0,
            "score_cap": 8.0,
            "cap_reasons": ["seed"],
            "automation": {
                "maestro_flow": "tools/simulator/flows/maestro-perfect-set/flow_row22_primary_screen_visual_crawl.yaml",
                "junit": junit_path,
                "watchdog_exit": True,
            },
            "evidence_artifacts": [evidence_path],
            "contract_tests": [{"command": "flutter test", "result": "pass"}],
            "semantic_evals": [{"id": "eval", "result": "pass"}],
            "user_visible_outcome": "Flow claims runtime proof.",
            "guidance_boundary_evidence": ["No product recommendation."],
            "rubric": {
                "runtime_mechanics": 8.0,
                "human_goal": 8.0,
                "guidance_boundary": 8.0,
                "user_data_grounding": 8.0,
                "provenance_freshness": 8.0,
                "restart_or_continuity": 8.0,
                "next_step_quality": 8.0,
                "ux_a11y_i18n": 8.0,
                "automation_reliability": 8.0,
                "debt_hygiene": 8.0,
            },
            "remaining_gaps": ["seed"],
            "last_reviewed": dt.date.today().isoformat(),
        }
    ]
    registry_path.write_text(json.dumps(registry, indent=2), encoding="utf-8")

    errors = _errors(tmp_path)

    assert any("automation.watchdog_exit must be an integer" in error for error in errors)
