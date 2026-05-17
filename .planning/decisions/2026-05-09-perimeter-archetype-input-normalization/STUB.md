---
name: MVP-ARCHETYPE-INPUT-NORMALIZATION — perimeter STUB
description: Audit finding 2026-05-08 — coach_profile.dart archetype getter compares residencePermit against 'G'/'C'/'B'/'Swiss' but the wizard persists 'permit_g'/'permit_c'/'permit_b'/'swiss'. Net effect: every cross-border, expat, and Swiss-permit user is silently downgraded to "default" archetype, breaking FATCA / frontalier / non-resident logic. Plus: anonymous_chat_screen hardcodes nationalityGroup='CH' for all anon stubs, pre-framing every anonymous user as Swiss native. Effort ~0.6 j.
type: decision
date: 2026-05-09
status: STUB → IN_FLIGHT (this PR opens with the fix)
related:
  - .planning/decisions/2026-05-09-perimeter-b14-b15-debt-context-rag/STUB.md
  - .planning/decisions/2026-05-08-coach-onboarding-redesign-panel/SYNTHESIS.md (P0#3 line item)
  - PR #533 (10-audit synthesis)
sources:
  - Audit synthesis 2026-05-09 (PR #533) — P0#3 line item
  - Code trace `apps/mobile/lib/data/wizard_questions_v2.dart:54-61` (wizard option values)
  - Code trace `apps/mobile/lib/models/coach_profile.dart:1781,1796` (archetype getter mismatched comparators)
  - Code trace `apps/mobile/lib/screens/anonymous/anonymous_chat_screen.dart:375` (hardcoded 'CH')
---

# MVP-ARCHETYPE-INPUT-NORMALIZATION — STUB

## Goal

**Normalize permit and nationality inputs at the model boundary** so the archetype getter actually fires for cross-border / expat / Swiss-permit users instead of silently falling through to the « default » archetype.

The audit found that:
1. Wizard option values are `'permit_g'`, `'permit_b'`, `'permit_c'`, `'swiss'` (canonicalized as enum strings).
2. `CoachProfile.archetype` getter compares against `'G'`, `'C'`, `'B'`, `'Swiss'` (single-letter ISO permit codes).
3. The two never match. Result: `residencePermit == 'G'` ALWAYS returns false. Cross-border (frontalier) archetype is never detected. Same for expat-eu / expat-non-eu / FATCA.

Plus: `anonymous_chat_screen.dart:375` hardcodes `nationalityGroup: 'CH'` for the anon-user fallback — pre-framing every anonymous user as Swiss native and skipping every expat/FATCA detection in `PremierEclairageSelector`.

## Truth-in-claim

The PR #529 commit B6 message « closes the silent FATCA bypass » is now layered. B6 partially fixed mobile→backend archetype propagation. **This perimeter is the OTHER half of the fix** — the mobile-side detection itself was broken because of the permit-string mismatch.

After this perimeter ships, the chain is :

`wizard answer 'permit_g'` → (NEW normalization) → `residencePermit='G'` → `archetype getter` → `FinancialArchetype.crossBorder` → `_archetypeToBackendName()` → `QuestionMeta.archetype='cross_border'` → backend doctrine_checks fires.

Without this perimeter, the chain breaks at step 1 and the rest of the pipeline operates on the « default » archetype regardless of what the user picked.

## Fix

Three surgical changes:

1. **`coach_profile.dart` — normalize at archetype getter (defensive net)**.
   Accept both wizard form (`'permit_g'`) and canonical form (`'G'`). This is the most surgical fix — no migration needed for already-persisted profiles.

2. **`coach_profile.dart` — normalize at `fromWizardAnswers`**.
   Strip the `'permit_'` prefix when constructing the model. Ensures the canonical `'G'`/`'B'`/`'C'`/`'Swiss'` is what gets persisted going forward (single-source-of-truth move per CLAUDE.md NEVER #3).

3. **`anonymous_chat_screen.dart` — drop hardcoded `nationalityGroup: 'CH'`**.
   Pass `null` instead. PremierEclairageSelector + visibility_score_service already handle null nationality (early-onboarding state). The change removes the systematic Swiss-native bias on anon users.

## 5 gates mécaniques

| Gate | Description | Évidence |
|---|---|---|
| G1 | sim walker — pick « Permis G » in wizard, complete onboarding, assert `_archetypeToBackendName()` returns `'cross_border'` (not default) at coach context build | walker logs from a fresh expat_g seed |
| G2 | device by Julien — pick « Permis G » + nationality FR on his account, confirm coach addresses him as frontalier | TestFlight v2.12.2+5 |
| G3 | dev CI green — flutter analyze + flutter test (incl. new archetype unit tests) | run green |
| G4 | regression tests — `test_coach_profile_archetype.dart` covers all 8 archetype branches with both wizard form and canonical form inputs | new test exit 0 |
| G5 | LSFin/accent/ARB lint — clean (this PR only touches Dart, no ARB changes expected) | banned_terms_arb exit 0 |

## Tâches breakdown

| # | Action | Effort | Dépendance |
|---|---|---|---|
| 1 | Add `_normalizePermit(String?)` helper at top of `coach_profile.dart` (before class) — strips `permit_` prefix, uppercases, maps `'swiss'` → `'Swiss'` | 0.05 j | None |
| 2 | Update `archetype` getter L1779-1820 — wrap `residencePermit` reads in `_normalizePermit()` | 0.05 j | 1 |
| 3 | Update `screen_registry.dart:243` `isPermitG` check to use `_normalizePermit` (consistent semantics) | 0.05 j | 1 |
| 4 | Update `fromWizardAnswers` L2894 to call `_normalizePermit` on `q_residence_permit` answer (canonical form persisted) | 0.05 j | 1 |
| 5 | Drop `nationalityGroup: 'CH'` at `anonymous_chat_screen.dart:375` ; pass `null` ; verify PremierEclairageSelector handles null gracefully | 0.1 j | None |
| 6 | Unit test `test/models/coach_profile_archetype_normalization_test.dart` — 8 cases × 2 forms (wizard + canonical) = 16 assertions ; 4 edge cases (null, empty, lowercase, weird whitespace) | 0.2 j | 1-4 |
| 7 | Widget test `test/screens/anonymous/anonymous_chat_screen_no_ch_default_test.dart` — assert anon stub passes null nationalityGroup | 0.1 j | 5 |
| 8 | Run `flutter analyze` + `flutter test` + accept perimeter PR | 0.05 j | All |

**Total estimé** : ~0.6 j.

## Counter-arguments and data gaps

- **Risk 1** : Existing persisted profiles in user storage may already have `'permit_g'` (uncanonicalized) form. The defensive net in tasks 1-2 covers them at read-time. No DB migration needed because we read-time-normalize — but if we EVER want to query by `residencePermit == 'G'` at the storage layer, a migration becomes necessary. This perimeter does not address storage querying because no production code currently does it.
- **Risk 2** : The anon stub null-nationality change may surface latent null-handling bugs in downstream selectors. Mitigation : grep for `nationalityGroup ==` and `nationality ==` in selectors, manually verify null-branch exists on each call site.
- **Risk 3** : The audit also flagged « wedge nationality capture » (the wizard never asks for nationality if user picks « Nationalité suisse » → no dedicated nationality field). This is a separate concern (data acquisition) and OUT OF SCOPE for this perimeter. Filed as MVP-WIZARD-NATIONALITY-CAPTURE future perimeter ; tracked in audit synthesis P0#3 sub-line.
- **Risk 4** : `_normalizePermit` is a new global function. If a future engineer adds a new permit type to the wizard but forgets to update the normalizer, archetype detection silently regresses. Mitigation : add a const map `_WIZARD_TO_PERMIT_CANONICAL` at the top of the helper ; assert in tests that it covers all 4 wizard option values exhaustively.
- **Data gap** : No telemetry on « how many production users currently have an unmapped permit_X persisted ». Mitigation : after merge, log archetype-detection mismatches once per session for 1 week, then read the metric to size the impact.

## Approval gate

**This PR opens immediately** — it does NOT block on G2 device confirm, because :
1. The change is mobile-side only, surgical, fully unit-tested.
2. Without it, every cross-border / FATCA user gets the wrong archetype downstream — silent fail mode that's already in production.
3. Worst case if the fix has a bug : reverts cleanly, no DB state to migrate back.

G2 device verify by Julien is encouraged post-merge but not a precondition for opening this PR.

## Order of fixes (within this perimeter)

1. Tasks 1-4 (`coach_profile.dart` permit normalization) — single commit.
2. Task 5 (anon `'CH'` removal) — single commit.
3. Tasks 6-7 (unit + widget tests) — single commit.
4. Task 8 (CI run + PR open).

Each commit atomic + traceable.
