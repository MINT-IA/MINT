from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

from tools.checks import mint2_navigation_spine_guard

REPO_ROOT = Path(__file__).resolve().parents[3]
SCRIPT = REPO_ROOT / "tools/checks/mint2_navigation_spine_guard.py"


def _run(root: Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, str(SCRIPT), "--root", str(root)],
        capture_output=True,
        text=True,
    )


def _write_fixture(root: Path) -> None:
    (root / "apps/mobile/lib/routes").mkdir(parents=True)
    (root / "tools/simulator/flows/maestro-perfect-set").mkdir(parents=True)
    (root / ".planning/journeys/records").mkdir(parents=True)
    (root / ".planning/journeys/issues").mkdir(parents=True)
    (root / ".planning/journeys/diagrams").mkdir(parents=True)

    (root / "apps/mobile/lib/routes/route_metadata.dart").write_text(
        """
const Map<String, RouteMeta> kRouteRegistry = <String, RouteMeta>{
  '/onb': RouteMeta(path: '/onb', category: RouteCategory.destination, owner: RouteOwner.anonymous, requiresAuth: false),
  '/retraite/rente-vs-capital': RouteMeta(path: '/retraite/rente-vs-capital', category: RouteCategory.destination, owner: RouteOwner.retraite, requiresAuth: false),
  '/rente-vs-capital': RouteMeta(path: '/rente-vs-capital', category: RouteCategory.alias, owner: RouteOwner.system, requiresAuth: false, description: 'Legacy redirect -> /retraite/rente-vs-capital'),
  '/arbitrage/rente-vs-capital': RouteMeta(path: '/arbitrage/rente-vs-capital', category: RouteCategory.alias, owner: RouteOwner.system, requiresAuth: false, description: 'Legacy redirect -> /retraite/rente-vs-capital'),
  '/simulator/rente-capital': RouteMeta(path: '/simulator/rente-capital', category: RouteCategory.alias, owner: RouteOwner.system, requiresAuth: false, description: 'Legacy redirect -> /retraite/rente-vs-capital'),
  '/coach/chat': RouteMeta(path: '/coach/chat', category: RouteCategory.destination, owner: RouteOwner.coach, requiresAuth: false),
  '/start': RouteMeta(path: '/start', category: RouteCategory.alias, owner: RouteOwner.anonymous, requiresAuth: false, description: 'Legacy redirect -> /onb'),
  '/anonymous/chat': RouteMeta(path: '/anonymous/chat', category: RouteCategory.alias, owner: RouteOwner.anonymous, requiresAuth: false, description: 'Legacy redirect -> /onb'),
  '/onboarding/quick': RouteMeta(path: '/onboarding/quick', category: RouteCategory.alias, owner: RouteOwner.system, requiresAuth: false, description: 'Legacy redirect -> /coach/chat'),
  '/onboarding/quick-start': RouteMeta(path: '/onboarding/quick-start', category: RouteCategory.alias, owner: RouteOwner.system, requiresAuth: false, description: 'Legacy redirect -> /coach/chat'),
  '/onboarding/premier-eclairage': RouteMeta(path: '/onboarding/premier-eclairage', category: RouteCategory.alias, owner: RouteOwner.system, requiresAuth: false, description: 'Legacy redirect -> /coach/chat'),
  '/onboarding/intent': RouteMeta(path: '/onboarding/intent', category: RouteCategory.alias, owner: RouteOwner.system, requiresAuth: false, description: 'Legacy redirect -> /coach/chat'),
  '/onboarding/promise': RouteMeta(path: '/onboarding/promise', category: RouteCategory.alias, owner: RouteOwner.system, requiresAuth: false, description: 'Legacy redirect -> /coach/chat'),
  '/onboarding/plan': RouteMeta(path: '/onboarding/plan', category: RouteCategory.alias, owner: RouteOwner.system, requiresAuth: false, description: 'Legacy redirect -> /coach/chat'),
  '/onboarding/smart': RouteMeta(path: '/onboarding/smart', category: RouteCategory.alias, owner: RouteOwner.system, requiresAuth: false, description: 'Legacy redirect -> /coach/chat'),
  '/onboarding/minimal': RouteMeta(path: '/onboarding/minimal', category: RouteCategory.alias, owner: RouteOwner.system, requiresAuth: false, description: 'Legacy redirect -> /coach/chat'),
};
""",
        encoding="utf-8",
    )
    (root / "apps/mobile/lib/app.dart").write_text(
        """
final router = [
  ScopedGoRoute(path: '/onb', scope: RouteScope.public, builder: (_, __) => Screen()),
  ScopedGoRoute(path: '/retraite/rente-vs-capital', scope: RouteScope.onboarding, builder: (_, __) => Screen()),
  ScopedGoRoute(path: '/rente-vs-capital', scope: RouteScope.onboarding, redirect: (_, __) => '/retraite/rente-vs-capital'),
  ScopedGoRoute(path: '/arbitrage/rente-vs-capital', scope: RouteScope.onboarding, redirect: (_, __) => '/retraite/rente-vs-capital'),
  ScopedGoRoute(path: '/simulator/rente-capital', scope: RouteScope.onboarding, redirect: (_, __) => '/retraite/rente-vs-capital'),
  ScopedGoRoute(path: '/coach/chat', scope: RouteScope.public, builder: (_, __) => Screen()),
  ScopedGoRoute(path: '/start', scope: RouteScope.public, redirect: (_, __) => '/onb'),
  ScopedGoRoute(path: '/anonymous/chat', scope: RouteScope.public, redirect: (_, __) => '/onb'),
  ScopedGoRoute(path: '/onboarding/quick', scope: RouteScope.onboarding, redirect: (_, __) => '/coach/chat'),
  ScopedGoRoute(path: '/onboarding/quick-start', scope: RouteScope.onboarding, redirect: (_, __) => '/coach/chat'),
  ScopedGoRoute(path: '/onboarding/premier-eclairage', scope: RouteScope.onboarding, redirect: (_, __) => '/coach/chat'),
  ScopedGoRoute(path: '/onboarding/intent', scope: RouteScope.onboarding, redirect: (_, __) => '/coach/chat'),
  ScopedGoRoute(path: '/onboarding/promise', scope: RouteScope.onboarding, redirect: (_, __) => '/coach/chat'),
  ScopedGoRoute(path: '/onboarding/plan', scope: RouteScope.onboarding, redirect: (_, __) => '/coach/chat'),
  ScopedGoRoute(path: '/onboarding/smart', scope: RouteScope.onboarding, redirect: (_, __) => '/coach/chat'),
  ScopedGoRoute(path: '/onboarding/minimal', scope: RouteScope.onboarding, redirect: (_, __) => '/coach/chat'),
];
""",
        encoding="utf-8",
    )
    flow = (
        "tools/simulator/flows/maestro-perfect-set/"
        "flow_mint2_first_experience_rente_capital_entry.yaml"
    )
    register_flow = (
        "tools/simulator/flows/maestro-perfect-set/"
        "flow_jos001_account_lifecycle_seeded_delete.yaml"
    )
    (root / flow).write_text(
        """
appId: ch.mint.app
---
- launchApp:
    clearState: true
- assertVisible:
    id: "mint2-axis-lpp_rente_capital"
- assertVisible:
    id: "rente_vs_capital_screen"
- assertNotVisible:
    text: "Cr\u00e9er ton compte"
""",
        encoding="utf-8",
    )
    (root / register_flow).write_text(
        """
appId: ch.mint.app
---
- extendedWaitUntil:
    visible: "Cr\u00e9er ton compte"
    timeout: 12000
- extendedWaitUntil:
    visible: { id: "auth_register_email_field" }
    timeout: 8000
- assertNotVisible: "Cr\u00e9er avec e-mail"
- tapOn:
    id: "auth_register_email_field"
""",
        encoding="utf-8",
    )
    (root / ".planning/journeys/records/onboarding_first_value.json").write_text(
        json.dumps(
            {
                "schema_version": 1,
                "id": "onboarding_first_value",
                "title": "Onboarding first value",
                "status": "partial",
                "runtime_replay": {
                    "flow": flow,
                    "sets": ["core"],
                    "requires_auth": False,
                    "build_defines": [
                        "MINT_DISABLE_BETA_MODAL=true",
                        "MINT_E2E_MINT2_FIRST_EXPERIENCE=true",
                        "MINT_E2E_PROOF_ANCHORS=true",
                    ],
                },
                "route_paths": [
                    "/onb",
                    "/retraite/rente-vs-capital",
                    "/coach/chat",
                    "/home",
                ],
                "issues": ["JOS-005"],
            }
        ),
        encoding="utf-8",
    )
    (root / ".planning/journeys/issues/JOS-005.json").write_text(
        json.dumps(
            {
                "schema_version": 1,
                "id": "JOS-005",
                "journey_id": "onboarding_first_value",
                "status": "verified",
                "evidence_status": "green",
            }
        ),
        encoding="utf-8",
    )
    (root / ".planning/journeys/diagrams/onboarding_first_value.mmd").write_text(
        """
%% Generated from .planning/journeys/records/onboarding_first_value.json
flowchart TD
  route_onb["/onb"]
  route_retraite_rente_vs_capital["/retraite/rente-vs-capital"]
  route_coach_chat["/coach/chat"]
  route_home["/home"]
  issue_JOS_005["JOS-005 verified/green"]
""",
        encoding="utf-8",
    )
    (
        root / ".planning/journeys/diagrams/onboarding_first_value_sequence.mmd"
    ).write_text(
        f"""
%% Generated from .planning/journeys/records/onboarding_first_value.json
sequenceDiagram
  Journey->>Routes: /onb, /retraite/rente-vs-capital, /coach/chat, /home
  Journey->>Evidence: replay core / no-auth / MINT iPhone 13 mini RvC / {flow}
  Evidence-->>Journey: issues JOS-005
""",
        encoding="utf-8",
    )
    (root / ".planning/journeys/diagrams/route_topology.mmd").write_text(
        """
flowchart LR
  route__onb["/onb<br/>destination/anonymous<br/>public"]
  route__retraite_rente_vs_capital["/retraite/rente-vs-capital<br/>destination/retraite<br/>public"]
  route__rente_vs_capital["/rente-vs-capital<br/>alias/system<br/>public"]
  route__arbitrage_rente_vs_capital["/arbitrage/rente-vs-capital<br/>alias/system<br/>public"]
  route__simulator_rente_capital["/simulator/rente-capital<br/>alias/system<br/>public"]
  route__rente_vs_capital -. redirects .-> route__retraite_rente_vs_capital
  route__arbitrage_rente_vs_capital -. redirects .-> route__retraite_rente_vs_capital
  route__simulator_rente_capital -. redirects .-> route__retraite_rente_vs_capital
""",
        encoding="utf-8",
    )


