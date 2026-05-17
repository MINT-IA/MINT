---
phase: wave-1a
plan: 04
type: tdd
wave: 1
depends_on: [wave-1a-00]
files_modified:
  - services/backend/app/services/couple_optimizer/__init__.py
  - services/backend/app/services/couple_optimizer/couple_optimizer.py
  - services/backend/app/models/coach_tools/couple_optimization.py
  - services/backend/app/api/v1/endpoints/coach_chat.py
  - services/backend/tests/test_couple_optimizer.py
  - services/backend/tests/test_coach_tools_couple_optimization.py
autonomous: true
requirements: [WAVE1A-05, WAVE1A-09, WAVE1A-10]
must_haves:
  truths:
    - "Python port of Flutter CoupleOptimizer exists at app.services.couple_optimizer.couple_optimizer mirroring the Dart 4 analyses (LPP buyback / 3a contribution / AVS couple cap LAVS art. 35 / marriage penalty)"
    - "Coach tool get_couple_optimization recomputes server-side from ProfileModel.data when COACH_TOOL_SERVER_SIDE_COUPLE_OPTIMIZATION_ENABLED is True"
    - "Per-analysis numeric parity ±0.01 CHF between Dart (apps/mobile/lib/services/financial_core/couple_optimizer.dart) and Python (services/backend/app/services/couple_optimizer/couple_optimizer.py) on 18 unit-test fixture cases"
    - "FR strings (reason, tradeOff) emitted by the Python port are byte-identical to Dart source strings (copy from couple_optimizer.dart lines 226, 229, 232, 239-240, 261-265, 298-299, 302, 305, 312-313, 415-420)"
    - "When flag OFF, dispatcher falls back to _format_couple_optimization(ctx) byte-identical (lines 2574-2628 of coach_chat.py)"
    - "No re-implementation of generic financial_core math beyond what couple_optimizer.dart already does inline — tax helpers (marginal rate, capital tax, monthly income tax) are mirrored from tax_calculator.dart inline because no Python equivalent exists for RetirementTaxCalculator/FiscalService.estimateTax (verified by grep 2026-05-14)"
  artifacts:
    - path: "services/backend/app/services/couple_optimizer/couple_optimizer.py"
      provides: "CoupleOptimizer.optimize(profile_data) + 4 sub-analysis methods, 1:1 mirror of Dart"
      contains: "class CoupleOptimizer"
      min_lines: 300
    - path: "services/backend/app/models/coach_tools/couple_optimization.py"
      provides: "CoupleOptimizationResponse Pydantic v2 model (camelCase) + 4 nested sub-models"
      contains: "class CoupleOptimizationResponse(BaseModel)"
    - path: "services/backend/tests/test_couple_optimizer.py"
      provides: "≥18 unit tests covering the 4 analyses × 4-5 cases each"
      contains: "def test_"
      min_lines: 250
    - path: "services/backend/app/api/v1/endpoints/coach_chat.py"
      provides: "_compute_couple_optimization sibling at ~line 2574 + flag-gated dispatcher branch at lines 1938-1941"
      contains: "_compute_couple_optimization"
  key_links:
    - from: "services/backend/app/services/couple_optimizer/couple_optimizer.py"
      to: "apps/mobile/lib/services/financial_core/couple_optimizer.dart"
      via: "1:1 port of CoupleOptimizer.optimize + _analyzeLppBuybackOrder + _analyze3aContributionOrder + _analyzeAvsCap + _analyzeMarriagePenalty"
      pattern: "class CoupleOptimizer"
    - from: "services/backend/app/api/v1/endpoints/coach_chat.py"
      to: "services/backend/app/services/couple_optimizer/couple_optimizer.py"
      via: "CoupleOptimizer.optimize(profile.data) call inside _compute_couple_optimization"
      pattern: "CoupleOptimizer.optimize"
    - from: "services/backend/app/api/v1/endpoints/coach_chat.py"
      to: "services/backend/app/core/config.py"
      via: "settings.COACH_TOOL_SERVER_SIDE_COUPLE_OPTIMIZATION_ENABLED flag check"
      pattern: "COACH_TOOL_SERVER_SIDE_COUPLE_OPTIMIZATION_ENABLED"
---

<objective>
Port the Flutter `CoupleOptimizer` (`apps/mobile/lib/services/financial_core/couple_optimizer.dart`, 423 lines, 4 analyses) to Python at `services/backend/app/services/couple_optimizer/couple_optimizer.py`. Per CONTEXT D-02 (option a — port to Python) + RESEARCH §3.

The Dart file analyses:
1. **LPP buyback order** (Dart lines 180-242) — who buys back first? (highest marginal tax rate wins).
2. **3a contribution order** (Dart lines 246-315) — who contributes first? + FATCA check.
3. **AVS couple cap** (Dart lines 319-369) — LAVS art. 35 plafonnement at 150% for married couples.
4. **Marriage penalty** (Dart lines 373-422) — is being married more or less tax-efficient?

The Dart implementation delegates to `RetirementTaxCalculator.estimateTaxSaving` (tax_calculator.dart:390), `RetirementTaxCalculator.estimateMarginalRate` (tax_calculator.dart:316), `RetirementTaxCalculator.estimateMonthlyIncomeTax` (tax_calculator.dart:476 — which itself calls `FiscalService.estimateTax`), and `AvsCalculator.computeMonthlyRente` / `AvsCalculator.computeCouple` / `AvsCalculator.annualRente` (avs_calculator.dart).

**Verified 2026-05-14:** there is **no Python equivalent of `RetirementTaxCalculator` or `FiscalService.estimateTax`** in `services/backend/app/services/` (grep returned zero matches for `estimateTaxSaving`, `estimateMarginalRate`, `estimateMonthlyIncomeTax`, `class FiscalService` under `services/backend/`). The closest Python service is `app.services.fiscal.cantonal_comparator` but its surface does not match the Dart helpers. The `services/backend/app/services/retirement/avs_estimation_service.AvsEstimationService` exists but its `estimate()` signature is DIFFERENT from Dart `AvsCalculator.computeMonthlyRente`. Therefore the Python port MUST mirror the Dart tax/AVS helpers INLINE (with `# MIRROR Dart {file:line}` traceability comments) and MUST NOT call into the existing Python financial services (signature mismatch would create a silent divergence).

Wave 1a D-13 contract: emitted user-facing French strings (`reason`, `tradeOff`) MUST be byte-identical to Dart source (verified via the `accent_lint_fr.py` check on the touched file). The legacy `_format_couple_optimization(ctx)` formatter at `coach_chat.py:2574-2628` reads `couple["lpp_buyback"]["reason"]`, `couple["lpp_buyback"]["trade_off"]`, etc. — same dict shape as Dart's `toJson()` output. The Python port mirrors that shape so the FR strings flow through unchanged.

Purpose: provide server-side ground-truth for couple optimization CHF claims (`savingDelta`, `monthlyReduction`, `annualDelta`), so the coach can no longer hallucinate them from a missing or stale `ctx["couple_optimization"]`.
Output: NEW Python service + ≥18 unit tests + dispatcher path (reads pre-existing flag from plan-00).
</objective>

<execution_context>
@/Users/julienbattaglia/Desktop/MINT.nosync/.claude/get-shit-done/workflows/execute-plan.md
@/Users/julienbattaglia/Desktop/MINT.nosync/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/phases/wave-1a-backend-tools-refactor/wave-1a-CONTEXT.md
@.planning/phases/wave-1a-backend-tools-refactor/wave-1a-RESEARCH.md
@apps/mobile/lib/services/financial_core/couple_optimizer.dart
@apps/mobile/lib/services/financial_core/tax_calculator.dart
@apps/mobile/lib/services/financial_core/avs_calculator.dart
@apps/mobile/lib/models/coach_profile.dart
@apps/mobile/lib/constants/social_insurance.dart
@services/backend/app/api/v1/endpoints/coach_chat.py
@services/backend/app/services/coach/inputs_hash.py
@services/backend/app/models/profile_model.py
@services/backend/app/constants/social_insurance.py
@services/backend/app/services/regulatory/registry.py
@CLAUDE.md

<interfaces>
<!-- Contracts the executor MUST follow. Every symbol below was grep-verified 2026-05-14. -->

== Dart source-of-truth — couple_optimizer.dart ==
File `apps/mobile/lib/services/financial_core/couple_optimizer.dart` (423 lines).

