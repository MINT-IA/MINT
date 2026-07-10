from pathlib import Path

from tools.checks import interaction_coverage_audit


def _write_repo(root: Path) -> None:
    (root / "apps/mobile/lib/routes").mkdir(parents=True)
    (root / "apps/mobile/lib/routes/route_metadata.dart").write_text(
        """
const Map<String, RouteMeta> kRouteRegistry = <String, RouteMeta>{
  '/coach/chat': RouteMeta(path: '/coach/chat'),
  '/data-block/:type': RouteMeta(path: '/data-block/:type'),
  '/documents/:id': RouteMeta(path: '/documents/:id'),
  '/home': RouteMeta(path: '/home'),
  '/hypotheque': RouteMeta(path: '/hypotheque'),
  '/:section/:id': RouteMeta(path: '/:section/:id'),
};
""",
        encoding="utf-8",
    )
    interactions = root / "interactions"
    interactions.mkdir()
    (interactions / "revenu_to_mortgage.yaml").write_text(
        """
schema_version: 1
flow:
  id: revenu_to_mortgage
  title: "Revenue to mortgage"
  exits: [mortgage.route.hypotheque]
nodes:
  - id: db.route.revenu
    kind: route
    route: /data-block/:type
    widget: screens/onboarding/data_block_enrichment_screen.dart
    entries: [{via: deeplink, back: reset_to(home.route.dashboard)}]
    states: [content]
  - id: mortgage.route.hypotheque
    kind: route
    route: /hypotheque
    widget: screens/mortgage/affordability_screen.dart
    entries: [{via: flow, back: pop}]
    states: [content]
edges:
  - id: db.edge.revenu.submit
    from: db.route.revenu
    to: mortgage.route.hypotheque
    trigger: submit
    intent: "See mortgage"
    payload: {}
    transition: push
    back: pop
    test_ref: apps/mobile/.maestro/f2_datablock_to_mortgage.yaml
""",
        encoding="utf-8",
    )
    (root / "apps/mobile/lib/services/navigation").mkdir(parents=True)
    (root / "apps/mobile/lib/services/navigation/screen_registry.dart").write_text(
        """
final screens = [
  ScreenDefinition(route: '/coach/chat'),
  ScreenDefinition(route: '/home'),
];
""",
        encoding="utf-8",
    )
    (root / "apps/mobile/lib/screens").mkdir(parents=True)
    (root / "apps/mobile/lib/screens/sample_screen.dart").write_text(
        """
void wire(context, doc) {
  context.push('/hypotheque');
  // context.push('/commented');
  context.go('/coach/chat?topic=budget');
  context.push('/missing');
  final item = LinkItem(route: '/documents/${doc.id}'); // context.push('/inline-commented');
  /*
   context.push('/block-commented');
   */
}
""",
        encoding="utf-8",
    )


def test_interaction_coverage_audit_generates_current_report(tmp_path: Path) -> None:
    _write_repo(tmp_path)

    assert interaction_coverage_audit.check(tmp_path) == [
        ".planning/journeys/INTERACTION_COVERAGE_AUDIT.md is missing or stale; run tools/checks/interaction_coverage_audit.py --write",
    ]

    interaction_coverage_audit.write_report(tmp_path)

    assert interaction_coverage_audit.check(tmp_path) == []
    report = (tmp_path / ".planning/journeys/INTERACTION_COVERAGE_AUDIT.md").read_text(
        encoding="utf-8",
    )
    assert "covered by declared edge target | `/hypotheque`" in report
    assert "uncovered literal route | `/coach/chat`" in report
    assert "uncovered literal route | `/documents/:id`" in report
    assert "unknown route literal | `/missing`" in report
    assert "sample_screen.dart:3" in report


def test_interaction_coverage_extracts_query_and_dynamic_route_templates(tmp_path: Path) -> None:
    _write_repo(tmp_path)

    refs = interaction_coverage_audit.extract_references(tmp_path)
    by_raw = {ref.raw_route: ref for ref in refs}

    assert by_raw["/coach/chat?topic=budget"].canonical_route == "/coach/chat"
    assert by_raw["/documents/${doc.id}"].canonical_route == "/documents/:id"
    assert "/commented" not in by_raw
    assert "/inline-commented" not in by_raw
    assert "/block-commented" not in by_raw


def test_interaction_coverage_does_not_guess_unanchored_dynamic_routes(tmp_path: Path) -> None:
    _write_repo(tmp_path)
    registry = interaction_coverage_audit._route_registry(tmp_path)

    assert interaction_coverage_audit.canonicalize_route("/$destination", registry) == "/:dynamic"


def test_interaction_coverage_ignores_route_catalogs(tmp_path: Path) -> None:
    _write_repo(tmp_path)

    refs = interaction_coverage_audit.extract_references(tmp_path)
    locations = [ref.location(tmp_path) for ref in refs]

    assert not any("screen_registry.dart" in location for location in locations)


def test_checked_in_interaction_coverage_report_is_current() -> None:
    assert interaction_coverage_audit.check(Path(__file__).resolve().parents[3]) == []