def test_navigation_spine_guard_passes_for_coherent_fixture(tmp_path: Path) -> None:
    _write_fixture(tmp_path)

    assert mint2_navigation_spine_guard.check(tmp_path) == []
    proc = _run(tmp_path)

    assert proc.returncode == 0
    assert "OK mint2_navigation_spine_guard" in proc.stdout


def test_navigation_spine_guard_passes_for_repo_flow() -> None:
    assert mint2_navigation_spine_guard.check(REPO_ROOT) == []


def test_navigation_spine_guard_fails_when_journey_os_uses_legacy_rvc_alias(
    tmp_path: Path,
) -> None:
    _write_fixture(tmp_path)
    record = tmp_path / ".planning/journeys/records/onboarding_first_value.json"
    data = json.loads(record.read_text(encoding="utf-8"))
    data["route_paths"] = [
        "/onb",
        "/rente-vs-capital",
        "/coach/chat",
        "/home",
    ]
    record.write_text(json.dumps(data), encoding="utf-8")

    errors = mint2_navigation_spine_guard.check(tmp_path)

    assert any(
        "onboarding_first_value route_paths must be" in error for error in errors
    )


def test_navigation_spine_guard_fails_when_journey_os_points_to_wrong_flow(
    tmp_path: Path,
) -> None:
    _write_fixture(tmp_path)
    record = tmp_path / ".planning/journeys/records/onboarding_first_value.json"
    data = json.loads(record.read_text(encoding="utf-8"))
    data["runtime_replay"]["flow"] = (
        "tools/simulator/flows/maestro-perfect-set/legacy_route.yaml"
    )
    record.write_text(json.dumps(data), encoding="utf-8")

    errors = mint2_navigation_spine_guard.check(tmp_path)

    assert any(
        "onboarding_first_value runtime_replay.flow must be" in error
        for error in errors
    )


