---
phase: 94-compliance-polish
plan: 01
subsystem: backend+mobile
tags: [compliance, i18n, locale, arb, finsa, lsfin, eclairage, benchmark, comp-02, comp-05, comp-06]
requirements: [COMP-02, COMP-05, COMP-06]
closes_bugs: ["#20", "#12", "#23"]
key-files:
  modified:
    - services/backend/app/services/coach/anonymous_eclairage_prompt.py
    - services/backend/app/api/v1/endpoints/anonymous_chat.py
    - apps/mobile/lib/l10n/app_en.arb
    - apps/mobile/lib/l10n/app_localizations_en.dart
    - apps/mobile/lib/constants/social_insurance.dart
    - apps/mobile/lib/services/benchmark_service.dart
    - apps/mobile/test/services/benchmark_service_test.dart
  created:
    - services/backend/tests/coach/test_anonymous_eclairage_prompt_locale.py
    - apps/mobile/test/l10n/test_app_en_arb_finsa_sweep.dart
    - .planning/phases/94-compliance-polish/deferred-items.md
decisions:
  - "Multiplicative (× 0.96) derivation for pilier3aProchePlafondThreshold: self-rebalances to ~96% of plafond when OFAS revalorises (vs additive `- 258` which silently drifts)."
  - "EN-only sweep for COMP-05: FR keeps LSFin (native FR regulator name), DE keeps FIDLEG, IT/ES/PT defer LSerFi migration to Phase 97 counsel pass."
  - "Promptfoo eval suite deferred to Phase 95 TEST-01: Plan 94-01 ships 39 unit cases instead so Phase 95 has a real code path to evaluate."
  - "Locale bodies trimmed to fit Pydantic max_length=240 on EclairagePayload.body — preserved CHF cap citation, locale fingerprint (« kannst »/« puoi »/« you can »/« podes »), and conditional « selon ton canton » idiom in every variant."
metrics:
  duration: ~25 min
  tasks_completed: 4
  backend_tests_added: 39 (24 parametrized + 15 standalone)
  mobile_tests_added: 8 (4 ARB sweep + 4 COMP-06 derivation)
  loc_added_prod: ~85
  loc_added_test: ~150
---

# Phase 94 Plan 01: Compliance Polish — Locale + i18n + Constants Summary

Three small, surgical compliance closures land in a single atomic commit:
6-locale anonymous éclairage prompt (FinSA art. 8 al. 1 let. d), EN ARB
« LSFin → FinSA » regulator-name correction, and `benchmark_service.dart`
literal `7000` replaced by a derived constant `pilier3aProchePlafondThreshold
= pilier3aPlafondAvecLpp * 0.96`.

## What shipped

### COMP-02 — éclairage 6-locale registry (BUG #20 closed)

`services/backend/app/services/coach/anonymous_eclairage_prompt.py` now
exposes `_ECLAIRAGE_BY_LANGUAGE` (FR/DE/IT/EN/ES/PT) and
`build_default_fiscal_margin_3a_eclairage(language="fr")` accepts the
locale arg. Caller `anonymous_chat.py:344` passes `body.language`.
Unsupported codes fall back to FR + emit `logger.warning`. The FR
variant references the locked Phase 71b constants by name — byte-identical
to pre-change output (zero regression on existing FR callers).

### COMP-05 — EN ARB regulator-name sweep (BUG #12 closed)

Single-file `sed` sweep on `app_en.arb`: 13 « LSFin » occurrences →
0; « FinSA » count 57 → 70. `flutter gen-l10n` regenerated
`app_localizations_en.dart` (67 FinSA / 0 LSFin). FR/DE/IT/ES/PT ARBs
untouched (verified: counts identical to pre-sweep baseline).

### COMP-06 — Magic-number 7000 killed (BUG #23 closed)

