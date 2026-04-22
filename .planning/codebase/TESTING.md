# Testing Patterns

**Analysis Date:** 2026-04-22

---

## Flutter / Dart

### Test Framework

**Runner:** `flutter_test` (built-in Flutter testing)
- Version: Flutter 3.41.4 (pinned in CI)
- Config: none beyond `pubspec.yaml`

**Run Commands:**
```bash
cd apps/mobile && flutter test                         # All tests
cd apps/mobile && flutter test test/golden/            # Specific directory
cd apps/mobile && flutter test test/golden/golden_couple_validation_test.dart  # Single file
flutter test --concurrency=4 --reporter compact        # CI mode (4 parallel)
```

**Analyze:**
```bash
cd apps/mobile && flutter analyze --no-fatal-warnings --no-fatal-infos
```

### Test File Organization

**Location:** `apps/mobile/test/` — NOT co-located with source files

**Structure mirrors source tree:**
```
apps/mobile/test/
├── calculators_test.dart          # Root-level (legacy, basic)
├── pillar_3a_calculator_test.dart
├── wizard_test.dart
├── monte_carlo_determinism_test.dart
├── golden/
│   └── golden_couple_validation_test.dart  # Julien+Lauren actuarial audit
├── simulators/
│   ├── rente_vs_capital_test.dart
│   ├── disability_gap_test.dart
│   ├── lpp_buyback_advanced_simulator_test.dart
│   ├── buyback_logic_test.dart
│   └── real_interest_test.dart
├── models/
│   ├── coach_profile_bridge_test.dart
│   ├── financial_plan_test.dart
│   ├── coach_profile_safe_mode_test.dart
│   └── ...
├── providers/
│   ├── financial_plan_provider_test.dart
│   ├── coach_profile_provider_tax_extraction_test.dart
│   └── ...
├── navigation/
│   ├── goroute_health_test.dart
│   └── home_gate_contract_test.dart
├── integration/
│   ├── coach_tool_choreography_test.dart  # facade-sans-cablage guard
│   ├── profile_hydration_test.dart
│   └── sequence_e2e_test.dart
├── auth/
│   └── auth_service_test.dart
├── design_system/
│   └── s0_s5_microtypography_test.dart
└── l10n_regional/
    └── regional_localizations_test.dart
```

**CI sharding (3 parallel runners):**
- `services` shard: `test/services/`, `test/simulators/`, `test/financial_core/`, `test/domain/`, `test/b2b/`, root-level `test/*.dart`
- `widgets` shard: `test/widgets/`, `test/models/`, `test/providers/`
- `screens` shard: `test/screens/`, `test/golden/`, `test/auth/`, `test/modules/`, `test/journeys/`, `test/accessibility/`, `test/i18n/`

**Excluded from CI:**
- `test/patrol/` — requires emulator infrastructure
- `test/golden_screenshots/` — pixel diffs are cross-platform fragile (macOS baselines drift on Linux)
- `test/_archive/` — legacy suite

### Test Structure

**Standard pattern:**
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/financial_core/avs_calculator.dart';

// Helper factories at top of file (outside test functions)
CoachProfile _makeProfile({double salary = 10000.0, String canton = 'VS'}) {
  return CoachProfile(
    birthYear: 1977,
    canton: canton,
    salaireBrutMensuel: salary,
    goalA: GoalA(type: GoalAType.achatImmo, ...),
  );
}