def test_navigation_spine_guard_fails_when_journey_os_requires_auth(
    tmp_path: Path,
) -> None:
    _write_fixture(tmp_path)
    record = tmp_path / ".planning/journeys/records/onboarding_first_value.json"
    data = json.loads(record.read_text(encoding="utf-8"))
    data["runtime_replay"]["requires_auth"] = True
    record.write_text(json.dumps(data), encoding="utf-8")

    errors = mint2_navigation_spine_guard.check(tmp_path)

    assert any(
        "onboarding_first_value runtime_replay.requires_auth must be false"
        in error
        for error in errors
    )


def test_navigation_spine_guard_fails_when_journey_os_loses_core_set(
    tmp_path: Path,
) -> None:
    _write_fixture(tmp_path)
    record = tmp_path / ".planning/journeys/records/onboarding_first_value.json"
    data = json.loads(record.read_text(encoding="utf-8"))
    data["runtime_replay"]["sets"] = ["top"]
    record.write_text(json.dumps(data), encoding="utf-8")

    errors = mint2_navigation_spine_guard.check(tmp_path)

    assert any(
        "onboarding_first_value runtime_replay.sets must include core" in error
        for error in errors
    )


def test_navigation_spine_guard_fails_when_journey_os_loses_e2e_defines(
    tmp_path: Path,
) -> None:
    _write_fixture(tmp_path)
    record = tmp_path / ".planning/journeys/records/onboarding_first_value.json"
    data = json.loads(record.read_text(encoding="utf-8"))
    data["runtime_replay"]["build_defines"] = ["MINT_DISABLE_BETA_MODAL=true"]
    record.write_text(json.dumps(data), encoding="utf-8")

    errors = mint2_navigation_spine_guard.check(tmp_path)

    assert any(
        "onboarding_first_value runtime_replay.build_defines missing" in error
        for error in errors
    )


