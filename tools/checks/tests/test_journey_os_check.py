from __future__ import annotations

import json
import subprocess
from pathlib import Path
from tools.checks import journey_os_check, journey_os_generate

GOOD_XML = """<?xml version='1.0' encoding='UTF-8'?><testsuites><testsuite tests="1" failures="0" errors="0"><testcase name="ok"/></testsuite></testsuites>"""
FAILING_XML = """<?xml version='1.0' encoding='UTF-8'?><testsuites><testsuite tests="1" failures="1" errors="0"><testcase name="x"><failure>boom</failure></testcase></testsuite></testsuites>"""
SHA_A = "a" * 40
SHA_B = "b" * 40

def _root(tmp_path: Path) -> Path:
    (tmp_path / "apps/mobile/lib/routes").mkdir(parents=True)
    (tmp_path / ".planning/journeys/records").mkdir(parents=True)
    (tmp_path / ".planning/journeys/issues").mkdir(parents=True)
    (tmp_path / ".planning/journeys/journey.schema.json").write_text(
        (journey_os_check.REPO_ROOT / ".planning/journeys/journey.schema.json").read_text(encoding="utf-8"),
        encoding="utf-8",
    )
    (tmp_path / ".planning/journeys/issue.schema.json").write_text(
        (journey_os_check.REPO_ROOT / ".planning/journeys/issue.schema.json").read_text(encoding="utf-8"),
        encoding="utf-8",
    )
    (tmp_path / "artifacts").mkdir()
    (tmp_path / "artifacts/result.xml").write_text(GOOD_XML, encoding="utf-8")
    routes = ["/budget", "/mon-argent", "/rapport", "/coach/chat", "/profile/bilan"]
    (tmp_path / "apps/mobile/lib/routes/route_metadata.dart").write_text(
        "\n".join(f"  '{route}': RouteMeta(path: '{route}')," for route in routes),
        encoding="utf-8",
    )
    return tmp_path

def _record(root: Path, **updates: object) -> None:
    data: dict[str, object] = {
        "schema_version": 1,
        "id": "money_truth_spine",
        "title": "Money truth spine",
        "tier": "T0",
        "status": "partial",
        "human_promise": "My money numbers are consistent.",
        "accountable_team": "mint-quality-gate",
        "route_paths": ["/budget", "/mon-argent", "/rapport", "/coach/chat"],
        "surfaces": ["BudgetSnapshot", "DataSpineSnapshot"],
        "external_apis": [],
        "issues": ["JOS-001"],
        "priority": {
            "trust_blast_radius": 5,
            "release_blocker_weight": 5,
            "user_frequency": 5,
            "evidence_gap": 2,
            "route_centrality": 5,
            "compliance_risk": 4,
            "learning_value": 5,
            "proof_cost": 3,
            "rationale": "Money consistency is the central Mint trust promise.",
        },
        "evidence": [
            {
                "kind": "runtime",
                "status": "green",
                "command": "maestro test flow.yaml",
                "artifact": "artifacts/result.xml",
                "verified_at": "2026-06-26T00:00:00Z",
                "verified_commit": SHA_A,
            }
        ],
    }
    stem = str(updates.pop("_stem", data["id"]))
    data.update(updates)
    (root / f".planning/journeys/records/{stem}.json").write_text(json.dumps(data), encoding="utf-8")

def _issue(root: Path, **updates: object) -> None:
    data: dict[str, object] = {
        "schema_version": 1,
        "id": "JOS-001",
        "title": "Prove money truth spine",
        "journey_id": "money_truth_spine",
        "status": "proof_needed",
        "owner": "mint-quality-gate",
        "severity": "P0",
        "evidence_status": "green",
        "next_action": "Create the next deterministic runtime proof for the highest-scoring journey.",
        "source": "CJT-003",
    }
    data.update(updates)
    (root / f".planning/journeys/issues/{data['id']}.json").write_text(json.dumps(data), encoding="utf-8")

