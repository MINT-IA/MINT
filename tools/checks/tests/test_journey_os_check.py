from __future__ import annotations

import json
from pathlib import Path
from tools.checks import journey_os_check, journey_os_generate

def _root(tmp_path: Path) -> Path:
    (tmp_path / "apps/mobile/lib/routes").mkdir(parents=True)
    (tmp_path / ".planning/journeys/records").mkdir(parents=True)
    (tmp_path / ".planning/journeys/journey.schema.json").write_text("{}", encoding="utf-8")
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
        "issues": ["CJT-003"],
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

def _errors(root: Path, changed: list[str] | None = None) -> list[str]:
    return journey_os_check.check(root, changed or ["tools/checks/journey_os_check.py"])

def test_valid_fixture_passes(tmp_path: Path) -> None:
    root = _root(tmp_path)
    _record(root)
    journey_os_generate.write(root)
    assert _errors(root) == []

def test_missing_baseline_fails_closed(tmp_path: Path) -> None:
    root = _root(tmp_path)
    _record(root)
    journey_os_generate.write(root)
    assert any("origin/dev" in error or "baseline" in error for error in journey_os_check.check(root, []))

def test_changed_file_outside_whitelist_fails(tmp_path: Path) -> None:
    root = _root(tmp_path)
    _record(root)
    journey_os_generate.write(root)
    assert any("outside Journey OS whitelist" in error for error in _errors(root, ["apps/mobile/lib/app.dart"]))

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
        assert any(expected in error for error in _errors(root)), expected
    root = _root(tmp_path / "mermaid")
    _record(root)
    readme = root / ".planning/journeys/README.md"
    readme.write_text("```mermaid\ngraph TD\n```", encoding="utf-8")
    assert any("Mermaid" in error for error in _errors(root, [".planning/journeys/README.md"]))

def test_generated_views_are_required_and_current(tmp_path: Path) -> None:
    root = _root(tmp_path)
    _record(root)
    assert any("missing generated" in error for error in _errors(root))
    journey_os_generate.write(root)
    (root / ".planning/journeys/JOURNEYS.md").write_text("stale\n", encoding="utf-8")
    assert any("stale generated" in error for error in _errors(root))
