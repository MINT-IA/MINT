from pathlib import Path

from tools.checks import interaction_registry_lint


def _write_minimal_repo(root: Path) -> None:
    (root / "apps/mobile/lib/routes").mkdir(parents=True)
    (root / "apps/mobile/lib/routes/route_metadata.dart").write_text(
        """
const Map<String, RouteMeta> kRouteRegistry = <String, RouteMeta>{
  '/data-block/:type': RouteMeta(path: '/data-block/:type'),
  '/hypotheque': RouteMeta(path: '/hypotheque'),
  '/home': RouteMeta(path: '/home'),
};
""",
        encoding="utf-8",
    )
    (root / "apps/mobile/lib/screens/aujourdhui").mkdir(parents=True)
    (root / "apps/mobile/lib/screens/aujourdhui/aujourdhui_screen.dart").write_text(
        "class AujourdhuiScreen {}\n",
        encoding="utf-8",
    )
    (root / "apps/mobile/lib/screens/onboarding").mkdir(parents=True)
    (root / "apps/mobile/lib/screens/onboarding/data_block_enrichment_screen.dart").write_text(
        "class DataBlockEnrichmentScreen {}\n",
        encoding="utf-8",
    )
    (root / "apps/mobile/lib/screens/mortgage").mkdir(parents=True)
    (root / "apps/mobile/lib/screens/mortgage/affordability_screen.dart").write_text(
        "class AffordabilityScreen {}\n",
        encoding="utf-8",
    )
    (root / "apps/mobile/lib/services").mkdir(parents=True)
    (root / "apps/mobile/lib/services/analytics_events.dart").write_text(
        "const String kEventCtaClicked = 'cta_clicked';\n",
        encoding="utf-8",
    )
    (root / "apps/mobile/lib/l10n").mkdir(parents=True)
    (root / "apps/mobile/lib/l10n/app_fr.arb").write_text(
        '{"mortgageCta": "Voir ma capacité"}\n',
        encoding="utf-8",
    )
    (root / "apps/mobile/.maestro").mkdir(parents=True)
    (root / "apps/mobile/.maestro/f2_datablock_to_mortgage.yaml").write_text(
        "appId: ch.mint.app\n---\n- assertVisible: {text: Revenu}\n",
        encoding="utf-8",
    )
    (root / ".planning/journeys/diagrams").mkdir(parents=True)


def _write_registry(root: Path) -> None:
    interactions = root / "interactions"
    interactions.mkdir()
    (interactions / "revenu_to_mortgage.yaml").write_text(
        """
schema_version: 1
flow:
  id: revenu_to_mortgage
  title: "Faits de revenu canoniques vers capacité d'achat immobilier"
  exits: [mortgage.route.hypotheque, home.route.dashboard]
  invariants:
    max_depth: 4
    back_never_loses_input: true
    every_scene_has_exit: true
nodes:
  - id: db.route.revenu
    kind: route
    route: /data-block/:type
    widget: screens/onboarding/data_block_enrichment_screen.dart
    entries:
      - {via: deeplink, back: reset_to(home.route.dashboard)}
    states: [content, loading, error.compute]
  - id: home.route.dashboard
    kind: route
    route: /home
    widget: screens/aujourdhui/aujourdhui_screen.dart
    entries:
      - {via: tab, back: exits_app}
    states: [content, loading]
  - id: mortgage.route.hypotheque
    kind: route
    route: /hypotheque
    widget: screens/mortgage/affordability_screen.dart
    entries:
      - {via: flow, back: pop}
    states: [content, partial, loading, error.compute]
edges:
  - id: db.edge.revenu.submit
    from: db.route.revenu
    to: mortgage.route.hypotheque
    trigger: submit
    intent: "Enregistrer mes faits de revenu et voir ma capacité d'achat"
    payload: {}
    transition: push
    back: pop
    analytics: cta_clicked
    a11y_label: mortgageCta
    test_ref: apps/mobile/.maestro/f2_datablock_to_mortgage.yaml
""",
        encoding="utf-8",
    )


def test_interaction_registry_lint_accepts_a_real_flow_and_writes_artifacts(tmp_path: Path) -> None:
    _write_minimal_repo(tmp_path)
    _write_registry(tmp_path)

    assert interaction_registry_lint.check(tmp_path) == [
        "interactions/INDEX.md is missing or stale; run tools/checks/interaction_registry_lint.py --write",
        ".planning/journeys/diagrams/interaction_graph.mmd is missing or stale; run tools/checks/interaction_registry_lint.py --write",
    ]

    interaction_registry_lint.write_generated_artifacts(tmp_path)

    assert interaction_registry_lint.check(tmp_path) == []
    index = (tmp_path / "interactions/INDEX.md").read_text(encoding="utf-8")
    graph = (tmp_path / ".planning/journeys/diagrams/interaction_graph.mmd").read_text(
        encoding="utf-8",
    )
    assert "db.edge.revenu.submit" in index
    assert "db.route.revenu -> mortgage.route.hypotheque" in index
    assert '"db.route.revenu<br/>/data-block/:type"' in graph
    assert '"submit / push"' in graph
    assert 'db_route_revenu -. "back" .-> home_route_dashboard' in graph