def _errors(root: Path, changed: list[str] | None = None) -> list[str]:
    return journey_os_check.check(root, changed or ["tools/checks/journey_os_check.py"])

def test_valid_fixture_passes(tmp_path: Path) -> None:
    root = _root(tmp_path)
    _record(root)
    _issue(root)
    journey_os_generate.write(root)
    assert _errors(root) == []

def test_missing_baseline_fails_closed(tmp_path: Path) -> None:
    root = _root(tmp_path)
    _record(root)
    _issue(root)
    journey_os_generate.write(root)
    assert any("origin/dev" in error or "baseline" in error for error in journey_os_check.check(root, []))

def test_changed_file_outside_whitelist_fails(tmp_path: Path) -> None:
    root = _root(tmp_path)
    _record(root)
    _issue(root)
    journey_os_generate.write(root)
    assert any("outside Journey OS whitelist" in error for error in _errors(root, ["apps/mobile/lib/app.dart"]))

def test_active_context_branch_authorization_is_in_scope(tmp_path: Path) -> None:
    root = _root(tmp_path)
    _record(root)
    _issue(root)
    journey_os_generate.write(root)

    errors = _errors(
        root,
        [
            ".planning/ACTIVE_CONTEXT.md",
            ".planning/ACTIVE_CONTEXT.json",
        ],
    )

    assert not any("outside Journey OS whitelist" in error for error in errors)

def test_journey_os_workflow_files_are_in_scope(tmp_path: Path) -> None:
    root = _root(tmp_path)
    _record(root)
    _issue(root)
    journey_os_generate.write(root)

    errors = _errors(
        root,
        [
            ".claude/AGENT_BOOTSTRAP.md",
            ".github/pull_request_template.md",
            ".github/workflows/ai-workflow-guards.yml",
            ".planning/ROADMAP.md",
            "AGENTS.md",
            "docs/MINT_AGENT_WORKFLOW.md",
            "lefthook.yml",
            "rules.md",
            "tools/claude_review.sh",
            "tools/checks/active_context_guard.py",
            "tools/checks/mint_rules_guard.py",
            "tools/checks/tests/test_active_context_guard.py",
            "tools/checks/tests/test_mint_rules_guard.py",
        ],
    )

    assert not any("outside Journey OS whitelist" in error for error in errors)

def test_python_editable_install_egg_info_is_ignored(tmp_path: Path) -> None:
    root = _root(tmp_path)
    _record(root)
    _issue(root)
    journey_os_generate.write(root)

    errors = _errors(
        root,
        [
            "services/backend/mint_backend.egg-info/PKG-INFO",
            "services/backend/mint_backend.egg-info/SOURCES.txt",
            "services/backend/mint_backend.egg-info/requires.txt",
        ],
    )

    assert not any("outside Journey OS whitelist" in error for error in errors)

def test_row24_privacy_runtime_flow_is_in_scope(tmp_path: Path) -> None:
    root = _root(tmp_path)
    _record(root)
    _issue(root)
    journey_os_generate.write(root)

    errors = _errors(
        root,
        [
            "tools/simulator/flows/maestro-perfect-set/flow_row24_privacy_control_runtime.yaml",
        ],
    )

    assert not any("outside Journey OS whitelist" in error for error in errors)

def test_jos004_coach_advice_runtime_flow_is_in_scope(tmp_path: Path) -> None:
    root = _root(tmp_path)
    _record(root)
    _issue(root)
    journey_os_generate.write(root)

    errors = _errors(
        root,
        [
            "tools/simulator/flows/maestro-perfect-set/flow_jos004_coach_advice_turn_runtime.yaml",
        ],
    )

    assert not any("outside Journey OS whitelist" in error for error in errors)

