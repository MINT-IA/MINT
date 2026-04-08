# Testing Patterns

**Analysis Date:** 2026-04-05

## Overview

**Total test count:** ~12,892 (8,137 Flutter + 4,755 backend) — all green as of 2026-04-05.

## Test Framework

**Flutter:**
- Runner: `flutter_test` (built-in)
- No separate test runner config file — uses `analysis_options.yaml` excludes
- Assertion: `expect()` with matchers (`closeTo`, `greaterThan`, `findsOneWidget`, etc.)

**Backend:**
- Runner: `pytest >= 8.0.0` with `pytest-asyncio >= 0.23.0`
- Config: `[tool.pytest.ini_options]` in `services/backend/pyproject.toml`
- Options: `addopts = "-ra -q"`, `testpaths = ["tests"]`
- Coverage: `pytest-cov >= 5.0.0`

**Run Commands:**
```bash
# Flutter (in apps/mobile/)
flutter test                              # Run all tests
flutter test test/services/               # Run one directory
flutter test test/golden/ --concurrency=4 # Specific shard

# Backend (in services/backend/)
python3 -m pytest tests/ -q               # Run all tests
python3 -m pytest tests/test_retirement.py -v  # Single file verbose
python3 -m pytest tests/ -q --cov=app --cov-fail-under=60  # With coverage
```

## Test File Organization

**Flutter — Location:**
- Mirror structure in `apps/mobile/test/` matching `lib/` organization
- Co-located by layer, not co-located with source

**Flutter — Test directories (by test count):**
| Directory | Files | What it covers |
|-----------|-------|----------------|
| `test/services/` | ~199 | Service logic, financial calculators, coach, LLM |
| `test/widgets/` | ~80 | Widget rendering, interaction tests |
| `test/screens/` | ~41 | Screen-level widget tests |
| `test/providers/` | 8 | Provider state management tests |
| `test/models/` | 7 | Model serialization, computed properties |
| `test/simulators/` | 5 | Simulator integration tests |
| `test/domain/` | 3 | Domain logic (budget) |
| `test/b2b/` | 3 | B2B feature tests |
| `test/golden/` | 1 | Golden couple validation (Julien + Lauren) |
| `test/financial_core/` | 1 | Financial core calculator tests |
| `test/auth/` | 1 | Authentication tests |

**Flutter — Naming:**
- `{feature}_test.dart` — e.g., `avs_calculator_test.dart`, `explore_tab_test.dart`
- Subdirectories mirror service structure: `test/services/coach/`, `test/services/financial_core/`

**Backend — Location:**
- Flat structure in `services/backend/tests/` (118 test files)
- Single `conftest.py` for shared fixtures

**Backend — Naming:**
- `test_{feature}.py` — e.g., `test_retirement.py`, `test_compliance_guard.py`, `test_golden_julien_lauren.py`

## Flutter Test Structure

**Unit Test Pattern (calculators/services):**
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/financial_core/avs_calculator.dart';

void main() {
  group('AvsCalculator.computeMonthlyRente', () {
    test('high income full career -> max rente 2520', () {
      final rente = AvsCalculator.computeMonthlyRente(
        currentAge: 45,
        retirementAge: 65,
        grossAnnualSalary: 120000,
      );
      expect(rente, closeTo(avsRenteMaxMensuelle, 1));
    });

    test('expat arrivalAge 35 -> fewer contribution years', () {
      final native = AvsCalculator.computeMonthlyRente(
        currentAge: 45, retirementAge: 65, grossAnnualSalary: 100000,
      );
      final expat = AvsCalculator.computeMonthlyRente(
        currentAge: 45, retirementAge: 65, arrivalAge: 35, grossAnnualSalary: 100000,
      );
      expect(expat, lessThan(native));
      expect(expat / native, closeTo(30 / 44, 0.05));
    });
  });
}
```

**Widget Test Pattern (screens):**
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildWidget() {
    return ChangeNotifierProvider<CoachProfileProvider>(
      create: (_) => CoachProfileProvider(),
      child: const MaterialApp(
        locale: Locale('fr'),
        localizationsDelegates: [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.supportedLocales,
        home: Scaffold(body: MyWidget()),
      ),
    );
  }

  group('MyWidget', () {
    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.pump();
      expect(find.byType(MyWidget), findsOneWidget);
    });
  });
}
```

**Key patterns for widget tests:**
- Always `SharedPreferences.setMockInitialValues({})` in `setUp`
- Wrap in `MaterialApp` with full localization delegates (fr locale)
- Provide required `ChangeNotifierProvider`s
- `await tester.pump()` after `pumpWidget` to settle
- Use `find.byType()`, `find.text()`, `find.byIcon()` for assertions

## Backend Test Structure