def test_navigation_spine_guard_allows_honest_jos005_regression_state(
    tmp_path: Path,
) -> None:
    _write_fixture(tmp_path)
    issue = tmp_path / ".planning/journeys/issues/JOS-005.json"
    data = json.loads(issue.read_text(encoding="utf-8"))
    data["status"] = "regressed"
    data["evidence_status"] = "red"
    issue.write_text(json.dumps(data), encoding="utf-8")

    errors = mint2_navigation_spine_guard.check(tmp_path)

    assert errors == []


def test_navigation_spine_guard_fails_when_jos005_points_elsewhere(
    tmp_path: Path,
) -> None:
    _write_fixture(tmp_path)
    issue = tmp_path / ".planning/journeys/issues/JOS-005.json"
    data = json.loads(issue.read_text(encoding="utf-8"))
    data["journey_id"] = "another_journey"
    issue.write_text(json.dumps(data), encoding="utf-8")

    errors = mint2_navigation_spine_guard.check(tmp_path)

    assert any(
        "JOS-005.json must point to onboarding_first_value" in error
        for error in errors
    )


def test_navigation_spine_guard_fails_when_journey_mermaid_omits_route(
    tmp_path: Path,
) -> None:
    _write_fixture(tmp_path)
    diagram = tmp_path / ".planning/journeys/diagrams/onboarding_first_value.mmd"
    diagram.write_text(
        diagram.read_text(encoding="utf-8").replace(
            'route_retraite_rente_vs_capital["/retraite/rente-vs-capital"]',
            "",
        ),
        encoding="utf-8",
    )

    errors = mint2_navigation_spine_guard.check(tmp_path)

    assert any(
        "onboarding_first_value.mmd must include /retraite/rente-vs-capital"
        in error
        for error in errors
    )


def test_navigation_spine_guard_fails_when_journey_mermaid_promotes_alias(
    tmp_path: Path,
) -> None:
    _write_fixture(tmp_path)
    diagram = tmp_path / ".planning/journeys/diagrams/onboarding_first_value.mmd"
    diagram.write_text(
        diagram.read_text(encoding="utf-8")
        + '\n  route_legacy["/rente-vs-capital"]\n',
        encoding="utf-8",
    )

    errors = mint2_navigation_spine_guard.check(tmp_path)

    assert any(
        "must not promote legacy alias /rente-vs-capital" in error
        for error in errors
    )


def test_navigation_spine_guard_fails_when_rvc_requires_auth(tmp_path: Path) -> None:
    _write_fixture(tmp_path)
    metadata = tmp_path / "apps/mobile/lib/routes/route_metadata.dart"
    metadata.write_text(
        metadata.read_text(encoding="utf-8").replace(
            "'/retraite/rente-vs-capital', category: RouteCategory.destination, owner: RouteOwner.retraite, requiresAuth: false",
            "'/retraite/rente-vs-capital', category: RouteCategory.destination, owner: RouteOwner.retraite, requiresAuth: true",
        ),
        encoding="utf-8",
    )

    errors = mint2_navigation_spine_guard.check(tmp_path)

    assert any(
        "/retraite/rente-vs-capital must not require auth" in error
        for error in errors
    )