def test_jos004_runtime_flow_completes_first_experience_before_coach() -> None:
    flow = (
        journey_os_check.REPO_ROOT
        / "tools/simulator/flows/maestro-perfect-set/"
        "flow_jos004_coach_advice_turn_runtime.yaml"
    ).read_text(encoding="utf-8")

    login = "mintapp:///auth/login?redirect=%2Fcoach%2Fchat"
    fixture = (
        "mintapp:///__e2e/row23-independent-no-lpp-profile?"
        "slug=cadre_salarie_lpp_suisse_ready"
    )
    coach = 'openLink: "mintapp:///coach/chat"'

    assert login in flow
    assert fixture in flow
    assert 'id: "e2e_profile_fixture_applied"' in flow
    assert flow.index(login) < flow.index(fixture) < flow.index(coach)

def test_onboarding_first_value_tracks_mint2_route_and_issue() -> None:
    record = json.loads(
        (
            journey_os_check.REPO_ROOT
            / ".planning/journeys/records/onboarding_first_value.json"
        ).read_text(encoding="utf-8")
    )

    assert "/rente-vs-capital" in record["route_paths"]
    assert "JOS-005" in record["issues"]

def test_journey_evidence_artifacts_are_in_scope(tmp_path: Path) -> None:
    root = _root(tmp_path)
    _record(root)
    _issue(root)
    evidence_dir = root / ".planning/journeys/evidence/money_truth_spine/20260626T120000Z"
    evidence_dir.mkdir(parents=True)
    (evidence_dir / "result.xml").write_text("<testsuite/>", encoding="utf-8")
    journey_os_generate.write(root)

    errors = _errors(
        root,
        [
            ".planning/journeys/evidence/money_truth_spine/20260626T120000Z/result.xml",
        ],
    )

    assert not any("outside Journey OS whitelist" in error for error in errors)
    assert not any("unsupported Journey OS generated view" in error for error in errors)

def test_changed_includes_local_tracked_worktree_changes(tmp_path: Path) -> None:
    root = _root(tmp_path)
    _record(root)
    _issue(root)
    journey_os_generate.write(root)
    (root / "rules.md").write_text("before\n", encoding="utf-8")

    subprocess.run(["git", "init"], cwd=root, check=True, capture_output=True)
    subprocess.run(
        ["git", "config", "user.email", "test@example.invalid"],
        cwd=root,
        check=True,
        capture_output=True,
    )
    subprocess.run(
        ["git", "config", "user.name", "Test"],
        cwd=root,
        check=True,
        capture_output=True,
    )
    subprocess.run(["git", "add", "."], cwd=root, check=True, capture_output=True)
    subprocess.run(
        ["git", "commit", "-m", "baseline"],
        cwd=root,
        check=True,
        capture_output=True,
    )
    subprocess.run(
        ["git", "update-ref", "refs/remotes/origin/dev", "HEAD"],
        cwd=root,
        check=True,
        capture_output=True,
    )

    (root / "rules.md").write_text("after\n", encoding="utf-8")

    changed, errors = journey_os_check._changed(root, "origin/dev")

    assert errors == []
    assert "rules.md" in changed
    assert journey_os_check.check(root, base_ref="origin/dev") == []

def test_jos_issue_refs_require_registry_files(tmp_path: Path) -> None:
    root = _root(tmp_path)
    _record(root)
    journey_os_generate.write(root)
    assert any("missing Journey OS issue" in error for error in _errors(root))

def test_issue_registry_and_generated_board(tmp_path: Path) -> None:
    root = _root(tmp_path)
    _record(root, external_apis=["POST /api/v1/coach/chat"])
    _issue(root)
    journey_os_generate.write(root)
    assert _errors(root) == []
    board = (root / ".planning/journeys/BOARD.md").read_text(encoding="utf-8")
    today = (root / ".planning/journeys/TODAY.md").read_text(encoding="utf-8")
    system_map = (root / ".planning/journeys/diagrams/system_map.mmd").read_text(encoding="utf-8")
    assert "Next Journey OS Work" in board
    assert "Latest proof" in board
    assert "JOS-001" in board
    assert "money_truth_spine" in board
    assert "Journey OS Today" in today
    assert "flowchart LR" in system_map
    assert "route_coach_chat" in system_map
    assert "api_POST_api_v1_coach_chat" in system_map
    assert "classDef green" in system_map
    assert "classDef api" in system_map
    assert "\\n" not in system_map

