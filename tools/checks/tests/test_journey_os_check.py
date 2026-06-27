from __future__ import annotations

import json
from pathlib import Path
from tools.checks import journey_os_check, journey_os_generate

def _root(tmp_path: Path) -> Path:
    (tmp_path / "apps/mobile/lib/routes").mkdir(parents=True)
    (tmp_path / ".planning/journeys/records").mkdir(parents=True)
    (tmp_path / ".planning/journeys/issues").mkdir(parents=True)
    (tmp_path / ".planning/journeys/journey.schema.json").write_text("{}", encoding="utf-8")
    (tmp_path / ".planning/journeys/issue.schema.json").write_text("{}", encoding="utf-8")
    (tmp_path / "artifacts").mkdir()
    (tmp_path / "artifacts/result.xml").write_text("<testsuite/>", encoding="utf-8")
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
        "evidence": [{"kind": "runtime", "status": "green", "command": "maestro test flow.yaml", "artifact": "artifacts/result.xml"}],
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

def test_jos_issue_refs_require_registry_files(tmp_path: Path) -> None:
    root = _root(tmp_path)
    _record(root)
    journey_os_generate.write(root)
    assert any("missing Journey OS issue" in error for error in _errors(root))

def test_issue_registry_and_generated_board(tmp_path: Path) -> None:
    root = _root(tmp_path)
    _record(root)
    _issue(root)
    journey_os_generate.write(root)
    assert _errors(root) == []
    board = (root / ".planning/journeys/BOARD.md").read_text(encoding="utf-8")
    assert "Next Journey OS Work" in board
    assert "JOS-001" in board
    assert "money_truth_spine" in board

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