`apps/mobile/lib/constants/social_insurance.dart` gains
`pilier3aProchePlafondThreshold = pilier3aPlafondAvecLpp * 0.96`
(= 6967.68 for plafond 7'258). `benchmark_service.dart` imports
`social_insurance.dart` (first import in the file) and references the
named constant on line 118. UX semantic preserved: `compare3a` with
`annualContribution=7000.0` still emits « Tu es proche du plafond 3a »
because 7000 ≥ 6967.68.

## Diff stat

| File | LOC delta |
|------|-----------|
| `services/backend/app/services/coach/anonymous_eclairage_prompt.py` | +103 |
| `services/backend/app/api/v1/endpoints/anonymous_chat.py` | ~1 |
| `services/backend/tests/coach/test_anonymous_eclairage_prompt_locale.py` | +172 (new) |
| `apps/mobile/lib/l10n/app_en.arb` | 13× value swap |
| `apps/mobile/lib/l10n/app_localizations_en.dart` | regen (13× value swap) |
| `apps/mobile/lib/constants/social_insurance.dart` | +9 |
| `apps/mobile/lib/services/benchmark_service.dart` | +2 / −1 |
| `apps/mobile/test/services/benchmark_service_test.dart` | +63 |
| `apps/mobile/test/l10n/test_app_en_arb_finsa_sweep.dart` | +71 (new) |

## ARB grep table (pre / post)

| Locale | LSFin pre | LSFin post | FinSA pre | FinSA post | Native regulator |
|--------|----------:|----------:|----------:|----------:|------------------|
| en | 13 | **0** | 57 | **70** | FinSA |
| fr | 72 | 72 | 1 | 1 | LSFin |
| de | 8 | 8 | 1 | 1 | FIDLEG (61 hits, unchanged) |
| it | 56 | 56 | 1 | 1 | LSFin (LSerFi → Phase 97) |
| es | 66 | 66 | 1 | 1 | LSFin (FR-anchored) |
| pt | 66 | 66 | 1 | 1 | LSFin (FR-anchored) |

## Test counts

- **Backend new:** 39 cases pass (`test_anonymous_eclairage_prompt_locale.py`)
  - 24 parametrized (4 archetypes × 6 locales) — structure + banned-term scan
  - 6 fingerprint-present (one per locale)
  - 5 FR-leak guard (one per non-FR locale)
  - 1 unsupported-language fallback + warning capture
  - 1 default-arg returns FR
  - 1 registry covers exactly the 6 supported locales
  - 1 FR variant byte-identical to Phase 71b locked constants
- **Backend regression:** 155/155 coach tests green (`tests/coach/`)
- **Backend full unit suite:** 6089 / 6090 pass (1 pre-existing failure documented in `deferred-items.md`)
- **Mobile new:** 4 ARB sweep + 4 COMP-06 derivation = 8 cases pass
- **Mobile regression:** 31/31 in `benchmark_service_test.dart` (27 pre-existing + 4 new)
- **Mobile static analysis:** 4 touched files clean (`flutter analyze` zero issues)

## Per-locale banned-term scan (success criterion #4)

| Locale | Body hits | Headline hits | Hint hits | Body length |
|--------|-----------|---------------|-----------|-------------|
| fr | [] | [] | [] | 223 / 240 |
| de | [] | [] | [] | 235 / 240 |
| it | [] | [] | [] | 227 / 240 |
| en | [] | [] | [] | 228 / 240 |
| es | [] | [] | [] | 226 / 240 |
| pt | [] | [] | [] | 222 / 240 |

All 6 locales clean against `ComplianceGuard._check_banned_terms`. No
« optimal », « meilleur », « garanti », « sicher », « migliore »,
« sin riesgo », « garantizado », « garantido », « best », « ótimo »
detected.

## COMP-06 derived constant — exact form

```dart
const double pilier3aProchePlafondThreshold = pilier3aPlafondAvecLpp * 0.96;
// = 7258.0 * 0.96 = 6967.68
```

Multiplicative (× 0.96), not additive (`pilier3aPlafondAvecLpp - 258`).
Rationale: when OFAS bumps the plafond from 7'258 → 7'350 (~2027), the
multiplicative form auto-rebalances the « proche du plafond » band to
~96 % of the new cap (= 7'056). The additive form would silently drift
to 7'092 = 96.5 % of the new cap, breaking the « within 4 % of cap »
semantic. Self-documenting + zero-maintenance.

## Deviations from plan

1. **Locale body length trim** (Rule 1 — bug fix): The plan-authored DE,
   IT, EN, PT translations exceeded the `EclairagePayload.body`
   `max_length=240` Pydantic constraint (252, 255, 246, 246 chars). I
   trimmed each to fit (235, 227, 228, 222) while preserving:
   (a) CHF 7'258 / 7,258 cap citation,
   (b) locale fingerprint (« kannst » / « puoi » / « you can » / « podes »),
   (c) conditional « selon ton canton » idiom (« je nach Kanton »,
   « a seconda del cantone », « depending on your canton »,
   « conforme o cantão »),
   (d) zero banned terms.
   FR + ES variants were already under the limit and shipped as-planned.

2. **`ComplianceGuard.scan()` API mismatch** (anticipated by plan §risks):
   Plan Task 2 instructed the executor to read `compliance_guard.py` and
   adapt. Real API exposes `_check_banned_terms(text)` (Layer 1 only) —
   not a `scan()` method. The test helper `_scan_banned_terms()` calls
   the Layer-1 helper directly with the same negated-guarantee masking
   that `validate()` uses, so a body containing « rien n'est garanti »
   would not falsely trip Layer 1.

3. **Pre-existing `test_compliance_wording.py` failure** (Karpathy 3 —
   surgical): The lint flags a meta-doc-comment in `anonymous_chat.py:169`
   that lists « garanti », « sans risque » as the banned vocabulary the
   prompt itself must avoid. Verified pre-existing on tip of
   `feat/phase-A-e2e-unblock` BEFORE any 94-01 change (via `git stash`).
   Out of scope. Logged in `.planning/phases/94-compliance-polish/deferred-items.md`.

## Confirmation

- BUG #20 (P1, eclairage locale) — **CLOSED**
- BUG #12 (P3, EN regulator name) — **CLOSED**
- BUG #23 (P2, magic 7000 literal) — **CLOSED**
- Phase 94 success criteria 1, 2, 3 — **GREEN**
- Phase 95 TEST-01 unblocked: 6-locale code path now exists for promptfoo to evaluate.

## Self-Check: PASSED

- Created files exist:
  - `services/backend/tests/coach/test_anonymous_eclairage_prompt_locale.py` ✓
  - `apps/mobile/test/l10n/test_app_en_arb_finsa_sweep.dart` ✓
  - `.planning/phases/94-compliance-polish/deferred-items.md` ✓
- Modified files contain expected changes:
  - `pilier3aProchePlafondThreshold = pilier3aPlafondAvecLpp * 0.96` in `social_insurance.dart` ✓
  - `contribution >= pilier3aProchePlafondThreshold` in `benchmark_service.dart` ✓
  - `_ECLAIRAGE_BY_LANGUAGE` 6-locale registry in `anonymous_eclairage_prompt.py` ✓
  - 0 LSFin in `app_en.arb` ✓
  - 70 FinSA in `app_en.arb` ✓
- Tests green: backend 39/39 new + 155/155 coach regression; mobile 8/8 new + 27/27 regression.