void main() {
  group('FinancialPlanProvider', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Test 7: hasPlan is false initially', () {
      final provider = FinancialPlanProvider();
      expect(provider.hasPlan, isFalse);
      expect(provider.currentPlan, isNull);
    });
  });
}
```

**Patterns:**
- `group()` to namespace related tests — often prefixed with class/feature name
- `setUp()` for shared initialization, used for `SharedPreferences.setMockInitialValues({})`
- Test names numbered (`Test 7:`, `Test 8:`) in provider tests for traceability
- Private `_make*()` factory functions for test fixture construction

### Mocking (Flutter)

**SharedPreferences:**
```dart
setUp(() {
  SharedPreferences.setMockInitialValues({});
});
```

**GoRouter stub for widget tests:**
```dart
final router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (_, __) => Scaffold(body: child)),
    GoRoute(path: '/documents', builder: (_, __) => const Scaffold()),
  ],
);
```

**Provider injection in widget tests:**
```dart
Widget _wrap({required Widget child, CoachProfileProvider? coachProvider}) {
  final coach = coachProvider ?? CoachProfileProvider();
  return MultiProvider(
    providers: [ChangeNotifierProvider.value(value: coach)],
    child: MaterialApp.router(routerConfig: router, ...),
  );
}
```

**Integration test coaches (facade-sans-cablage guard):**
- `apps/mobile/test/integration/coach_tool_choreography_test.dart` proves all 4 coach tools render real widgets (not `SizedBox.shrink`) end-to-end
- Pattern: `RagToolCall → ChatMessage(richToolCalls) → CoachMessageBubble → WidgetRenderer → finder`

### Golden Couple Fixture (Dart)

**File:** `apps/mobile/test/golden/golden_couple_validation_test.dart`

Julien + Lauren reference data (CLAUDE.md §8):
```dart
// Julien: born 1977 (age 49), CHF 122'207/an, VS, swiss_native, CPE Plan Maxi
// Lauren: born 1982 (age 43), CHF 67'000/an, VS, expat_us (FATCA)
```

**Pattern — actuarial audit:**
```dart
test('1a. AVS Julien — individual monthly rente', () {
  final rente = AvsCalculator.computeMonthlyRente(
    currentAge: 49,
    retirementAge: 65,
    lacunes: 0,
    grossAnnualSalary: 122207,
  );
  const expected = 2520.0;
  expect(rente, closeTo(expected, 300));
});
```

**Tolerance pattern:** `closeTo(expected, toleranceAbs)` or `closeTo(expected, expected * 0.10)` for percentage-based
**Verbose output:** `print()` with `// ignore: avoid_print` to log computed vs expected for every assertion
**SUMMARY test:** Last test in golden file prints a full audit table — always include when adding golden tests

### Persona-Named Tests

**Pattern used in simulators:**
```dart
test('Marc: ZH single, 200k+300k, surob 5%, age 65', () {
  final r = computeRenteVsCapital(avoirObligatoire: 200000, ...);
  expect(r.renteAnnuelle, closeTo(28600, 1));
  expect(r.impotRetrait, closeTo(39325, 1));
});

test('Sophie: VD married, 150k+100k, surob 4.5%, age 64', () { ... });
```

Use exact CHF values in test names (not vague descriptions) for auditability.

---

## Python / Backend

### Test Framework

**Runner:** `pytest` 8.0+
- Config: `services/backend/pytest.ini` → `asyncio_mode = auto`
- Config: `services/backend/pyproject.toml` → `[project.optional-dependencies] dev = ["pytest>=8.0.0", "pytest-asyncio>=0.23.0", "pytest-cov>=5.0.0"]`

**Run Commands:**
```bash
cd services/backend && python3 -m pytest tests/ -q               # All tests, quiet
cd services/backend && python -m pytest tests/ -q --tb=short -x  # Fail-fast
cd services/backend && python -m pytest tests/ --cov=app --cov-report=term-missing --cov-fail-under=60
cd services/backend && python3 -m pytest tests/test_golden_julien_lauren.py -v  # Specific
```

**Coverage thresholds:**
- Overall: `--cov-fail-under=60` (CI gate)
- Changed lines (PRs): `diff-cover --fail-under=80` (CI gate, only on PRs)

### Test File Organization

**Location:** `services/backend/tests/` — separate from source

```
services/backend/tests/
├── conftest.py                        # Shared fixtures, DB setup, auth override
├── test_rules_engine.py               # Pure calculation tests
├── test_golden_julien_lauren.py       # Golden couple validation
├── test_coach_chat_endpoint.py        # API endpoint tests
├── test_compliance_guard.py (in services/compliance/)
├── test_structured_reasoning.py
├── test_enhanced_confidence.py
├── test_personas_integration.py
├── test_e2e_coach_pipeline.py
├── privacy/
│   ├── test_save_fact_pii_redaction.py
│   └── test_coerce_fact_value_range.py
└── tools/
    └── test_krippendorff_alpha.py
```