**Unit Test Pattern (services):**
```python
import pytest
from app.services.retirement.avs_estimation_service import AvsEstimationService

@pytest.fixture
def avs_service():
    return AvsEstimationService()

class TestAvsEstimation:
    def test_max_rente_full_career(self, avs_service):
        result = avs_service.estimate(salary=120000, contribution_years=44)
        assert result.monthly_rente == pytest.approx(2520, abs=5)
```

**Integration Test Pattern (API endpoints):**
```python
def test_retirement_estimate(client):
    response = client.post("/api/v1/retirement/avs/estimate", json={
        "grossAnnualSalary": 100000,
        "canton": "VD",
        "age": 45,
    })
    assert response.status_code == 200
    data = response.json()
    assert "monthlyRente" in data
    assert data["disclaimer"] is not None
```

**Compliance Test Pattern:**
```python
class TestBannedTerms:
    def test_catches_garanti(self, guard):
        result = guard.validate("Ton rendement est garanti a 3%.")
        assert not result.is_compliant
        assert any("garanti" in v for v in result.violations)
```

**Backend test organization by category:**
- Grouped in `class Test*:` per logical concern
- Fixtures via `@pytest.fixture` (function-scoped by default)
- Module docstrings list test count target, sprint reference, and legal sources

## Backend Fixtures (conftest.py)

**Location:** `services/backend/tests/conftest.py`

**Database Setup:**
- In-memory SQLite with `StaticPool` (shared across connections)
- Session-scoped `setup_test_database` fixture: creates all tables once
- Function-scoped `clean_database` fixture: truncates all tables between tests (ordered by FK dependencies)

**Auth Override:**
- `_fake_user()` returns a `MagicMock` with `id="test-user-id"`, `email="test@mint.ch"`
- All three auth dependencies overridden: `get_db`, `require_current_user`, `get_current_user`

**Test Client:**
```python
@pytest.fixture
def client():
    app.dependency_overrides[get_db] = override_get_db
    app.dependency_overrides[require_current_user] = _fake_user
    app.dependency_overrides[get_current_user] = _fake_user
    with TestClient(app) as test_client:
        yield test_client
    app.dependency_overrides.clear()
```

**Environment:**
- `os.environ["TESTING"] = "1"` set at module level — disables rate limiting
- `DATABASE_URL = "sqlite:///./test.db"` in CI

## Golden Test Couple (Julien + Lauren)

**Purpose:** Validate ALL financial calculators against known expected values from real Swiss financial data.

**Flutter:** `apps/mobile/test/golden/golden_couple_validation_test.dart`
- Calls every `financial_core/` calculator with golden data
- Validates outputs against CLAUDE.md Section 8 expected values
- Covers: AVS, LPP, tax, cross-pillar, couple optimizer, forecaster

**Backend:** `services/backend/tests/test_golden_julien_lauren.py`
- 10 deterministic tests using `MinimalProfileService`
- Helper builders: `_julien_base()`, `_julien_full()`, `_lauren_base()`, `_lauren_full()`
- Tests: base profile (3 inputs), full profile, complementaire vs base LPP, debt impact, replacement ratio

**Golden Data (from CLAUDE.md Section 8):**
| Field | Julien | Lauren |
|-------|--------|--------|
| Age | 49 | 43 |
| Salary | 122,207 CHF | 67,000 CHF |
| Canton | VS | VS |
| Archetype | swiss_native | expat_us (FATCA) |
| LPP capital | 70,377 CHF | 19,620 CHF |
| 3a capital | 32,000 CHF | 14,000 CHF |

**Multi-domain coverage:** tax, housing (EPL), 3a, LPP, couple dynamics, archetype differences.

## Mocking

**Flutter:**
- `SharedPreferences.setMockInitialValues({})` for local storage
- Provider injection via `ChangeNotifierProvider` in test widget tree
- No external mocking framework — test doubles created manually
- Financial core calculators are pure static functions (no mocking needed, test directly)

**Backend:**
- `unittest.mock.MagicMock` for auth user
- FastAPI `dependency_overrides` for database and auth injection
- `TESTING=1` environment flag to disable rate limiting and external services
- Pure service functions tested directly without mocking (preferred pattern)

**What to Mock:**
- External API calls (Anthropic, Sentry)
- Database connections (overridden via `conftest.py`)
- Authentication (overridden with fake user)
- SharedPreferences (mock initial values)

**What NOT to Mock:**
- Financial calculators — test with real inputs and assert real outputs
- Pydantic validation — test with real schemas
- Compliance guard — test with real banned term detection

## Coverage

**CI Requirements:**
- Backend: `--cov-fail-under=60` (60% minimum overall coverage)
- Backend PRs: `diff-cover` at 80% minimum on changed lines
- Flutter: no coverage threshold enforced in CI (implicit via test count)

**View Coverage:**
```bash
# Backend
python3 -m pytest tests/ --cov=app --cov-report=term-missing --cov-report=html

# Flutter (no built-in coverage gate)
flutter test --coverage
```