Key types (lines 33-130):
```dart
// line 34
enum CoupleWinner { mainUser, conjoint, noPreference }

// line 37
class CoupleAnalysisResult {
  final CoupleWinner winner;
  final double savingDelta;
  final String reason;
  final String tradeOff;
}

// line 60
class AvsCoupleCapResult {
  final bool capApplied;
  final double monthlyReduction;
  final double userRenteBeforeCap;
  final double conjointRenteBeforeCap;
  final double totalAfterCap;
}

// line 86
class MarriagePenaltyResult {
  final bool hasPenalty;
  final double annualDelta;
  final String tradeOff;
}

// line 104
class CoupleOptimizationResult {
  final CoupleAnalysisResult? lppBuybackOrder;
  final CoupleAnalysisResult? pillar3aOrder;
  final AvsCoupleCapResult? avsCap;
  final MarriagePenaltyResult? marriagePenalty;
}

// line 141
class CoupleOptimizer {
  static const double _minDelta = 100.0;  // line 146
  static CoupleOptimizationResult optimize({CoachProfile mainUser, ConjointProfile? conjoint});  // line 155
}
```

Verbatim FR strings the Python port MUST copy (already grep-verified, all use proper FR accents):
```
couple_optimizer.dart:226  'Taux marginaux similaires — pas de préférence.'
couple_optimizer.dart:229  'Taux marginal plus élevé → économie fiscale supérieure par CHF racheté.'
couple_optimizer.dart:232  'Taux marginal plus élevé → économie fiscale supérieure par CHF racheté.'
couple_optimizer.dart:239  'Le rachat LPP est bloqué 3 ans avant le retrait (LPP art. 79b al. 3). '
couple_optimizer.dart:240  'Le timing dépend aussi de l\'âge de chaque personne.'
couple_optimizer.dart:261  'Le·la conjoint·e est résident·e FATCA — le versement 3a n\'est pas possible pour cette personne.'
couple_optimizer.dart:263  'FATCA (Foreign Account Tax Compliance Act) restreint l\'accès à certains produits 3a pour les résidents US.'
couple_optimizer.dart:298  'Taux marginaux similaires — les deux bénéficient de manière comparable.'
couple_optimizer.dart:302  'Revenu imposable plus élevé → déduction 3a plus avantageuse.'
couple_optimizer.dart:305  'Revenu imposable plus élevé → déduction 3a plus avantageuse.'
couple_optimizer.dart:312  'Le plafond 3a est individuel (CHF ${ceiling.round()}/an). Les deux partenaires peuvent verser chacun le maximum.'
couple_optimizer.dart:415  'Le mariage crée une surcharge fiscale de CHF ${annualDelta.round()}/an dans le canton $canton. Cet écart varie selon les cantons et les niveaux de revenu.'
couple_optimizer.dart:418  'Le mariage crée un avantage fiscal de CHF ${annualDelta.abs().round()}/an dans le canton $canton. Cet avantage est dû au splitting pour les couples mariés.'
```

== Dart tax helpers (port INLINE — no Python equivalent exists) ==

File `apps/mobile/lib/services/financial_core/tax_calculator.dart`:

```dart
// lines 276-284 — effective rates by canton (single, 100k income)
static const Map<String, double> _effectiveRates100k = {
  'ZG': 0.0823, 'NW': 0.0891, 'OW': 0.0934, 'AI': 0.0956,
  'AR': 0.1012, 'SZ': 0.1034, 'UR': 0.1067, 'LU': 0.1089,
  'GL': 0.1102, 'TG': 0.1145, 'SH': 0.1167, 'AG': 0.1189,
  'GR': 0.1203, 'BL': 0.1256, 'SG': 0.1278, 'ZH': 0.1290,
  'FR': 0.1312, 'SO': 0.1334, 'TI': 0.1356, 'BE': 0.1389,
  'NE': 0.1423, 'VS': 0.1456, 'VD': 0.1489, 'JU': 0.1512,
  'GE': 0.1545, 'BS': 0.1578,
};

// lines 290-293 — income adjustment brackets
static const Map<int, double> _incomeAdjustment = {
  50000: 0.75, 80000: 0.90, 100000: 1.00,
  150000: 1.10, 200000: 1.18, 300000: 1.25, 500000: 1.32,
};

// lines 299-305 — family adjustment
static const Map<String, double> _familyAdjustment = {
  'celibataire': 1.00,
  'marie_sans_enfant': 0.85,
  'marie_1_enfant': 0.78,
  'marie_2_enfants': 0.72,
  'marie_3_enfants': 0.66,
};

// lines 316-360 — estimateMarginalRate(income, canton, isMarried, children, actualRate?)
//   Returns marginal rate clamped to [0.05, 0.45] = effectiveRate * 1.3.

// lines 390-419 — estimateTaxSaving(income, deduction, canton, isMarried, children, steps=10)
//   Numerical integration over 10 slices: sum stepSize * estimateMarginalRate(midPoint).

// lines 476-490 — estimateMonthlyIncomeTax(revenuAnnuelImposable, canton, etatCivil, nombreEnfants)
//   Calls FiscalService.estimateTax(...).chargeTotale / 12. The Python port mirrors
//   THIS by approximating chargeTotale = revenu × effectiveRate(income, canton, etatCivil, children).
//   This is a deliberate simplification — the Dart FiscalService.estimateTax does a
//   more nuanced calc, but for parity-on-the-fixture-set we use the same effectiveRate
//   table × income approach. Document the simplification in a # MIRROR Dart comment.
```

File `apps/mobile/lib/services/financial_core/avs_calculator.dart`:

```dart
// line 12 — class AvsCalculator
// line 29 — static double computeMonthlyRente({currentAge, retirementAge, grossAnnualSalary,
//                                              isFemale, birthYear, arrivalAge})
// line 156 — static ({double user, double conjoint, double total}) computeCouple({
//                avsUser, avsConjoint, isMarried})
// line 212 — static double annualRente(double monthlyRente)
```

**Critical:** the existing Python `services/backend/app/services/retirement/avs_estimation_service.AvsEstimationService.estimate()` (verified line 109) has a DIFFERENT signature (`current_age, retirement_age=65, is_couple=False, annees_lacunes=0, life_expectancy=87, gross_salary=0.0`) and a different return shape. The Dart `AvsCalculator.computeMonthlyRente` uses `arrivalAge`, `birthYear`, `isFemale` which the Python service does NOT expose. The port MUST mirror the Dart AVS logic INLINE (do not delegate to AvsEstimationService — signatures incompatible, parity would silently drift).

== Profile fields the port reads (from CoachProfile JSON via toJson()) ==

Confirmed in `apps/mobile/lib/models/coach_profile.dart`:
- `salaireBrutMensuel: double?` (line 125)
- `nombreDeMois: double` (line 126, default 12.0)
- `etatCivil: CoachCivilStatus` (line 1403; serialized as string `"celibataire"|"marie"|"divorce"|"veuf"|"concubinage"` per enum at line 25)
- `birthYear: int?` (line 122)
- `gender: String?` ('M', 'F', or null — line 124)
- `nombreEnfants: int` (verify via grep `nombreEnfants` in coach_profile.dart; field exists per line 1697)
- `canton: String`
- `prevoyance: PrevoyanceProfile?` (line 133) — exposes `lacuneRachatRestante` (line 419 in coach_profile.dart)
- `conjoint: ConjointProfile?` — sub-fields confirmed lines 121-159 (gender, birthYear, salaireBrutMensuel, nombreDeMois, employmentStatus, nationality, isFatcaResident, canContribute3a, prevoyance, canton, nombreEnfants, arrivalAge, targetRetirementAge, invitationLevel)
- `ConjointProfile.revenuBrutAnnuel: double` (getter, line 183)
- `ConjointProfile.age: int?` (getter, line 192)
- `ConjointProfile.effectiveRetirementAge: int` (getter, line 209)

The Python port reads `profile_data` (which is `ProfileModel.data`, a JSON dict using CoachProfile `toJson()` keys verbatim). camelCase keys. The conjoint sub-dict is at `profile_data["conjoint"]` (verify the actual key during executor `read_first`; if Flutter top-level uses `conjoint` literally, mirror it).

== Legacy formatter (byte-identity target for FR strings flowing through) ==