### conftest.py Pattern

**`services/backend/tests/conftest.py`** — shared fixtures:

```python
# In-memory SQLite with StaticPool (same connection across test threads)
engine = create_engine("sqlite:///:memory:", connect_args={"check_same_thread": False}, poolclass=StaticPool)

@pytest.fixture(scope="session", autouse=True)
def setup_test_database():
    """Create all tables once per session."""
    Base.metadata.create_all(bind=engine)
    yield
    Base.metadata.drop_all(bind=engine)

@pytest.fixture(scope="function", autouse=True)
def clean_database():
    """Truncate all tables before each test (order matters for FK constraints)."""
    db = TestingSessionLocal()
    try:
        db.query(ScenarioModel).delete()
        # ... all models in FK-safe order
        db.commit()
    finally:
        db.close()

@pytest.fixture
def client():
    """TestClient with auth + DB overrides."""
    app.dependency_overrides[get_db] = override_get_db
    app.dependency_overrides[require_current_user] = _fake_user
    app.dependency_overrides[get_current_user] = _fake_user
    with TestClient(app) as test_client:
        yield test_client
    app.dependency_overrides.clear()
```

### Test Structure

**Class-based grouping (preferred for related tests):**
```python
class TestCompoundInterest:
    """Tests for compound interest calculations."""

    def test_basic_compound_interest(self):
        """Docstring: what this validates and why the numbers are expected."""
        result = calculate_compound_interest(principal=10000, annual_rate=5.0, years=10)
        assert result["finalValue"] > 16000
        assert result["finalValue"] < 16500

    def test_zero_rate(self):
        """Test with zero interest rate — returns sum of contributions."""
        result = calculate_compound_interest(principal=1000, monthly_contribution=100, annual_rate=0, years=5)
        assert result["finalValue"] == 1000 + 100 * 60
        assert result["gains"] == 0
```

**Minimum 10 tests per service file** (per CLAUDE.md §5).

### Golden Couple Fixture (Python)

**File:** `services/backend/tests/test_golden_julien_lauren.py`

Builder pattern for reuse:
```python
def _julien_base() -> MinimalProfileInput:
    """Julien: born 1977, age 49, 122'207 CHF/an, VS (CLAUDE.md §8)."""
    return MinimalProfileInput(age=49, gross_salary=122_207.0, canton="VS")

def _julien_full() -> MinimalProfileInput:
    """Julien with ALL optional fields (CLAUDE.md §8 golden values)."""
    return MinimalProfileInput(
        age=49, gross_salary=122_207.0, canton="VS",
        household_type="couple",
        existing_lpp=70_377.0, lpp_caisse_type="complementaire",
        ...
    )

class TestGoldenJulienLauren:
    def test_julien_base(self):
        result = compute_minimal_profile(_julien_base())
        assert result.projected_avs_monthly > 2000, (
            f"Julien at 100k should get near-max AVS rente, got {result.projected_avs_monthly}"
        )
        assert result.confidence_score == 30.0  # 3 inputs = 30%
        assert len(result.estimated_fields) == 7
```

**Assertion pattern:** Always include an f-string message explaining the expected value source:
```python
assert result.projected_lpp_capital > 200_000, (
    f"Julien with 25 years of contributions should have >200k LPP, "
    f"got {result.projected_lpp_capital}"
)
```

### Mocking (Backend)

**Auth override in conftest:**
```python
def _fake_user():
    user = MagicMock()
    user.id = "test-user-id"
    user.email = "test@mint.ch"
    user.display_name = "Test User"
    return user
```

**LLM/orchestrator mock in endpoint tests:**
```python
@pytest.fixture
def client_with_auth():
    app.dependency_overrides[require_current_user] = _fake_user
    with TestClient(app) as test_client:
        yield test_client
    app.dependency_overrides.clear()

def test_chat_success(client_with_auth):
    with patch("app.api.v1.endpoints.coach_chat.coach_orchestrator.run_async",
               new_callable=AsyncMock) as mock_run:
        mock_run.return_value = _ORCHESTRATOR_OK_RESULT
        resp = client_with_auth.post("/api/v1/coach/chat", json=_VALID_BODY)
        assert resp.status_code == 200
```