def test_today_does_not_promote_green_issue_when_no_actionable_work(tmp_path: Path) -> None:
    root = _root(tmp_path)
    _record(root, status="live_proven")
    _issue(root, status="verified", evidence_status="green")
    journey_os_generate.write(root)
    today = (root / ".planning/journeys/TODAY.md").read_text(encoding="utf-8")

    assert "No red, missing, or baselined Journey OS issue is currently queued." in today
    assert "| JOS-001 |" not in today

def test_today_routes_red_before_higher_priority_baselined_issue(tmp_path: Path) -> None:
    root = _root(tmp_path)
    _record(
        root,
        id="coach_advice_turn",
        title="Coach advice turn",
        _stem="coach_advice_turn",
        issues=["JOS-001"],
        evidence=[
            {
                "kind": "runtime",
                "status": "baselined",
                "command": "maestro test coach.yaml",
                "artifact": "artifacts/result.xml",
                "debt_ref": "JOS-001",
                "verified_at": "2026-06-27T00:00:00Z",
                "verified_commit": SHA_A,
            }
        ],
    )
    _issue(root, id="JOS-001", journey_id="coach_advice_turn", evidence_status="baselined")
    (root / "artifacts/red.xml").write_text(FAILING_XML, encoding="utf-8")
    _record(
        root,
        id="onboarding_first_value",
        title="Onboarding first value",
        _stem="onboarding_first_value",
        issues=["JOS-002"],
        priority={
            "trust_blast_radius": 4,
            "release_blocker_weight": 4,
            "user_frequency": 4,
            "evidence_gap": 2,
            "route_centrality": 4,
            "compliance_risk": 2,
            "learning_value": 4,
            "proof_cost": 3,
            "rationale": "Lower priority red issue must still route before baselined work.",
        },
        evidence=[
            {
                "kind": "runtime",
                "status": "red",
                "command": "maestro test onboarding.yaml",
                "artifact": "artifacts/red.xml",
                "verified_at": "2026-06-27T00:00:00Z",
                "verified_commit": SHA_B,
            }
        ],
    )
    _issue(root, id="JOS-002", journey_id="onboarding_first_value", status="regressed", evidence_status="red")
    journey_os_generate.write(root)
    today = (root / ".planning/journeys/TODAY.md").read_text(encoding="utf-8")

    assert "| JOS-002 | P0 | regressed | onboarding_first_value |" in today
    assert "| JOS-001 |" not in today

def test_issue_status_tracks_referenced_record_evidence(tmp_path: Path) -> None:
    root = _root(tmp_path)
    _record(root)
    _issue(root, status="triaged", evidence_status="missing")
    journey_os_generate.write(root)
    errors = _errors(root)
    assert any("cannot stay triaged" in error for error in errors)
    assert any("cannot stay missing" in error for error in errors)
    root = _root(tmp_path / "overclaim")
    _record(root, evidence=[{"kind": "runtime", "status": "missing", "command": None, "artifact": None}])
    _issue(root, status="proof_needed", evidence_status="green")
    journey_os_generate.write(root)
    assert any("cannot be green" in error for error in _errors(root))

def test_issue_registry_shape_rules(tmp_path: Path) -> None:
    cases = [
        ({"journey_id": "missing_journey"}, "journey_id"),
        ({"status": "new"}, "status"),
        ({"owner": "vendor-agent"}, "owner"),
        ({"severity": "S0"}, "severity"),
        ({"evidence_status": "unknown"}, "evidence_status"),
        ({"id": "BUG-1"}, "JOS-###"),
        ({"next_action": "Too short"}, "next_action"),
    ]
    for update, expected in cases:
        root = _root(tmp_path / expected)
        _record(root)
        _issue(root, **update)
        journey_os_generate.write(root)
        assert any(expected in error for error in _errors(root)), expected