File `services/backend/app/api/v1/endpoints/coach_chat.py` lines 2574-2628:
```python
def _format_couple_optimization(ctx: dict) -> str:
    couple = ctx.get("couple_optimization")
    if not couple or not isinstance(couple, dict):
        is_couple = ctx.get("civil_status") in ("marie", "concubinage")
        if not is_couple:
            return "L'utilisateur n'est pas en couple — analyse couple non applicable."
        return (
            "Données couple non disponibles. L'utilisateur est en couple mais "
            "les données du conjoint ne sont pas renseignées. "
            "Propose d'ajouter le profil du conjoint pour une analyse couple."
        )

    lines = ["Optimisation couple :"]
    lpp = couple.get("lpp_buyback")
    if lpp:
        winner = lpp.get("winner", "?")
        delta = lpp.get("saving_delta", 0)
        reason = lpp.get("reason", "")
        lines.append(f"- Rachat LPP : {winner} en premier ({reason})")
        if delta > 0:
            lines.append(f"  Économie différentielle : {_fmt_chf(delta)}")
        lines.append(f"  Note : {lpp.get('trade_off', '')}")

    p3a = couple.get("pillar_3a")
    if p3a:
        winner = p3a.get("winner", "?")
        reason = p3a.get("reason", "")
        lines.append(f"- 3a : {winner} en premier ({reason})")
        lines.append(f"  Note : {p3a.get('trade_off', '')}")

    avs = couple.get("avs_cap")
    if avs:
        if avs.get("cap_applied"):
            reduction = avs.get("monthly_reduction", 0)
            lines.append("- AVS couple : plafonnement appliqué (LAVS art. 35)")
            lines.append(f"  Réduction mensuelle : {_fmt_chf(reduction)}")
        else:
            lines.append("- AVS couple : pas de plafonnement (revenus sous le seuil)")

    mp = couple.get("marriage_penalty")
    if mp:
        delta = mp.get("annual_delta", 0)
        if mp.get("has_penalty"):
            lines.append(f"- Pénalité mariage : {_fmt_chf(abs(delta))}/an de surcharge")
        else:
            lines.append(f"- Bonus mariage : {_fmt_chf(abs(delta))}/an d'avantage")

    return "\n".join(lines)
```

The legacy reads dict keys `lpp_buyback`, `pillar_3a`, `avs_cap`, `marriage_penalty`, with sub-keys `winner` (snake_case string), `saving_delta`, `reason`, `trade_off`, `cap_applied`, `monthly_reduction`, `has_penalty`, `annual_delta`. The Python port's `to_legacy_dict()` method must produce a dict with these exact keys so that — in the future — a contracted-on-the-fly translation from server JSON to legacy formatter input remains possible (used by the parity test in plan-07).

== Dispatcher marker pair (REPLACE inside markers shipped by plan-00) ==

File `services/backend/app/api/v1/endpoints/coach_chat.py` lines 1938-1941 (verified 2026-05-14):
```python
    # >>> dispatch: get_couple_optimization
    if name == "get_couple_optimization":
        return _format_couple_optimization(ctx)
    # <<< dispatch: get_couple_optimization
```

Replace WITH (markers preserved verbatim):
```python
    # >>> dispatch: get_couple_optimization
    if name == "get_couple_optimization":
        return _compute_couple_optimization(user_id=user_id, ctx=ctx, db=db)
    # <<< dispatch: get_couple_optimization
```

== Pre-existing scaffolding (DO NOT redeclare) ==

Confirmed in place 2026-05-14:
- `services/backend/app/core/config.py:100` — `COACH_TOOL_SERVER_SIDE_COUPLE_OPTIMIZATION_ENABLED: bool = False`
- `services/backend/app/services/couple_optimizer/__init__.py` — empty package marker (plan-00)
- `services/backend/app/models/coach_tools/__init__.py` — empty package marker (plan-00)
- `services/backend/app/observability/coach_breadcrumbs.py:26` — `def emit_coach_tool_breadcrumb(tool_name, inputs_hash, profile_id_hashed, elapsed_ms, flag_state)`
- `services/backend/app/utils/hashing.py:12` — `def hash_profile_id(profile_id) -> str` (16-char hex)
- `services/backend/app/services/coach/inputs_hash.py:58` — `def compute_inputs_hash(inputs: dict) -> str` (64-char hex)
- `services/backend/app/api/v1/endpoints/coach_chat.py:1834` — `_execute_internal_tool(tool_call, memory_block, profile_context, user_id, db, ...)` (uses `user_id`, NOT `profile_id`)

== Pattern reference (post-rewrite shipped plan-02 + plan-01) ==

The shipped `_compute_retirement_projection` and `_compute_budget_status` already use this pattern. The plan-04 executor should read those two functions in `coach_chat.py` (lines 2286-2388 and 2390-2470) to mirror the structure: flag check → user_id+db check → try block → DB query (newest profile wins) → service call → Pydantic response → breadcrumb → JSON dump. Any deviation (e.g. catching `ValueError` only instead of broad `Exception`) is a regression of the python-pro panel fix.