def test_navigation_spine_guard_fails_when_live_alias_targets_account_gate(
    tmp_path: Path,
) -> None:
    _write_fixture(tmp_path)
    app = tmp_path / "apps/mobile/lib/app.dart"
    app.write_text(
        app.read_text(encoding="utf-8").replace(
            "ScopedGoRoute(path: '/arbitrage/rente-vs-capital', scope: RouteScope.onboarding, redirect: (_, __) => '/retraite/rente-vs-capital')",
            "ScopedGoRoute(path: '/arbitrage/rente-vs-capital', scope: RouteScope.onboarding, redirect: (_, __) => '/auth/register')",
        ),
        encoding="utf-8",
    )

    errors = mint2_navigation_spine_guard.check(tmp_path)

    assert any(
        "/arbitrage/rente-vs-capital app redirect must target /retraite/rente-vs-capital"
        in error
        for error in errors
    )


def test_navigation_spine_guard_fails_when_maestro_flow_loses_live_route_probe(
    tmp_path: Path,
) -> None:
    _write_fixture(tmp_path)
    flow = (
        tmp_path
        / "tools/simulator/flows/maestro-perfect-set/"
        "flow_mint2_first_experience_rente_capital_entry.yaml"
    )
    flow.write_text(flow.read_text(encoding="utf-8").replace("rente_vs_capital_screen", "account_gate"), encoding="utf-8")

    errors = mint2_navigation_spine_guard.check(tmp_path)

    assert any("must assert rente_vs_capital_screen" in error for error in errors)


def test_navigation_spine_guard_fails_without_account_wall_positive_control(
    tmp_path: Path,
) -> None:
    _write_fixture(tmp_path)
    register_flow = (
        tmp_path
        / "tools/simulator/flows/maestro-perfect-set/"
        "flow_jos001_account_lifecycle_seeded_delete.yaml"
    )
    register_flow.write_text("appId: ch.mint.app\n---\n- launchApp\n", encoding="utf-8")

    errors = mint2_navigation_spine_guard.check(tmp_path)

    assert any("must positively assert" in error for error in errors)


def test_navigation_spine_guard_fails_without_direct_email_entry_control(
    tmp_path: Path,
) -> None:
    _write_fixture(tmp_path)
    register_flow = (
        tmp_path
        / "tools/simulator/flows/maestro-perfect-set/"
        "flow_jos001_account_lifecycle_seeded_delete.yaml"
    )
    register_flow.write_text(
        """
appId: ch.mint.app
---
- extendedWaitUntil:
    visible: "Cr\u00e9er ton compte"
    timeout: 12000
- runFlow:
    when:
      visible: "Cr\u00e9er avec e-mail"
    commands:
      - tapOn: "Cr\u00e9er avec e-mail"
- extendedWaitUntil:
    visible: { id: "auth_register_email_field" }
    timeout: 8000
""",
        encoding="utf-8",
    )

    errors = mint2_navigation_spine_guard.check(tmp_path)

    assert any(
        "must reject the hidden email fallback CTA" in error
        for error in errors
    )


def test_navigation_spine_guard_fails_if_fallback_cta_is_tapped(
    tmp_path: Path,
) -> None:
    _write_fixture(tmp_path)
    register_flow = (
        tmp_path
        / "tools/simulator/flows/maestro-perfect-set/"
        "flow_jos001_account_lifecycle_seeded_delete.yaml"
    )
    register_flow.write_text(
        """
appId: ch.mint.app
---
- extendedWaitUntil:
    visible: "Cr\u00e9er ton compte"
    timeout: 12000
- extendedWaitUntil:
    visible: { id: "auth_register_email_field" }
    timeout: 8000
- tapOn: "Cr\u00e9er avec e-mail"
""",
        encoding="utf-8",
    )

    errors = mint2_navigation_spine_guard.check(tmp_path)

    assert any(
        "must not tap the hidden email fallback CTA" in error
        for error in errors
    )