def test_route_owner_status_and_artifact_rules(tmp_path: Path) -> None:
    cases = [
        ({"route_paths": ["/budget", "DELETE /auth/account"]}, "not a registered route"),
        ({"accountable_team": "vendor-agent"}, "accountable_team"),
        ({"evidence": [{"kind": "runtime", "command": "x", "artifact": "artifacts/result.xml"}]}, "status"),
        ({"evidence": [{"kind": "runtime", "status": "green", "command": "x", "artifact": "/tmp/x.xml"}]}, "durable"),
        ({"evidence": [{"kind": "unit", "status": "baselined", "command": "pytest", "artifact": "artifacts/result.xml"}]}, "debt_ref"),
        ({"status": "live_proven", "evidence": [{"kind": "runtime", "status": "red", "command": "x", "artifact": "artifacts/result.xml"}]}, "live_proven"),
    ]
    for update, expected in cases:
        root = _root(tmp_path / expected.replace("/", "_"))
        _record(root, **update)
        _issue(root)
        assert any(expected in error for error in _errors(root)), expected

def test_shape_filename_and_generated_view_rules(tmp_path: Path) -> None:
    cases = [
        ({"title": ""}, "title"),
        ({"tier": "P0"}, "tier"),
        ({"surfaces": ["Budget", 3]}, "surfaces"),
        ({"unknown": True}, "unknown field"),
        ({"_stem": "other_id"}, "filename stem"),
        ({"priority": {"rationale": "too small"}}, "priority missing"),
        ({"priority": {"trust_blast_radius": 1, "release_blocker_weight": 1, "user_frequency": 1, "evidence_gap": 1, "route_centrality": 1, "compliance_risk": 1, "learning_value": 1, "proof_cost": 5, "rationale": "This T0 score is intentionally below the threshold."}}, "T0 priority score"),
    ]
    for update, expected in cases:
        root = _root(tmp_path / expected.replace(" ", "_"))
        _record(root, **update)
        _issue(root)
        assert any(expected in error for error in _errors(root)), expected
    root = _root(tmp_path / "mermaid")
    _record(root)
    _issue(root)
    readme = root / ".planning/journeys/README.md"
    readme.write_text("```mermaid\ngraph TD\n```", encoding="utf-8")
    assert any("Mermaid" in error for error in _errors(root, [".planning/journeys/README.md"]))

def test_generated_views_are_required_and_current(tmp_path: Path) -> None:
    root = _root(tmp_path)
    _record(root)
    _issue(root)
    assert any("missing generated" in error for error in _errors(root))
    journey_os_generate.write(root)
    (root / ".planning/journeys/JOURNEYS.md").write_text("stale\n", encoding="utf-8")
    assert any("stale generated" in error for error in _errors(root))

def test_generated_mermaid_views_are_required_and_current(tmp_path: Path) -> None:
    root = _root(tmp_path)
    _record(root)
    _issue(root)
    journey_os_generate.write(root)

    (root / ".planning/journeys/diagrams/system_map.mmd").unlink()
    assert any("missing generated" in error for error in _errors(root))

    journey_os_generate.write(root)
    (root / ".planning/journeys/diagrams/money_truth_spine.mmd").write_text("stale\n", encoding="utf-8")
    assert any("stale generated" in error for error in _errors(root))

    journey_os_generate.write(root)
    (root / ".planning/journeys/diagrams/orphan.mmd").write_text("flowchart TD\n", encoding="utf-8")
    assert any("orphan generated" in error for error in _errors(root))

def test_schema_files_are_executed(tmp_path: Path) -> None:
    root = _root(tmp_path)
    _record(root)
    _issue(root)
    journey_os_generate.write(root)
    schema_path = root / ".planning/journeys/journey.schema.json"
    schema = json.loads(schema_path.read_text(encoding="utf-8"))
    schema["required"].append("schema_only_field")
    schema_path.write_text(json.dumps(schema), encoding="utf-8")

    assert any("schema_only_field" in error for error in _errors(root))

