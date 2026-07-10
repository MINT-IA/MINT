import json
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
SCRIPT = ROOT / "tools/checks/interaction_registry_lint.py"


def _run(*args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, str(SCRIPT), *args],
        cwd=ROOT,
        text=True,
        capture_output=True,
        check=False,
    )


def test_live_interaction_registry_validates() -> None:
    result = _run()

    assert result.returncode == 0, result.stdout + result.stderr
    assert "1 flow file(s) validated" in result.stdout


def test_interaction_index_is_generated_from_registry() -> None:
    result = _run("--emit-index")
    index = (ROOT / "interactions/INDEX.md").read_text(encoding="utf-8")

    assert result.returncode == 0, result.stdout + result.stderr
    assert result.stdout == index


def test_root_option_resolves_references_inside_target_repo(tmp_path: Path) -> None:
    (tmp_path / "interactions").mkdir()
    (tmp_path / "apps/mobile/lib/routes").mkdir(parents=True)
    (tmp_path / "apps/mobile/lib/l10n").mkdir(parents=True)
    (tmp_path / "apps/mobile/lib/services").mkdir(parents=True)
    (tmp_path / "apps/mobile/lib/screens").mkdir(parents=True)
    (tmp_path / "apps/mobile/lib/routes/route_metadata.dart").write_text(
        "const routes = {\n  '/custom': RouteMeta(path: '/custom'),\n};\n",
        encoding="utf-8",
    )
    (tmp_path / "apps/mobile/lib/l10n/app_fr.arb").write_text(
        json.dumps({"ctaKey": "Continuer"}),
        encoding="utf-8",
    )
    (tmp_path / "apps/mobile/lib/services/analytics_events.dart").write_text(
        "const String kEventCustom = 'event_clicked';\n",
        encoding="utf-8",
    )
    (tmp_path / "apps/mobile/lib/screens/custom.dart").write_text(
        "class CustomScreen {}\n",
        encoding="utf-8",
    )
    (tmp_path / "proof.yaml").write_text("appId: test\n---\n", encoding="utf-8")
    (tmp_path / "interactions/custom.yaml").write_text(
        json.dumps(
            {
                "schema_version": 1,
                "flow": {
                    "id": "custom",
                    "title": "Custom flow",
                    "exits": ["custom.route.screen"],
                    "invariants": {"max_depth": 1, "every_scene_has_exit": True},
                },
                "nodes": [
                    {
                        "id": "custom.route.screen",
                        "kind": "route",
                        "route": "/custom",
                        "widget": "screens/custom.dart",
                        "entries": [{"via": "flow", "back": "pop"}],
                        "states": ["content"],
                    }
                ],
                "edges": [
                    {
                        "id": "custom.edge.submit",
                        "from": "custom.route.screen",
                        "to": "custom.route.screen",
                        "trigger": "submit",
                        "payload": {},
                        "transition": "push",
                        "analytics": "event_clicked",
                        "a11y_label": "ctaKey",
                        "test_ref": "proof.yaml",
                    }
                ],
            }
        ),
        encoding="utf-8",
    )

    result = _run("--root", str(tmp_path))

    assert result.returncode == 0, result.stdout + result.stderr


def test_lint_rejects_unknown_route(tmp_path: Path) -> None:
    flow = json.loads((ROOT / "interactions/revenu_to_mortgage.yaml").read_text())
    flow["nodes"][1]["route"] = "/ghost-route"
    fixture = tmp_path / "revenu_to_mortgage.yaml"
    fixture.write_text(json.dumps(flow), encoding="utf-8")

    result = _run("--file", str(fixture))

    assert result.returncode == 1
    assert "unknown route '/ghost-route'" in result.stderr


def test_lint_enforces_declared_max_depth(tmp_path: Path) -> None:
    flow = json.loads((ROOT / "interactions/revenu_to_mortgage.yaml").read_text())
    flow["flow"]["invariants"]["max_depth"] = 0
    fixture = tmp_path / "revenu_to_mortgage.yaml"
    fixture.write_text(json.dumps(flow), encoding="utf-8")

    result = _run("--file", str(fixture))

    assert result.returncode == 1
    assert "max depth 1 exceeds 0" in result.stderr


def test_lint_rejects_dead_end_without_flow_exit(tmp_path: Path) -> None:
    flow = json.loads((ROOT / "interactions/revenu_to_mortgage.yaml").read_text())
    flow["flow"]["exits"] = ["home.route.dashboard"]
    fixture = tmp_path / "revenu_to_mortgage.yaml"
    fixture.write_text(json.dumps(flow), encoding="utf-8")

    result = _run("--file", str(fixture))

    assert result.returncode == 1
    assert "mortgage.route.hypotheque: dead end without flow exit" in result.stderr


def test_lint_rejects_unknown_exit_identifier(tmp_path: Path) -> None:
    flow = json.loads((ROOT / "interactions/revenu_to_mortgage.yaml").read_text())
    flow["flow"]["exits"] = ["home.route.typo"]
    fixture = tmp_path / "revenu_to_mortgage.yaml"
    fixture.write_text(json.dumps(flow), encoding="utf-8")

    result = _run("--file", str(fixture))

    assert result.returncode == 1
    assert "exit references unknown node or flow ref 'home.route.typo'" in result.stderr


def test_lint_allows_cross_flow_edge_targets(tmp_path: Path) -> None:
    flow = json.loads((ROOT / "interactions/revenu_to_mortgage.yaml").read_text())
    flow["edges"][1]["to"] = "mortgage.flow.next"
    fixture = tmp_path / "revenu_to_mortgage.yaml"
    fixture.write_text(json.dumps(flow), encoding="utf-8")

    result = _run("--file", str(fixture))

    assert result.returncode == 0, result.stdout + result.stderr


def test_lint_rejects_unknown_payload_keys(tmp_path: Path) -> None:
    flow = json.loads((ROOT / "interactions/revenu_to_mortgage.yaml").read_text())
    flow["edges"][1]["payload"] = {"deeplink": "mint:///hypotheque"}
    fixture = tmp_path / "revenu_to_mortgage.yaml"
    fixture.write_text(json.dumps(flow), encoding="utf-8")

    result = _run("--file", str(fixture))

    assert result.returncode == 1
    assert "unknown payload key(s): deeplink" in result.stderr


def test_lint_rejects_domain_data_in_extra(tmp_path: Path) -> None:
    flow = json.loads((ROOT / "interactions/revenu_to_mortgage.yaml").read_text())
    flow["edges"][0]["payload"] = {"extra": "CoachProfile"}
    fixture = tmp_path / "revenu_to_mortgage.yaml"
    fixture.write_text(json.dumps(flow), encoding="utf-8")

    result = _run("--file", str(fixture))

    assert result.returncode == 1
    assert "payload.extra must not carry domain data" in result.stderr
