from __future__ import annotations

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

    (root / "apps/mobile/lib/routes/route_metadata.dart").write_text(
        """
const Map<String, RouteMeta> kRouteRegistry = <String, RouteMeta>{
  '/onb': RouteMeta(path: '/onb', category: RouteCategory.destination, owner: RouteOwner.anonymous, requiresAuth: false),
  '/rente-vs-capital': RouteMeta(path: '/rente-vs-capital', category: RouteCategory.destination, owner: RouteOwner.retraite, requiresAuth: false),
  '/arbitrage/rente-vs-capital': RouteMeta(path: '/arbitrage/rente-vs-capital', category: RouteCategory.alias, owner: RouteOwner.system, requiresAuth: false, description: 'Legacy redirect -> /rente-vs-capital'),
  '/simulator/rente-capital': RouteMeta(path: '/simulator/rente-capital', category: RouteCategory.alias, owner: RouteOwner.system, requiresAuth: false, description: 'Legacy redirect -> /rente-vs-capital'),
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
  ScopedGoRoute(path: '/rente-vs-capital', scope: RouteScope.onboarding, builder: (_, __) => Screen()),
  ScopedGoRoute(path: '/arbitrage/rente-vs-capital', scope: RouteScope.onboarding, redirect: (_, __) => '/rente-vs-capital'),
  ScopedGoRoute(path: '/simulator/rente-capital', scope: RouteScope.onboarding, redirect: (_, __) => '/rente-vs-capital'),
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
""",
        encoding="utf-8",
    )


def test_navigation_spine_guard_passes_for_coherent_fixture(tmp_path: Path) -> None:
    _write_fixture(tmp_path)

    assert mint2_navigation_spine_guard.check(tmp_path) == []
    proc = _run(tmp_path)

    assert proc.returncode == 0
    assert "OK mint2_navigation_spine_guard" in proc.stdout


def test_navigation_spine_guard_fails_when_rvc_requires_auth(tmp_path: Path) -> None:
    _write_fixture(tmp_path)
    metadata = tmp_path / "apps/mobile/lib/routes/route_metadata.dart"
    metadata.write_text(
        metadata.read_text(encoding="utf-8").replace(
            "'/rente-vs-capital', category: RouteCategory.destination, owner: RouteOwner.retraite, requiresAuth: false",
            "'/rente-vs-capital', category: RouteCategory.destination, owner: RouteOwner.retraite, requiresAuth: true",
        ),
        encoding="utf-8",
    )

    errors = mint2_navigation_spine_guard.check(tmp_path)

    assert any("/rente-vs-capital must not require auth" in error for error in errors)


def test_navigation_spine_guard_fails_when_live_alias_targets_account_gate(
    tmp_path: Path,
) -> None:
    _write_fixture(tmp_path)
    app = tmp_path / "apps/mobile/lib/app.dart"
    app.write_text(
        app.read_text(encoding="utf-8").replace(
            "ScopedGoRoute(path: '/arbitrage/rente-vs-capital', scope: RouteScope.onboarding, redirect: (_, __) => '/rente-vs-capital')",
            "ScopedGoRoute(path: '/arbitrage/rente-vs-capital', scope: RouteScope.onboarding, redirect: (_, __) => '/auth/register')",
        ),
        encoding="utf-8",
    )

    errors = mint2_navigation_spine_guard.check(tmp_path)

    assert any(
        "/arbitrage/rente-vs-capital app redirect must target /rente-vs-capital"
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