def test_green_runtime_xml_artifact_cannot_report_failures(tmp_path: Path) -> None:
    root = _root(tmp_path)
    (root / "artifacts/result.xml").write_text(FAILING_XML, encoding="utf-8")
    _record(root)
    _issue(root)
    journey_os_generate.write(root)

    assert any("green but JUnit artifact reports failures" in error for error in _errors(root))

def test_green_runtime_xml_artifact_cannot_be_vacuous(tmp_path: Path) -> None:
    root = _root(tmp_path)
    (root / "artifacts/result.xml").write_text("<testsuite/>", encoding="utf-8")
    _record(root)
    _issue(root)
    journey_os_generate.write(root)

    assert any("zero executed tests" in error for error in _errors(root))

def test_baselined_runtime_xml_artifact_cannot_be_vacuous(tmp_path: Path) -> None:
    root = _root(tmp_path)
    (root / "artifacts/result.xml").write_text("<testsuite/>", encoding="utf-8")
    _record(
        root,
        evidence=[
            {
                "kind": "runtime",
                "status": "baselined",
                "command": "maestro test flow.yaml",
                "artifact": "artifacts/result.xml",
                "debt_ref": "JOS-TEST",
                "verified_at": "2026-06-26T00:00:00Z",
                "verified_commit": SHA_A,
            }
        ],
    )
    _issue(root, evidence_status="baselined")
    journey_os_generate.write(root)

    assert any("zero executed tests" in error for error in _errors(root))

def test_runtime_evidence_requires_verified_provenance(tmp_path: Path) -> None:
    root = _root(tmp_path)
    _record(
        root,
        evidence=[{"kind": "runtime", "status": "green", "command": "maestro test flow.yaml", "artifact": "artifacts/result.xml"}],
    )
    _issue(root)
    journey_os_generate.write(root)

    errors = _errors(root)
    assert any("requires verified_at" in error for error in errors)
    assert any("requires verified_commit" in error for error in errors)

def test_runtime_evidence_requires_full_sha(tmp_path: Path) -> None:
    root = _root(tmp_path)
    _record(
        root,
        evidence=[
            {
                "kind": "runtime",
                "status": "green",
                "command": "maestro test flow.yaml",
                "artifact": "artifacts/result.xml",
                "verified_at": "2026-06-26T00:00:00Z",
                "verified_commit": "abc123",
            }
        ],
    )
    _issue(root)
    journey_os_generate.write(root)

    assert any("full SHA" in error for error in _errors(root))

def test_red_runtime_xml_artifact_requires_failure(tmp_path: Path) -> None:
    root = _root(tmp_path)
    _record(
        root,
        evidence=[
            {
                "kind": "runtime",
                "status": "red",
                "command": "maestro test flow.yaml",
                "artifact": "artifacts/result.xml",
                "verified_at": "2026-06-26T00:00:00Z",
                "verified_commit": SHA_A,
            }
        ],
    )
    _issue(root, evidence_status="red")
    journey_os_generate.write(root)

    assert any("red but JUnit artifact reports no failures" in error for error in _errors(root))

def test_green_text_artifact_cannot_contain_failure_marker(tmp_path: Path) -> None:
    root = _root(tmp_path)
    artifact = root / ".planning/journeys/evidence/money_truth_spine/20260626T120000Z/result.txt"
    artifact.parent.mkdir(parents=True)
    artifact.write_text("[Failed] Assertion is false\n", encoding="utf-8")
    _record(
        root,
        evidence=[
            {
                "kind": "runtime",
                "status": "green",
                "command": "maestro test flow.yaml",
                "artifact": str(artifact.relative_to(root)),
                "verified_at": "2026-06-26T00:00:00Z",
                "verified_commit": SHA_A,
            }
        ],
    )
    _issue(root)
    journey_os_generate.write(root)

    assert any("text artifact contains failure markers" in error for error in _errors(root))