def test_navigation_spine_guard_fails_if_block_form_fallback_cta_is_tapped(
    tmp_path: Path,
) -> None:
    _write_fixture(tmp_path)
    register_flow = (
        tmp_path
        / "tools/simulator/flows/maestro-perfect-set/"
        "flow_jos001_account_lifecycle_seeded_delete.yaml"
    )
    register_flow.write_text(
        """
appId: ch.mint.app
---
- extendedWaitUntil:
    visible: "Cr\u00e9er ton compte"
    timeout: 12000
- extendedWaitUntil:
    visible: { id: "auth_register_email_field" }
    timeout: 8000
- assertNotVisible: "Cr\u00e9er avec e-mail"
- tapOn:
    text: "Cr\u00e9er avec e-mail"
""",
        encoding="utf-8",
    )

    errors = mint2_navigation_spine_guard.check(tmp_path)

    assert any(
        "must not tap the hidden email fallback CTA" in error
        for error in errors
    )


def test_navigation_spine_guard_fails_if_fallback_cta_is_branch_condition(
    tmp_path: Path,
) -> None:
    _write_fixture(tmp_path)
    register_flow = (
        tmp_path
        / "tools/simulator/flows/maestro-perfect-set/"
        "flow_jos001_account_lifecycle_seeded_delete.yaml"
    )
    register_flow.write_text(
        """
appId: ch.mint.app
---
- extendedWaitUntil:
    visible: "Cr\u00e9er ton compte"
    timeout: 12000
- runFlow:
    when:
      visible: "Cr\u00e9er avec e-mail"
    commands:
      - waitForAnimationToEnd
- extendedWaitUntil:
    visible: { id: "auth_register_email_field" }
    timeout: 8000
- assertNotVisible: "Cr\u00e9er avec e-mail"
- tapOn:
    id: "auth_register_email_field"
""",
        encoding="utf-8",
    )

    errors = mint2_navigation_spine_guard.check(tmp_path)

    assert any(
        "must not branch on hidden email fallback CTA" in error
        for error in errors
    )


def test_navigation_spine_guard_fails_without_direct_email_field_probe(
    tmp_path: Path,
) -> None:
    _write_fixture(tmp_path)
    register_flow = (
        tmp_path
        / "tools/simulator/flows/maestro-perfect-set/"
        "flow_jos001_account_lifecycle_seeded_delete.yaml"
    )
    register_flow.write_text(
        """
appId: ch.mint.app
---
- extendedWaitUntil:
    visible: "Cr\u00e9er ton compte"
    timeout: 12000
- assertNotVisible: "Cr\u00e9er avec e-mail"
""",
        encoding="utf-8",
    )

    errors = mint2_navigation_spine_guard.check(tmp_path)

    assert any(
        "must assert direct register email field visibility" in error
        for error in errors
    )


def test_navigation_spine_guard_fails_without_direct_email_field_tap(
    tmp_path: Path,
) -> None:
    _write_fixture(tmp_path)
    register_flow = (
        tmp_path
        / "tools/simulator/flows/maestro-perfect-set/"
        "flow_jos001_account_lifecycle_seeded_delete.yaml"
    )
    register_flow.write_text(
        """
appId: ch.mint.app
---
- extendedWaitUntil:
    visible: "Cr\u00e9er ton compte"
    timeout: 12000
- extendedWaitUntil:
    visible: { id: "auth_register_email_field" }
    timeout: 8000
- assertNotVisible: "Cr\u00e9er avec e-mail"
""",
        encoding="utf-8",
    )

    errors = mint2_navigation_spine_guard.check(tmp_path)

    assert any(
        "must tap the direct register email field by id" in error
        for error in errors
    )


def test_navigation_spine_guard_fails_when_negative_assert_runs_too_early(
    tmp_path: Path,
) -> None:
    _write_fixture(tmp_path)
    register_flow = (
        tmp_path
        / "tools/simulator/flows/maestro-perfect-set/"
        "flow_jos001_account_lifecycle_seeded_delete.yaml"
    )
    register_flow.write_text(
        """
appId: ch.mint.app
---
- extendedWaitUntil:
    visible: "Cr\u00e9er ton compte"
    timeout: 12000
- assertNotVisible: "Cr\u00e9er avec e-mail"
- extendedWaitUntil:
    visible: { id: "auth_register_email_field" }
    timeout: 8000
""",
        encoding="utf-8",
    )

    errors = mint2_navigation_spine_guard.check(tmp_path)

    assert any(
        "must assert direct email field before rejecting" in error
        for error in errors
    )