**Well-Tested Areas:**
- Financial core calculators (`lib/services/financial_core/`) — extensive edge cases
- Compliance guard (25+ adversarial tests)
- Golden couple validation across all calculators
- Service layer logic (199 test files in `test/services/`)
- Backend onboarding minimal profile service

**Under-Tested Areas (from memory):**
- ~120 hardcoded strings in 24 secondary service files (i18n gaps)
- Screen-level tests (41 files for ~65 screen directories)
- Integration tests (only 2 files in `test/integration/`)
- Widget tests lighter than service tests (80 vs 199 files)

## CI Integration

**Pipeline:** GitHub Actions in `.github/workflows/ci.yml`

**Triggers:** Push to `dev`/`staging`/`main` + PRs targeting those branches

**Smart Path Detection:**
- `dorny/paths-filter@v3` detects which paths changed
- Backend jobs run only when `services/backend/**` changed
- Flutter jobs run only when `apps/mobile/**` changed
- On push events, both always run

**Backend CI Job:**
1. Python 3.12 setup with pip cache
2. `pip install ".[dev]" pytest-cov diff-cover`
3. Security audit via `pip-audit`
4. `pytest tests/ -q --tb=short -x --cov=app --cov-fail-under=60`
5. `diff-cover` on PRs (80% minimum on changed lines)
6. OpenAPI contract check (drift detection, auto-commit on main)
7. Alembic migration round-trip: `upgrade head -> downgrade base -> upgrade head`

**Flutter CI Job (3-shard parallel):**
- Sharding strategy splits ~369 test files across 3 parallel runners:
  - `services`: `test/services/` + `test/simulators/` + `test/financial_core/` + `test/domain/` + `test/b2b/` (~200 files)
  - `widgets`: `test/widgets/` + `test/models/` + `test/providers/` (~85 files)
  - `screens`: `test/screens/` + `test/golden/` + `test/auth/` + `test/modules/` (~34 files)
- Flutter 3.27.4 pinned
- `flutter analyze` runs only in services shard (errors-only gate, warnings logged but non-blocking)
- Tests run with `--concurrency=4` within each shard
- Excludes `test/_archive/` (legacy suite)

**CI Gate:**
- Final `ci-gate` job requires both backend and flutter to pass
- Skipped jobs (no relevant changes) count as success
- Concurrency: `ci-${{ github.ref }}` with `cancel-in-progress: true`

## Test Types

**Unit Tests:**
- Primary test type for both Flutter and backend
- Pure function testing: inputs -> expected outputs
- Financial calculators tested with edge cases, boundary values, archetype variations
- Service logic tested in isolation

**Widget Tests (Flutter):**
- Render tests: widget builds without crashing
- Interaction tests: tap, scroll, find text
- Provider integration: verify state propagation
- Always include localization setup

**Integration Tests (Backend):**
- API endpoint tests via `TestClient`
- Full request/response cycle with JSON payloads
- Auth dependency overridden with fake user
- Database operations against in-memory SQLite

**Compliance Tests (Backend):**
- Adversarial inputs testing banned terms, prescriptive language, hallucinations
- 5-layer validation pipeline coverage
- Wording compliance checks against legal requirements

**Golden Tests:**
- Deterministic validation against known reference values
- Golden couple (Julien + Lauren) tests both Flutter and backend
- Cross-calculator consistency checks

**E2E Tests:**
- `test/integration/` directory exists but minimal (2 files)
- `integration_test` SDK dependency declared in `pubspec.yaml`
- Golden screenshot tests in `test/golden_screenshots/` (with failures/ and goldens/ dirs)

## Common Patterns

**Async Testing (Backend):**
```python
import pytest

@pytest.mark.asyncio
async def test_async_service():
    result = await some_async_service()
    assert result is not None
```

**Error Testing (Backend):**
```python
def test_invalid_input_raises(client):
    response = client.post("/api/v1/endpoint", json={"age": -1})
    assert response.status_code == 422  # Pydantic validation error
```

**Comparison Testing (Flutter):**
```dart
test('expat gets less than native', () {
  final native = Calculator.compute(archetype: 'swiss_native');
  final expat = Calculator.compute(archetype: 'expat_eu');
  expect(expat, lessThan(native));
  expect(expat / native, closeTo(expectedRatio, 0.05));
});
```

**Boundary Testing:**
```dart
test('zero income -> zero rente', () {
  final rente = AvsCalculator.computeMonthlyRente(
    currentAge: 45, retirementAge: 65, grossAnnualSalary: 0,
  );
  expect(rente, equals(0.0));
});
```

**Test Documentation Standard:**
- Backend: module docstring with test count, sprint reference, legal sources, run command
- Flutter: group names describe the class/method under test
- Individual test names describe the scenario: `'expat arrivalAge 35 -> fewer contribution years'`

---

*Testing analysis: 2026-04-05*