def test_green_text_artifact_needs_success_marker(tmp_path: Path) -> None:
    root = _root(tmp_path)
    artifact = root / ".planning/journeys/evidence/money_truth_spine/20260626T120000Z/result.txt"
    artifact.parent.mkdir(parents=True)
    artifact.write_text("Assert that id: money_screen is visible... COMPLETED\n", encoding="utf-8")
    _record(
        root,
        evidence=[
            {
                "kind": "runtime",
                "status": "green",
                "command": "maestro test flow.yaml",
                "artifact": str(artifact.relative_to(root)),
                "verified_at": "2026-06-26T00:00:00Z",
                "verified_commit": SHA_A,
            }
        ],
    )
    _issue(root)
    journey_os_generate.write(root)

    assert any("needs an explicit success marker" in error for error in _errors(root))

def test_runtime_evidence_rejects_arbitrary_artifact_type(tmp_path: Path) -> None:
    root = _root(tmp_path)
    source_artifact = root / "apps/mobile/lib/routes/route_metadata.dart"
    _record(
        root,
        evidence=[
            {
                "kind": "runtime",
                "status": "green",
                "command": "maestro test flow.yaml",
                "artifact": str(source_artifact.relative_to(root)),
                "verified_at": "2026-06-26T00:00:00Z",
                "verified_commit": SHA_A,
            }
        ],
    )
    _issue(root)
    journey_os_generate.write(root)

    assert any("runtime evidence must use a parseable" in error for error in _errors(root))

def test_red_text_artifact_requires_failure_marker(tmp_path: Path) -> None:
    root = _root(tmp_path)
    artifact = root / ".planning/journeys/evidence/money_truth_spine/20260626T120000Z/result.txt"
    artifact.parent.mkdir(parents=True)
    artifact.write_text("No structured failure marker\n", encoding="utf-8")
    _record(
        root,
        evidence=[
            {
                "kind": "runtime",
                "status": "red",
                "command": "maestro test flow.yaml",
                "artifact": str(artifact.relative_to(root)),
                "verified_at": "2026-06-26T00:00:00Z",
                "verified_commit": SHA_A,
            }
        ],
    )
    _issue(root, evidence_status="red")
    journey_os_generate.write(root)

    assert any("text artifact has no failure marker" in error for error in _errors(root))

def test_green_issue_rejects_latest_red_evidence(tmp_path: Path) -> None:
    root = _root(tmp_path)
    (root / "artifacts/green.xml").write_text(GOOD_XML, encoding="utf-8")
    (root / "artifacts/red.xml").write_text(FAILING_XML, encoding="utf-8")
    _record(
        root,
        evidence=[
            {
                "kind": "runtime",
                "status": "green",
                "command": "maestro test flow.yaml",
                "artifact": "artifacts/green.xml",
                "verified_at": "2026-06-26T00:00:00Z",
                "verified_commit": SHA_A,
            },
            {
                "kind": "runtime",
                "status": "red",
                "command": "maestro test flow.yaml",
                "artifact": "artifacts/red.xml",
                "verified_at": "2026-06-27T00:00:00Z",
                "verified_commit": SHA_B,
            },
        ],
    )
    _issue(root, status="verified", evidence_status="green")
    journey_os_generate.write(root)

    assert any("latest evidence" in error for error in _errors(root))

def test_green_issue_rejects_latest_baselined_evidence(tmp_path: Path) -> None:
    root = _root(tmp_path)
    (root / "artifacts/green.xml").write_text(GOOD_XML, encoding="utf-8")
    _record(
        root,
        evidence=[
            {
                "kind": "runtime",
                "status": "green",
                "command": "maestro test flow.yaml",
                "artifact": "artifacts/green.xml",
                "verified_at": "2026-06-26T00:00:00Z",
                "verified_commit": SHA_A,
            },
            {
                "kind": "runtime",
                "status": "baselined",
                "command": "maestro test flow.yaml",
                "artifact": "artifacts/result.xml",
                "debt_ref": "JOS-TEST",
                "verified_at": "2026-06-27T00:00:00Z",
                "verified_commit": SHA_B,
            },
        ],
    )
    _issue(root, status="verified", evidence_status="green")
    journey_os_generate.write(root)

    assert any("latest evidence" in error and "baselined" in error for error in _errors(root))