</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Port Flutter CoupleOptimizer to Python (300+ lines) + Pydantic response model + ≥18 unit tests</name>
  <read_first>
    - apps/mobile/lib/services/financial_core/couple_optimizer.dart (FULL 423 lines — this IS the source of truth being ported)
    - apps/mobile/lib/services/financial_core/tax_calculator.dart lines 200-491 (RetirementTaxCalculator class — must be mirrored INLINE per the interfaces block)
    - apps/mobile/lib/services/financial_core/avs_calculator.dart (FULL — AvsCalculator class, methods computeMonthlyRente / computeCouple / annualRente)
    - apps/mobile/lib/models/coach_profile.dart lines 25 (CoachCivilStatus enum) + 120-209 (ConjointProfile class with getters revenuBrutAnnuel / age / effectiveRetirementAge) + 1400-1700 (CoachProfile etatCivil / nombreEnfants / prevoyance)
    - apps/mobile/lib/constants/social_insurance.dart (find `pilier3aPlafondAvecLpp` constant — should be 7258.0)
    - services/backend/app/api/v1/endpoints/coach_chat.py lines 2574-2628 (legacy formatter — byte-identity reference for FR strings flowing through and dict shape contract)
    - services/backend/app/api/v1/endpoints/coach_chat.py lines 2286-2388 (shipped _compute_budget_status — pattern reference for dispatcher) and lines 2390-2470 (shipped _compute_retirement_projection — same pattern)
    - services/backend/app/services/coach/inputs_hash.py (compute_inputs_hash signature)
    - services/backend/app/services/couple_optimizer/__init__.py (plan-00 marker — currently empty)
    - services/backend/app/models/coach_tools/__init__.py (plan-00 marker — currently empty)
    - services/backend/app/observability/coach_breadcrumbs.py (emit_coach_tool_breadcrumb signature)
    - services/backend/app/constants/social_insurance.py (PILIER_3A_PLAFOND_AVEC_LPP constant)
    - services/backend/tests/conftest.py (pytest DB session fixture pattern — sqlite in-memory, autoflush=False)
    - services/backend/tests/test_coach_tools_retirement_projection.py (shipped plan-02 test layout reference)
  </read_first>
  <files>
    - services/backend/app/services/couple_optimizer/__init__.py (modify — add re-exports)
    - services/backend/app/services/couple_optimizer/couple_optimizer.py (create, ≥300 lines mirroring Dart)
    - services/backend/tests/test_couple_optimizer.py (create, ≥18 tests)
    - services/backend/app/models/coach_tools/couple_optimization.py (create — Pydantic models)
  </files>
  <behavior>
    Test counts per analysis (TDD RED-GREEN cycles):
    - LPP buyback order (4 tests):
      - (a) user higher marginal rate → winner=MAIN_USER, saving_delta>=100 CHF, reason byte-identical to Dart line 229.
      - (b) conjoint higher rate → winner=CONJOINT, saving_delta>=100 CHF, reason byte-identical to Dart line 232.
      - (c) abs(delta)<100 CHF → winner=NO_PREFERENCE, reason byte-identical to Dart line 226.
      - (d) both rachat=0 → returns None.
    - 3a contribution order (4 tests):
      - (a) user higher marginal rate → winner=MAIN_USER.
      - (b) conjoint higher → winner=CONJOINT.
      - (c) conjoint canContribute3a=False (FATCA) → winner=MAIN_USER, saving_delta=0, reason byte-identical to Dart line 261-262 (« Le·la conjoint·e est résident·e FATCA … »), tradeOff byte-identical to Dart line 263-264.
      - (d) both incomes 0 → returns None.
    - AVS couple cap (4 tests):
      - (a) married + combined rente > 150% AVS max → cap_applied=True, monthly_reduction>0.
      - (b) married + combined ≤ 150% → cap_applied=False, monthly_reduction=0.
      - (c) conjoint.age is None → returns None.
      - (d) not married (CoachCivilStatus.celibataire) → returns None (cap applies only to marriage per LAVS art. 35).
    - Marriage penalty (4 tests):
      - (a) double-income high in BE canton → has_penalty=True, annual_delta>0, tradeOff format Dart lines 415-417.
      - (b) single-income → annual_delta near 0 or negative, has_penalty=False, tradeOff format Dart lines 418-420.
      - (c) edge: both incomes 0 → returns None.
      - (d) tradeOff contains the canton ISO code (e.g. "VS") byte-identical with Dart line 416/419.
    - Integration tests (2 tests):
      - (a) `optimize()` with full Julien-profile (CoachProfile + ConjointProfile dicts) returns `CoupleOptimizationResult` with all 4 sub-results non-None.
      - (b) `optimize()` with no conjoint → returns `CoupleOptimizationResult.empty()` (all 4 sub-fields None).
    - **Total: 18 unit tests (4×4 + 2 = 18).**
    - Test 19 (Pydantic shape): `CoupleOptimizationResponse(...).model_dump(by_alias=True)` produces camelCase keys (`lppBuyback.savingDelta`, `pillar3a.tradeOff`, `avsCap.capApplied`, `marriagePenalty.hasPenalty`, `inputsHash`, `computedAt`).
    - Test 20 (FR-string accent integrity): assert that the `reason` returned by Test 1a contains the precise accented characters `é` and `→` (proves Python source preserves Dart accents byte-identically).
  </behavior>
  <action>
    Step A — Read `apps/mobile/lib/services/financial_core/couple_optimizer.dart` IN FULL. Note every method signature, every constant referenced, every FR string emitted in `reason` / `tradeOff` fields. The Python port copies these strings verbatim (per Wave 1a D-13 + CLAUDE.md rule 1 banned-terms LSFin compliance).

    Step B — Modify `services/backend/app/services/couple_optimizer/__init__.py` (plan-00 left it as a docstring-only marker). Append re-exports:
    ```python
    """Wave 1a D-02 — Python port of Flutter CoupleOptimizer.

    Plan-00 shipped this package as an empty marker; plan-04 fills it.
    """
    from app.services.couple_optimizer.couple_optimizer import (
        CoupleOptimizer,
        CoupleOptimizationResult,
        CoupleAnalysisResult,
        AvsCoupleCapResult,
        MarriagePenaltyResult,
        CoupleWinner,
    )

    __all__ = [
        "CoupleOptimizer",
        "CoupleOptimizationResult",
        "CoupleAnalysisResult",
        "AvsCoupleCapResult",
        "MarriagePenaltyResult",
        "CoupleWinner",
    ]
    ```

    Step C — Create `services/backend/app/services/couple_optimizer/couple_optimizer.py` (≥300 lines).
    Structure:

    1. **Module docstring** stating: « Wave 1a D-02 — 1:1 port of `apps/mobile/lib/services/financial_core/couple_optimizer.dart`. All FR strings copied verbatim. Tax helpers mirrored INLINE because no Python equivalent of RetirementTaxCalculator / FiscalService.estimateTax exists (verified by grep 2026-05-14). Every non-trivial branch carries a `# MIRROR Dart <file>:<line>` traceability comment. »

    2. **Enums and dataclasses** mirroring Dart lines 33-130:
       ```python
       class CoupleWinner(str, Enum):
           MAIN_USER = "main_user"      # mirror Dart CoupleWinner.mainUser; legacy formatter at coach_chat.py:2596 receives this string
           CONJOINT = "conjoint"        # mirror Dart CoupleWinner.conjoint
           NO_PREFERENCE = "no_preference"  # mirror Dart CoupleWinner.noPreference
       ```
       NOTE on enum string values: the legacy formatter at `coach_chat.py:2596` interpolates `winner` directly into the FR sentence (`f"- Rachat LPP : {winner} en premier ({reason})"`). The Dart serialisation likely produces a similar literal. Verify what string the Dart `CoupleAnalysisResult.toJson()` emits for the enum (read `apps/mobile/lib/models/coach_profile.dart` if CoupleAnalysisResult has a toJson, else assume Dart enum default `.name` → `mainUser` / `conjoint` / `noPreference`). If Dart emits camelCase enum names, mirror that EXACTLY (override the Python enum value to `"mainUser"` etc.). **The executor MUST grep `CoupleAnalysisResult.toJson\|"winner"` across the Flutter codebase during read_first to lock the exact string before writing the port.** If no toJson exists, default to Python snake_case values AND document the choice in a comment — the plan-07 parity test will catch any mismatch.

       Continue with `@dataclass(frozen=True) class CoupleAnalysisResult`, `AvsCoupleCapResult`, `MarriagePenaltyResult`, `CoupleOptimizationResult`. Mirror Dart field names converted to snake_case (Dart `savingDelta` → Python `saving_delta`). Add `.empty()` classmethod for `CoupleOptimizationResult` mirroring Dart `const CoupleOptimizationResult.empty()` (line 118) and `.has_results` property mirroring Dart `hasResults` getter (line 125).

       Add `to_legacy_dict() -> dict` method to `CoupleOptimizationResult` that produces the dict shape consumed by `_format_couple_optimization(ctx)` at `coach_chat.py:2588-2628`:
       ```python
       {
         "lpp_buyback": {"winner": "...", "saving_delta": float, "reason": "...", "trade_off": "..."} | None,
         "pillar_3a": {"winner": "...", "reason": "...", "trade_off": "..."} | None,
         "avs_cap": {"cap_applied": bool, "monthly_reduction": float, "user_rente_before_cap": float,
                     "conjoint_rente_before_cap": float, "total_after_cap": float} | None,
         "marriage_penalty": {"has_penalty": bool, "annual_delta": float, "trade_off": "..."} | None,
       }
       ```
       Used by Task 2 fallback when the new path needs to emit FR text via the legacy formatter.

    3. **Constants mirrored from Dart** — copy the 3 constant maps verbatim from `tax_calculator.dart:276-305`:
       ```python
       # MIRROR Dart tax_calculator.dart:276-284
       _EFFECTIVE_RATES_100K: dict[str, float] = {
           "ZG": 0.0823, "NW": 0.0891, "OW": 0.0934, "AI": 0.0956,
           "AR": 0.1012, "SZ": 0.1034, "UR": 0.1067, "LU": 0.1089,
           "GL": 0.1102, "TG": 0.1145, "SH": 0.1167, "AG": 0.1189,
           "GR": 0.1203, "BL": 0.1256, "SG": 0.1278, "ZH": 0.1290,
           "FR": 0.1312, "SO": 0.1334, "TI": 0.1356, "BE": 0.1389,
           "NE": 0.1423, "VS": 0.1456, "VD": 0.1489, "JU": 0.1512,
           "GE": 0.1545, "BS": 0.1578,
       }
       # MIRROR Dart tax_calculator.dart:290-293
       _INCOME_ADJUSTMENT: dict[int, float] = {
           50_000: 0.75, 80_000: 0.90, 100_000: 1.00,
           150_000: 1.10, 200_000: 1.18, 300_000: 1.25, 500_000: 1.32,
       }
       # MIRROR Dart tax_calculator.dart:299-305
       _FAMILY_ADJUSTMENT: dict[str, float] = {
           "celibataire": 1.00,
           "marie_sans_enfant": 0.85,
           "marie_1_enfant": 0.78,
           "marie_2_enfants": 0.72,
           "marie_3_enfants": 0.66,
       }

       _MIN_DELTA: float = 100.0  # MIRROR Dart couple_optimizer.dart:146 (_minDelta)
       _PILIER_3A_PLAFOND_AVEC_LPP: float = 7258.0  # MIRROR Dart social_insurance.dart:351 — also matches backend constant PILIER_3A_PLAFOND_AVEC_LPP
       ```

    4. **Tax helper inline ports** (mirror Dart `RetirementTaxCalculator.estimateMarginalRate` + `estimateTaxSaving` + `estimateMonthlyIncomeTax`):
       ```python
       def _interpolate_income_adjustment(income: float) -> float:
           """MIRROR Dart tax_calculator.dart:365-383 — linear interpolation
           between income brackets, clamped to boundary values."""
           keys = sorted(_INCOME_ADJUSTMENT.keys())
           if income <= keys[0]:
               return _INCOME_ADJUSTMENT[keys[0]]
           if income >= keys[-1]:
               return _INCOME_ADJUSTMENT[keys[-1]]
           for i in range(len(keys) - 1):
               lower, upper = keys[i], keys[i + 1]
               if lower <= income <= upper:
                   ratio = (income - lower) / (upper - lower)
                   return _INCOME_ADJUSTMENT[lower] + (_INCOME_ADJUSTMENT[upper] - _INCOME_ADJUSTMENT[lower]) * ratio
           return 1.0


       def _estimate_marginal_rate(
           revenu_brut_annuel: float,
           canton: str,
           *,
           is_married: bool = False,
           children: int = 0,
       ) -> float:
           """MIRROR Dart tax_calculator.dart:316-360.

           marginal = effective * 1.3, clamped [0.05, 0.45].
           No `actualRate` override here (the Python port operates on raw
           profile data; future enhancement may pass a scanned-tax-return
           override the same way Dart does).
           """
           canton_code = (canton or "ZH").upper()  # MIRROR Dart resolveCanton + fallback to ZH
           base_rate = _EFFECTIVE_RATES_100K.get(canton_code, 0.13)  # MIRROR Dart line 333 (Swiss average fallback)
           income_adj = _interpolate_income_adjustment(revenu_brut_annuel)
           if not is_married:
               family_key = "celibataire"
           elif children >= 3:
               family_key = "marie_3_enfants"
           elif children == 2:
               family_key = "marie_2_enfants"
           elif children == 1:
               family_key = "marie_1_enfant"
           else:
               family_key = "marie_sans_enfant"
           family_adj = _FAMILY_ADJUSTMENT.get(family_key, 1.0)
           effective = base_rate * income_adj * family_adj
           marginal = effective * 1.3  # MIRROR Dart line 357
           return max(0.05, min(0.45, marginal))


       def _estimate_tax_saving(
           income: float,
           deduction: float,
           canton: str,
           *,
           is_married: bool = False,
           children: int = 0,
           steps: int = 10,
       ) -> float:
           """MIRROR Dart tax_calculator.dart:390-419.

           Numerical integration over `steps` slices: sum of stepSize *
           marginalRate(midPoint) as income decreases.
           """
           if deduction <= 0 or steps <= 0:
               return 0.0
           step_size = deduction / steps
           current_income = income
           total_saved = 0.0
           for _ in range(steps):
               midpoint = current_income - (step_size / 2)
               rate = _estimate_marginal_rate(midpoint, canton, is_married=is_married, children=children)
               total_saved += step_size * rate
               current_income -= step_size
           return total_saved


       def _estimate_monthly_income_tax(
           revenu_annuel_imposable: float,
           canton: str,
           *,
           etat_civil: str = "celibataire",
           nombre_enfants: int = 0,
       ) -> float:
           """MIRROR Dart tax_calculator.dart:476-490 (simplified).

           Dart's FiscalService.estimateTax is more nuanced (canton-specific
           bareme + multipliers). For Wave 1a parity-on-the-fixture-set we
           approximate chargeTotale = revenue * effective_rate(...). The
           plan-07 parity test asserts ±0.01 CHF on Julien/Lauren fixtures.
           If parity fails for any fixture, executor must surface in
           SUMMARY and the Dart FiscalService logic is in scope for an
           inline port in the same plan (do not defer).
           """
           if revenu_annuel_imposable <= 0:
               return 0.0
           canton_code = (canton or "ZH").upper()
           base_rate = _EFFECTIVE_RATES_100K.get(canton_code, 0.13)
           income_adj = _interpolate_income_adjustment(revenu_annuel_imposable)
           is_married = etat_civil == "marie"
           if not is_married:
               family_key = "celibataire"
           elif nombre_enfants >= 3:
               family_key = "marie_3_enfants"
           elif nombre_enfants == 2:
               family_key = "marie_2_enfants"
           elif nombre_enfants == 1:
               family_key = "marie_1_enfant"
           else:
               family_key = "marie_sans_enfant"
           family_adj = _FAMILY_ADJUSTMENT.get(family_key, 1.0)
           effective_rate = base_rate * income_adj * family_adj
           charge_totale = revenu_annuel_imposable * effective_rate
           return charge_totale / 12.0
       ```

    5. **AVS helper inline ports** — mirror Dart `AvsCalculator.computeMonthlyRente` / `computeCouple` / `annualRente`. The executor reads `apps/mobile/lib/services/financial_core/avs_calculator.dart` in full during `read_first` to extract the exact formulas. Mirror them line-by-line with `# MIRROR Dart avs_calculator.dart:<line>` traceability. Critical: do NOT delegate to `app.services.retirement.avs_estimation_service.AvsEstimationService` — signature mismatch (no `arrivalAge`, no `isFemale`, no `birthYear` parameter exposed) would silently diverge.

    6. **CoupleOptimizer class** — Python class with `optimize(profile_data: dict) -> CoupleOptimizationResult` static method that mirrors Dart `optimize({mainUser, conjoint})`:
       - Read `profile_data` keys: `etatCivil` (string, one of `celibataire|marie|divorce|veuf|concubinage`), `canton`, `nombreEnfants`, `salaireBrutMensuel`, `nombreDeMois`, `birthYear`, `gender`, `prevoyance` (dict with `lacuneRachatRestante`), `conjoint` (dict with sub-fields verified above).
       - Internal flow mirrors Dart lines 155-176: guard if `conjoint is None` → return `CoupleOptimizationResult.empty()`. Guard if both incomes zero → empty.
       - Call 4 private static methods `_analyze_lpp_buyback_order`, `_analyze_3a_contribution_order`, `_analyze_avs_cap`, `_analyze_marriage_penalty` — each mirrors the corresponding Dart method line-by-line with `# MIRROR Dart couple_optimizer.dart:<line>` comments.

    7. Every FR `reason` / `tradeOff` string copied VERBATIM from Dart (the verbatim strings are embedded in the `<interfaces>` block above with their Dart line numbers). For interpolated strings (Dart uses `${ceiling.round()}` and `${annualDelta.round()}` and `${canton}`), the Python port uses f-strings with the same `round()` semantics (Python `round()` matches Dart `.round()` for positive numbers; verify on edge case via Test 13 marriage penalty).

    Step D — Create `services/backend/app/models/coach_tools/couple_optimization.py`:
    ```python
    """Wave 1a D-03 — get_couple_optimization Pydantic v2 response model.

    Nested structure mirrors Dart CoupleOptimizationResult. camelCase aliases
    via to_camel (CLAUDE.md §1 backend AGENT contract).

    Units:
      saving_delta / monthly_reduction / annual_delta / *_rente* — Decimal CHF.
      cap_applied / has_penalty — bool.
      winner — str ("main_user"|"conjoint"|"no_preference" per Python enum
        value; verify Dart toJson output during executor read_first per
        Task 1 Step C #2 note).
      inputs_hash — 64-char lowercase hex SHA-256 of canonical-JSON profile
        slice (Phase 95 DAG-INVALIDATION pattern).
    """
    from datetime import datetime
    from decimal import Decimal
    from typing import Optional

    from pydantic import BaseModel, ConfigDict, Field
    from pydantic.alias_generators import to_camel


    class LppBuybackOrderResponse(BaseModel):
        model_config = ConfigDict(populate_by_name=True, alias_generator=to_camel, frozen=True)
        winner: str
        saving_delta: Decimal
        reason: str
        trade_off: str


    class Pillar3aOrderResponse(BaseModel):
        model_config = ConfigDict(populate_by_name=True, alias_generator=to_camel, frozen=True)
        winner: str
        saving_delta: Decimal
        reason: str
        trade_off: str


    class AvsCapResponse(BaseModel):
        model_config = ConfigDict(populate_by_name=True, alias_generator=to_camel, frozen=True)
        cap_applied: bool
        monthly_reduction: Decimal
        user_rente_before_cap: Decimal
        conjoint_rente_before_cap: Decimal
        total_after_cap: Decimal


    class MarriagePenaltyResponse(BaseModel):
        model_config = ConfigDict(populate_by_name=True, alias_generator=to_camel, frozen=True)
        has_penalty: bool
        annual_delta: Decimal
        trade_off: str


    class CoupleOptimizationResponse(BaseModel):
        model_config = ConfigDict(populate_by_name=True, alias_generator=to_camel, frozen=True)
        lpp_buyback: Optional[LppBuybackOrderResponse] = None
        pillar_3a: Optional[Pillar3aOrderResponse] = None
        avs_cap: Optional[AvsCapResponse] = None
        marriage_penalty: Optional[MarriagePenaltyResponse] = None
        inputs_hash: str = Field(..., min_length=64, max_length=64)
        computed_at: datetime
    ```

    Step E — DO NOT modify `services/backend/app/models/coach_tools/__init__.py`. Per plan-00 invariant (panel fix: fastapi-pro concern #1), plans 01-05 do NOT edit the package init — consumers import directly:
    `from app.models.coach_tools.couple_optimization import CoupleOptimizationResponse`.

    Step F — Flag verification (READ-ONLY — plan-00 already added it). Executor MUST verify before writing tests:
    ```bash
    grep -c "COACH_TOOL_SERVER_SIDE_COUPLE_OPTIMIZATION_ENABLED" services/backend/app/core/config.py
    # Expected: 1 (added by plan-00)
    ```
    If 0, FAIL LOUDLY — plan-00 has not landed; do NOT add the flag here (would duplicate).

    Step G — Create `services/backend/tests/test_couple_optimizer.py` with the 20 tests from `<behavior>` (≥18 mandatory + 2 Pydantic/accent integrity). Test fixtures:
    - `_PROFILE_USER_HIGH_TAX` — single-tax-bracket profile: ZH canton, salaireBrutMensuel=15_000, nombreDeMois=13, etatCivil="marie", nombreEnfants=2, birthYear=1985, prevoyance={"lacuneRachatRestante": 50_000}, conjoint={"salaireBrutMensuel": 4_000, "nombreDeMois": 12, "canContribute3a": True, ...}.
    - `_PROFILE_CONJOINT_HIGH_TAX` — mirrored swap.
    - `_PROFILE_FATCA` — conjoint.canContribute3a=False, conjoint.isFatcaResident=True.
    - `_PROFILE_SINGLE` — etatCivil="celibataire", conjoint=None.
    - Assert ±Decimal("0.01") on every CHF field using `assert abs(result.saving_delta - Decimal("XXXX.XX")) <= Decimal("0.01")`.
    - For FR-string tests assert the byte-exact string from the Dart line cited.
    - Test 20 (accent integrity): `assert "é" in result.reason` AND `assert "→" in result.reason` (Dart line 229).
  </action>
  <verify>
    <automated>cd services/backend &amp;&amp; python3 -m pytest tests/test_couple_optimizer.py -q</automated>
  </verify>
  <acceptance_criteria>
    - `python3 -c "from app.services.couple_optimizer import CoupleOptimizer, CoupleOptimizationResult, CoupleWinner; print('ok')"` exits 0.
    - `python3 -c "from app.models.coach_tools.couple_optimization import CoupleOptimizationResponse, LppBuybackOrderResponse, Pillar3aOrderResponse, AvsCapResponse, MarriagePenaltyResponse; print('ok')"` exits 0.
    - `grep -c "COACH_TOOL_SERVER_SIDE_COUPLE_OPTIMIZATION_ENABLED" services/backend/app/core/config.py` returns ≥1 (plan-00 invariant).
    - `wc -l services/backend/app/services/couple_optimizer/couple_optimizer.py` returns ≥300 (true port, not stub).
    - `wc -l services/backend/tests/test_couple_optimizer.py` returns ≥250.
    - `pytest services/backend/tests/test_couple_optimizer.py -q` exits 0 with ≥18 tests collected.
    - `grep -c "# MIRROR Dart" services/backend/app/services/couple_optimizer/couple_optimizer.py` returns ≥10 (traceability comments — one per major Dart line group).
    - `grep -c "couple_optimizer.dart:" services/backend/app/services/couple_optimizer/couple_optimizer.py` returns ≥4 (at least one citation per Dart analysis method).
    - `grep -c "tax_calculator.dart:" services/backend/app/services/couple_optimizer/couple_optimizer.py` returns ≥3 (citations for marginal-rate / tax-saving / monthly-income-tax helpers).
    - `grep -c "avs_calculator.dart:" services/backend/app/services/couple_optimizer/couple_optimizer.py` returns ≥3 (citations for computeMonthlyRente / computeCouple / annualRente).
    - `python3 tools/checks/accent_lint_fr.py services/backend/app/services/couple_optimizer/couple_optimizer.py services/backend/app/models/coach_tools/couple_optimization.py` exits 0 (FR strings preserve Dart accents byte-identically — proves no `e→é` ASCII regression).
    - `python3 tools/checks/banned_terms_python.py services/backend/app/services/couple_optimizer/couple_optimizer.py services/backend/app/models/coach_tools/couple_optimization.py` exits 0 (no LSFin banned terms introduced by the port — should be impossible since Dart source is already lint-clean, but Python may introduce drift via docstrings).
    - `grep -c "AvsEstimationService\|FiscalService.estimateTax" services/backend/app/services/couple_optimizer/couple_optimizer.py` returns 0 (the port does NOT delegate to Python services with incompatible signatures — explicit anti-fabrication grep).
  </acceptance_criteria>
  <done>
    Python port + 20 unit tests green; per-method parity ±0.01 CHF asserted in tests; FR strings byte-identical to Dart (accent_lint green); tax + AVS helpers ported INLINE with traceability comments (≥10 MIRROR comments + ≥10 Dart-file:line citations); zero illegal cross-service delegations to Python financial services with incompatible signatures.
  </done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Wire _compute_couple_optimization + dispatcher branch + ≥7 dispatcher tests</name>
  <read_first>
    - services/backend/app/api/v1/endpoints/coach_chat.py lines 1938-1941 (dispatcher marker pair from plan-00)
    - services/backend/app/api/v1/endpoints/coach_chat.py lines 2574-2628 (legacy _format_couple_optimization — preserve unchanged)
    - services/backend/app/api/v1/endpoints/coach_chat.py lines 2286-2388 (shipped _compute_budget_status pattern reference)
    - services/backend/app/api/v1/endpoints/coach_chat.py lines 2390-2470 (shipped _compute_retirement_projection — same pattern; mirror)
    - services/backend/app/services/couple_optimizer/couple_optimizer.py (just created in Task 1)
    - services/backend/app/observability/coach_breadcrumbs.py (emit_coach_tool_breadcrumb signature — 5 kwargs locked by plan-00 Test 14)
  </read_first>
  <files>
    - services/backend/app/api/v1/endpoints/coach_chat.py (modify — insert _compute_couple_optimization above _format_couple_optimization, replace dispatcher branch body)
    - services/backend/tests/test_coach_tools_couple_optimization.py (create)
  </files>
  <behavior>
    - Test 1: dispatcher with flag OFF returns legacy `_format_couple_optimization(ctx)` byte-identical (use `ctx={"couple_optimization": {...complete dict...}}` and assert `out == _format_couple_optimization(ctx)`).
    - Test 2: dispatcher with flag ON + valid profile in DB returns parseable `CoupleOptimizationResponse` JSON with camelCase nested keys (json.loads the output, assert `parsed["lppBuyback"]["savingDelta"]` exists).
    - Test 3: dispatcher with flag ON + single-status profile in DB → returns response with all 4 sub-fields None + valid `inputsHash` (64-char hex).
    - Test 4: dispatcher with flag ON + user_id is None OR db is None → fallback to legacy formatter (no exception raised, returns the legacy FR string).
    - Test 5: dispatcher with flag ON but DB returns no ProfileModel for user_id → fallback to legacy.
    - Test 6: dispatcher with flag ON but `CoupleOptimizer.optimize` raises (mock to raise ValueError) → broad `Exception` fallback to legacy formatter, logger.warning called (no crash leaks).
    - Test 7: inputs_hash deterministic across 2 calls with same profile.data input.
    - Test 8: emit_coach_tool_breadcrumb is called with tool_name="couple_optimization" + the EXACT 5 D-15 kwargs (inputs_hash, profile_id_hashed, elapsed_ms, flag_state="on"). Use `unittest.mock.patch("app.api.v1.endpoints.coach_chat.emit_coach_tool_breadcrumb")`, assert called once, inspect call.kwargs against the 5-kwarg D-15 contract.
    - Test 9: D-15 payload non-PII — profile_id_hashed is 16 chars, NOT the raw user_id (proves hash_profile_id was applied).
  </behavior>
  <action>
    Step A — In `services/backend/app/api/v1/endpoints/coach_chat.py`, INSERT `_compute_couple_optimization(user_id: str | None, ctx: dict, db) -> str` ABOVE `_format_couple_optimization` (at the blank line preceding line 2574). Pattern mirrors the shipped `_compute_budget_status` (lines 2286-2388) and `_compute_retirement_projection` (lines 2390-2470):
    ```python
    def _compute_couple_optimization(user_id: str | None, ctx: dict, db) -> str:
        """Wave 1a D-02 server-side path for get_couple_optimization.

        Returns either:
          - JSON string `CoupleOptimizationResponse.model_dump_json(by_alias=True)`
            (flag ON success path), OR
          - legacy FR string from `_format_couple_optimization(ctx)`
            (flag OFF / fallback path).

        Falls back to legacy formatter when:
          - settings flag is OFF, OR
          - user_id is None / db session is None, OR
          - DB returns no ProfileModel for user_id / profile.data is empty, OR
          - CoupleOptimizer.optimize raises ANY Exception (defensive: DB flake,
            unexpected shape, Pydantic validation, breadcrumb error).
            User-facing text never breaks the coach loop.
        """
        import time
        import logging
        from app.core.config import settings

        if not settings.COACH_TOOL_SERVER_SIDE_COUPLE_OPTIMIZATION_ENABLED:
            return _format_couple_optimization(ctx)
        if not user_id or db is None:
            return _format_couple_optimization(ctx)

        _t0 = time.perf_counter()
        try:
            from datetime import datetime, timezone

            from app.models.coach_tools.couple_optimization import (
                CoupleOptimizationResponse,
                LppBuybackOrderResponse,
                Pillar3aOrderResponse,
                AvsCapResponse,
                MarriagePenaltyResponse,
            )
            from app.models.profile_model import ProfileModel
            from app.observability.coach_breadcrumbs import emit_coach_tool_breadcrumb
            from app.services.coach.inputs_hash import compute_inputs_hash
            from app.services.couple_optimizer import CoupleOptimizer
            from app.utils.hashing import hash_profile_id

            # Newest-profile-wins lookup — mirrors shipped pattern at
            # coach_chat.py:2327-2332 (plan-01) and :2435-2440 (plan-02).
            profile = (
                db.query(ProfileModel)
                .filter(ProfileModel.user_id == user_id)
                .order_by(ProfileModel.updated_at.desc())
                .first()
            )
            if profile is None or not profile.data:
                return _format_couple_optimization(ctx)

            result = CoupleOptimizer.optimize(profile.data)
            # Build the inputs_hash slice from the actual fields the port reads
            # (mirror the keys read inside CoupleOptimizer.optimize).
            slice_ = {
                "etatCivil": profile.data.get("etatCivil"),
                "canton": profile.data.get("canton"),
                "nombreEnfants": profile.data.get("nombreEnfants"),
                "salaireBrutMensuel": profile.data.get("salaireBrutMensuel"),
                "nombreDeMois": profile.data.get("nombreDeMois"),
                "birthYear": profile.data.get("birthYear"),
                "gender": profile.data.get("gender"),
                "prevoyance": profile.data.get("prevoyance"),
                "conjoint": profile.data.get("conjoint"),
            }

            def _to_lpp(r) -> LppBuybackOrderResponse | None:
                if r is None:
                    return None
                return LppBuybackOrderResponse(
                    winner=r.winner.value if hasattr(r.winner, "value") else str(r.winner),
                    saving_delta=Decimal(str(r.saving_delta)).quantize(Decimal("0.01")),
                    reason=r.reason,
                    trade_off=r.trade_off,
                )

            def _to_p3a(r) -> Pillar3aOrderResponse | None:
                if r is None:
                    return None
                return Pillar3aOrderResponse(
                    winner=r.winner.value if hasattr(r.winner, "value") else str(r.winner),
                    saving_delta=Decimal(str(r.saving_delta)).quantize(Decimal("0.01")),
                    reason=r.reason,
                    trade_off=r.trade_off,
                )

            def _to_avs(r) -> AvsCapResponse | None:
                if r is None:
                    return None
                q = lambda v: Decimal(str(v)).quantize(Decimal("0.01"))
                return AvsCapResponse(
                    cap_applied=r.cap_applied,
                    monthly_reduction=q(r.monthly_reduction),
                    user_rente_before_cap=q(r.user_rente_before_cap),
                    conjoint_rente_before_cap=q(r.conjoint_rente_before_cap),
                    total_after_cap=q(r.total_after_cap),
                )

            def _to_mp(r) -> MarriagePenaltyResponse | None:
                if r is None:
                    return None
                return MarriagePenaltyResponse(
                    has_penalty=r.has_penalty,
                    annual_delta=Decimal(str(r.annual_delta)).quantize(Decimal("0.01")),
                    trade_off=r.trade_off,
                )

            response = CoupleOptimizationResponse(
                lpp_buyback=_to_lpp(result.lpp_buyback_order),
                pillar_3a=_to_p3a(result.pillar_3a_order),
                avs_cap=_to_avs(result.avs_cap),
                marriage_penalty=_to_mp(result.marriage_penalty),
                inputs_hash=compute_inputs_hash(slice_),
                computed_at=datetime.now(timezone.utc),
            )
            # D-15 uniform Sentry payload via plan-00 helper. EXACT 5 kwargs locked.
            elapsed_ms = int((time.perf_counter() - _t0) * 1000)
            emit_coach_tool_breadcrumb(
                tool_name="couple_optimization",
                inputs_hash=response.inputs_hash,
                profile_id_hashed=hash_profile_id(user_id),
                elapsed_ms=elapsed_ms,
                flag_state="on",
            )
            return response.model_dump_json(by_alias=True)
        except Exception as exc:  # defensive fallback (python-pro panel — broad, not bare ValueError)
            logging.getLogger(__name__).warning(
                "compute_couple_optimization failed, falling back to legacy: %s", exc
            )
            return _format_couple_optimization(ctx)
    ```
    Add `from decimal import Decimal` to the imports at the top of `coach_chat.py` IF it is not already imported there (grep first to avoid double import). Also add `from datetime import timezone` IF not present.

    Step B — Replace the dispatcher branch body INSIDE the marker pair shipped by plan-00 (lines 1938-1941, verified 2026-05-14). Locate the EXACT 4-line block:
    ```python
        # >>> dispatch: get_couple_optimization
        if name == "get_couple_optimization":
            return _format_couple_optimization(ctx)
        # <<< dispatch: get_couple_optimization
    ```
    Replace WITH (markers preserved verbatim — DO NOT modify or remove the marker comment lines):
    ```python
        # >>> dispatch: get_couple_optimization
        if name == "get_couple_optimization":
            return _compute_couple_optimization(user_id=user_id, ctx=ctx, db=db)
        # <<< dispatch: get_couple_optimization
    ```
    Acceptance after edit: `grep -c "# >>> dispatch: get_couple_optimization" services/backend/app/api/v1/endpoints/coach_chat.py` returns exactly 1 AND `grep -c "# <<< dispatch: get_couple_optimization" services/backend/app/api/v1/endpoints/coach_chat.py` returns exactly 1.

    Step C — Create `services/backend/tests/test_coach_tools_couple_optimization.py` with Tests 1-9. Use `monkeypatch.setattr(settings, "COACH_TOOL_SERVER_SIDE_COUPLE_OPTIMIZATION_ENABLED", True/False)`. Use `unittest.mock.patch("app.api.v1.endpoints.coach_chat.emit_coach_tool_breadcrumb")` for Test 8. Use `unittest.mock.patch("app.api.v1.endpoints.coach_chat.CoupleOptimizer.optimize", side_effect=ValueError("test"))` for Test 6. Mirror the test layout of `services/backend/tests/test_coach_tools_retirement_projection.py` (Task 2 tests 7-12 — same shape, different tool).
  </action>
  <verify>
    <automated>cd services/backend &amp;&amp; python3 -m pytest tests/test_coach_tools_couple_optimization.py tests/test_couple_optimizer.py -q &amp;&amp; python3 tools/checks/banned_terms_python.py services/backend/app/services/couple_optimizer/couple_optimizer.py services/backend/app/models/coach_tools/couple_optimization.py services/backend/app/api/v1/endpoints/coach_chat.py &amp;&amp; python3 tools/checks/accent_lint_fr.py services/backend/app/services/couple_optimizer/couple_optimizer.py services/backend/app/models/coach_tools/couple_optimization.py</automated>
  </verify>
  <acceptance_criteria>
    - `grep -c "def _compute_couple_optimization" services/backend/app/api/v1/endpoints/coach_chat.py` returns exactly 1.
    - `grep -c "_compute_couple_optimization" services/backend/app/api/v1/endpoints/coach_chat.py` returns ≥3 (def + dispatcher call + at minimum no other callers).
    - `grep -c "_format_couple_optimization" services/backend/app/api/v1/endpoints/coach_chat.py` returns ≥4 (legacy def + 4 fallback calls from _compute_couple_optimization).
    - `grep -c "COACH_TOOL_SERVER_SIDE_COUPLE_OPTIMIZATION_ENABLED" services/backend/app/api/v1/endpoints/coach_chat.py` returns ≥1.
    - `pytest services/backend/tests/test_couple_optimizer.py tests/test_coach_tools_couple_optimization.py -q` exits 0 with ≥27 total tests (20 port + ≥7 dispatcher).
    - `grep "tool_name=\"couple_optimization\"" services/backend/app/api/v1/endpoints/coach_chat.py` returns ≥1.
    - `grep "profile_id_hashed=hash_profile_id(user_id)" services/backend/app/api/v1/endpoints/coach_chat.py` returns at least one new occurrence (count strictly increases vs the pre-plan-04 baseline).
    - `grep -c "# >>> dispatch: get_couple_optimization" services/backend/app/api/v1/endpoints/coach_chat.py` returns exactly 1 (marker preserved).
    - `grep -c "# <<< dispatch: get_couple_optimization" services/backend/app/api/v1/endpoints/coach_chat.py` returns exactly 1.
    - `python3 tools/checks/banned_terms_python.py services/backend/app/services/couple_optimizer/couple_optimizer.py services/backend/app/models/coach_tools/couple_optimization.py services/backend/app/api/v1/endpoints/coach_chat.py` exits 0.
    - `python3 tools/checks/accent_lint_fr.py services/backend/app/services/couple_optimizer/couple_optimizer.py services/backend/app/models/coach_tools/couple_optimization.py` exits 0.
  </acceptance_criteria>
  <done>
    Dispatcher routes through Python port when flag ON; ≥27 tests green (20 Task 1 + ≥7 Task 2); FR strings byte-identical Dart↔Python (accent_lint_fr proof); dispatcher marker pair preserved exactly; D-15 5-kwarg breadcrumb contract honored.
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| Coach LLM → Python port output | Untrusted LLM tool_input crosses into _compute_couple_optimization (only `name` field reaches the function; user_id comes from authenticated session, ctx from sanitized profile_context). |
| Dart source ↔ Python port | Cross-language source-of-truth boundary — port divergence = silent numeric drift = LLM hallucination amplifier. |
| profile.data JSON ↔ port input | Untrusted shape (Flutter sends what it wants); port must tolerate missing/typo'd keys without crash. |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-WAVE1A-04-01 | T (Tampering) | Legacy `_format_couple_optimization` regression when flag OFF | mitigate | Task-2 Test 1 asserts byte-identity passthrough on a known ctx fixture. |
| T-WAVE1A-04-02 | I (Information disclosure) | LSFin banned-terms leak via newly-emitted Python FR strings | mitigate | Strings copied VERBATIM from Dart (Dart source is already LSFin-clean per existing Flutter `accent_lint_fr` + `banned_terms_dart` gates); `banned_terms_python.py` enforces in verify step; `accent_lint_fr.py` enforces accent integrity. |
| T-WAVE1A-04-03 | I | PII leak in Sentry breadcrumb | mitigate | D-15 payload locked to 5 non-PII kwargs (inputs_hash 64-char SHA-256, profile_id_hashed 16-char SHA-256 prefix, elapsed_ms int, flag_state Literal, tool_name string). plan-00 Test 14 pins the contract via inspect.signature; this plan honors it. |
| T-WAVE1A-04-04 | T | Numeric drift Flutter ↔ Python (Dart formula deviates from Python port) | mitigate | (a) 18 unit-test cases assert per-method parity ±0.01 CHF; (b) ≥10 `# MIRROR Dart <file>:<line>` traceability comments + ≥4 Dart-line citations per analysis method enable line-by-line cross-review; (c) plan-07 parity harness adds 3-archetype cross-validation. |
| T-WAVE1A-04-05 | T | Port silently delegates to incompatible Python financial services (e.g. AvsEstimationService) and diverges from Dart | mitigate | Task 1 acceptance criterion enforces `grep -c "AvsEstimationService\|FiscalService.estimateTax" couple_optimizer.py` returns 0 — explicit anti-fabrication grep proves the port mirrors INLINE (correct per signature-mismatch analysis in interfaces block). |
| T-WAVE1A-04-06 | D (Denial of service) | profile.data shape mismatch (missing keys, wrong types) crashes the coach response path | mitigate | `_compute_couple_optimization` catches broad `Exception` and falls back to legacy formatter (Test 6); CoupleOptimizer.optimize itself uses `.get()` for all profile_data reads (no KeyError); fail-open semantics. |
| T-WAVE1A-04-07 | I | Enum-string serialization drift Dart↔Python (e.g. Dart toJson emits "mainUser" but Python emits "main_user") | mitigate | Task 1 Step C #2 instructs executor to grep `CoupleAnalysisResult.toJson` in Flutter and lock the exact string before writing the port. If no toJson exists, plan-07 parity test catches the mismatch on the legacy formatter pass-through. |
</threat_model>

<verification>
- `pytest services/backend/tests/test_couple_optimizer.py tests/test_coach_tools_couple_optimization.py -q` exits 0 with ≥27 tests.
- `pytest services/backend/ -q` full suite — zero regressions (target ≥6567 baseline + 27 = ≥6594).
- `python3 tools/checks/banned_terms_python.py` green on all touched files.
- `python3 tools/checks/accent_lint_fr.py` green on the port + Pydantic models.
- `wc -l services/backend/app/services/couple_optimizer/couple_optimizer.py` ≥300 (true port, not stub).
- Dart-traceability comments present: ≥10 `# MIRROR Dart` + ≥4 `couple_optimizer.dart:` + ≥3 `tax_calculator.dart:` + ≥3 `avs_calculator.dart:` citations (grep proofs).
- Dispatcher marker pair preserved exactly (grep proof: 1 opening + 1 closing).
- Anti-fabrication grep: zero `AvsEstimationService` or `FiscalService.estimateTax` references in the port (proves it mirrored INLINE, did not silently delegate to incompatible Python services).
</verification>

<success_criteria>
- WAVE1A-05 satisfied: Python port at `app.services.couple_optimizer` exists, mirrors Dart 1:1 with traceability, parity ±0.01 CHF on 18 unit tests, no incompatible-service delegation.
- WAVE1A-09 satisfied: Pydantic v2 camelCase response with nested structure (lppBuyback / pillar3a / avsCap / marriagePenalty + inputsHash + computedAt).
- WAVE1A-10 satisfied: dispatcher reads `COACH_TOOL_SERVER_SIDE_COUPLE_OPTIMIZATION_ENABLED` flag from plan-00 scaffolding; OFF default → byte-identical legacy fallback.
- ≥27 new backend tests (20 port incl. Pydantic + accent integrity + ≥7 dispatcher), lints green, no FR-string drift Dart↔Python (accent_lint proof).
</success_criteria>

<output>
After completion, create `.planning/phases/wave-1a-backend-tools-refactor/wave-1a-04-SUMMARY.md` with:
- Files created (paths + line counts).
- Port-vs-Dart traceability table: which Dart `<file>:<line>` was mirrored where in Python (extracted from `# MIRROR Dart` comments — paste the grep output).
- 27+ tests collected + passed (paste pytest tail).
- accent_lint_fr.py + banned_terms_python.py green outputs.
- Anti-fabrication grep proof: zero `AvsEstimationService` or `FiscalService.estimateTax` references (paste grep output showing 0).
- Decision recorded: which string form Dart `CoupleAnalysisResult.toJson` emits for `winner` (snake_case vs camelCase) — paste the grep that resolved the question.
- 0-trust §9 self-check section citing every command output verbatim (G3 pytest exit 0 + G4 regression count baseline+N + G5 lints exit 0).
</output>