**fakeredis for Redis-dependent tests:**
```python
# In pyproject.toml dev deps: "fakeredis>=2.20.0"
```

**TESTING env var:** `os.environ["TESTING"] = "1"` in `conftest.py` disables rate limiting globally.

### Test Fixtures (Constants in Tests)

```python
_VALID_BODY = {
    "message": "Comment puis-je optimiser mon pilier 3a ?",
    "api_key": "sk-test-key-12345",
    "provider": "claude",
}

_ORCHESTRATOR_OK_RESULT = {
    "answer": "Le pilier 3a pourrait te permettre d'economiser jusqu'a 2 000 CHF d'impot.",
    "sources": [{"file": "pilier_3a.md", ...}],
    "disclaimers": ["Outil educatif, ne constitue pas un conseil financier (LSFin)."],
    "tokens_used": 350,
}
```

Module-level constants (not `@pytest.fixture`) for static request/response bodies.

### Async Testing

**Config:** `asyncio_mode = auto` in `pytest.ini` — all async tests run without explicit `@pytest.mark.asyncio`

```python
async def test_async_endpoint(client):
    resp = client.get("/api/v1/profiles/me")
    assert resp.status_code == 200
```

### Error Testing

**HTTP error assertions:**
```python
def test_unauthenticated(client_no_auth):
    resp = client_no_auth.post("/api/v1/coach/chat", json=_VALID_BODY)
    assert resp.status_code == 401

def test_missing_field(client_with_auth):
    resp = client_with_auth.post("/api/v1/coach/chat", json={"provider": "claude"})
    assert resp.status_code == 422  # Pydantic validation error
```

**Compliance violations tested:**
- `services/backend/tests/compliance/` — dedicated compliance test folder
- Tests verify banned terms are caught before reaching user

---

## CI Pipeline — Full Test Gate

**Location:** `.github/workflows/ci.yml`

**Pre-test static gates (backend):**
1. `python3 tools/checks/no_chiffre_choc.py` — no legacy "chiffre choc" token
2. `python3 tools/checks/no_legacy_confidence_render.py`
3. `python3 tools/checks/no_implicit_bloom_strategy.py`
4. `python3 tools/checks/sentence_subject_arb_lint.py`
5. `python3 tools/checks/no_llm_alert.py`
6. `python3 tools/checks/landing_no_numbers.py`
7. `python3 tools/checks/landing_no_financial_core.py`
8. Regional microcopy codegen drift check
9. Alembic migration round-trip: `upgrade head → downgrade base → upgrade head`

**Pre-test static gates (flutter):**
1. `tools/checks/wcag_aa_all_touched.py` — hardcoded color scan
2. Dart `meetsGuideline` AA test: `test/accessibility/wcag_aa_all_touched_test.dart`
3. Flesch–Kincaid readability gate: `dart run tools/checks/flesch_kincaid_fr.dart --min=50`

**Pre-commit hooks (lefthook):**
- `memory-retention-gate`: `python3 tools/checks/memory_retention.py` (HARD gate)
- `map-freshness-hint`: `python3 tools/checks/map_freshness_hint.py {staged_files}` (hint only)

**What Device Walkthroughs Gate (non-automated):**
- No milestone is "production ready" until creator cold-starts on real iPhone
- "Tests green ≠ app functional" — 9326 tests passing did not prevent 4 blocking device bugs

---

## Integration Tests

**Flutter integration tests:**
- `apps/mobile/integration_test/persona_marc_test.dart`
- `apps/mobile/integration_test/persona_lea_test.dart`
- Run via `test_driver/integration_test.dart`
- NOT run in CI (`test/patrol/` excluded) — manual gate policy

**Backend e2e pipeline:**
- `services/backend/tests/test_e2e_coach_pipeline.py` — full coach chain
- `services/backend/tests/test_personas_integration.py` — persona-driven integration

---

*Testing analysis: 2026-04-22*
