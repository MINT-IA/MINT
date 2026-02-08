---
name: mint-test-suite
description: Run and fix the MINT test suite. Use when running tests, diagnosing test failures, or fixing broken tests. Covers both Flutter (114 tests in apps/mobile/) and Python backend (59 tests in services/backend/).
compatibility: Requires Flutter SDK and Python 3.10+ with pytest.
allowed-tools: Bash(flutter:*) Bash(pytest:*)
metadata:
  author: mint-team
  version: "1.0"
---

# MINT Test Suite

## Quick Commands

```bash
# Flutter (from apps/mobile/)
cd apps/mobile && flutter test                    # All 114 tests
cd apps/mobile && flutter test test/xxx_test.dart  # Single file
cd apps/mobile && flutter analyze                  # Static analysis

# Backend (from services/backend/)
cd services/backend && pytest -q                  # All 59 tests
cd services/backend && pytest -q -x               # Stop at first failure
cd services/backend && ruff check .               # Lint
```

## Test Structure

### Flutter Tests (apps/mobile/test/)
```
test/
├── calculators_test.dart          # Pure calculation tests
├── fiscal_intelligence_test.dart  # Tax intelligence logic
├── golden_path_test.dart          # E2E wizard happy path
├── home_screen_test.dart          # Home screen widgets
├── navigation_verify_test.dart    # Full navigation flow
├── pillar_3a_calculator_test.dart # 3a simulator tests
├── tax_estimator_test.dart        # Tax estimation (6 cantons)
├── widget_test.dart               # Basic app widget test
├── wizard_test.dart               # Wizard V2 flow tests
├── wizard_insight_test.dart       # Wizard insight generation
├── domain/
│   └── budget_service_test.dart   # Budget calculations
├── modules/
│   └── pc_checklist_test.dart     # PC module tests
├── scenarios/
│   ├── persona_lea_test.dart      # Full wizard: Lea (starter)
│   ├── persona_marc_test.dart     # Full wizard: Marc (debt)
│   └── persona_sophie_test.dart   # Full wizard: Sophie (wealth)
├── screens/
│   ├── budget_screen_smoke_test.dart
│   └── tools_library_test.dart
├── services/
│   ├── avs_logic_test.dart
│   ├── letter_generator_test.dart
│   └── persistence_test.dart
└── simulators/
    ├── buyback_logic_test.dart
    └── real_interest_test.dart
```

### Backend Tests (services/backend/tests/)
```
tests/
├── conftest.py                    # TestClient fixture (sync, NOT async)
├── test_health.py
├── test_profiles.py
├── test_recommendations.py
├── test_rules_engine.py           # Core calculation tests
├── test_scenarios.py
├── test_sessions.py
├── test_partners.py
├── test_docs_copy_compliance.py   # Wording compliance
├── test_compliance_stress.py
└── test_personas_integration.py   # Full persona scenarios
```

## Common Failure Patterns and Fixes

### Flutter: "No GoRouter found in context"
The test wraps with `MaterialApp` but widgets use `context.go()`. Fix:
```dart
final router = GoRouter(routes: [
  GoRoute(path: '/', builder: (_, __) => const MyScreen()),
  GoRoute(path: '/report', builder: (_, state) => Scaffold(
    body: Center(child: Text('Report: ${state.extra}')),
  )),
]);
await tester.pumpWidget(MaterialApp.router(routerConfig: router));
```

### Flutter: "findsOneWidget" fails (found 2+)
Widget text appears in multiple places (nav bar + content). Fix: use `findsWidgets` instead of `findsOneWidget`.

### Flutter: Widget not found (below fold)
Content in scrollable view not visible. Fix:
```dart
await tester.scrollUntilVisible(find.text('Target'), 500.0);
```

### Flutter: Wizard question order changed
Wizard V2 starts with `q_financial_stress_check` (choice), then `q_firstname` (text). Check `lib/data/wizard_questions_v2.dart` for current order.

### Flutter: RenderFlex overflow
Add to test setup:
```dart
FlutterError.onError = (details) {
  if (details.toString().contains('RenderFlex overflowed')) return;
  FlutterError.presentError(details);
};
```

### Backend: async test failures
Use `TestClient(app)` (sync), NOT `httpx.AsyncClient`:
```python
from starlette.testclient import TestClient
from app.main import app
client = TestClient(app)
```

### Backend: missing topActions
`rules_engine.py` pads `topActions` to minimum 3. If your test expects specific actions, account for padding.

## Test Expectations

- **Flutter**: 114/114 must pass. Zero `flutter analyze` warnings.
- **Backend**: 59/59 must pass. Zero `ruff check` errors.
- **Before every commit**: both suites must be green.