def test_interaction_registry_lint_rejects_unknown_route(tmp_path: Path) -> None:
    _write_minimal_repo(tmp_path)
    _write_registry(tmp_path)
    registry = tmp_path / "interactions/revenu_to_mortgage.yaml"
    registry.write_text(
        registry.read_text(encoding="utf-8").replace("/hypotheque", "/missing-route"),
        encoding="utf-8",
    )

    assert "interactions/revenu_to_mortgage.yaml: unknown route /missing-route" in (
        interaction_registry_lint.check(tmp_path)
    )


def test_interaction_registry_lint_rejects_domain_objects_in_extra(tmp_path: Path) -> None:
    _write_minimal_repo(tmp_path)
    _write_registry(tmp_path)
    registry = tmp_path / "interactions/revenu_to_mortgage.yaml"
    registry.write_text(
        registry.read_text(encoding="utf-8").replace(
            "payload: {}",
            "payload:\n      extra: CoachProfile",
        ),
        encoding="utf-8",
    )

    assert (
        "interactions/revenu_to_mortgage.yaml: edge db.edge.revenu.submit payload.extra "
        "must be an id, enum, code, token, or ephemeral selection, not CoachProfile"
    ) in interaction_registry_lint.check(tmp_path)


def test_interaction_registry_lint_allows_result_code_extra(tmp_path: Path) -> None:
    _write_minimal_repo(tmp_path)
    _write_registry(tmp_path)
    registry = tmp_path / "interactions/revenu_to_mortgage.yaml"
    registry.write_text(
        registry.read_text(encoding="utf-8").replace(
            "payload: {}",
            "payload:\n      extra: ResultCode",
        ),
        encoding="utf-8",
    )

    errors = interaction_registry_lint.check(tmp_path)

    assert not any("payload.extra" in error for error in errors)


def test_interaction_registry_lint_rejects_unapproved_extra_type(tmp_path: Path) -> None:
    _write_minimal_repo(tmp_path)
    _write_registry(tmp_path)
    registry = tmp_path / "interactions/revenu_to_mortgage.yaml"
    registry.write_text(
        registry.read_text(encoding="utf-8").replace(
            "payload: {}",
            "payload:\n      extra: MortgageResult",
        ),
        encoding="utf-8",
    )

    assert (
        "interactions/revenu_to_mortgage.yaml: edge db.edge.revenu.submit payload.extra "
        "must be an id, enum, code, token, or ephemeral selection, not MortgageResult"
    ) in interaction_registry_lint.check(tmp_path)


def test_interaction_registry_lint_rejects_dead_end_and_undeclared_exit(tmp_path: Path) -> None:
    _write_minimal_repo(tmp_path)
    _write_registry(tmp_path)
    registry = tmp_path / "interactions/revenu_to_mortgage.yaml"
    registry.write_text(
        registry.read_text(encoding="utf-8").replace(
            "exits: [mortgage.route.hypotheque, home.route.dashboard]",
            "exits: [home.route.dashbord]",
        ),
        encoding="utf-8",
    )

    errors = interaction_registry_lint.check(tmp_path)

    assert "interactions/revenu_to_mortgage.yaml: undeclared exit home.route.dashbord" in errors
    assert "interactions/revenu_to_mortgage.yaml: dead-end node mortgage.route.hypotheque" in errors


def test_interaction_registry_lint_rejects_undeclared_back_target(tmp_path: Path) -> None:
    _write_minimal_repo(tmp_path)
    _write_registry(tmp_path)
    registry = tmp_path / "interactions/revenu_to_mortgage.yaml"
    registry.write_text(
        registry.read_text(encoding="utf-8").replace(
            "reset_to(home.route.dashboard)",
            "reset_to(home.route.dashbord)",
        ),
        encoding="utf-8",
    )

    assert (
        "interactions/revenu_to_mortgage.yaml: node db.route.revenu back target "
        "is undeclared: home.route.dashbord"
    ) in interaction_registry_lint.check(tmp_path)


def test_checked_in_interaction_registry_is_current() -> None:
    assert interaction_registry_lint.check(Path(__file__).resolve().parents[3]) == []