def test_live_proven_rejects_latest_red_runtime_evidence(tmp_path: Path) -> None:
    root = _root(tmp_path)
    (root / "artifacts/green.xml").write_text(GOOD_XML, encoding="utf-8")
    (root / "artifacts/red.xml").write_text(FAILING_XML, encoding="utf-8")
    _record(
        root,
        status="live_proven",
        evidence=[
            {
                "kind": "runtime",
                "status": "green",
                "command": "maestro test flow.yaml",
                "artifact": "artifacts/green.xml",
                "verified_at": "2026-06-26T00:00:00Z",
                "verified_commit": SHA_A,
            },
            {
                "kind": "runtime",
                "status": "red",
                "command": "maestro test flow.yaml",
                "artifact": "artifacts/red.xml",
                "verified_at": "2026-06-27T00:00:00Z",
                "verified_commit": SHA_B,
            },
        ],
    )
    _issue(root, evidence_status="red")
    journey_os_generate.write(root)

    assert any("latest runtime evidence" in error for error in _errors(root))

def test_latest_evidence_tiebreak_uses_append_order(tmp_path: Path) -> None:
    root = _root(tmp_path)
    (root / "artifacts/green.xml").write_text(GOOD_XML, encoding="utf-8")
    (root / "artifacts/red.xml").write_text(FAILING_XML, encoding="utf-8")
    _record(
        root,
        evidence=[
            {
                "kind": "runtime",
                "status": "green",
                "command": "maestro test flow.yaml",
                "artifact": "artifacts/green.xml",
                "verified_at": "2026-06-27T00:00:00Z",
                "verified_commit": SHA_A,
            },
            {
                "kind": "runtime",
                "status": "red",
                "command": "maestro test flow.yaml",
                "artifact": "artifacts/red.xml",
                "verified_at": "2026-06-27T00:00:00Z",
                "verified_commit": SHA_B,
            },
        ],
    )
    _issue(root, status="regressed", evidence_status="red")
    journey_os_generate.write(root)
    board = (root / ".planning/journeys/BOARD.md").read_text(encoding="utf-8")

    assert "red / runtime / 2026-06-27T00:00:00Z / bbbbbbbb" in board
    assert not any("latest evidence" in error for error in _errors(root))

def test_latest_evidence_append_order_beats_older_timestamp(tmp_path: Path) -> None:
    root = _root(tmp_path)
    (root / "artifacts/green.xml").write_text(GOOD_XML, encoding="utf-8")
    (root / "artifacts/red.xml").write_text(FAILING_XML, encoding="utf-8")
    _record(
        root,
        evidence=[
            {
                "kind": "runtime",
                "status": "green",
                "command": "maestro test flow.yaml",
                "artifact": "artifacts/green.xml",
                "verified_at": "2026-06-27T00:00:00Z",
                "verified_commit": SHA_A,
            },
            {
                "kind": "runtime",
                "status": "red",
                "command": "maestro test flow.yaml",
                "artifact": "artifacts/red.xml",
                "verified_at": "2026-06-26T00:00:00Z",
                "verified_commit": SHA_B,
            },
        ],
    )
    _issue(root, status="regressed", evidence_status="red")
    journey_os_generate.write(root)
    board = (root / ".planning/journeys/BOARD.md").read_text(encoding="utf-8")

    assert "red / runtime / 2026-06-26T00:00:00Z / bbbbbbbb" in board
    assert not any("latest evidence" in error for error in _errors(root))
