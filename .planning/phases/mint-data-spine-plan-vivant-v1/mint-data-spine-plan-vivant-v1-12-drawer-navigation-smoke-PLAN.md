description: Plan 12 makes the drawer navigation smoke flow self-bootstrapping again after the anonymous landing CTA moved to onboarding.

# Plan 12 — Drawer Navigation Smoke

Goal: make `flow_drawer_navigation_smoke.yaml` deterministic from a cold simulator launch, then use it as the next navigation regression gate before deeper data-spine work.

Context:
- RED run: `bash tools/simulator/maestro_with_watchdog.sh test tools/simulator/flows/maestro-perfect-set/flow_drawer_navigation_smoke.yaml --format junit --output .planning/walker/maestro-flows/drawer-navigation-smoke/plan-12-red/result.xml`
- Failure: `_fragment_cold_launch_to_aujourdhui.yaml` still expects `Continuer sans compte` to route to `/home`.
- Current app behavior is intentionally different: the landing test documents `Continuer sans compte` routing to `/onb` so the FATCA gate runs before financial data capture.

Scope:
- Update the drawer smoke flow bootstrap only.
- Keep app runtime routes unchanged.
- Keep drawer entries, route assertions, and ProfileDrawer implementation unchanged unless the flow exposes a deterministic runtime defect.

Verification:
- `python3 tools/checks/maestro_locator_audit.py`
- `bash tools/simulator/maestro_with_watchdog.sh test tools/simulator/flows/maestro-perfect-set/flow_drawer_navigation_smoke.yaml`
- If YAML-only, no Flutter unit test is required; the Maestro RED/GREEN pair is the regression proof.

Decision rule:
- If the flow reaches `/explore` and fails on a drawer entry, fix that first deterministic drawer/navigation blocker.
- If the flow passes, next GSD step can move back to data-spine/budget architecture rather than navigation bootstrap.
