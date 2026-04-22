# Coding Conventions

**Analysis Date:** 2026-04-22

---

## Dart / Flutter Conventions

### Naming Patterns

**Files:**
- `snake_case.dart` for all Dart files: `coach_profile.dart`, `avs_calculator.dart`, `financial_plan_provider.dart`
- Test files: `snake_case_test.dart` co-located in `apps/mobile/test/` mirroring the `lib/` structure
- Screen files: `*_screen.dart` suffix, e.g. `coach_chat_screen.dart`, `disability_gap_screen.dart`
- Widget files: `*_widget.dart` or descriptive noun: `coach_message_bubble.dart`

**Classes:**
- `PascalCase`: `CoachProfile`, `AvsCalculator`, `MintColors`, `FinancialPlanProvider`
- Enums: `PascalCase` type, `camelCase` values: `enum CoachCivilStatus { celibataire, marie, divorce }`
- Abstract/base classes: descriptive suffix-free: `CoachChatBaseModel`

**Functions and Methods:**
- `camelCase`: `computeMonthlyRente()`, `loadFromPersistence()`, `annualRente()`
- Private helpers: `_stampTimestamps()`, `_persistTimestamps()`, `_makeProfile()`
- Static pure functions in calculator classes: `AvsCalculator.computeMonthlyRente(...)`, `LppCalculator.projectToRetirement(...)`

**Variables:**
- `camelCase`: `currentAge`, `retirementAge`, `lacunes`, `salaireBrutMensuel`
- Field names match French domain language (Swiss finance): `avoirLpp`, `rachatMaximum`, `tauxConversion`
- Boolean flags: `isFatcaResident`, `canContribute3a`, `hasPlan`, `isPlanStale`

**Test helpers:**
- Factory functions prefixed with `_make`: `_makeProfile(...)`, `_makePlan(...)`
- Golden data builders named after persona: `_julienProfile`, `_laurenBase()`

### Code Style

**Formatting:**
- Dart `analysis_options.yaml` governs linting (no external formatter config found)
- `flutter analyze --no-fatal-warnings --no-fatal-infos` — CI fails on errors only
- `// ignore: avoid_print` annotations used in test golden output (acceptable in test context)

**Import Organization:**
```dart
// 1. Dart SDK
import 'dart:math' as math;

// 2. Flutter packages
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

// 3. Third-party packages
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

// 4. Internal packages (all via mint_mobile prefix)
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/financial_core/avs_calculator.dart';
```

**Path Aliases:** All internal imports use `package:mint_mobile/`. No relative imports in lib code.

### i18n — Mandatory Rule

**Every user-facing string MUST use ARB localization:**
```dart
// CORRECT
Text(AppLocalizations.of(context)!.startDiagnostic)

// NEVER
Text('Démarrer mon diagnostic')
```

- 6 ARB files: `apps/mobile/lib/l10n/app_fr.arb`, `app_en.arb`, `app_de.arb`, `app_es.arb`, `app_it.arb`, `app_pt.arb`
- Generated classes: `apps/mobile/lib/l10n/app_localizations.dart` (auto-generated, do not edit)
- Run `flutter gen-l10n` after every ARB change
- CI gate: `readability` job runs Kandel–Moles French readability on `app_fr.arb` (min score 50)
- CI gate: `sentence_subject_arb_lint.py` enforces sentence-subject rules in ARB strings

### Colors — Mandatory Rule

**Every color MUST come from `MintColors`:**
```dart
// CORRECT
color: MintColors.primary
color: MintColors.textSecondary
color: MintColors.success

// NEVER
color: Color(0xFF1D1D1F)
```

- Source: `apps/mobile/lib/theme/colors.dart`
- 12 core semantic tokens + extended premium palette (`porcelaine`, `craie`, `saugeClaire`, `bleuAir`, `ardoise`, `pecheDouce`, `corailDiscret`, `warmWhite`)
- All tokens have WCAG AA contrast ratios baked in (comments show old vs new values)
- CI gate: `tools/checks/wcag_aa_all_touched.py` scans for raw `Color(0xFF...)` in text contexts

### Financial Calculations — Mandatory Rule

**NEVER re-implement calculations. Use `financial_core`:**
```dart
// CORRECT
AvsCalculator.computeMonthlyRente(currentAge: 49, ...)
LppCalculator.projectToRetirement(currentBalance: 70377, ...)
RetirementTaxCalculator.capitalWithdrawalTax(capitalBrut: 677847, ...)

// NEVER
double _calculateAvs(profile) { ... }  // local re-implementation = P0
```

- Source of truth: `apps/mobile/lib/services/financial_core/` (16 files)
- All calculators: pure static functions, deterministic, stateless
- Legal basis annotated in docstrings: `/// LAVS art. 29`, `/// LPP art. 14-16`
- Singleton-guard comment at top of every calculator: `// ALL X calculations MUST use XCalculator from financial_core.`

### Constants

- Swiss legal constants centralized in `apps/mobile/lib/constants/social_insurance.dart`
- Always import constants, never hardcode: `avsRenteMaxMensuelle` not `2520.0`
- Constants sourced from law with comments: `LAVS art. 21-29`, `OPP3 art. 7`

### Comments

**When to Comment:**
- Legal basis references: `/// LAVS art. 29quinquies`, `/// LPP art. 15-16`
- Compliance decisions: `// FIX-111: Removed || delta.abs() < 50 loophole`
- KILL tags for deleted files: `// consent_dashboard_screen.dart DELETED (KILL-03, Phase 2)`
- Section dividers: `// ════════════════════════════════════ SECTION NAME`

**No comments for self-explanatory getters:**
```dart
double get revenuBrutAnnuel {
  final base = salaireBrutMensuel! * nombreDeMois;
  final bonus = (bonusPourcentage ?? 0) / 100 * base;
  return base + bonus;
}
```

---

## Python / Backend Conventions

### Naming Patterns

**Files:**
- `snake_case.py`: `compliance_guard.py`, `rules_engine.py`, `minimal_profile_service.py`
- Test files: `test_<module>.py`: `test_rules_engine.py`, `test_golden_julien_lauren.py`
- Schema files: domain-named: `coach_chat.py`, `profile.py`, `retirement.py`

**Classes:**
- `PascalCase`: `ComplianceGuard`, `TestCompoundInterest`, `TestGoldenJulienLauren`
- Test classes: `Test` prefix: `class TestGoldenJulienLauren:`

**Functions:**
- `snake_case`: `compute_minimal_profile()`, `calculate_compound_interest()`, `_fake_user()`
- Private helpers: `_` prefix: `_check_banned_terms()`, `_check_certain_guarantee()`, `_julien_base()`
- Builder helpers in tests: `_julien_base()`, `_julien_full()`, `_lauren_base()`

**Variables:**
- `snake_case` for Python fields
- Pydantic model fields: `snake_case` in Python, auto-aliased to `camelCase` for API output via `alias_generator=to_camel`

### Pydantic v2 Schema Pattern

```python
from pydantic import BaseModel, ConfigDict, Field
from pydantic.alias_generators import to_camel

class CoachChatBaseModel(BaseModel):
    """Base with camelCase aliases for mobile interop."""
    model_config = ConfigDict(populate_by_name=True, alias_generator=to_camel)

class CoachChatRequest(CoachChatBaseModel):
    message: str = Field(..., min_length=1, max_length=2000)

    @field_validator('message')
    @classmethod
    def validate_message_not_whitespace(cls, v: str) -> str:
        if not v.strip():
            raise ValueError('Le message ne peut pas être vide.')
        return v
```

- All API response schemas inherit a base with `alias_generator=to_camel` and `populate_by_name=True`
- Field constraints declared inline via `Field(ge=0, le=10_000_000)`
- `@field_validator` for business rule validation, not just type coercion

### FastAPI Route Pattern

```python
router = APIRouter()

@router.get("/me", response_model=Profile)
@limiter.limit("30/minute")
def get_my_profile(
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_current_user),
) -> Profile:
    """Docstring: what the endpoint does, special behaviors (FIX notes)."""
    ...
    raise HTTPException(status_code=404, detail="Profile not found")
```

- Rate limiting on every endpoint: `@limiter.limit("30/minute")`
- Auth dependency: `Depends(require_current_user)` for authenticated, `Depends(get_current_user)` for optional
- `HTTPException` for 4xx errors with descriptive `detail` string
- Response model declared on decorator, not inferred

### Error Handling

**Backend:**
- Use `HTTPException` for expected API errors: `raise HTTPException(status_code=404, detail="...")`
- Unreachable states documented: `# Should be unreachable — ...`
- `try/except` in database sessions, always `finally: db.close()`
- Global exception handler wired in `app/main.py`

**Flutter:**
- `?.` and `.firstOrNull` for safe collection access (per 7 code safety patterns)
- `context.read<T>()` before `await` (never inside async gap without guard)
- Provider `dispose()` patterns enforced (no dangling listeners)

### Compliance — LSFin Enforcement

`services/backend/app/services/coach/compliance_guard.py` validates ALL LLM output before display:

**Layer 1 — Banned terms (exact list):**
- `garanti`, `garantie`, `garantis`, `garanties`
- `assuré`, `assurée`, `assurés`, `assurées`
- `optimal`, `optimale`, `optimaux`, `optimales`
- `meilleur`, `meilleure`, `meilleurs`, `meilleures`
- `parfait`, `parfaite`, `parfaits`, `parfaites`
- `tu devrais`, `tu dois`, `il faut que tu`, `la meilleure option`
- `conseiller` → use `spécialiste` instead

**Allowed alternatives:** `pourrait`, `envisager`, `adapté`, `scénario Bas/Moyen/Haut`, `selon ton profil`

**Layer 2** — Prescriptive language detection
**Layer 3** — Hallucination detection (numbers verified against `financial_core`)
**Layer 4** — Auto-injection of LSFin disclaimer for projections
**Layer 5** — Length constraints per component type

### FR Accent Lint

`tools/checks/accent_lint_fr.py` scans `.dart`, `.py`, `.arb`, `.md` for ASCII-flattened French:

| Wrong | Correct |
|-------|---------|
| `creer` | `créer` |
| `decouvrir` | `découvrir` |
| `eclairage` | `éclairage` |
| `securite` | `sécurité` |
| `liberer` | `libérer` |
| `deja` | `déjà` |
| `specialiste` | `spécialiste` |

Exit code 1 = violation. Wire `--file <path>` for per-file lint.

### Logging

**Backend:** Python `logging` module, structured via `app/core/logging_config.py`
```python
logger = logging.getLogger(__name__)
logger.info("...")
logger.error("...")
```
- `send_default_pii=False` in Sentry (nLPD compliance)
- PII log gate in CI: `scripts/check_pii_in_logs.py` scans for IBAN/AVS/phone in logs

**Flutter:** No logging framework found. `print()` used in test golden output only (annotated `// ignore: avoid_print`).

---

## Cross-Stack Contracts

- Dart field names match Python `snake_case` field names before aliasing: `avoirLpp` ↔ `avoirLpp`
- `tools/contracts/voice_cursor.json` → codegen produces `apps/mobile/lib/services/voice/voice_cursor_contract.g.dart` and `services/backend/app/schemas/voice_cursor.py`
- CI `contracts-drift` job regenerates and diffs — any drift blocks the build

---

*Convention analysis: 2026-04-22*
